
function initialize_raw_loop_async(connection::HTTPConnection, buffer; skip_preface=false)
    channel_act_raw = connection.channel_act_raw
    channel_evt_raw = connection.channel_evt_raw

    ## Initialize the connection
    CLIENT_PREFACE = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    if !skip_preface
        if connection.isclient
            write(buffer, CLIENT_PREFACE)
        else
            @assert readbytes(buffer, length(CLIENT_PREFACE)) == CLIENT_PREFACE
        end
    end

    @async begin
        while true
            if connection.closed
                break
            end

            if eof(buffer)
                connection.closed = true
                continue
            end

            frame = try
                Frame.decode(buffer)
            catch
                goaway!(connection, ProtocolError("Decode error."))
                break
            end

            # Abstract atom headers frame away
            if typeof(frame) == HeadersFrame || typeof(frame) == PushPromiseFrame
                continuations = Array{ContinuationFrame, 1}()
                while !(frame.is_end_headers ||
                        (!frame.is_end_headers && length(continuations) == 0) ||
                        continuations[length(continuations)].is_end_headers)

                    continuation = try
                        Frame.decode(buffer)
                    catch
                        goaway!(connection, ProtocolError("Decode error."))
                        break
                    end

                    if !(typeof(continuation) == ContinuationFrame &&
                         continuation.stream_identifier == frame.stream_identifier)
                        goaway!(connection, ProtocolError("Headers must be followed by continuations if it is not the end."))
                    end
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

                if typeof(frame) == DataFrame
                    put!(channel_act_raw, WindowUpdateFrame(0, length(frame.data)))
                    put!(channel_act_raw, WindowUpdateFrame(frame.stream_identifier, length(frame.data)))
                end

                if typeof(frame) == GoawayFrame
                    connection.closed = true
                end
            end
        end
    end

    @async begin
        while true
            if connection.closed
                break
            end

            frame = take!(channel_act_raw)

            if typeof(frame) == HeadersFrame || typeof(frame) == PushPromiseFrame
                write(buffer, Frame.encode(frame))
                while !frame.is_end_headers
                    continuation = take!(channel_act_raw)
                    if !(typeof(continuation) == ContinuationFrame &&
                         continuation.stream_identifier == frame.stream_identifier)
                        goaway!(connection, InternalError("Headers must be followed by continuations if it is not the end."))
                    end
                    write(buffer, Frame.encode(continuation))
                end
            else
                encoded = Frame.encode(frame)

                if typeof(frame) == DataFrame
                    stream = get_stream(connection, frame.stream_identifier)
                    if stream.window_size < length(encoded)
                        put!(channel_act_raw, frame)
                        continue
                    end

                    stream.window_size -= length(encoded)
                end

                write(buffer, encoded)

                if typeof(frame) == GoawayFrame
                    connection.closed = true
                end
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

    if connection.last_stream_identifier <= act.stream_identifier
        connection.last_stream_identifier = act.stream_identifier
    end

    stream = get_stream(connection, act.stream_identifier)
    if stream.state == IDLE && !isnull(connection.settings.max_concurrent_streams) &&
        concurrent_streams_count(connection) > get(connection.settings.max_concurrent_streams)
        put!(channel_act, act)
        return
    end

    if typeof(act) == ActSendHeaders
        if !isnull(connection.settings.max_header_list_size)
            sum = 0

            for k in keys(act.headers)
                sum += length(k) + length(act.headers[k]) + 32
            end

            if sum > get(connection.settings.max_header_list_size)
                goaway!(connection, InternalError("Header list size exceeded."))
                return
            end
        end

        frame = send_stream_headers(connection, act)
        handle_stream_state!(connection, frame, true)
    elseif typeof(act) == ActSendData
        frame = send_stream_data(connection, act)
        handle_stream_state!(connection, frame, true)
    elseif typeof(act) == ActPushPromise
        if !connection.settings.push_enabled
            goaway!(connection, InternalError("Push is disabled."))
            return
        end

        frame = send_stream_push_promise(connection, act)
        handle_stream_state!(connection, frame, true)
    else
        goaway!(connection, InternalError("Unknown action for channel."))
    end
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

function initialize_loop_async(connection::HTTPConnection, buffer; skip_preface=false)
    initialize_raw_loop_async(connection, buffer; skip_preface=skip_preface)

    channel_act_raw = connection.channel_act_raw
    channel_act = connection.channel_act
    channel_evt_raw = connection.channel_evt_raw
    channel_evt = connection.channel_evt

    @async begin
        while true
            if connection.closed
                put!(channel_evt, EvtGoaway())
                break
            end

            c = select([channel_evt_raw, channel_act])
            if c == channel_evt_raw
                process_channel_evt(connection)
            else
                process_channel_act(connection)
            end
        end
    end
end
