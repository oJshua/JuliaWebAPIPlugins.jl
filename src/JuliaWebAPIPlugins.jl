module JuliaWebAPIPlugins

using JuliaWebAPI
using AMQPClient
using Logging

import JuliaWebAPI: sendrecv, sendresp, recvreq, close
import JuliaWebAPI: wireformat, juliaformat, cmd, args, data, httpresponse, fnresponse

import Base: run
export AMQPTransport
export APIClient, srvrcall, hasclient, purgeclients, closeclient
export APIServer, run, configure

include("amqp_transport.jl")
include("amqp_client_server.jl")

end # module
