# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http1/connection"
require "protocol/http/body/buffered"
require "protocol/http/body/writable"

require "connection_context"

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	with "multiple requests in a single connection" do
		it "handles two back-to-back GET requests (HTTP/1.1 keep-alive)" do
			client.write_request("localhost", "GET", "/first", "HTTP/1.1", {"Header-A" => "Value-A"})
			client.write_body("HTTP/1.1", nil)
			expect(client).to be(:half_closed_local?)
			
			# Server reads it:
			authority, method, path, version, headers, body = server.read_request
			expect(authority).to be == "localhost"
			expect(method).to be == "GET"
			expect(path).to be == "/first"
			expect(version).to be == "HTTP/1.1"
			expect(headers["header-a"]).to be == ["Value-A"]
			expect(body).to be_nil
			
			# Server writes a response:
			expect(server).to be(:half_closed_remote?)
			server.write_response("HTTP/1.1", 200, {"Res-A" => "ValA"}, "OK")
			server.write_body("HTTP/1.1", nil)
			expect(server).to be(:idle?)
			
			# Client reads first response:
			version, status, reason, headers, body = client.read_response("GET")
			expect(version).to be == "HTTP/1.1"
			expect(status).to be == 200
			expect(reason).to be == "OK"
			expect(headers["res-a"]).to be == ["ValA"]
			expect(body).to be_nil
			
			# Now both sides should be back to :idle (persistent re-use):
			expect(client).to be(:idle?)
			expect(server).to be(:idle?)
			
			# Second request:
			client.write_request("localhost", "GET", "/second", "HTTP/1.1", {"Header-B" => "Value-B"})
			client.write_body("HTTP/1.1", nil)
			expect(client).to be(:half_closed_local?)
			
			# Server reads it:
			authority, method, path, version, headers, body = server.read_request
			expect(authority).to be == "localhost"
			expect(method).to be == "GET"
			expect(path).to be == "/second"
			expect(version).to be == "HTTP/1.1"
			expect(headers["header-b"]).to be == ["Value-B"]
			expect(body).to be_nil
			
			# Server writes a response:
			expect(server).to be(:half_closed_remote?)
			server.write_response("HTTP/1.1", 200, {"Res-B" => "ValB"}, "OK")
			server.write_body("HTTP/1.1", nil)
			
			# Client reads second response:
			version, status, reason, headers, body = client.read_response("GET")
			expect(version).to be == "HTTP/1.1"
			expect(status).to be == 200
			expect(reason).to be == "OK"
			expect(headers["res-b"]).to be == ["ValB"]
			expect(body).to be_nil
			
			# Confirm final states:
			expect(client).to be(:idle?)
			expect(server).to be(:idle?)
		end
	end
	
	with "partial body read" do
		it "closes correctly if server does not consume entire fixed-length body" do
			# Indicate Content-Length = 11 but only read part of it on server side:
			client.stream.write "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 11\r\n\r\nHello"
			client.stream.close
			
			# Server reads request line/headers:
			authority, method, path, version, headers, body = server.read_request
			expect(method).to be == "POST"
			expect(body).to be_a(Protocol::HTTP1::Body::Fixed)
			
			# Partially read 5 bytes only:
			partial = body.read
			expect(partial).to be == "Hello"
			
			expect do
				body.read
			end.to raise_exception(EOFError)
			
			# Then server forcibly closes read (simulating a deliberate stop):
			server.close_read
			
			# Because of partial consumption, that should move the state to half-closed remote or closed, etc.
			expect(server).to be(:half_closed_remote?)
			expect(server).not.to be(:persistent)
		end
	end
	
	with "no persistence" do
		it "closes connection after request" do
			server.persistent = false
			
			client.write_request("localhost", "GET", "/first", "HTTP/1.1", {"Header-A" => "Value-A"})
			client.write_body("HTTP/1.1", nil)
			expect(client).to be(:half_closed_local?)
			
			# Server reads it:
			authority, method, path, version, headers, body = server.read_request
			expect(authority).to be == "localhost"
			expect(method).to be == "GET"
			expect(path).to be == "/first"
			expect(version).to be == "HTTP/1.1"
			expect(headers["header-a"]).to be == ["Value-A"]
			expect(body).to be_nil
			
			# Server writes a response:
			expect(server).to be(:half_closed_remote?)
			server.write_response("HTTP/1.1", 200, {"Res-A" => "ValA"}, "OK")
			server.write_body("HTTP/1.1", nil)
			expect(server).to be(:closed?)
		end
	end
end
