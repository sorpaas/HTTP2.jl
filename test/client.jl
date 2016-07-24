import HTTP2
using HTTP2.Frame
using Base.Test

## Run `nghttpd --verbose --no-tls 9000` to make this test pass
(headers, body) = HTTP2.request(ip"127.0.0.1", 9000, "/")

println()
println("Results of the request")
println("======================")
println()
println("Headers")
println("======================")
for header in headers
    print(ascii(header[1]))
    print(": ")
    print(ascii(header[2]))
    print("\n")
end
println()
println("Body")
println("======================")
println(ascii(body))
