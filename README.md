# HTTP2

[![Build Status](https://travis-ci.org/sorpaas/HTTP2.jl.svg?branch=master)](https://travis-ci.org/sorpaas/HTTP2.jl)
[![HTTPClient](http://pkg.julialang.org/badges/HTTP2_0.4.svg)](http://pkg.julialang.org/?pkg=HTTP2&ver=0.4)

A HTTP2 support library that handles frames, streams and connections.

```julia
julia> Pkg.add("HTTP2")
julia> using HTTP2
```

## Simple Servers and Clients

The library can directly create simple servers and clients.

You only use this library directly if you need low-level functionality. An
example for the server is as follows. The code will be explained in the next
section.

```julia
using HTTP2
using Sockets
using Dates

port = 8888
server = listen(port)

println("Waiting for a connection ...")
buffer = accept(server)
println("Processing a connection ...")

connection = HTTP2.Session.new_connection(buffer; isclient=false)

## Recv the client preface, and send an empty SETTING frame.
headers_evt = HTTP2.Session.take_evt!(connection)
stream_identifier = headers_evt.stream_identifier

sending_headers = HTTP2.Headers(":status" => "200",
                          "server" => "HTTP2.jl",
                          "date" => Dates.format(now(Dates.UTC), Dates.RFC1123Format),
                          "content-type" => "text/html; charset=UTF-8")
sending_body = convert(Vector{UInt8}, codeunits("hello"))

@info("Resopnding", sending_headers, sending_body)

HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendHeaders(stream_identifier, sending_headers, false))
HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendData(stream_identifier, sending_body, true))
## We are done!
```

A client can be started in a similar way. Again the code will be explained in
the next section.

```julia
using HTTP2
using Sockets

@info("Opening connection", conn_id)
buffer = connect("127.0.0.1", 8888)
connection = HTTP2.Session.new_connection(buffer; isclient=true)
headers = HTTP2.Headers(":method" => "GET",
                  ":path" => "/",
                  ":scheme" => "http",
                  ":authority" => "127.0.0.1:9000",
                  "accept" => "*/*",
                  "accept-encoding" => "gzip, deflate",
                  "user-agent" => "HTTP2.jl")

@info("Sending request", req_id)
HTTP2.Session.put_act!(connection, HTTP2.Session.ActSendHeaders(HTTP2.Session.next_free_stream_identifier(connection), headers, true))
(rcvd_headers, rcvd_data) = (HTTP2.Session.take_evt!(connection).headers, HTTP2.Session.take_evt!(connection).data)
```

## Connection Lifecycle

HTTP/2 is a binary protocol, and can handle multiple requests and responses in
one connection. As a result, you cannot read and write directly in the stream
like HTTP/1.1. Instead, you talk with the connection through channels. The main
interface of low-level HTTP/2 support resides in `HTTP2.Session` module.

```julia
import HTTP2.Session
```

### Create a Buffer

First you need to create a `buffer` that the connection can read and write. A
normal TCP connection from a client is usually like this:

```julia
buffer = connect(dest, port)
```

While for server, it usually looks like this:

```julia
server = listen(port)
buffer = accept(server)
```

You can also use `MbedTLS.jl` or other TLS library to get a buffer over TLS and
initialize a HTTPS connection.

### Initialize the Connection

After getting the buffer, we can start to initialize the connection.

```julia
connection = Session.new_connection(buffer; isclient=true)
```

`isclient` key indicates whether you are a server or a client. This is needed
because the server and client uses different stream identifiers.

Another important key to note is `skip_preface`. For a normal HTTP/2 connection,
this is usually set to false. However, if you are doing HTTP/2 protocol upgrade
(in which case the HTTP/2 preface should be skipped), you should set this key to
true.

### Initialize a New Stream

You don't need to do anything in particular to initialize a new stream, because
they are solely identified by its identifier. To get a new stream identifier,
call the `next_free_stream_identifier(connection)` function.

### Send and Receive Headers and Data

The connection is then alive, and you can start to send or receive headers and
data through the connection. Those are done by the `take_evt!` and `put_act!`
functions. `take_evt!(connection)` waits and return an event struct from the
connection. `put_act!(connection, action)` put a new action to the connection
and returns immediately.

#### Actions

* `ActPromise(stream_identifier, promised_stream_identifier, headers)`: This is
  usually sent from a server which sends a push promise. `stream_identifier`
  is the main stream identifier, `promised_stream_identifier` is the promised
  stream identifier that is going to be pushed, and `headers` are a `Headers`
  struct that sends the requests.
* `ActSendHeaders(stream_identifier, headers, is_end_stream)`: This can be used
  to send request headers, response headers, or other headers specified in the
  HTTP specification. If there's no more headers or data to be sent in the
  stream, `is_end_stream` should set to true.
* `ActSendData(stream_identifier, data, is_end_stream)`: This can be used to
  send request body, response body, or if a protocol switch is initialized, other
  specified protocol data. If there's no more headers or data to be sent in the
  stream, `is_end_stream` should set to true.

#### Events

* `EvtPromise(stream_identifier, promised_stream_identifier, headers)`: This
  event is triggered when a push promise is received. The struct is similar to
  `ActPromise`.
* `EvtRecvHeaders(stream_identifier, headers, is_end_stream)`: This event is
  triggered when a header is received. The struct is similar to
  `ActSendHeaders`.
* `EvtRecvData(stream_identifier, data, is_end_stream)`: This event is triggered
  when data is received in a stream. The struct is similar to `ActSendData`.
* `EvtGoaway()`: This event is triggered when the whole connection is about to
  be closed.

### Close the Connection

The connection can be closed using `close(connection)`.

## Frame

You can do `using HTTP2.Frame` to import the library. After that, a `encode` function and a `decode` function are available. The `encode` function takes a typed frame into its binary form. The `decode` function takes an IO buffer, and returns a typed frame.

For details about frames, see the [HTTP2 Specification](http://httpwg.org/specs/rfc7540.html).
