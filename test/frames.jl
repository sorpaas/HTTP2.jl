using HTTP2.Frame
import HTTP2: bytearr

@test decode(IOBuffer(encode(ContinuationFrame(false, 0x51, bytearr("test"))))) == ContinuationFrame(false, 0x51, bytearr("test"))
@test decode(IOBuffer(encode(DataFrame(0x51, false, bytearr("test"))))) == DataFrame(0x51, false, bytearr("test"))
@test decode(IOBuffer(encode(GoawayFrame(0x4f, 0x4, bytearr("test"))))) == GoawayFrame(0x4f, 0x4, bytearr("test"))
@test decode(IOBuffer(encode(HeadersFrame(false, false, true, 0x51, false, 0x50, 0x1, bytearr("test"))))) == HeadersFrame(false, false, true, 0x51, false, 0x50, 0x1, bytearr("test"))
@test decode(IOBuffer(encode(PingFrame(false, bytearr("testtest"))))) == PingFrame(false, bytearr("testtest"))
@test decode(IOBuffer(encode(PriorityFrame(0x51, false, 0x50, 0x2)))) == PriorityFrame(0x51, false, 0x50, 0x2)
@test decode(IOBuffer(encode(PushPromiseFrame(false, 0x51, 0x54, bytearr("test"))))) == PushPromiseFrame(false, 0x51, 0x54, bytearr("test"))
@test decode(IOBuffer(encode(RstStreamFrame(0x51, 0x4)))) == RstStreamFrame(0x51, 0x4)
@test decode(IOBuffer(encode(SettingsFrame(true, nothing)))) == SettingsFrame(true, nothing)
@test decode(IOBuffer(encode(WindowUpdateFrame(0x51, 0x2)))) == WindowUpdateFrame(0x51, 0x2)
