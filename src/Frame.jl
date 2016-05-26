module Frame

type FrameHeader
    length::UInt32
    typ::UInt8
    flags::UInt8
    stream_identifier::UInt32
end

function decode_header(buf::IOBuffer)
    length_arr = readbytes(buf, nb=3; all=true)
    length = UInt32(length_arr[1]) << 16 + UInt32(length_arr[2]) << 8 + UInt32(length_arr[3])

    typ = read(buf, UInt8)
    flags = read(buf, UInt8)
    stream_identifier_arr = readbytes(buf, nb=4; all=true)
    stream_identifier = UInt32(stream_identifier_arr[1]) << 24 + UInt32(stream_identifier_arr[2]) << 16 +
        UInt32(stream_identifier_arr[3]) << 8 + UInt32(stream_identifier_arr[4])

    @assert stream_identifier & 0x8000000000 == 0

    return FrameHeader(length, typ, flags, stream_identifier)
end

function encode_header(header::FrameHeader)
    buf = IOBuffer()

    write(buf, UInt8(header.length >> 16), UInt8((header.length >> 8) & 0x000000ff), UInt8(header.length & 0x000000ff))
    write(buf, header.typ)
    write(buf, header.flags)

    @assert header.stream_identifier & 0x8000000000 == 0

    write(buf, header.stream_identifier)

    return takebuf_array(buf)
end

end
