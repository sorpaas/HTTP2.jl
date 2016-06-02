# HTTP2

A HTTP2 support library. It currently implements HTTP Frame encoders and decoders. A full stream and connection handler is planned.

## Sending Requests

To test this library, you can start a HTTP2 server by using `nghttp2` with the
following command:

```
nghttpd --verbose --no-tls 9000
```

After that, run:

```julia
import HTTP2

stream = HTTP2.request(ip"127.0.0.1", 9000, b"/")
```

`stream.received_headers` now contains the response headers and
`stream.received_body` contains the response body.

## Serving Responses

To test the HTTP server, import `HTTP2` namespace and run:

```julia
HTTP2.serve(8000, b"<h1>Hello, world!</h1>")
```

Now you can use HTTP2 client, for example `nghttp2` to get the result:

```
nghttp http://127.0.0.1:8000
```

## Frame

You can do `using HTTP2.Frame` to import the library. After that, a `encode` function and a `decode` function are available. The `encode` function takes a typed frame into its binary form. The `decode` function takes an IO buffer, and returns a typed frame.

For details about frames, see the [HTTP2 Specification](http://httpwg.org/specs/rfc7540.html).

## Stream and Connection

Once you have initialized a HTTP/2 connection, you can use the `HTTP2.Session`
namespace to send requests and responses.

### `send!`

`send!` function is defined as:

```julia
send!(connection::Connection, outbuf::IOBuffer,
      stream_identifier::UInt32, headers::Array{Header, 1}, body::Array{UInt8, 1})
```

You can use this function to initialize a request.

### `promise!`

`promise!` is defined as:

```julia
promise!(connection::Connection, outbuf::IOBuffer, stream_identifier::UInt32,
         request_headers::Array{Header, 1},
         headers::Array{Header, 1}, body::Array{UInt8, 1})
```

Use this function to initialize a push promise.

### `send_next` and `recv_next`

To maintain the connection, you need to create a loop that repeatly call
`send_next` and `recv_next`. Those functions need two IO Buffers, one for
sending data, and another for receiving data.
