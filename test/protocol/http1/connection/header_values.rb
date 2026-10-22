# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http1/connection"
require "stringio"

describe Protocol::HTTP1::Connection do
	let(:stream) {StringIO.new("".b)}
	let(:connection) {subject.new(stream)}
	
	["\r", "\n", "\0", "\r\n"].each do |character|
		with "a value containing #{character.inspect}", unique: character.inspect do
			let(:value) {"before#{character}after"}
			let(:headers) {Protocol::HTTP::Headers["location" => value]}
			
			it "rejects ordinary header values before writing them" do
				expect do
					connection.write_headers(headers)
				end.to raise_exception(Protocol::HTTP1::BadHeader)
				
				expect(stream.string).to be == ""
			end
			
			it "rejects request header values" do
				expect do
					connection.write_request(nil, "GET", "/", "HTTP/1.1", headers)
				end.to raise_exception(Protocol::HTTP::RefusedError)
			end
			
			it "rejects response header values" do
				connection.open!
				
				expect do
					connection.write_response("HTTP/1.1", 302, headers)
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
			
			it "rejects interim response header values" do
				connection.open!
				
				expect do
					connection.write_interim_response("HTTP/1.1", 103, headers)
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
			
			it "rejects the authority before writing any request bytes" do
				expect do
					connection.write_request(value, "GET", "/", "HTTP/1.1", {})
				end.to raise_exception(Protocol::HTTP::RefusedError)
				
				expect(stream.string).to be == ""
			end
			
			it "rejects the target before writing any request bytes" do
				expect do
					connection.write_request("example.com", "GET", "/#{value}", "HTTP/1.1", {})
				end.to raise_exception(Protocol::HTTP::RefusedError)
				
				expect(stream.string).to be == ""
			end
			
			it "rejects CONNECT targets before writing any request bytes" do
				expect do
					connection.write_request(nil, "CONNECT", "#{value}:443", "HTTP/1.1", {})
				end.to raise_exception(Protocol::HTTP::RefusedError)
				
				expect(stream.string).to be == ""
			end
			
			it "rejects generated Upgrade header values before writing them" do
				expect do
					connection.write_upgrade_header(value)
				end.to raise_exception(Protocol::HTTP1::BadHeader)
				
				expect(stream.string).not.to be(:include?, "upgrade:")
			end
		end
	end
	
	it "preserves an empty header value" do
		connection.write_headers("x-empty" => "")
		
		expect(stream.string).to be == "x-empty: \r\n"
	end
	
	it "preserves all other bytes in header values" do
		value = ((0..255).to_a - [0, 10, 13]).pack("C*")
		connection.write_headers("x-bytes" => value)
		
		expect(stream.string).to be == "x-bytes: #{value}\r\n"
	end
	
	it "writes a valid Host header" do
		connection.write_request("example.com", "GET", "/", "HTTP/1.1", {})
		
		expect(stream.string).to be == "GET / HTTP/1.1\r\nhost: example.com\r\n"
	end
	
	it "preserves percent-encoded request targets" do
		connection.write_request("example.com", "GET", "/%00%0D%0A", "HTTP/1.1", {})
		
		expect(stream.string).to be == "GET /%00%0D%0A HTTP/1.1\r\nhost: example.com\r\n"
	end
	
	it "writes a valid CONNECT target without a Host header" do
		connection.write_request(nil, "CONNECT", "example.com:443", "HTTP/1.1", {})
		
		expect(stream.string).to be == "CONNECT example.com:443 HTTP/1.1\r\n"
	end
	
	it "writes valid upgrade headers" do
		connection.write_upgrade_header("websocket")
		
		expect(stream.string).to be == "connection: upgrade\r\nupgrade: websocket\r\n"
	end
end
