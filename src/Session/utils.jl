function get_stream(connection::HTTPConnection, stream_identifier::UInt32)
    @assert stream_identifier != 0x0

    for stream in connection.streams
        if stream.stream_identifier == stream_identifier
            return stream
        end
    end

    stream = HTTPStream(stream_identifier, IDLE,
                        connection.settings.initial_window_size, nothing)

    push!(connection.streams, stream)
    return stream
end

function stream_states(connection::HTTPConnection)
    result = Array{Tuple{UInt32, STREAM_STATE}, 1}()

    for i = 1:length(connection.streams)
        push!(result, (connection.streams[i].stream_identifier, connection.streams[i].state))
    end

    return result
end

function get_dependency_parent(connection::HTTPConnection, stream_identifier::UInt32)
    stream = get_stream(connection, stream_identifier)

    if stream.priority === nothing
        return nothing
    else
        return get_stream(stream.priority.dependent_stream_identifier)
    end
end

function get_dependency_children(connection::HTTPConnection, stream_identifier::UInt32)
    result = Array{Stream}()

    for i = 1:length(connection.streams)
        stream = connection.streams[i]

        if (stream.priority !== nothing) &&
            stream.priority.dependent_stream_identifier == stream_identifier
            push!(result, stream)
        end
    end

    return result
end

function handle_priority!(connection::HTTPConnection, stream_identifier::UInt32,
                          exclusive::Bool, dependent_stream_identifier::UInt32, weight::UInt8)
    stream = get_stream(connection, stream_identifier)

    if exclusive
        children = get_dependency_children(connection, stream_identifier)

        for i = 1:length(children)
            children[i].priority.dependent_stream_identifier = stream_identifier
        end
    end

    stream.priority = Priority(dependent_stream_identifier, weight)
end

function concurrent_streams_count(connection::HTTPConnection)
    n = 0

    for stream in connection.streams
        if stream.state != IDLE && stream.state != CLOSED
            n += 1
        end
    end

    return n
end
