import HTTP2
using HTTP2.Frame
using Base.Test

## Run `nghttpd --verbose --no-tls 9000` to make this test pass
stream = HTTP2.request(ip"127.0.0.1", 9000, b"/")

println()
println("Results of the request")
println("======================")
println()
println("Headers")
println("======================")
for i = 1:length(stream.received_headers)
    print(ascii(stream.received_headers[i][1]))
    print(": ")
    print(ascii(stream.received_headers[i][2]))
    print("\n")
end
println()
println("Body")
println("======================")
println(ascii(stream.received_body))
