module HTTP2

using Sockets
using Dates

const Headers = Dict{String,String}

bytearr(a::Vector{UInt8}) = a
bytearr(cs::Base.CodeUnits{UInt8,String}) = convert(Vector{UInt8}, cs)
bytearr(s::String) = bytearr(codeunits(s))

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
    headers = Headers(":method" => "GET",
                      ":path" => url,
                      ":scheme" => "http",
                      ":authority" => "127.0.0.1:9000",
                      "accept" => "*/*",
                      "accept-encoding" => "gzip, deflate",
                      "user-agent" => "HTTP2.jl")

    Session.put_act!(connection, Session.ActSendHeaders(Session.next_free_stream_identifier(connection), headers, true))

    return (Session.take_evt!(connection).headers, Session.take_evt!(connection).data)
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

    println("Server started.")
    while(true)
        buffer = accept(server)
        println("Processing a connection ...")

        connection = Session.new_connection(buffer; isclient=false)
        ## Recv the client preface, and send an empty SETTING frame.

        headers_evt = Session.take_evt!(connection)
        stream_identifier = headers_evt.stream_identifier

        sending_headers = Headers(":status" => "200",
                                  "server" => "HTTP2.jl",
                                  "date" => Dates.format(now(Dates.UTC), Dates.RFC1123Format),
                                  "content-type" => "text/html; charset=UTF-8")

        Session.put_act!(connection, Session.ActSendHeaders(stream_identifier, sending_headers, false))
        Session.put_act!(connection, Session.ActSendData(stream_identifier, body, true))

        ## We are done!
    end
end

end # module
