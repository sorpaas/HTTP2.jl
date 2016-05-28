function remove_padding(header, payload)
    is_padded = header.flags & 0x8 == 0x8

    if is_padded
        pad_length = payload[1]
        return getindex(payload, 2:(length(payload) - pad_length))
    else
        return payload
    end
end

function wrap_payload(payload, typ, flags, stream_identifier)
    len = length(payload)
    result = encode_header(FrameHeader(len, typ, flags, stream_identifier))
    append!(result, payload)

    return result
end
