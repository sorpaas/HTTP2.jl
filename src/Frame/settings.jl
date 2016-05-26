@enum SETTING_IDENTIFIER SETTINGS_HEADER_TABLE_SIZE=0x1 SETTINGS_ENABLE_PUSH=0x2 SETTINGS_MAX_CONCURRENT_STREAMS=0x3 SETTINGS_INITIAL_WINDOW_SIZE=0x4 SETTINGS_MAX_FRAME_SIZE=0x5 SETTINGS_MAX_HEADER_LIST_SIZE=0x6

type SettingsFrame
    is_ack::Bool
    parameters::Nullable{Array{Tuple{SETTING_IDENTIFIER, UInt32}}}
end

type UnknownIdentifierError :> Exception end

function decode_settings(header, payload)
    @assert header.stream_identifier == 0x0

    is_ack = header.flags & 0x1 == 0x1

    if is_ack
        @assert length(payload) == 0
        return SettingsFrame(is_ack, Nullable{Array{Tuple{SETTING_IDENTIFIER, UInt32}}}())
    else
        parameters = Array{Tuple{SETTING_IDENTIFIER, UInt32}, 1}()
        for i = 1:(length(payload) / 6)
            identifier = UInt16(payload[(i-1)*6+1]) << 8 + UInt16(payload[(i-1)*6+2])
            value = UInt32(payload[(i-1)*6+3]) << 24 + UInt32(payload[(i-1)*6+4]) << 16 +
                UInt32(payload[(i-1)*6+5]) << 8 + UInt32(payload[(i-1)*6+6])
            push!(parameters, (SETTING_IDENTIFIER(identifier), value))
        end
        return SettingsFrame(is_ack, Nullable(parameters))
    end
end

function encode_settings(frame)
    if frame.is_ack
        return wrap_payload([], SETTINGS, 0x1, 0x0)
    else
        payload = Array{UInt8, 1}()
        for i = 1:length(frame.parameters)
            append!(payload, [ UInt8(UInt16(frame.parameters[i][1]) >> 8);
                               UInt8(UInt16(frame.parameters[i][1]) & 0x00ff);
                               UInt8(frame.parameters[i][2] >> 24);
                               UInt8(frame.parameters[i][2] >> 16 & 0x000000ff);
                               UInt8(frame.parameters[i][2] >> 8 & 0x000000ff);
                               UInt8(frame.parameters[i][2] & 0x000000ff) ])
        end
        return wrap_payload(payload, SETTINGS, 0x0, 0x0)
    end
end
