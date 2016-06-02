## Headers Handlers

function recv_stream_headers_continuations(connection::HTTPConnection, headers::HeadersFrame,
                                          continuations::Array{ContinuationFrame, 1})
    stream_identifier = headers.stream_identifier
    stream = get_stream(connection, stream_identifier)

    if headers.is_priority
        handle_priority!(connection, stream_identifier, headers.exclusive.value,
                         headers.dependent_stream_identifier.value,
                         headers.weight.value)
    end

    block = copy(headers.fragment)

    if length(continuations) > 0
        for i = 1:length(continuations)
            @assert continuations[i].stream_identifier == stream_identifier
            append!(block, continuations[i].fragment)
        end
        @assert continuations[length(continuations)].is_end_headers
    else
        @assert headers.is_end_headers
    end

    stream.received_headers = HPack.decode(connection.dynamic_table, IOBuffer(block))

    @show stream
    if stream.state == IDLE
        stream.state = OPEN
        if headers.is_end_stream
            stream.state = HALF_CLOSED_REMOTE
        end
    elseif stream.state == RESERVED_REMOTE
        stream.state = HALF_CLOSED_LOCAL
    elseif stream.state == HALF_CLOSED_LOCAL
        if headers.is_end_stream
            stream.state = CLOSED
        end
    else
        @assert false
    end
end

function send_stream_headers_continuations(connection::HTTPConnection, stream_identifier::UInt32)
    buffer = connection.buffer
    stream = get_stream(connection, stream_identifier)

    block = HPack.encode(connection.dynamic_table, stream.sending_headers; huffman=false)
    is_end_stream = length(stream.sending_body) == 0
    frame = HeadersFrame(is_end_stream, true, false, stream_identifier, Nullable{Bool}(),
                         Nullable{UInt32}(), Nullable{UInt8}(), block)

    write(buffer, Frame.encode(frame))

    if stream.state == IDLE
        stream.state = OPEN
        if is_end_stream
            stream.state = HALF_CLOSED_LOCAL
        end
    elseif stream.state == RESERVED_LOCAL
        stream.state = HALF_CLOSED_REMOTE
    else
        @assert false
    end
end

## Data Handlers

function recv_stream_data(connection::HTTPConnection, data::DataFrame)
    stream = get_stream(connection, data.stream_identifier)

    append!(stream.received_body, data.data)

    if stream.state == OPEN
        if data.is_end_stream
            stream.state = HALF_CLOSED_REMOTE
        end
    elseif stream.state == HALF_CLOSED_LOCAL
        if data.is_end_stream
            stream.state = CLOSED
        end
    else
        @assert false
    end
end

function send_stream_data(connection::HTTPConnection, stream_identifier::UInt32)
    buffer = connection.buffer
    stream = get_stream(connection, stream_identifier)

    is_end_stream = true
    frame = DataFrame(stream_identifier, is_end_stream, stream.sending_body)

    write(buffer, Frame.encode(frame))

    if stream.state == OPEN
        if is_end_stream
            stream.state = HALF_CLOSED_LOCAL
        end
    elseif stream.state == HALF_CLOSED_REMOTE
        if is_end_stream
            stream.state = CLOSED
        end
    else
        @assert false
    end
end

## Priority Handlers

function recv_stream_priority(connection::HTTPConnection, priority::PriorityFrame)
    handle_priority!(connection, priority.stream_identifier, priority.exclusive,
                     priority.dependent_stream_identifier,
                     priority.weight)
end

## Rst Stream Handlers

function recv_stream_rst_stream(connection::HTTPConnection, rstStream::RstStreamFrame)
    stream = get_stream(connection, rstStream.stream_identifier)

    stream.state = CLOSED
end

## Push Promise Handlers

function recv_stream_push_promise(connection::HTTPConnection, headers::PushPromiseFrame, continuations::Array{ContinuationFrame, 1})
    stream = get_stream(connection, headers.stream_identifier)

    block = similar(headers.fragment)

    if length(continuations) > 0
        for i = 1:length(continuations)
            @assert continuations[i].stream_identifier == stream_identifier
            append!(block, continuations[i].fragment)
        end
        @assert continuations[length(continuations)].is_end_headers
    else
        @assert headers.is_end_headers
    end

    stream.sending_headers = HPack.decode(connection.dynamic_table, IOBuffer(block))

    stream.state = RESERVED_REMOTE
end

function send_stream_push_promise(connection::HTTPConnection, stream_identifier::UInt32)
    buffer = connection.buffer
    stream = get_stream(connection, stream_identifier)

    block = HPACK.encode(connection.dynamic_table, stream.receiving_headers; huffman=false)
    frame = PushPromiseFrame(true, stream_identifier, block)

    write(buffer, Frame.encode(frame))

    stream.state = RESERVED_LOCAL
end

## Window Update Handlers

function recv_stream_window_update(connection::HTTPConnection, headers::WindowUpdateFrame)
    stream = get_stream(connection, stream_identifier)

    stream.window_size += headers.window_size_increment
end
