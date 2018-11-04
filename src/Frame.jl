module Frame
import Base: ==

@enum FRAME_TYPES DATA=0x0 HEADERS=0x1 PRIORITY=0x2 RST_STREAM=0x3 SETTINGS=0x4 PUSH_PROMISE=0x5 PING=0x6 GOAWAY=0x7 WINDOW_UPDATE=0x8 CONTINUATION=0x9

struct FrameHeader
    length::UInt32
    typ::FRAME_TYPES
    flags::UInt8
    stream_identifier::UInt32
end

function decode_header(buf)
    length_arr = read(buf, 3)
    length = UInt32(length_arr[1]) << 16 + UInt32(length_arr[2]) << 8 + UInt32(length_arr[3])

    typ = FRAME_TYPES(read(buf, 1)[1])
    flags = read(buf, 1)[1]
    stream_identifier_arr = read(buf, 4)
    stream_identifier = UInt32(stream_identifier_arr[1]) << 24 + UInt32(stream_identifier_arr[2]) << 16 +
        UInt32(stream_identifier_arr[3]) << 8 + UInt32(stream_identifier_arr[4])

    @assert stream_identifier & 0x8000000000 == 0

    return FrameHeader(length, typ, flags, stream_identifier)
end

function encode_header(header::FrameHeader)
    buf = IOBuffer()

    write(buf, UInt8(header.length >> 16), UInt8((header.length >> 8) & 0x000000ff), UInt8(header.length & 0x000000ff))
    write(buf, UInt8(header.typ))
    write(buf, header.flags)

    @assert header.stream_identifier & 0x8000000000 == 0

    write(buf, UInt8(header.stream_identifier >> 24), UInt8((header.stream_identifier >> 16) & 0x000000ff),
          UInt8((header.stream_identifier >> 8) & 0x000000ff), UInt8(header.stream_identifier & 0x000000ff))

    return take!(buf)
end


struct UnimplementedError <: Exception end

include("Frame/utils.jl")
include("Frame/data.jl")
include("Frame/headers.jl")
include("Frame/priority.jl")
include("Frame/rst_stream.jl")
include("Frame/settings.jl")
include("Frame/push_promise.jl")
include("Frame/ping.jl")
include("Frame/goaway.jl")
include("Frame/window_update.jl")
include("Frame/continuation.jl")

function decode(buf)
    header = decode_header(buf)
    payload = read(buf, header.length)
    @assert length(payload) == header.length

    if header.typ == DATA
        return decode_data(header, payload)
    elseif header.typ == HEADERS
        return decode_headers(header, payload)
    elseif header.typ == PRIORITY
        return decode_priority(header, payload)
    elseif header.typ == RST_STREAM
        return decode_rst_stream(header, payload)
    elseif header.typ == SETTINGS
        return decode_settings(header, payload)
    elseif header.typ == PUSH_PROMISE
        return decode_push_promise(header, payload)
    elseif header.typ == PING
        return decode_ping(header, payload)
    elseif header.typ == GOAWAY
        return decode_goaway(header, payload)
    elseif header.typ == WINDOW_UPDATE
        return decode_window_update(header, payload)
    elseif header.typ == CONTINUATION
        return decode_continuation(header, payload)
    else
        throw(ParseError())
    end
end

encode(frame::DataFrame) = encode_data(frame)
encode(frame::HeadersFrame) = encode_headers(frame)
encode(frame::PriorityFrame) = encode_priority(frame)
encode(frame::RstStreamFrame) = encode_rst_stream(frame)
encode(frame::SettingsFrame) = encode_settings(frame)
encode(frame::PushPromiseFrame) = encode_push_promise(frame)
encode(frame::PingFrame) = encode_ping(frame)
encode(frame::GoawayFrame) = encode_goaway(frame)
encode(frame::WindowUpdateFrame) = encode_window_update(frame)
encode(frame::ContinuationFrame) = encode_continuation(frame)

export encode, decode, DataFrame, HeadersFrame, PriorityFrame, RstStreamFrame, SettingsFrame, PushPromiseFrame, PingFrame, GoawayFrame, WindowUpdateFrame, ContinuationFrame

end
