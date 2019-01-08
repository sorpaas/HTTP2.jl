import HTTP2
using HTTP2.Frame
using Test
using Sockets
using MbedTLS

function sslconnect(dest, port, certhostname)
    println("Connecting over SSL ...")
    buffer = connect(dest, port)
    sslconfig = MbedTLS.SSLConfig(false)
    sslbuffer = MbedTLS.SSLContext()
    MbedTLS.setup!(sslbuffer, sslconfig)
    MbedTLS.set_bio!(sslbuffer, buffer)
    MbedTLS.hostname!(sslbuffer, certhostname)
    MbedTLS.handshake!(sslbuffer)
    return sslbuffer
end

function show_response(headers, body)
    for header in headers
        @info("Result header: " * String(header[1]) * ": " * String(header[2]))
    end
    @info("Result body: " * String(body))
end


function test_request(dest, port, url, certhostname=nothing)
    for conn_id in 1:3
        @info("Opening connection", conn_id)
        buffer = (certhostname === nothing) ? connect(dest, port) : sslconnect(dest, port, certhostname)
        connection = HTTP2.Session.new_connection(buffer; isclient=true)
        headers = [(":method", "GET"),
                   (":path", url),
                   (":scheme", "http"),
                   (":authority", "127.0.0.1:9000"),
                   ("accept", "*/*"),
                   ("accept-encoding", "gzip, deflate"),
                   ("user-agent", "HTTP2.jl")]

        @sync begin
            @async for req_id in 1:3
                @info("Sending request", req_id)
                HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendHeaders(HTTP2.Session.next_free_stream_identifier(connection), headers, true))
            end
            @async for resp_id in 1:3
                resp_headers = HTTP2.Session.take_evt!(connection).headers
                @show resp_headers
                resp_data = HTTP2.Session.take_evt!(connection).data
                @show resp_data
                show_response(resp_headers, resp_data)
            end
        end

        @info("Closing connection", conn_id)
        close(connection)
        sleep(2) # wait for close message to percolate
        close(buffer)
    end
end

if length(ARGS) == 1
    test_request(ip"127.0.0.1", 8000, "/", ARGS[1])
else
    test_request(ip"127.0.0.1", 8000, "/")
end
