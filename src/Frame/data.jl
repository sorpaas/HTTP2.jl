struct DataFrame
    stream_identifier::UInt32
    is_end_stream::Bool
    data::Array{UInt8, 1}
end

==(a::DataFrame, b::DataFrame) =
    a.stream_identifier == b.stream_identifier &&
    a.is_end_stream == b.is_end_stream &&
    a.data == b.data

function decode_data(header, payload)
    is_end_stream = header.flags & 0x1 == 0x1

    payload = remove_padding(header, payload)

    return DataFrame(header.stream_identifier, is_end_stream, payload)
end

function encode_data(frame)
    typ = DATA
    flags = 0x0 | (frame.is_end_stream ? 0x1 : 0x0)
    stream_identifier = frame.stream_identifier

    return wrap_payload(frame.data, typ, flags, frame.stream_identifier)
end
