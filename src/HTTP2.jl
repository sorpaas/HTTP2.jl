module HTTP2

const Headers = Dict{String,String}

bytearr(a::Vector{UInt8}) = a
bytearr(cs::Base.CodeUnits{UInt8,String}) = convert(Vector{UInt8}, cs)
bytearr(s::String) = bytearr(codeunits(s))

# package code goes here
include("Frame.jl")
include("Session.jl")

end # module
