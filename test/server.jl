import HTTP2
using HTTP2.Frame
using Base.Test

# A server example
HTTP2.serve(8000, b"<h1>Hello, world!</h1>")
