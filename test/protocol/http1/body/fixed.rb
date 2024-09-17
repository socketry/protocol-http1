# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http1/body/fixed"

describe Protocol::HTTP1::Body::Fixed do
	let(:content) {"Hello World"}
	let(:buffer) {StringIO.new(content)}
	let(:body) {subject.new(buffer, content.bytesize)}
	
	with "#inspect" do
		it "can be inspected" do
			expect(body.inspect).to be =~ /length=11 remaining=11/
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
		
		it "doesn't close the stream when EOF was reached" do
			body.read
			body.close(EOFError)
			expect(buffer).not.to be(:closed?)
		end
	end
	
	with "#read" do
		it "retrieves chunks of content" do
			expect(body.read).to be == "Hello World"
			expect(body.read).to be == nil
		end
		
		it "updates number of bytes retrieved" do
			body.read
			expect(body).to be(:empty?)
		end
		
		with "length smaller than stream size" do
			let(:body) {subject.new(buffer, 5)}
			
			it "retrieves content up to provided length" do
				expect(body.read).to be == "Hello"
				expect(body.read).to be == nil
			end
			
			it "updates number of bytes retrieved" do
				body.read
				expect(body).to be(:empty?)
			end
		end
		
		with "length larger than stream size" do
			let(:body) {subject.new(buffer, 20)}
			
			it "retrieves content up to provided length" do
				body.read
				
				expect do
					body.read
				end.to raise_exception(EOFError)
			end
		end
	end
	
	with "#join" do
		it "returns all content" do
			expect(body.join).to be == "Hello World"
		end
		
		it "updates number of bytes retrieved" do
			chunk = body.read
			
			expect(body).to be(:empty?)
			
			expect(body).to have_attributes(
				length: be == chunk.bytesize,
				remaining: be == 0
			)
		end
	end
	
	with "#discard" do
		it "causes #read to raise EOFError" do
			body.discard
			
			expect do
				body.read
			end.to raise_exception(EOFError)
		end
	end
end
