# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http1/connection"
require "stringio"

describe Protocol::HTTP1::Connection do
	let(:stream) {StringIO.new("".b)}
	let(:connection) {subject.new(stream)}
	
	["", "GE T", "GE\tT", "GET\r", "GET\n", "GE\0T", "GET:", "GÉT", "GE\xFFT".b.force_encoding(Encoding::UTF_8)].each do |method|
		with "an invalid method #{method.inspect}", unique: method.inspect do
			it "rejects the method before writing any request bytes" do
				expect do
					connection.write_request("example.com", method, "/", "HTTP/1.1", {})
				end.to raise_exception(Protocol::HTTP::RefusedError)
				
				expect(stream.string).to be == ""
				expect(connection).to be(:idle?)
			end
		end
	end
	
	it "rejects a method containing an injected request" do
		method = "GET /first HTTP/1.1\r\nhost: example.com\r\ncontent-length: 0\r\n\r\nGET"
		
		expect do
			connection.write_request("example.com", method, "/", "HTTP/1.1", {})
			connection.write_body("HTTP/1.1", nil)
		end.to raise_exception(Protocol::HTTP::RefusedError)
		
		expect(stream.string).to be == ""
		expect(connection).to be(:idle?)
	end
	
	it "preserves extension methods using any HTTP token character" do
		method = "!\#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
		connection.write_request("example.com", method, "/", "HTTP/1.1", {})
		
		expect(stream.string).to be == "#{method} / HTTP/1.1\r\nhost: example.com\r\n"
	end
end
