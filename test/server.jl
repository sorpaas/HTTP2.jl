import HTTP2
import HTTP2: bytearr
using HTTP2.Frame
using Test

# A server example
HTTP2.serve(8000, bytearr("<h1>Hello, world!</h1>"))
