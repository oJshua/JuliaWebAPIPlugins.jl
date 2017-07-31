# Tests SerializedMsgFormat in async mode operation.
# Both server and client run in the same process.
# In this mode the transport can be in-memory.
using JuliaWebAPIPlugins

include("srvr.jl")
include("clnt.jl")

function test_amqp_transport_ser()
    stport = JuliaWebAPIPlugins.AMQPTransport("juliawebapi", :server)
    run_srvr(JuliaWebAPI.SerializedMsgFormat(), stport, true)
    run_clnt(JuliaWebAPI.SerializedMsgFormat(), JuliaWebAPIPlugins.AMQPTransport("juliawebapi", :client))
    close(stport)
end

function test_amqp_transport_json()
    stport = JuliaWebAPIPlugins.AMQPTransport("juliawebapi", :server)
    run_srvr(JuliaWebAPI.JSONMsgFormat(), stport, true)
    run_clnt(JuliaWebAPI.JSONMsgFormat(), JuliaWebAPIPlugins.AMQPTransport("juliawebapi", :client))
    close(stport)
end

# run tests
!isempty(ARGS) && (ARGS[1] == "--ser") && test_amqp_transport_ser()
!isempty(ARGS) && (ARGS[1] == "--json") && test_amqp_transport_json()
