function handle_setting!(connection::HTTPConnection, key::Frame.SETTING_IDENTIFIER, value::UInt32)
    if key == Frame.SETTINGS_HEADER_TABLE_SIZE
        HPack.set_max_table_size!(connection.dynamic_table, Int(value))
    elseif key == Frame.SETTINGS_ENABLE_PUSH
        connection.settings.push_enabled = value != 0
    elseif key == Frame.SETTINGS_MAX_CONCURRENT_STREAMS
        connection.settings.max_concurrent_streams = UInt(value)
    elseif key == Frame.SETTINGS_INITIAL_WINDOW_SIZE
        diff = UInt(value) - connection.settings.initial_window_size
        for stream in connection.streams
            stream.window_size += diff
        end
        connection.settings.initial_window_size = UInt(value)
    elseif key == Frame.SETTINGS_MAX_FRAME_SIZE
        connection.settings.max_frame_size = UInt(value)
    elseif key == Frame.SETTINGS_MAX_HEADER_LIST_SIZE
        connection.settings.max_header_list_size = UInt(value)
    else
        goaway!(connection, ProtocolError("Unknown settings key."))
    end
end
