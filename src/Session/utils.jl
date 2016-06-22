function get_stream(connection::HTTPConnection, stream_identifier::UInt32)
    @assert stream_identifier != 0x0

    for i = 1:length(connection.streams)
        if connection.streams[i].stream_identifier == stream_identifier
            return connection.streams[i]
        end
    end

    stream = HTTPStream(stream_identifier, IDLE,
                        65535, Nullable{Priority}())

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

    if isnull(stream.priority)
        return Nullable{Stream}()
    else
        return Nullable(get_stream(stream.priority.value.dependent_stream_identifier))
    end
end

function get_dependency_children(connection::HTTPConnection, stream_identifier::UInt32)
    result = Array{Stream}()

    for i = 1:length(connection.streams)
        stream = connection.streams[i]

        if !isnull(stream.priority) &&
            stream.priority.value.dependent_stream_identifier == stream_identifier
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
            children[i].priority.value.dependent_stream_identifier = stream_identifier
        end
    end

    stream.priority = Nullable(Priority(dependent_stream_identifier, weight))
end

function handle_setting!(connection::HTTPConnection, key::Frame.SETTING_IDENTIFIER, value::UInt32)
    if key == Frame.SETTINGS_HEADER_TABLE_SIZE
        HPack.set_max_table_size!(connection.dynamic_table, Int(value))
    else
        ## TODO implement this
    end
end
