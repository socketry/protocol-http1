# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

require 'protocol/http1/connection'
require 'protocol/http/body/buffered'

require 'connection_context'

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	let(:chunks) {["Hello", "World"]}
	let(:body) {::Protocol::HTTP::Body::Buffered.wrap(chunks)}
	
	let(:trailer) {Hash.new}
	
	with 'trailers' do
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
			trailer['foo'] = 'bar'
			
			server.write_response("HTTP/1.1", 200, {})
			server.write_body("HTTP/1.1", body, false, trailer)
			
			version, status, reason, headers, body = client.read_response("GET")
			
			expect(version).to be == 'HTTP/1.1'
			expect(status).to be == 200
			expect(headers).to be == {}
			
			# Read all of the response body, including trailers:
			body.join
			
			# Headers are updated:
			expect(headers).to be == {'foo' => ['bar']}
		end
	end
end
