## Headers Handlers

function recv_stream_headers(connection::HTTPConnection, frame::HeadersFrame)
    stream_identifier = frame.stream_identifier
    stream = get_stream(connection, stream_identifier)

    if frame.is_priority
        handle_priority!(connection, stream_identifier, frame.exclusive.value,
                         frame.dependent_stream_identifier.value,
                         frame.weight.value)
    end

    block = copy(frame.fragment)
    headers = HPack.decode(connection.dynamic_table, IOBuffer(block))
    put!(connection.channel_evt, EvtRecvHeaders(stream_identifier, headers, frame.is_end_stream))
end

function send_stream_headers(connection::HTTPConnection, act::ActSendHeaders)
    stream_identifier = act.stream_identifier
    stream = get_stream(connection, stream_identifier)

    block = HPack.encode(connection.dynamic_table, act.headers; huffman=false)
    is_end_stream = act.is_end_stream
    frame = HeadersFrame(is_end_stream, true, false, stream_identifier, Nullable{Bool}(),
                         Nullable{UInt32}(), Nullable{UInt8}(), block)

    put!(connection.channel_act_raw, frame)
    return frame
end

## Data Handlers

function recv_stream_data(connection::HTTPConnection, frame::DataFrame)
    stream = get_stream(connection, frame.stream_identifier)

    data = copy(frame.data)
    put!(connection.channel_evt, EvtRecvData(frame.stream_identifier, data, frame.is_end_stream))
end

function send_stream_data(connection::HTTPConnection, act::ActSendData)
    stream = get_stream(connection, act.stream_identifier)

    is_end_stream = act.is_end_stream
    frame = DataFrame(act.stream_identifier, is_end_stream, act.data)

    put!(connection.channel_act_raw, frame)
    return frame
end

## Priority Handlers

function recv_stream_priority(connection::HTTPConnection, priority::PriorityFrame)
    handle_priority!(connection, priority.stream_identifier, priority.exclusive,
                     priority.dependent_stream_identifier,
                     priority.weight)
end

## Rst Stream Handlers

function recv_stream_rst_stream(connection::HTTPConnection, rstStream::RstStreamFrame)
    ## Nothing to do
end

## Push Promise Handlers

function recv_stream_push_promise(connection::HTTPConnection, frame::PushPromiseFrame)
    stream = get_stream(connection, frame.stream_identifier)

    block = copy(frame.fragment)
    headers = HPack.decode(connection.dynamic_table, IOBuffer(block))

    put!(connection.channel_evt, EvtPromise(frame.stream_identifier, frame.promised_stream_identifier,
                                            headers))
end

function send_stream_push_promise(connection::HTTPConnection, act::ActPromise)
    stream = get_stream(connection, act.stream_identifier)

    block = HPACK.encode(connection.dynamic_table, stream.receiving_headers; huffman=false)
    frame = PushPromiseFrame(true, act.stream_identifier, act.promised_stream_identifier, block)

    put!(connection.channel_act_raw, frame)
    return frame
end

## Window Update Handlers

function recv_stream_window_update(connection::HTTPConnection, headers::WindowUpdateFrame)
    stream = get_stream(connection, stream_identifier)

    stream.window_size += headers.window_size_increment
end
