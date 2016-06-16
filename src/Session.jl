module Session

import HPack
import HPack: DynamicTable, Header
import HTTP2.Frame
import HTTP2.Frame: ContinuationFrame, DataFrame, GoawayFrame, HeadersFrame, PingFrame, PriorityFrame, PushPromiseFrame, RstStreamFrame, SettingsFrame, WindowUpdateFrame

@enum STREAM_STATE IDLE=1 RESERVED_LOCAL=2 RESERVED_REMOTE=3 OPEN=4 HALF_CLOSED_REMOTE=5 HALF_CLOSED_LOCAL=6 CLOSED=7

type Priority
    dependent_stream_identifier::UInt32
    weight::UInt8
end

type HTTPStream
    stream_identifier::UInt32
    state::STREAM_STATE
    sending_headers::Array{Header, 1}
    sending_body::Array{UInt8, 1}
    received_headers::Array{Header, 1}
    received_body::Array{UInt8, 1}
    window_size::UInt32
    priority::Nullable{Priority}
    channel_in::Channel{Any}
end

type HTTPConnection
    dynamic_table::DynamicTable
    streams::Array{HTTPStream, 1}
    window_size::UInt32
    buffer::TCPSocket
    channel_in::Channel{Any}
    channel_out::Channel{Any}
    isclient::Bool
end

include("Session/utils.jl")
include("Session/handlers.jl")

## Stream specific handlers

function stream_loop(connection::HTTPConnection, stream::HTTPStream)
    channel_in = stream.channel_in
    channel_out = connection.channel_out

    while true
        frame = take!(channel_in)

        if typeof(frame) == DataFrame
            recv_stream_data(connection, frame)
        elseif typeof(frame) == HeadersFrame
            continuations = Array{ContinuationFrame, 1}()
            while !(frame.is_end_headers ||
                    (!frame.is_end_headers && length(continuations) == 0) ||
                    continuations[length(continuations)].is_end_headers)

                continuation = Frame.decode(buffer)
                @assert typeof(continuation) == ContinuationFrame &&
                    continuation.stream_identifier == frame.stream_identifier
                push!(continuations, continuation)
            end
            recv_stream_headers_continuations(connection, frame, continuations)
        elseif typeof(frame) == PriorityFrame
            recv_stream_priority(connection, frame)
        elseif typeof(frame) == RstStreamFrame
            recv_stream_rst_stream(connection, frame)
        elseif typeof(frame) == PushPromiseFrame
            continuations = Array{ContinuationFrame, 1}()
            while !(frame.is_end_headers ||
                    (!frame.is_end_headers && length(continuations) == 0) ||
                    continuations[length(continuations)].is_end_headers)

                continuation = Frame.decode(buffer)
                assert!((typeof(continuation) == ContinuationFrame) &&
                        continuation.stream_identifier == frame.stream_identifier)
                push!(continuations, continuation)
            end
            recv_stream_push_promise(connection, frame, continuations)
        elseif typeof(frame) == WindowUpdateFrame
            recv_stream_window_update(connection, frame)
        else
            @assert false
        end
    end
end

function get_stream(connection::HTTPConnection, stream_identifier::UInt32)
    @assert stream_identifier != 0x0

    for i = 1:length(connection.streams)
        if connection.streams[i].stream_identifier == stream_identifier
            return connection.streams[i]
        end
    end

    stream = HTTPStream(stream_identifier, IDLE,
                        Array{HPack.Header, 1}(), Array{UInt8, 1}(),
                        Array{HPack.Header, 1}(), Array{UInt8, 1}(),
                        65535, Nullable{Priority}(), Channel{Any}())

    @async begin
        stream_loop(connection, stream)
    end

    push!(connection.streams, stream)
    return stream
end

## Connection handlers

function handle_setting(connection::HTTPConnection, key::Frame.SETTING_IDENTIFIER, value::UInt32)
    if key == Frame.SETTINGS_HEADER_TABLE_SIZE
        HPack.set_max_table_size!(connection.dynamic_table, Int(value))
    else
        ## TODO implement this
    end
end

function connection_loop(connection::HTTPConnection)
    buffer = connection.buffer
    channel_in = connection.channel_in
    channel_out = connection.channel_out

    ## Initialize the connection
    CLIENT_PREFACE = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    if connection.isclient
        write(buffer, CLIENT_PREFACE)
    else
        @assert readbytes(buffer, length(CLIENT_PREFACE)) == CLIENT_PREFACE
    end

    ## Deal with incoming frames
    @async begin
        while true
            frame = Frame.decode(buffer)
            put!(channel_in, frame)
        end
    end

    ## Deal with outgoing frames
    @async begin
        while true
            ## TODO Take in account of flow control
            frame = take!(channel_out)
            write(buffer, Frame.encode(frame))
        end
    end

    while true
        frame = take!(channel_in)

        if typeof(frame) == SettingsFrame
            ## Frames where stream identifier is 0x0
            if !frame.is_ack
                parameters = frame.parameters.value
                if length(parameters) > 0
                    for i = 1:length(parameters)
                        handle_setting(connection, parameters[i][1], parameters[i][2])
                    end
                end
                put!(channel_out, SettingsFrame(true, Nullable{Tuple{Frame.SETTING_IDENTIFIER, UInt32}}()))
            end
        elseif typeof(frame) == PingFrame
            put!(channel_out, PingFrame(true, frame.data))
        elseif typeof(frame) == GoawayFrame
            @assert false
        elseif typeof(frame) == WindowUpdateFrame && frame.stream_identifier == 0x0
            connection.window_size += frame.window_size_increment
        else
            ## Frames where stream identifier is not 0x0
            stream_identifier = frame.stream_identifier
            @assert stream_identifier != 0x0
            stream = get_stream(connection, stream_identifier)
            put!(stream.channel_in, frame)
        end
    end
end

function new_connection(buffer::TCPSocket; isclient::Bool=true)
    connection = HTTPConnection(HPack.new_dynamic_table(), Array{HTTPStream, 1}(), 65535, buffer, Channel{Any}(), Channel{Any}(), isclient)
    channel = connection.channel

    @async begin
        connection_loop(connection)
    end
    put!(channel, SettingsFrame(false, Nullable(Array{Tuple{Frame.SETTING_IDENTIFIER, UInt32}, 1}())))
    return connection
end

function send!(connection::HTTPConnection, stream_identifier::UInt32, headers::Array{Header, 1}, body::Array{UInt8, 1})
    buffer = connection.buffer
    stream = get_stream(connection, stream_identifier)
    stream.sending_headers = headers
    stream.sending_body = body
    send_stream_headers_continuations(connection, stream_identifier)
    send_stream_data(connection, stream_identifier)
end

function promise!(connection::HTTPConnection, stream_identifier::UInt32,
                  request_headers::Array{Header, 1},
                  headers::Array{Header, 1}, body::Array{UInt8, 1})
    stream = get_stream(connection, stream_identifier)
    stream.receiving_headers = request_headers
    stream.sending_headers = headers
    stream.sending_body = body
    send_stream_push_promise(connection, stream_identifier)
end

function recv_next(connection::HTTPConnection)
    buffer = connection.buffer
    frame = Frame.decode(buffer)

    if frame == false
        return false
    end

    return frame
end

function select_next(streams::Array{HTTPStream, 1}, ignored::Array{HTTPStream, 1})
    @assert length(streams) > 0

    if length(ignored) == 0
        return Nullable(streams[1])
    end

    if length(ignored) >= length(streams)
        return Nullable{HTTPStream}()
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

    return Nullable{HTTPStream}()
end

function send_next(connection::HTTPConnection; ignored=Array{HTTPStream, 1}())
    stream_nullable = select_next(connection.streams, ignored)

    if isnull(stream_nullable)
        return Nullable{HTTPStream}()
    end

    stream = stream_nullable.value

    if stream.state == RESERVED_LOCAL
        send_stream_headers_continuations(connection, stream.stream_identifier)
        # RESERVED_LOCAL -> HALF_CLOSED_REMOTE

        send_stream_data(connection, stream.streaam_identifier)
        # HALF_CLOSED_REMOTE -> CLOSED
    elseif stream.state == OPEN
        send_stream_data(connection, stream.stream_identifier)
        # OPEN -> HALF_CLOSED_LOCAL

    elseif stream.state == HALF_CLOSED_REMOTE
        send_stream_data(connection, stream.stream_identifier)
        # HALF_CLOSED_REMOTE -> CLOSED
    else
        push!(ignored, stream)
        return send_next(connection; ignored=ignored)
    end

    return Nullable(stream)
end

end
