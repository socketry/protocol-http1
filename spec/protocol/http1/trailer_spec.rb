# frozen_string_literal: true

# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'protocol/http1/connection'
require 'protocol/http/body/buffered'

require_relative 'connection_context'

RSpec.describe Protocol::HTTP1::Connection do
	include_context Protocol::HTTP1::Connection
	
	let(:chunks) {["Hello", "World"]}
	let(:body) {::Protocol::HTTP::Body::Buffered.wrap(chunks)}
	
	let(:trailer) {Hash.new}
	
	context 'with trailers' do
		it "ignores trailers with HTTP/1.0" do
			expect(server).to receive(:write_fixed_length_body)
			server.write_body("HTTP/1.0", body, false, trailer)
		end
		
		it "choose chunked encoding when given trailers" do
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
