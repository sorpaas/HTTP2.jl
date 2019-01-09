@enum SETTING_IDENTIFIER SETTINGS_HEADER_TABLE_SIZE=0x1 SETTINGS_ENABLE_PUSH=0x2 SETTINGS_MAX_CONCURRENT_STREAMS=0x3 SETTINGS_INITIAL_WINDOW_SIZE=0x4 SETTINGS_MAX_FRAME_SIZE=0x5 SETTINGS_MAX_HEADER_LIST_SIZE=0x6

struct SettingsFrame
    is_ack::Bool
    parameters::Union{Nothing,Array{Tuple{SETTING_IDENTIFIER, UInt32}, 1}}
end

SettingsFrame() = SettingsFrame(false, Array{Tuple{Frame.SETTING_IDENTIFIER, UInt32}, 1}())

==(a::SettingsFrame, b::SettingsFrame) =
    a.is_ack == b.is_ack &&
    ((a.parameters === nothing) || a.parameters == b.parameters)

struct UnknownIdentifierError <: Exception end

function decode_settings(header, payload)
    @assert header.stream_identifier == 0x0

    is_ack = header.flags & 0x1 == 0x1

    if is_ack
        @assert length(payload) == 0
        return SettingsFrame(is_ack, nothing)
    else
        parameters = Array{Tuple{SETTING_IDENTIFIER, UInt32}, 1}()
        for i = 1:div(length(payload), 6)
            identifier = UInt16(payload[(i-1)*6+1]) << 8 + UInt16(payload[(i-1)*6+2])
            value = UInt32(payload[(i-1)*6+3]) << 24 + UInt32(payload[(i-1)*6+4]) << 16 +
                UInt32(payload[(i-1)*6+5]) << 8 + UInt32(payload[(i-1)*6+6])
            push!(parameters, (SETTING_IDENTIFIER(identifier), value))
        end
        return SettingsFrame(is_ack, parameters)
    end
end

function encode_settings(frame)
    if frame.is_ack
        return wrap_payload([], SETTINGS, 0x1, 0x0)
    else
        payload = Array{UInt8, 1}()
        for val in frame.parameters
            append!(payload, [ UInt8(UInt16(val[1]) >> 8);
                               UInt8(UInt16(val[1]) & 0x00ff);
                               UInt8(val[2] >> 24);
                               UInt8(val[2] >> 16 & 0x000000ff);
                               UInt8(val[2] >> 8 & 0x000000ff);
                               UInt8(val[2] & 0x000000ff) ])
        end
        return wrap_payload(payload, SETTINGS, 0x0, 0x0)
    end
end
