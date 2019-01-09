function handle_stream_state!(connection::HTTPConnection, frame, issend::Bool)
    stream_identifier = frame.stream_identifier
    stream = get_stream(connection, stream_identifier)

    isrecv = !issend

    # idle state
    if stream.state == IDLE
        ## Sending or receiving a HEADERS frame causes the stream to become
        ## "open". The stream identifier is selected as described in Section
        ## 5.1.1. The same HEADERS frame can also cause a stream to immediately
        ## become "half-closed".
        if typeof(frame) == HeadersFrame
            stream.state = OPEN

            if frame.is_end_stream
                if issend
                    stream.state = HALF_CLOSED_LOCAL
                else
                    stream.state = HALF_CLOSED_REMOTE
                end
            end
            return
        end

        ## Receiving any frame other than HEADERS or PRIORITY on a stream in
        ## this state MUST be treated as a connection error (Section 5.4.1) of
        ## type PROTOCOL_ERROR.
        if isrecv && (typeof(frame) == PriorityFrame ||
                      typeof(frame) == HeadersFrame)
            return
        end

        @assert false
    end

    # reserved (local)
    if stream.state == RESERVED_LOCAL
        ## The endpoint can send a HEADERS frame. This causes the stream to open
        ## in a "half-closed (remote)" state.
        if typeof(frame) == HeadersFrame && issend
            stream.state = HALF_CLOSED_REMOTE
            return
        end

        ## Either endpoint can send a RST_STREAM frame to cause the stream to
        ## become "closed". This releases the stream reservation.
        if typeof(frame) == RstStreamFrame
            stream.state = CLOSED
            return
        end

        ## An endpoint MUST NOT send any type of frame other than HEADERS,
        ## RST_STREAM, or PRIORITY in this state.
        if issend && (typeof(frame) == PriorityFrame ||
                      typeof(frame) == RstStreamFrame ||
                      typeof(frame) == HeadersFrame)
            return
        end

        ## A PRIORITY or WINDOW_UPDATE frame MAY be received in this state.
        ## Receiving any type of frame other than RST_STREAM, PRIORITY, or
        ## WINDOW_UPDATE on a stream in this state MUST be treated as a
        ## connection error (Section 5.4.1) of type PROTOCOL_ERROR.
        if isrecv && (typeof(frame) == PriorityFrame ||
                      typeof(frame) == WindowUpdateFrame ||
                      typeof(frame) == RstStreamFrame)
            return
        end

        @assert false
    end

    # reserved (remote)
    if stream.state == RESERVED_REMOTE
        ## Receiving a HEADERS frame causes the stream to transition to
        ## "half-closed (local)".
        if typeof(frame) == HeadersFrame && isrecv
            stream.state = HALF_CLOSED_LOCAL
            return
        end

        ## Either endpoint can send a RST_STREAM frame to cause the stream to
        ## become "closed". This releases the stream reservation.
        if typeof(frame) == RstStreamFrame
            stream.state = CLOSED
            return
        end

        ## An endpoint MAY send a PRIORITY frame in this state to reprioritize
        ## the reserved stream. An endpoint MUST NOT send any type of frame
        ## other than RST_STREAM, WINDOW_UPDATE, or PRIORITY in this state.
        if issend && (typeof(frame) == RstStreamFrame ||
                      typeof(frame) == WindowUpdateFrame ||
                      typeof(frame) == PriorityFrame)
            return
        end

        ## Receiving any type of frame other than HEADERS, RST_STREAM, or
        ## PRIORITY on a stream in this state MUST be treated as a connection
        ## error (Section 5.4.1) of type PROTOCOL_ERROR.
        if isrecv && (typeof(frame) == HeadersFrame ||
                      typeof(frame) == RstStreamFrame ||
                      typeof(frame) == PriorityFrame)
            return
        end

        @assert false
    end

    # closed
    if stream.state == CLOSED
        ## An endpoint MUST NOT send frames other than PRIORITY on a closed
        ## stream. An endpoint that receives any frame other than PRIORITY after
        ## receiving a RST_STREAM MUST treat that as a stream error (Section
        ## 5.4.2) of type STREAM_CLOSED. Similarly, an endpoint that receives
        ## any frames after receiving a frame with the END_STREAM flag set MUST
        ## treat that as a connection error (Section 5.4.1) of type
        ## STREAM_CLOSED, unless the frame is permitted as described below.
        if typeof(frame) == PriorityFrame
            return
        end

        @assert false
    end

    # half-closed (remote)
    if stream.state == HALF_CLOSED_REMOTE
        ## A stream can transition from this state to "closed" by sending a
        ## frame that contains an END_STREAM flag or when either peer sends a
        ## RST_STREAM frame.
        if (typeof(frame) == DataFrame || typeof(frame) == HeadersFrame) && frame.is_end_stream && issend
            stream.state = CLOSED
            return
        end

        if typeof(frame) == RstStreamFrame
            stream.state = CLOSED
            return
        end

        if issend && typeof(frame) == PushPromiseFrame
            promised_stream = get_stream(connection, frame.promised_stream_identifier)

            ## Sending a PUSH_PROMISE frame on another stream reserves the idle
            ## stream that is identified for later use. The stream state for the
            ## reserved stream transitions to "reserved (local)". Receiving a
            ## PUSH_PROMISE frame on another stream reserves an idle stream that
            ## is identified for later use. The stream state for the reserved
            ## stream transitions to "reserved (remote)".
            if issend
                promised_stream = RESERVED_LOCAL
            else
                promised_stream = RESERVED_REMOTE
            end
            return
        end

        ## If an endpoint receives additional frames, other than WINDOW_UPDATE,
        ## PRIORITY, or RST_STREAM, for a stream that is in this state, it MUST
        ## respond with a stream error (Section 5.4.2) of type STREAM_CLOSED.
        if isrecv && (typeof(frame) == WindowUpdateFrame ||
                      typeof(frame) == PriorityFrame ||
                      typeof(frame) == RstStreamFrame)
            return
        end

        ## A stream that is "half-closed (remote)" can be used by the endpoint
        ## to send frames of any type. In this state, the endpoint continues to
        ## observe advertised stream-level flow-control limits (Section 5.2).
        if issend
            return
        end

        @assert false
    end

    # half-closed (local)
    if stream.state == HALF_CLOSED_LOCAL
        ## A stream transitions from this state to "closed" when a frame that
        ## contains an END_STREAM flag is received or when either peer sends a
        ## RST_STREAM frame.
        if (typeof(frame) == DataFrame || typeof(frame) == HeadersFrame) && frame.is_end_stream && isrecv
            stream.state = CLOSED
            return
        end

        if typeof(frame) == RstStreamFrame
            stream.state = CLOSED
            return
        end

        if isrecv && typeof(frame) == PushPromiseFrame
            promised_stream = get_stream(connection, frame.promised_stream_identifier)

            ## Sending a PUSH_PROMISE frame on another stream reserves the idle
            ## stream that is identified for later use. The stream state for the
            ## reserved stream transitions to "reserved (local)". Receiving a
            ## PUSH_PROMISE frame on another stream reserves an idle stream that
            ## is identified for later use. The stream state for the reserved
            ## stream transitions to "reserved (remote)".
            if issend
                promised_stream = RESERVED_LOCAL
            else
                promised_stream = RESERVED_REMOTE
            end
            return
        end

        ## A stream that is in the "half-closed (local)" state cannot be used
        ## for sending frames other than WINDOW_UPDATE, PRIORITY, and
        ## RST_STREAM.
        if issend && (typeof(frame) == WindowUpdateFrame ||
                      typeof(frame) == PriorityFrame ||
                      typeof(frame) == RstStreamFrame)
            return
        end

        ## An endpoint can receive any type of frame in this state. Providing
        ## flow-control credit using WINDOW_UPDATE frames is necessary to
        ## continue receiving flow-controlled frames. In this state, a receiver
        ## can ignore WINDOW_UPDATE frames, which might arrive for a short
        ## period after a frame bearing the END_STREAM flag is sent.
        if isrecv
            return
        end

        @assert false
    end

    # open
    if stream.state == OPEN
        ## From this state, either endpoint can send a frame with an END_STREAM
        ## flag set, which causes the stream to transition into one of the
        ## "half-closed" states. An endpoint sending an END_STREAM flag causes
        ## the stream state to become "half-closed (local)"; an endpoint
        ## receiving an END_STREAM flag causes the stream state to become
        ## "half-closed (remote)".
        if (typeof(frame) == DataFrame || typeof(frame) == HeadersFrame) && frame.is_end_stream
            if issend
                stream.state = HALF_CLOSED_LOCAL
            else
                stream.state = HALF_CLOSED_REMOTE
            end
            return
        end

        ## Either endpoint can send a RST_STREAM frame from this state, causing
        ## it to transition immediately to "closed".
        if typeof(frame) == RstStreamFrame
            stream.state = CLOSED
            return
        end

        if typeof(frame) == PushPromiseFrame
            promised_stream = get_stream(connection, frame.promised_stream_identifier)

            ## Sending a PUSH_PROMISE frame on another stream reserves the idle
            ## stream that is identified for later use. The stream state for the
            ## reserved stream transitions to "reserved (local)". Receiving a
            ## PUSH_PROMISE frame on another stream reserves an idle stream that
            ## is identified for later use. The stream state for the reserved
            ## stream transitions to "reserved (remote)".
            if issend
                promised_stream = RESERVED_LOCAL
            else
                promised_stream = RESERVED_REMOTE
            end
            return
        end

        ## A stream in the "open" state may be used by both peers to send frames
        ## of any type. In this state, sending peers observe advertised
        ## stream-level flow-control limits (Section 5.2).
        return
    end

    @assert false
end
