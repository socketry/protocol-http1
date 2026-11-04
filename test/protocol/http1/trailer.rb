# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "protocol/http1/connection"
require "protocol/http/body/buffered"

require "connection_context"

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	let(:chunks) {["Hello", "World"]}
	let(:body) {::Protocol::HTTP::Body::Buffered.wrap(chunks)}
	
	let(:trailer) {Hash.new}
	
	with "trailers" do
		before do
			client.open!
			server.open!
		end
		
		it "ignores trailers with HTTP/1.0" do
			expect(server).to receive(:write_fixed_length_body)
			server.write_body("HTTP/1.0", body, false, trailer)
		end
		
		it "ignores trailers with content length" do
			expect(server).to receive(:write_fixed_length_body)
			server.write_body("HTTP/1.1", body, false, trailer)
		end
		
		it "uses chunked encoding when given trailers without content length" do
			expect(body).to receive(:length).and_return(nil)
			trailer["foo"] = "bar"
			
			server.write_response("HTTP/1.1", 200, {})
			server.write_body("HTTP/1.1", body, false, trailer)
			
			version, status, reason, headers, body = client.read_response("GET")
			
			expect(version).to be == "HTTP/1.1"
			expect(status).to be == 200
			expect(headers).to be == {}
			
			# Read all of the response body, including trailers:
			body.join
			
			# Headers are updated:
			expect(headers).to be == {"foo" => ["bar"]}
		end
		
		it "keeps received trailers separate from the header section" do
			expect(body).to receive(:length).and_return(nil)
			trailer["foo"] = "bar"
			
			server.write_response("HTTP/1.1", 200, {"etag" => "abcd"})
			server.write_body("HTTP/1.1", body, false, trailer)
			
			version, status, reason, headers, body = client.read_response("GET")
			
			expect(headers).not.to be(:trailer?)
			expect(headers.header.to_a).to be == [["etag", "abcd"]]
			
			body.join
			
			expect(headers).to be(:trailer?)
			expect(headers.header.to_a).to be == [["etag", "abcd"]]
			expect(headers.trailer.to_a).to be == [["foo", "bar"]]
		end
	end
	
	with "request trailers" do
		it "keeps received request trailers separate from the header section" do
			expect(body).to receive(:length).and_return(nil)
			trailer["x-forwarded-host"] = "evil"
			
			client.write_request("localhost", "POST", "/", "HTTP/1.1", {"content-type" => "text/plain"})
			client.write_body("HTTP/1.1", body, false, trailer)
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(method).to be == "POST"
			expect(headers).not.to be(:trailer?)
			expect(headers.header.to_a).to be == [["content-type", "text/plain"]]
			
			expect(body.join).to be == "HelloWorld"
			
			# Request trailers are controlled by the client, so they must not appear in the header section:
			expect(headers).to be(:trailer?)
			expect(headers.header.to_a).to be == [["content-type", "text/plain"]]
			expect(headers.trailer.to_a).to be == [["x-forwarded-host", "evil"]]
		end
		
		it "does not mark the trailer section when no request trailers are received" do
			expect(body).to receive(:length).and_return(nil)
			
			client.write_request("localhost", "POST", "/", "HTTP/1.1", {"content-type" => "text/plain"})
			client.write_body("HTTP/1.1", body)
			
			authority, method, target, version, headers, body = server.read_request
			
			expect(body.join).to be == "HelloWorld"
			
			expect(headers).not.to be(:trailer?)
			expect(headers.header.to_a).to be == [["content-type", "text/plain"]]
		end
	end
end
