struct GoawayFrame
    last_stream_identifier::UInt32
    error_code::UInt32
    debug_data::Array{UInt8, 1}
end

==(a::GoawayFrame, b::GoawayFrame) =
    a.last_stream_identifier == b.last_stream_identifier &&
    a.error_code == b.error_code &&
    a.debug_data == b.debug_data

function decode_goaway(header, payload)
    @assert header.stream_identifier == 0x0

    last_stream_identifier = (UInt32(payload[1]) << 24 + UInt32(payload[2]) << 16 +
                              UInt32(payload[3]) << 8 + UInt32(payload[4])) & 0x7fffffff
    error_code = UInt32(payload[5]) << 24 + UInt32(payload[6]) << 16 +
        UInt32(payload[7]) << 8 + UInt32(payload[8])
    debug_data = getindex(payload, 9:length(payload))

    return GoawayFrame(last_stream_identifier, error_code, debug_data)
end

function encode_goaway(frame)
    payload::Array{UInt8, 1} = [ UInt8(frame.last_stream_identifier >> 24) & 0x7f;
                                 UInt8(frame.last_stream_identifier >> 16 & 0x000000ff);
                                 UInt8(frame.last_stream_identifier >> 8 & 0x000000ff);
                                 UInt8(frame.last_stream_identifier & 0x000000ff);
                                 UInt8(frame.error_code >> 24);
                                 UInt8(frame.error_code >> 16 & 0x000000ff);
                                 UInt8(frame.error_code >> 8 & 0x000000ff);
                                 UInt8(frame.error_code & 0x000000ff) ]
    append!(payload, frame.debug_data)

    return wrap_payload(payload, GOAWAY, 0x0, 0x0)
end
