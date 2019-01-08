@enum ERROR_CODE begin
    ERROR_NONE=0x0
    ERROR_PROTOCOL=0x1
    ERROR_INTERNAL=0x2
    ERROR_FLOW_CONTROL=0x3
    ERROR_SETTINGS_TIMEOUT=0x4
    ERROR_STREAM_CLOSED=0x5
    ERROR_FRAME_SIZE=0x6
    ERROR_REFUSED_STREAM=0x7
    ERROR_CANCEL=0x8
    ERROR_COMPRESSION=0x9
    ERROR_CONNECT=0xa
    ERROR_ENHANCE_YOUR_CALM=0xb
    ERROR_INADEQUATE_SECURITY=0xc
    ERROR_HTTP_1_1_REQUIRED=0xd
end

struct ProtocolError
    message::String
end

struct InternalError
    message::String
end

struct NullError end

function goaway!(connection::HTTPConnection, error)
    error_code = if typeof(error) == NullError
        ERROR_NONE
    elseif typeof(error) == InternalError
        ERROR_INTERNAL
    else
        ERROR_PROTOCOL
    end

    frame = GoawayFrame(0x0, UInt32(error_code), Array{UInt8, 1}())

    put!(connection.channel_act_raw, frame)
end

Base.close(connection::HTTPConnection) = goaway!(connection, NullError())
