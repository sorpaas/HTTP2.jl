type PingFrame
    is_ack::Bool
    stream_identifier::UInt32
    data::Array{UInt8, 1}
end

function decode_ping(header, payload)
    @assert length(payload) == 8

    is_ack = header.flags & 0x1 == 0x1
    return PingFrame(is_ack, header.stream_identifier, payload)
end

function encode_ping(frame)
    flags = 0x0 | frame.is_ack ? 0x1 : 0x0

    return wrap_payload(frame.data, PING, flags, frame.stream_identifier)
end
