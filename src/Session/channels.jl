
function initialize_raw_loop_async(connection::HTTPConnection, buffer::TCPSocket)
    channel_act_raw = connection.channel_act_raw
    channel_evt_raw = connection.channel_evt_raw

    ## Initialize the connection
    CLIENT_PREFACE = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    if connection.isclient
        write(buffer, CLIENT_PREFACE)
    else
        @assert readbytes(buffer, length(CLIENT_PREFACE)) == CLIENT_PREFACE
    end

    @async begin
        while true
            if eof(buffer)
                return
            end
            frame = Frame.decode(buffer)

            # Abstract atom headers frame away
            if typeof(frame) == HeadersFrame || typeof(frame) == PushPromiseFrame
                continuations = Array{ContinuationFrame, 1}()
                while !(frame.is_end_headers ||
                        (!frame.is_end_headers && length(continuations) == 0) ||
                        continuations[length(continuations)].is_end_headers)

                    continuation = Frame.decode(buffer)
                    @assert typeof(continuation) == ContinuationFrame &&
                        continuation.stream_identifier == frame.stream_identifier
                    push!(continuations, continuation)
                end

                fragment = copy(frame.fragment)
                if length(continuations) > 0
                    for i = 1:length(continuations)
                        append!(fragment, continuations[i].fragment)
                    end
                end

                if typeof(frame) == HeadersFrame
                    put!(channel_evt_raw, HeadersFrame(frame.is_end_stream,
                                                       true,
                                                       frame.is_priority,
                                                       frame.stream_identifier,
                                                       frame.exclusive,
                                                       frame.dependent_stream_identifier,
                                                       frame.weight,
                                                       fragment))
                else
                    put!(channel_evt_raw, PushPromiseFrame(true,
                                                           frame.stream_identifier,
                                                           frame.promised_stream_identifier,
                                                           fragment))
                end
            else
                put!(channel_evt_raw, frame)
            end
        end
    end

    @async begin
        while true
            frame = take!(channel_act_raw)

            if typeof(frame) == HeadersFrame || typeof(frame) == PushPromiseFrame
                @assert frame.is_end_headers == true
                ## TODO Split fragment into continuations if necessary

                write(buffer, Frame.encode(frame))
            else
                write(buffer, Frame.encode(frame))
            end
        end
    end

    put!(channel_act_raw, SettingsFrame(false, Nullable(Array{Tuple{Frame.SETTING_IDENTIFIER, UInt32}, 1}())))
end

function process_channel_act(connection::HTTPConnection)
    channel_act_raw = connection.channel_act_raw
    channel_act = connection.channel_act
    channel_evt_raw = connection.channel_evt_raw
    channel_evt = connection.channel_evt

    act = take!(channel_act)

    if connection.next_free_stream_identifier <= act.stream_identifier
        connection.next_free_stream_identifier = act.stream_identifier + 2
    end

    if typeof(act) == ActSendHeaders
        frame = send_stream_headers(connection, act)
        handle_stream_state!(connection, frame, true)
        return
    end

    if typeof(act) == ActSendData
        frame = send_stream_data(connection, act)
        handle_stream_state!(connection, frame, true)
        return
    end

    if typeof(act) == ActPushPromise
        frame = send_stream_push_promise(connection, act)
        handle_stream_state!(connection, frame, true)
        return
    end

    @assert false
end

function process_channel_evt(connection::HTTPConnection)
    channel_act_raw = connection.channel_act_raw
    channel_act = connection.channel_act
    channel_evt_raw = connection.channel_evt_raw
    channel_evt = connection.channel_evt

    frame = take!(channel_evt_raw)

    ## Frames where stream identifier is 0x0

    if typeof(frame) == SettingsFrame
        if !frame.is_ack
            parameters = frame.parameters.value
            if length(parameters) > 0
                for i = 1:length(parameters)
                    handle_setting!(connection, parameters[i][1], parameters[i][2])
                end
            end
            put!(channel_act_raw,
                 SettingsFrame(true, Nullable{Tuple{Frame.SETTING_IDENTIFIER, UInt32}}()))
        end
        return
    end
    if typeof(frame) == PingFrame
        put!(channel_act_raw, PingFrame(true, frame.data))
        return
    end
    if typeof(frame) == GoawayFrame
        @assert frame.error_code == 0x0
        return
    end
    if typeof(frame) == WindowUpdateFrame && frame.stream_identifier == 0x0
        connection.window_size += frame.window_size_increment
        return
    end

    ## Frames where stream identifier is not 0x0
    @assert frame.stream_identifier != 0x0
    handle_stream_state!(connection, frame, false)
    stream = get_stream(connection, frame.stream_identifier)

    if connection.next_free_stream_identifier <= frame.stream_identifier
        connection.next_free_stream_identifier = frame.stream_identifier + 1
    end

    if typeof(frame) == DataFrame
        recv_stream_data(connection, frame)
        return
    end
    if typeof(frame) == HeadersFrame
        recv_stream_headers(connection, frame)
        return
    end
    if typeof(frame) == PriorityFrame
        recv_stream_priority(connection, frame)
        return
    end
    if typeof(frame) == RstStreamFrame
        recv_stream_rst_stream(connection, frame)
        return
    end
    if typeof(frame) == PushPromiseFrame
        recv_stream_push_promise(connection, frame)
        return
    end
    if typeof(frame) == WindowUpdateFrame
        recv_stream_window_update(connection, frame)
        return
    end

    @assert false
end

function select(waitset::Array)
    c = Channel(length(waitset))
    for w in waitset
        @async put!(c, (wait(w); w))
    end
    take!(c)
end

function initialize_loop_async(connection::HTTPConnection, buffer::TCPSocket)
    initialize_raw_loop_async(connection, buffer)

    channel_act_raw = connection.channel_act_raw
    channel_act = connection.channel_act
    channel_evt_raw = connection.channel_evt_raw
    channel_evt = connection.channel_evt

    @async begin
        while true
            c = select([channel_evt_raw, channel_act])
            if c == channel_evt_raw
                process_channel_evt(connection)
            else
                process_channel_act(connection)
            end
        end
    end
end
