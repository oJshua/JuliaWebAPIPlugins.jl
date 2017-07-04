module JuliaWebAPIPlugins

using JuliaWebAPI
using AMQPClient
using Logging

import JuliaWebAPI: sendrecv, sendresp, recvreq, close

include("amqp_transport.jl")

end # module
