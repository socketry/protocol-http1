# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "protocol/http1/connection"
require "connection_context"

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	with "#upgrade" do
		let(:protocol) {"binary"}
		let(:request_version) {Protocol::HTTP1::Connection::HTTP11}
		
		it "should upgrade connection" do
			client.write_request("testing.com", "GET", "/", request_version, [])
			stream = client.write_upgrade_body(protocol)
			
			stream.write "Hello World"
			stream.close_write
			
			authority, method, path, version, headers, body = server.read_request
			
			expect(version).to be == request_version
			expect(headers["upgrade"]).to be == [protocol]
			expect(body).to be_a(Protocol::HTTP1::Body::Remainder)
			
			stream = server.hijack!
			expect(stream.read).to be == "Hello World"
		end
		
		with "HTTP/1.0 request" do
			let(:request_version) {Protocol::HTTP1::Connection::HTTP10}
			
			it "should ignore upgrade header" do
				# RFC 9110 Section 7.8: a server MUST ignore the Upgrade header field in an HTTP/1.0 request.
				client.write_request("testing.com", "GET", "/", request_version, [])
				client.write_upgrade_body(protocol)
				
				authority, method, path, version, headers, body = server.read_request
				
				expect(version).to be == request_version
				expect(headers["upgrade"]).to be == [protocol]
				expect(body).to be_nil
				expect(server).not.to be(:persistent)
			end
			
			it "should not bypass transfer-encoding framing checks" do
				client.stream.write "GET / HTTP/1.0\r\nHost: localhost\r\nConnection: keep-alive\r\nUpgrade: #{protocol}\r\nTransfer-Encoding: chunked\r\n\r\nb\r\nHello World\r\n0\r\n\r\n"
				client.stream.close
				
				expect do
					server.read_request
				end.to raise_exception(Protocol::HTTP1::BadRequest, message: be =~ /HTTP\/1.0/)
				
				expect(server).not.to be(:persistent)
			end
		end
	end
end
