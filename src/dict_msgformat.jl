"""
Intermediate format that's just a Dict. No serialization.
A Dict with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable DictMsgFormat <: AbstractMsgFormat
end

wireformat(fmt::DictMsgFormat, cmd::String, args...; data...) = JuliaWebAPI._dict_fmt(cmd, args...; data...)
wireformat(fmt::DictMsgFormat, code::Int, headers::Dict{String,String}, resp, id=nothing) = JuliaWebAPI._dict_fmt(code, headers, resp, id)
juliaformat(fmt::DictMsgFormat, msg) = msg
cmd(fmt::DictMsgFormat, msg) = get(msg, "cmd", "")
args(fmt::DictMsgFormat, msg) = get(msg, "args", [])
data(fmt::DictMsgFormat, msg) = convert(Dict{Symbol,Any}, get(msg, "vargs", Dict{Symbol,Any}()))

"""construct an HTTP Response object from the API response"""
httpresponse(fmt::DictMsgFormat, resp) = JuliaWebAPI._dict_httpresponse(resp)

"""
extract and return the response data as a direct function call would have returned
but throw error if the call was not successful.
"""
fnresponse(fmt::DictMsgFormat, resp) = JuliaWebAPI._dict_fnresponse(resp)
