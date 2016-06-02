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

end # module
