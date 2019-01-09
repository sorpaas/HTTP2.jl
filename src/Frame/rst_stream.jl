struct RstStreamFrame
    stream_identifier::UInt32
    error_code::UInt32
end

==(a::RstStreamFrame, b::RstStreamFrame) =
    a.stream_identifier == b.stream_identifier &&
    a.error_code == b.error_code

function decode_rst_stream(header, payload)
    error_code = (UInt32(payload[1]) << 24 + UInt32(payload[2]) << 16 +
                  UInt32(payload[3]) << 8 + UInt32(payload[4]))

    return RstStreamFrame(header.stream_identifier, error_code)
end

function encode_rst_stream(frame)
    payload::Array{UInt8, 1} = [ UInt8(frame.error_code >> 24);
                                 UInt8(frame.error_code >> 16 & 0x000000ff);
                                 UInt8(frame.error_code >> 8 & 0x000000ff);
                                 UInt8(frame.error_code & 0x000000ff) ]

    return wrap_payload(payload, RST_STREAM, 0x0, frame.stream_identifier)
end
