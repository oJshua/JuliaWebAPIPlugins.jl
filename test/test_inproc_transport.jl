# Tests SerializedMsgFormat in async mode operation.
# Both server and client run in the same process.
# In this mode the transport can be in-memory.
using JuliaWebAPIPlugins

include("srvr.jl")
include("clnt.jl")

function test_inproc_transport()
    run_srvr(JuliaWebAPIPlugins.DictMsgFormat(), JuliaWebAPIPlugins.InProcTransport(:juliawebapi), true)
    run_clnt(JuliaWebAPIPlugins.DictMsgFormat(), JuliaWebAPIPlugins.InProcTransport(:juliawebapi))
end

# run tests
test_inproc_transport()
