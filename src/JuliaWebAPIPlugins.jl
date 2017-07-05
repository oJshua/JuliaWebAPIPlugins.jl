module JuliaWebAPIPlugins

using JuliaWebAPI
using AMQPClient
using Logging

import JuliaWebAPI: sendrecv, sendresp, recvreq, close
import JuliaWebAPI: wireformat, juliaformat, cmd, args, data, httpresponse, fnresponse

include("amqp_transport.jl")
include("inproc_transport.jl")
include("dict_msgformat.jl")

end # module
