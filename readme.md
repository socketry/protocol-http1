# Protocol::HTTP1

Provides a low-level implementation of the HTTP/1 protocol.

[![Development Status](https://github.com/socketry/protocol-http1/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http1/actions?workflow=Test)

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'protocol-http1'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install protocol-http1

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-http1/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-http1/guides/getting-started/index) - This guide explains how to get started with `protocol-http1`, a low-level implementation of the HTTP/1 protocol for building HTTP clients and servers.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-http1/releases/index) for all releases.

### Unreleased

  - Add traces provider for `Protocol::HTTP1::Connection`.

### v0.34.1

  - Fix connection state handling to allow idempotent response body closing.
  - Add `kisaten` fuzzing integration for improved security testing.

### v0.34.0

  - Support empty header values in HTTP parsing for better compatibility.

### v0.33.0

  - Support high-byte characters in HTTP headers for improved international compatibility.

### v0.32.0

  - Fix header parsing to handle tab characters between values correctly.
  - Complete documentation coverage for all public APIs.

### v0.31.0

  - Enforce one-way transition for persistent connections to prevent invalid state changes.

### v0.30.0

  - Make `authority` header optional in HTTP requests for improved flexibility.

### v0.29.0

  - Add block/yield interface to `read_request` and `read_response` methods.

### v0.28.1

  - Fix handling of `nil` lines in HTTP parsing.

### v0.28.0

  - Add configurable maximum line length to prevent denial of service attacks.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
