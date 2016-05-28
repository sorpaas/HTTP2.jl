# HTTP2

[![Build Status](https://travis-ci.org/sorpaas/HTTP2.jl.svg?branch=master)](https://travis-ci.org/sorpaas/HTTP2.jl)

A HTTP2 support library. It currently implements HTTP Frame encoders and decoders. A full stream and connection handler is planned.

## Frame

You can do `using HTTP2.Frame` to import the library. After that, a `encode` function and a `decode` function are available. The `encode` function takes a typed frame into its binary form. The `decode` function takes an IO buffer, and returns a typed frame.

For details about frames, see the [HTTP2 Specification](http://httpwg.org/specs/rfc7540.html).
