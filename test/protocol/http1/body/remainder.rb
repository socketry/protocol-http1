# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'protocol/http1/body/remainder'

describe Protocol::HTTP1::Body::Remainder do
	let(:content) {"Hello World"}
	let(:buffer) {StringIO.new(content)}
	let(:body) {subject.new(buffer)}
	
	with "#inspect" do
		it "can be inspected" do
			expect(body.inspect).to be =~ /open/
		end
	end
	
	with "#empty?" do
		it "returns whether EOF was reached" do
			expect(body.empty?).to be == false
		end
	end
	
	with "#stop" do
		it "closes the stream" do
			body.close(EOFError)
			expect(buffer).to be(:closed?)
		end
		
		it "closes the stream when EOF was reached" do
			body.read
			body.close(EOFError)
			expect(buffer).to be(:closed?)
		end
	end
	
	with "#read" do
		it "retrieves chunks of content" do
			expect(body).not.to be(:empty?)
			
			expect(body.read).to be == "Hello World"
			expect(body.read).to be == nil
			
			expect(body).to be(:empty?)
		end
	end
	
	with "#call" do
		it "streams the content" do
			stream = StringIO.new
			body.call(stream)
			expect(stream.string).to be == "Hello World"
		end
	end
	
	with "#join" do
		it "returns all content" do
			expect(body).not.to be(:empty?)
			
			expect(body.join).to be == "Hello World"
			
			expect(body).to be(:empty?)
		end
	end
end
