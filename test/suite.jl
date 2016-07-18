import HTTP2

# Server Testing
@async HTTP2.serve(8080, b"<h1>Hello, world!</h1>")
run("cd test/http2-test && npm install && grunt mochaTest:server")

@async (headers, body) = HTTP2.request(ip"127.0.0.1", 8000, b"/")
run("cd test/http2-test && npm install && grunt mochaTest:client")
