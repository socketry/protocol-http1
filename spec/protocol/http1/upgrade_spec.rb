# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'protocol/http1/connection'
require_relative 'connection_context'

RSpec.describe Protocol::HTTP1::Connection do
	include_context Protocol::HTTP1::Connection
	
	describe '#upgrade' do
		let(:protocol) {'binary'}
		let(:request_version) {Protocol::HTTP1::Connection::HTTP10}
		
		it "should upgrade connection" do
			client.write_request("testing.com", "GET", "/", request_version, [])
			stream = client.write_upgrade_body(protocol)
			
			stream.write "Hello World"
			stream.close_write
			
			authority, method, path, version, headers, body = server.read_request
			
			expect(version).to be == request_version
			expect(headers['upgrade']).to be == [protocol]
			expect(body).to be_nil
			
			stream = server.hijack!
			expect(stream.read).to be == "Hello World"
		end
	end
end
