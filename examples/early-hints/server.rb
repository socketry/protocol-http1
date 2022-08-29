#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require 'async'
require 'async/http/endpoint'

RESPONSE = <<~HTTP.split(/\r?\n/).join("\r\n")
HTTP/1.1 103 Early Hints
Link: </style.css>; rel=preload; as=style
Link: </script.js>; rel=preload; as=script

HTTP/1.1 200 OK
Content-Length: 11
Connection: close
Content-Type: text/plain

Hello World
HTTP

p RESPONSE

Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:3000")
	
	endpoint.accept do |peer|
		peer.write(RESPONSE)
	end
end
