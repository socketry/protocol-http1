# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http1/body/fixed"
require "protocol/http1/connection"

describe Protocol::HTTP1::Body::Fixed do
	let(:content) {"Hello World"}
	let(:buffer) {StringIO.new(content)}
	let(:connection) {Protocol::HTTP1::Connection.new(buffer, state: :open)}
	let(:body) {subject.new(connection, content.bytesize)}
	
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
			
			expect(connection).to be(:half_closed_remote?)
		end
		
		it "doesn't close the stream when EOF was reached" do
			body.read
			body.close(EOFError)
			expect(buffer).not.to be(:closed?)
			
			expect(connection).to be(:half_closed_remote?)
		end
		
		it "causes #read to raise EOFError" do
			body.close
			
			expect do
				body.read
			end.to raise_exception(EOFError)
		end
	end
	
	with "#read" do
		it "retrieves chunks of content" do
			expect(body.read).to be == "Hello World"
			expect(body.read).to be == nil
			
			expect(connection).to be(:half_closed_remote?)
		end
		
		it "updates number of bytes retrieved" do
			body.read
			expect(body).to be(:empty?)
		end
		
		with "length smaller than stream size" do
			let(:body) {subject.new(connection, 5)}
			
			it "retrieves content up to provided length" do
				expect(body.read).to be == "Hello"
				expect(body.read).to be == nil
				
				expect(connection).to be(:half_closed_remote?)
			end
			
			it "updates number of bytes retrieved" do
				expect(body).to have_attributes(remaining: be == body.length)
				
				body.read
				
				expect(body).to have_attributes(remaining: be == 0)
				expect(body).to be(:empty?)
				
				expect(connection).to be(:half_closed_remote?)
			end
		end
		
		with "length larger than stream size" do
			let(:body) {subject.new(connection, 20)}
			
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
			
			expect(connection).to be(:half_closed_remote?)
		end
	end
	
	with "#discard" do
		it "causes #read to return nil" do
			body.discard
			
			expect(body.read).to be == nil
			
			expect(connection).to be(:half_closed_remote?)
		end
	end
end
