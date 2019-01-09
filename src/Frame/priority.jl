struct PriorityFrame
    stream_identifier::UInt32
    exclusive::Bool
    dependent_stream_identifier::UInt32
    weight::UInt8
end

==(a::PriorityFrame, b::PriorityFrame) =
    a.stream_identifier == b.stream_identifier &&
    a.exclusive == b.exclusive &&
    a.dependent_stream_identifier == b.dependent_stream_identifier &&
    a.weight == b.weight

function decode_priority(header, payload)
    dependent_stream_identifier = (UInt32(payload[1]) << 24 + UInt32(payload[2]) << 16 +
                                   UInt32(payload[3]) << 8 + UInt32(payload[4])) & 0x7fffffff
    exclusive = payload[1] & 0x80 == 0x80
    weight = payload[5]

    return PriorityFrame(header.stream_identifier, exclusive, dependent_stream_identifier,
                         weight)
end

function encode_priority(frame)
    payload::Array{UInt8, 1} = [ UInt8(frame.dependent_stream_identifier >> 24);
                                 UInt8(frame.dependent_stream_identifier >> 16 & 0x000000ff);
                                 UInt8(frame.dependent_stream_identifier >> 8 & 0x000000ff);
                                 UInt8(frame.dependent_stream_identifier & 0x000000ff) ]
    payload[1] = frame.exclusive ? (payload[1] | 0x80) : payload[1]
    push!(payload, frame.weight)

    return wrap_payload(payload, PRIORITY, 0x0, frame.stream_identifier)
end
