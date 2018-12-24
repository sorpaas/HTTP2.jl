import HTTP2
import HTTP2: bytearr
using HTTP2.Frame
using Test
using Dates
using Sockets

# test serve method
function test_serve(port, body)
    server = listen(port)

    println("Server started.")
    while true
        println("Waiting for a connection ...")
        buffer = accept(server)
        println("Processing a connection ...")

        connection = HTTP2.Session.new_connection(buffer; isclient=false)
        @info("Connected", connection)
        ## Recv the client preface, and send an empty SETTING frame.

        while true
            headers_evt = HTTP2.Session.take_evt!(connection)
            @info("Received headers", headers_evt)
            if isa(headers_evt, HTTP2.Session.EvtGoaway)
                close(buffer)
                break
            end

            stream_identifier = headers_evt.stream_identifier
            @info("Stream ", stream_identifier)

            sending_headers = HTTP2.Headers(":status" => "200",
                                      "server" => "HTTP2.jl",
                                      "date" => Dates.format(now(Dates.UTC), Dates.RFC1123Format),
                                      "content-type" => "text/html; charset=UTF-8")
            sending_body = isa(body, String) ? convert(Vector{UInt8}, codeunits(body)) : body
            @info("Resopnding", sending_headers, sending_body)

            HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendHeaders(stream_identifier, sending_headers, false))
            @info("sent headers")
            HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendData(stream_identifier, sending_body, true))
            @info("sent body")
        end
        ## We are done!
    end
end

# A server example
test_serve(8000, bytearr("<h1>Hello, world!</h1>"))
