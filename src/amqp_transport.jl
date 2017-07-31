"""Transport layer over Message Queues"""
type AMQPTransportClient
    queue::String
    correlation_id::Int
end

immutable AMQPTransport <: AbstractTransport
    queue::String
    mode::Symbol # :client / :server
    mqconn::Any
    mqchan::Any
    consumer_tag::String
    msgchan::Channel{AMQPClient.Message}
    client::AMQPTransportClient

    function AMQPTransport(queue::String, mode::Symbol; virtualhost="/", host="localhost", port=AMQPClient.AMQP_DEFAULT_PORT, auth_params=AMQPClient.DEFAULT_AUTH_PARAMS)
        Logging.info("opening connection...")
        conn = connection(;virtualhost=virtualhost, host=host, port=port, auth_params=auth_params)
        Logging.info("opening channel...")
        chan1 = channel(conn, AMQPClient.UNUSED_CHANNEL, true)
        Logging.info("opening message channel...")
        msgchan = Channel{AMQPClient.Message}(1) # should use unbuffered channels in Julia v0.6

        rpc_fn = (rcvd_msg) -> begin
            put!(msgchan, rcvd_msg)
        end
        Logging.info("initializing as ", mode)

        if mode === :client
            # create a reply queue for the client
            client_queue = string(Base.Random.uuid1())
            success, message_count, consumer_count = queue_declare(chan1, client_queue; exclusive=true)
            @assert success

            # start a consumer task
            success, consumer_tag = basic_consume(chan1, client_queue, rpc_fn)
            @assert success
            client = AMQPTransportClient(client_queue, 0)

            success, message_count, consumer_count = queue_declare(chan1, queue; durable=true)
            @assert success
            # wait till server queue is set up (if queue is not durable)
            while consumer_count == 0
                Logging.info("waiting for consumers...")
                sleep(5)
                success, message_count, consumer_count = queue_declare(chan1, queue; durable=true)
            end
            new(queue, mode, conn, chan1, consumer_tag, msgchan, client)
        elseif mode === :server
            # create a server queue
            Logging.info("creating server queue...")
            success, message_count, consumer_count = queue_declare(chan1, queue; durable=true)
            Logging.info("created server queue...")
            @assert success

            # start a consumer task
            success, consumer_tag = basic_consume(chan1, queue, rpc_fn)
            @assert success
            client = AMQPTransportClient("", 0)
            new(queue, mode, conn, chan1, consumer_tag, msgchan, client)
        else
            error("Unknown mode $mode")
        end
    end
end

function sendrecv(conn::AMQPTransport, msgstr)
    Logging.debug("sending request: ", msgstr)

    if conn.client.correlation_id == typemax(Int)
        conn.client.correlation_id = 0
    end
    conn.client.correlation_id += 1

    M = AMQPClient.Message(convert(Vector{UInt8}, msgstr), content_type="application/octet-stream", delivery_mode=PERSISTENT, reply_to=conn.client.queue, correlation_id=string(conn.client.correlation_id))
    basic_publish(conn.mqchan, M; exchange=default_exchange_name(), routing_key=conn.queue)
    respstr = ""

    while true
        rcvd_msg = take!(conn.msgchan)
        correlation_id = convert(String, rcvd_msg.properties[:correlation_id])
        basic_ack(conn.mqchan, rcvd_msg.delivery_tag)
        # ignore messages if not matching correlation id (could be a resend of something already processed)
        if correlation_id == string(conn.client.correlation_id)
            respstr = String(rcvd_msg.data)
            break
        end
    end

    Logging.debug("received response: ", respstr)
    respstr
end

function sendresp(conn::AMQPTransport, msgstr)
    Logging.debug("sending response: ", msgstr)
    M = AMQPClient.Message(convert(Vector{UInt8}, msgstr), content_type="application/octet-stream", delivery_mode=PERSISTENT, correlation_id=string(conn.client.correlation_id))
    basic_publish(conn.mqchan, M; exchange=default_exchange_name(), routing_key=conn.client.queue)
    nothing
end

function recvreq(conn::AMQPTransport)
    rcvd_msg = take!(conn.msgchan)
    conn.client.queue = convert(String, rcvd_msg.properties[:reply_to])
    conn.client.correlation_id = parse(Int, convert(String, rcvd_msg.properties[:correlation_id]))
    reqstr = String(rcvd_msg.data)
    Logging.debug("received request: ", reqstr)
    basic_ack(conn.mqchan, rcvd_msg.delivery_tag)
    reqstr
end

function close(conn::AMQPTransport)
    if conn.mode === :client
        queue = conn.client.queue
    elseif conn.mode === :server
        queue = conn.queue
    else
        error("Unknown mode $mode")
    end

    queue_purge(conn.mqchan, queue)
    basic_cancel(conn.mqchan, conn.consumer_tag)
    queue_delete(conn.mqchan, queue)
    close(conn.mqchan)
    close(conn.mqconn)
    nothing
end
