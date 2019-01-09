struct PingFrame
    is_ack::Bool
    data::Array{UInt8, 1}
end

==(a::PingFrame, b::PingFrame) =
    a.is_ack == b.is_ack &&
    a.data == b.data

function decode_ping(header, payload)
    @assert length(payload) == 8
    @assert header.stream_identifier == 0x0

    is_ack = header.flags & 0x1 == 0x1
    return PingFrame(is_ack, payload)
end

function encode_ping(frame)
    flags = 0x0 | (frame.is_ack ? 0x1 : 0x0)

    return wrap_payload(frame.data, PING, flags, 0x0)
end
