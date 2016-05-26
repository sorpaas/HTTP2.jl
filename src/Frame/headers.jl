type HeadersType
    is_end_stream::Bool
    is_end_headers::Bool
    is_priority::Bool
    stream_identifier::UInt32
    exclusive::Nullable{Bool}
    dependent_stream_identifier::Nullable{UInt32}
    weight::Nullable{UInt8}
    fragment::Array{UInt8, 1}
end

function decode_headers(header, payload)
    is_end_stream = header.flags & 0x1 == 0x1
    is_end_headers = header.flags & 0x4 == 0x4
    is_priority = header.flags & 0x20 == 0x20

    payload = remove_padding(header, payload)

    if is_priority
        dependent_stream_identifier = (UInt32(payload[1]) << 24 + UInt32(payload[2]) << 16 +
                                       UInt32(payload[3]) << 8 + UInt32(payload[4])) & 0x7fffffff
        exclusive = payload[1] & 0x80 == 0x80
        weight = payload[5]

        return HeadersType(is_end_stream, is_end_headers, is_priority, header.stream_identifier,
                           Nullable(exclusive), Nullable(dependent_stream_identifier),
                           Nullable(weight), getindex(payload, 6:length(payload)))
    else
        return HeadersType(is_end_stream, is_end_headers, is_priority, header.stream_identifier,
                           Nullable{Bool}(), Nullable{UInt32}(), Nullable{UInt8}(), payload)
end

function encode_headers(frame)
    typ = HEADERS
    flags = 0x0 | frame.is_end_stream ? 0x1 : 0x0 | frame.is_end_headers ? 0x4 : 0x0 |
        frame.is_priority ? 0x20 : 0x0

    if frame.is_priority
        payload::Array{UInt8, 1} = [ UInt8(header.dependent_stream_identifier >> 24) & 0x7f;
                                     UInt8(header.dependent_stream_identifier >> 16 & 0x000000ff);
                                     UInt8(header.dependent_stream_identifier >> 8 & 0x000000ff);
                                     UInt8(header.dependent_stream_identifier & 0x000000ff) ]
        payload[1] = frame.exclusive ? (payload[1] | 0x80 ) : payload[1]
        push!(payload, frame.weight)
        append!(payload, frame.fragment)
    else
        payload = frame.fragment
    end

    return wrap_payload(payload, typ, flags, frame.stream_identifier)
end
