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

    ## Create a request with headers
    headers = [(b":method", b"GET"),
               (b":path", url),
               (b":scheme", b"http"),
               (b":authority", b"127.0.0.1:9000"),
               (b"accept", b"*/*"),
               (b"accept-encoding", b"gzip, deflate"),
               (b"user-agent", b"HTTP2.jl")]

    Session.put_act!(connection, Session.ActSendHeaders(UInt32(13), headers, true))

    return (Session.take_evt!(connection), Session.take_evt!(connection))
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

        headers_evt = Session.take_evt!(connection)
        stream_identifier = headers_evt.stream_identifier

        sending_headers = [(b":status", b"200"),
                           (b"server", b"HTTP2.jl"),
                           (b"date", b"Thu, 02 Jun 2016 19:00:13 GMT"),
                           (b"content-type", b"text/html; charset=UTF-8")]

        Session.put_act!(connection, Session.ActSendHeaders(stream_identifier, sending_headers, true))
        Session.put_act!(connection, Session.ActSendData(stream_identifier, body, true))

        ## We are done!
    end
end

end # module
