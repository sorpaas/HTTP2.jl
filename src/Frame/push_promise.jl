type PushPromiseFrame
    is_end_headers::Bool
    stream_identifier::UInt32
    promised_stream_identifier::UInt32
    fragment::Array{UInt8, 1}
end

function decode_push_promise(header, payload)
    is_end_headers = header.flags & 0x4 == 0x4

    payload = remove_padding(header, payload)

    promised_stream_identifier = (UInt32(payload[1]) << 24 + UInt32(payload[2]) << 16 +
                                  UInt32(payload[3]) << 8 + UInt32(payload[4])) & 0x7fffffff
    fragment = getindex(payload, 5:length(payload))

    return PushPromiseFrame(is_end_headers, header.stream_identifier, promised_stream_identifier,
                            fragment)
end

function encode_push_promise(frame)
    flags = 0x0 | frame.is_end_headers ? 0x4 : 0x0
    payload = [ UInt8(header.promised_stream_identifier >> 24) & 0x7f;
                UInt8(header.promised_stream_identifier >> 16 & 0x000000ff);
                UInt8(header.promised_stream_identifier >> 8 & 0x000000ff);
                UInt8(header.promised_stream_identifier & 0x000000ff) ]
    append!(payload, frame.fragment)

    return wrap_payload(payload, PUSH_PROMISE, flags, frame.stream_identifier)
end
