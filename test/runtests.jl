import HTTP2
using HTTP2.Frame
using Base.Test

@test decode(IOBuffer(encode(ContinuationFrame(false, 0x51, b"test")))) ==
    ContinuationFrame(false, 0x51, b"test")
@test decode(IOBuffer(encode(DataFrame(0x51, false, b"test")))) ==
    DataFrame(0x51, false, b"test")
@test decode(IOBuffer(encode(GoawayFrame(0x4f, 0x4, b"test")))) ==
    GoawayFrame(0x4f, 0x4, b"test")
@test decode(IOBuffer(encode(HeadersFrame(false, false, true, 0x51,
                                          Nullable(false), Nullable(0x50),
                                          Nullable(0x1), b"test")))) ==
                                              HeadersFrame(false, false, true, 0x51,
                                                           Nullable(false), Nullable(0x50),
                                                           Nullable(0x1), b"test")
@test decode(IOBuffer(encode(PingFrame(false, b"testtest")))) ==
    PingFrame(false, b"testtest")
@test decode(IOBuffer(encode(PriorityFrame(0x51, false, 0x50, 0x2)))) ==
    PriorityFrame(0x51, false, 0x50, 0x2)
@test decode(IOBuffer(encode(PushPromiseFrame(false, 0x51, 0x54, b"test")))) ==
    PushPromiseFrame(false, 0x51, 0x54, b"test")
@test decode(IOBuffer(encode(RstStreamFrame(0x51, 0x4)))) ==
    RstStreamFrame(0x51, 0x4)
@test decode(IOBuffer(encode(SettingsFrame(true, Nullable())))) == SettingsFrame(true, Nullable())
@test decode(IOBuffer(encode(WindowUpdateFrame(0x51, 0x2)))) ==
    WindowUpdateFrame(0x51, 0x2)

## Run `nghttpd --verbose --no-tls 9000` to make this test pass
stream = HTTP2.request(ip"127.0.0.1", 9000, b"/")

@show stream.received_headers
@show stream.received_body
