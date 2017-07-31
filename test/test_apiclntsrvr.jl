using JuliaWebAPIPlugins
using Base.Test
using Logging

mytest(v1::AbstractString, v2::AbstractString) = mytest(parse(Int,v1), parse(Int,v2))
mytest(v1::Int, v2::Int) = v1 * v2

function mytestexit()
    info("exiting mytest")
end

function test_apiclntsrvr()
    configure(Dict(:debug_level => Logging.DEBUG))
    srvr = APIServer(mytest, mytestexit, "mytestserver")
    @async run(srvr)

    result = srvrcall("mytestserver", "mytest", 10, 20)
    @test result == 200
end

!isempty(ARGS) && (ARGS[1] == "--run") && test_apiclntsrvr()
