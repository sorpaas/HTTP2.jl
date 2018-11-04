struct WindowUpdateFrame
    stream_identifier::UInt32
    window_size_increment::UInt32
end

==(a::WindowUpdateFrame, b::WindowUpdateFrame) =
    a.stream_identifier == b.stream_identifier &&
    a.window_size_increment == b.window_size_increment

function decode_window_update(header, payload)
    window_size_increment = (UInt32(payload[1]) << 24 + UInt32(payload[2]) << 16 +
                             UInt32(payload[3]) << 8 + UInt32(payload[4])) & 0x7fffffff

    return WindowUpdateFrame(header.stream_identifier, window_size_increment)
end

function encode_window_update(frame)
    payload = [ UInt8(frame.window_size_increment >> 24) & 0x7f;
                UInt8(frame.window_size_increment >> 16 & 0x000000ff);
                UInt8(frame.window_size_increment >> 8 & 0x000000ff);
                UInt8(frame.window_size_increment & 0x000000ff) ]

    return wrap_payload(payload, WINDOW_UPDATE, 0x0, frame.stream_identifier)
end
