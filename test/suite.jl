import HTTP2

cd("test/http2-test")
run(`npm install`)

@async (headers, body) = HTTP2.request(ip"127.0.0.1", 8000, b"/")
sleep(3)
run(`grunt mochaTest:server`)

@async HTTP2.serve(8080, b"<h1>Hello, world!</h1>")
sleep(3)
run(`grunt mochaTest:client`)
