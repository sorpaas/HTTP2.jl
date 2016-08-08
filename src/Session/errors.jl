@enum ERROR_CODE ERROR_NONE=0x0
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

type ProtocolError
    message::AbstractString
end

type InternalError
    message::AbstractString
end

type NullError end

function goaway!(connection::HTTPConnection, error)
    error_code = if typeof(error) == NullError
        0x0
    elseif typeof(error) == InternalError
        0x2
    else
        0x1
    end

    frame = GoawayFrame(0x0, error_code, Array{UInt8, 1}())

    put!(connection.channel_act_raw, frame)
end

Base.close(connection::HTTPConnection) = goaway!(connection, NullError())
