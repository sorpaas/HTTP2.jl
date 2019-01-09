module HTTP2

using MbedTLS

const Headers = Vector{Tuple{String,String}}

bytearr(a::Vector{UInt8}) = a
bytearr(cs::Base.CodeUnits{UInt8,String}) = convert(Vector{UInt8}, cs)
bytearr(s::String) = bytearr(codeunits(s))

readallbytes(s, nbytes) = read(s, nbytes)
function readallbytes(s::MbedTLS.SSLContext, nbytes)
    finalbuf = Vector{UInt8}(undef, nbytes)
    lfinal = 0
    while (lfinal < nbytes) && !eof(s)
        toread = nbytes - lfinal
        buf = Vector{UInt8}(undef, toread)
        readbytes!(s, buf, toread)
        nread = length(buf)
        if nread > 0
            copyto!(finalbuf, lfinal+1, buf)
            lfinal += nread
        else
            yield()
        end
    end
    finalbuf
end

# package code goes here
include("Frame.jl")
include("Session.jl")

end # module
