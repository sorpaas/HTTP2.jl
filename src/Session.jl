module Stream

import HPack: DynamicTable, Header
import Frame: ContinuationFrame, DataFrame, GoawayFrame, HeadersFrame, PingFrame, PriorityFrame, PushPromiseFrame, RstStreamFrame, SettingsFrame, WindowUpdateFrame

@enum STREAM_STATE IDLE=1 RESERVED_LOCAL=2 RESERVED_REMOTE=3 OPEN=4 HALF_CLOSED_REMOTE=5 HALF_CLOSED_LOCAL=6 CLOSED=7

type Priority
    dependent_stream_identifier::UInt32
    weight::UInt8
end

type Stream
    stream_identifier::UInt32
    state::STREAM_STATE
    sending_headers::Array{Header, 1}
    sending_body::Array{UInt8, 1}
    received_headers::Array{Header, 1}
    received_body::Array{UInt8, 1}
    window_size::UInt32
    priority::Nullable{Priority}
end

type HeaderContinuation
    header::HeaderFrame
    continuations::Array{ContinuationFrame, 1}
end

type Connection
    dynamic_table::DynamicTable
    streams::Array{Stream, 1}
    window_size::UInt32
    header_continuations::Nullable{HeaderContinuation}
end

function send!(connection::Connection, outbuf::IOBuffer,
               stream_identifier::UInt32, headers::Array{Header, 1}, body::Array{UInt8, 1})
    stream = get_stream(connection, stream_identifier)
    stream.sending_headers = headers
    stream.sending_body = body
    send_stream_header_continuation(connection, outbuf, stream_identifier)
end

function promise!(connection::Connection, outbuf::IOBuffer, stream_identifier::UInt32,
                  request_headers::Array{Header, 1},
                  headers::Array{Header, 1}, body::Array{UInt8, 1})
    stream = get_stream(connection, stream_identifier)
    stream.receiving_headers = request_headers
    stream.sending_headers = headers
    stream.sending_body = body
    send_stream_push_promise(connection, outbuf, stream_identifier)
end

function handle_setting(connection::Connection, key::Frame.SETTING_IDENTIFIER, value::UInt32)
    if key == Frame.SETTINGS_HEADER_TABLE_SIZE
        HPack.set_max_table_size!(connection.dynamic_table, Int(value))
    else
        assert!(false) # Not yet implemented
    end
end

function recv_next(connection::Connection, inbuf::IOBuffer, outbuf::IOBuffer)
    frame = decode(inbuf)

    if typeof(frame) == DataFrame
        @assert frame.stream_identifier != 0x0
        recv_stream_data(connection, frame)
    elseif typeof(frame) == HeadersFrame
        @assert frame.stream_identifier != 0x0

        continuations = Array{ContinuationFrame, 1}()
        while frame.is_end_headers ||
            (!frame.is_end_headers && length(continuations) == 0) ||
            continuations[length(continuations)].is_end_headers

            continuation = Frame.decode(inbuf)
            @assert typeof(continuation) == ContinuationFrame &&
                continuation.stream_identifier == frame.stream_identifier
            push!(continuations, continuation)
        end
        recv_stream_headers_continuation(connection, frame, continuations)
    elseif typeof(frame) == PriorityFrame
        @assert frame.stream_identifier != 0x0

        recv_stream_priority(connection, frame)
    elseif typeof(frame) == RstStreamFrame
        @assert frame.stream_identifier != 0x0

        recv_stream_rst_stream(connection, frame)
    elseif typeof(frame) == SettingsFrame
        @assert frame.stream_identifier == 0x0

        if !frame.is_ack
            parameters = frame.parameters.value
            if length(parameters) > 0
                for i = 1:length(parameters)
                    handle_setting(connection, parameters[i][1], parameters[i][2])
                end
            end

            write(outbuf, SettingsFrame(true, Nullable{Tuple{Frame.SETTING_IDENTIFIER, UInt32}}()))
        end
    elseif typeof(frame) == PushPromiseFrame
        @assert frame.stream_identifier != 0x0

        continuations = Array{ContinuationFrame, 1}()
        while frame.is_end_headers ||
            (!frame.is_end_headers && length(continuations) == 0) ||
            continuations[length(continuations)].is_end_headers

            continuation = Frame.decode(inbuf)
            assert!((typeof(continuation) == ContinuationFrame) &&
                    continuation.stream_identifier == frame.stream_identifier)
            push!(continuations, continuation)
        end
        recv_stream_push_promise(connection, frame, continuations)
    elseif typeof(frame) == PingFrame
        @assert frame.stream_identifier != 0x0

        write(outbuf, PingFrame(true, frame.data))
    elseif typeof(frame) == GoawayFrame
        @assert false
    elseif typeof(frame) == WindowUpdateFrame
        if frame.stream_identifier == 0x0
            connection.window_size += frame.window_size_increment
        else
            recv_stream_window_update(connection, frame)
        end
    else
        @assert false
    end
end

function select_next(streams::Array{Stream, 1}, ignored::Array{Stream, 1})
    @assert length(stream) > 0

    if length(ignored) == 0
        return Nullable(streams[1])
    end

    for i = 1:length(streams)
        selectable = true
        for j = 1:length(ignored)
            if streams[i] == ignored[j]
                selectable = false
            end
        end
        if selectable
            return Nullable(streams[i])
        end
    end

    return Nullable{Stream}()
end

function send_next(connection::Connection, outbuf::IOBuffer; ignored=Array{Stream, 1}())
    stream_nullable = select_next(connection.streams, ignored)

    if isnull(stream_nullable)
        return
    end

    stream = stream_nullable.value

    if stream.state == RESERVED_LOCAL
        send_stream_header_continuations(connection, outbuf, stream.stream_identifier)
        # RESERVED_LOCAL -> HALF_CLOSED_REMOTE

        send_stream_data(connection, outbuf, stream.streaam_identifier)
        # HALF_CLOSED_REMOTE -> CLOSED
    elseif stream.state == OPEN
        send_stream_data(connection, outbuf, stream.stream_identifier)
        # OPEN -> HALF_CLOSED_LOCAL

    elseif stream.state == HALF_CLOSED_REMOTE
        send_stream_header_continuations(connection, outbuf, stream.stream_identifier)
        send_stream_data(connection, outbuf, stream.stream_identifier)

    else
        push!(ignored, stream)
        return send_next(connection, outbuf; ignored=ignored)
    end
end

include("Session/utils.jl")
include("Session/handlers.jl")

end
