"""Transport layer over in-process Channels"""


immutable InProcTransport <: AbstractTransport
    name::Symbol

    function InProcTransport(name::Symbol)
        if !(name in keys(InProcChannels))
            InProcChannels[name] = (Channel{Any}(1), Channel{Any}(1))
        end
        new(name)
    end
end

const InProcChannels = Dict{Symbol,Tuple{Channel{Any},Channel{Any}}}()

function sendrecv(conn::InProcTransport, msg)
    clntq,srvrq = InProcChannels[conn.name]

    Logging.debug("sending request: ", msg)
    put!(srvrq, msg)
    resp = take!(clntq)
    Logging.debug("received response: ", resp)
    resp
end

function sendresp(conn::InProcTransport, msg)
    clntq,srvrq = InProcChannels[conn.name]
    Logging.debug("sending response: ", msg)
    put!(clntq, msg)
    nothing
end

function recvreq(conn::InProcTransport)
    clntq,srvrq = InProcChannels[conn.name]
    req = take!(srvrq)
    Logging.debug("received request: ", req)
    req
end

function close(conn::InProcTransport)
    if conn.name in keys(InProcChannels)
        delete!(InProcChannels, conn.name)
    end
    nothing
end
