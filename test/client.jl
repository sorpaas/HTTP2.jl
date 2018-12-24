import HTTP2
using HTTP2.Frame
using Test
using Sockets

function show_response(headers, body)
    for header in headers
        @info("Result header: " * String(header[1]) * ": " * String(header[2]))
    end
    @info("Result body: " * String(body))
end


function test_request(dest, port, url)
    for conn_id in 1:3
        @info("Opening connection", conn_id)
        buffer = connect(dest, port)
        connection = HTTP2.Session.new_connection(buffer; isclient=true)
        headers = HTTP2.Headers(":method" => "GET",
                          ":path" => url,
                          ":scheme" => "http",
                          ":authority" => "127.0.0.1:9000",
                          "accept" => "*/*",
                          "accept-encoding" => "gzip, deflate",
                          "user-agent" => "HTTP2.jl")

        for req_id in 1:5
            @info("Sending request", req_id)
            HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendHeaders(HTTP2.Session.next_free_stream_identifier(connection), headers, true))
            show_response(HTTP2.Session.take_evt!(connection).headers, HTTP2.Session.take_evt!(connection).data)
        end

        @info("Closing connection", conn_id)
        close(connection)
        sleep(2) # wait for close message to percolate
        close(buffer)
    end
end

test_request(ip"127.0.0.1", 8000, "/")
