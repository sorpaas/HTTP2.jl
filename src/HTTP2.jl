module HTTP2

# package code goes here
include("Frame.jl")
include("Session.jl")

## Below we try to fire a HTTP2 request. This request is meant to be tested
## against a local nghttp2 server running on port 9000.
##
## The server is started by the command: `nghttpd --verbose --no-tls 9000`
import HTTP2.Session

function request(dest, port, url)
    ## Fire a HTTP connection to port 9000
    buffer = connect(dest, port)

    ## Create a HTTPConnection object
    connection = Session.new_connection(buffer; isclient=true)
    ## Send the preface, and an empty SETTINGS frame.

    @show Session.recv_next(connection)
    ## Recv the server preface SETTINGS frame

    ## Recv the ack SETTINGS frame
    @show Session.recv_next(connection)

    ## Create a request with headers
    headers = [(b":method", b"GET"),
               (b":path", url),
               (b":scheme", b"http"),
               (b":authority", b"127.0.0.1:9000"),
               (b"accept", b"*/*"),
               (b"accept-encoding", b"gzip, deflate"),
               (b"user-agent", b"HTTP2.jl")]

    Session.send!(connection, UInt32(13), headers, Array{UInt8, 1}())
    ## Send a header frame without a body.
    ## Status change from IDLE to HALF_CLOSED_LOCAL.

    stream = Session.get_stream(connection, UInt32(13))
    @show stream.state

    ## Recv the headers
    @show Session.recv_next(connection)

    ## Recv the body
    @show Session.recv_next(connection)

    ## Finally, close the connection
    close(buffer)

    return Session.get_stream(connection, UInt32(13))
end

function handle_util_frames_until(connection)
    received = Session.recv_next(connection)
    while typeof(received) == Frame.SettingsFrame || typeof(received) == Frame.PriorityFrame
        # do nothing for now
        received = Session.recv_next(connection)
    end
    return received
end

function serve(port, body)
    server = listen(port)

    while(true)
        buffer = accept(server)

        connection = Session.new_connection(buffer; isclient=false)
        ## Recv the client preface, and send an empty SETTING frame.

        @show Session.recv_next(connection)
        ## Recv the client SETTING frame.

        headers_frame = handle_util_frames_until(connection)
        ## Recv the ack SETTING and PRIORITY frame until we find a HEADERS frame.

        stream = Session.get_stream(connection, headers_frame.stream_identifier)

        for i = 1:length(stream.received_headers)
            if stream.received_headers[i][1] == b":path"
                print("Found path, its value is: ")
                print(ascii(stream.received_headers[i][2]))
                print("\n")
            end
        end

        Session.send!(connection, headers_frame.stream_identifier,
                      [(b":status", b"200"),
                       (b"server", b"HTTP2.jl"),
                       (b"date", b"Thu, 02 Jun 2016 19:00:13 GMT"),
                       (b"content-type", b"text/html; charset=UTF-8")], body)

        sending_stream = Session.send_next(connection)
        while !isnull(sending_stream)
            sending_stream = Session.send_next(connection)
        end
        ## We are done!
    end
end

end # module
