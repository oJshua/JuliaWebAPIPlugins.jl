const JSON_RESP_HDRS = Dict{String,String}("Content-Type" => "application/json; charset=utf-8")
const configuration = Dict(
    :virtualhost => "/",
    :host => "localhost",
    :port => AMQPClient.AMQP_DEFAULT_PORT,
    :auth_params => AMQPClient.DEFAULT_AUTH_PARAMS,
    :inactivity_timeout_secs => 240,
    :debug_level => Logging.WARNING
)

function configure(d::Dict)
    for (n,v) in d
        configuration[Symbol(n)] = v
    end
    api_clients.timeout = configuration[:inactivity_timeout_secs]
    Logging.configure(; level=configuration[:debug_level])
    nothing
end

amqp_params() = filter((n,v)->(n in (:virtualhost, :host, :port, :auth_params)), configuration)

"""
A message queue based client.
Can call multiple services.
Caches connections.
"""
type APIClient
    srvrs::Dict{String,Tuple}
    timeout::Int
    purged_time::Float64

    function APIClient(timeout::Int=typemax(Int))
        new(Dict{String,Tuple}(), timeout, time())
    end
end

"""Singleton client instance used by exported APIs"""
const api_clients = APIClient(configuration[:inactivity_timeout_secs])

function srvrcall(srvrname::String, command::String, args...; kwargs...)
    invoker,transport = getclient(srvrname)

    info("invoking ", srvrname, ": ", command)
    result = apicall(invoker, command, args...; kwargs...)
    info("got result ", result)

    if "data" in keys(result)
        data = result["data"]
        if "code" in keys(data)
            code = data["code"]
            if code == 0
                return data["data"]
            end
        end
    end
    error("Server error: ", result)
end

function getclient(name::String)
    clnt = api_clients
    if hasclient(name)
        invoker,transport,lastused = clnt.srvrs[name]
    else
        info("creating a conenction to ", name, "...")
        transport = JuliaWebAPIPlugins.AMQPTransport(name, :client; amqp_params()...)
        msgformat = JuliaWebAPI.SerializedMsgFormat()
        invoker = APIInvoker(transport, msgformat)
    end
    clnt.srvrs[name] = (invoker,transport,time())
    invoker,transport
end

function hasclient(name::String)
    clnt = api_clients
    !(name in keys(clnt.srvrs)) && (return false)
    invoker,transport,lastused = clnt.srvrs[name]
    if (time() - lastused) > clnt.timeout
        closeclient(name)
        return false
    end
    if (time() - clnt.purged_time) > (clnt.timeout * 5)
        purgeclients()
    end
    true
end

function purgeclients()
    clnt = api_clients
    for name in collect(keys(clnt.srvrs))
        invoker,transport,lastused = clnt.srvrs[name]
        if (time() - lastused) > clnt.timeout
            closeclient(name)
        end
    end
    clnt.purged_time = time()
    nothing
end

function closeclient(name::String)
    clnt = api_clients
    if name in keys(clnt.srvrs)
        invoker,transport,lastused = clnt.srvrs[name]
        close(transport)
        delete!(clnt.srvrs, name)
    end
end

"""
A message queue based service.
Receives a request to process from an upstream server.
Exits on inactivity, or upon receiving an exit command from upstream.
"""
type APIServer
    name::String
    srvr::APIResponder
    srvr_task::Union{Void,Task}
    last_busy::Float64
    command::Function
    atexit::Function
    inactivity_timeout::Int

    function APIServer(command, atexit, name::String)
        transport = JuliaWebAPIPlugins.AMQPTransport(name, :server; amqp_params()...)
        info("APIServer ", name, " created transport")
        msgformat = JuliaWebAPI.SerializedMsgFormat()

        srvr = APIResponder(transport, msgformat)
        endpt = JuliaWebAPI.default_endpoint(command)
        register(srvr, command_wrapper; endpt=endpt, resp_json=true, resp_headers=JSON_RESP_HDRS)
        register(srvr, atexit; endpt="exit", resp_json=true, resp_headers=JSON_RESP_HDRS)

        new(name, srvr, nothing, time(), command, atexit, configuration[:inactivity_timeout_secs])
    end
end

function run(srvr::APIServer)
    global srvr_instance = srvr
    info("APIServer $(srvr.name) starting...")
    srvr.srvr_task = @async process(srvr.srvr)

    # wait till we are receiving requests
    while !istaskdone(srvr.srvr_task) && ((time() - srvr.last_busy) < srvr.inactivity_timeout)
        sleep(5)
    end
    reason = istaskdone(srvr.srvr_task) ? "upstream command" : "inactivity"
    info("APIServer $(srvr.name) exiting due to $reason")
    close(srvr.srvr.transport)
    srvr.atexit()
    nothing
end

function command_wrapper(args...; kwargs...)
    global srvr_instance
    done = false
    keepalive_task = @async begin
        while !done
            srvr_instance.last_busy = time()
            sleep(30)
        end
    end

    try
        srvr_instance.command(args...; kwargs...)
    finally
        done = true
    end
end
