# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http1/connection"
require "connection_context"

describe Protocol::HTTP1::Connection do
	include_context ConnectionContext
	
	with "#write_response" do
		before do
			server.open!
		end

		def validate_headers!(expected_headers = self.headers)
			server.write_empty_body
			client.open!

			version, status, reason, headers, body = client.read_response("GET")

			expect(headers).to be == headers
		end

		with "a content-type header" do
			let(:headers) {{"content-type" => "text/plain"}}

			it "can parse the header" do
				server.write_response("HTTP/1.1", 200, headers)

				validate_headers!
			end
		end

		with "an empty header" do
			let(:headers) {{"nothing" => ""}}

			it "can parse the header" do
				server.write_response("HTTP/1.1", 200, headers)
				
				validate_headers!
			end
		end

		with "a header that contains tab characters" do
			let(:headers) {{"user-agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) \t\t\tChrome/55.0.2883.95 Safari/537.36"}}

			it "can parse the header" do
				server.write_response("HTTP/1.1", 200, headers)

				validate_headers!
			end
		end

		with "a header that contains obsolete folding whitespace" do
			let(:headers) {{"user-agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko)\n\tChrome/55.0.2883.95 Safari/537.36"}}

			it "rejects the response" do
				expect do
					server.write_response("HTTP/1.1", 200, headers)
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end

		with "a header that contains invalid characters" do
			let(:headers) {{"user-agent" => "Mozilla\x00Hacker Browser"}}

			it "rejects the response" do
				expect do
					server.write_response("HTTP/1.1", 200, headers)
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end

		with "a header that contains invalid high characters" do
			let(:headers) {{"user-agent" => "Mozilla\x7FHacker Browser"}}

			it "allows the response" do
				server.write_response("HTTP/1.1", 200, headers)

				validate_headers!
			end
		end
	end

	with "#read_request" do
		let(:headers) {Array.new}

		before do
			client.stream.write "GET / HTTP/1.1\r\nHost: localhost\r\n#{headers.join("\r\n")}\r\n\r\n"
			client.stream.close
		end

		with "a header that contains tab characters" do
			let(:headers) {[
				"user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) \t\t\tChrome/55.0.2883.95 Safari/537.36"
			]}

			it "can parse the header" do
				authority, method, target, version, headers, body = server.read_request

				expect(headers).to have_keys(
					"user-agent" => be == "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) \t\t\tChrome/55.0.2883.95 Safari/537.36"
				)
			end
		end

		with "a header that contains obsolete folding whitespace" do
			let(:headers) {[
				"user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko)\n\tChrome/55.0.2883.95 Safari/537.36"
			]}

			it "rejects the request" do
				expect do
					server.read_request
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end

		with "a header that contains invalid characters" do
			let(:headers) {[
				"user-agent: Mozilla\x00Hacker Browser"
			]}

			it "rejects the request" do
				expect do
					server.read_request
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end

		with "a header that contains invalid high characters" do
			let(:headers) {[
				"user-agent: Mozilla\x7FHacker Browser"
			]}

			it "allows the request" do
				authority, method, target, version, headers, body = server.read_request

				expect(headers).to have_keys(
					"user-agent" => be == "Mozilla\x7FHacker Browser"
				)
			end
		end

		with "a header that contains null character" do
			let(:headers) {[
				"user-agent: Mozilla\x00Hacker Browser"
			]}

			it "rejects the request" do
				expect do
					server.read_request
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end

		with "a header that has empty value but includes optional whitespace" do
			let(:headers) {[
				"user-agent: "
			]}

			it "can parse the header" do
				authority, method, target, version, headers, body = server.read_request

				expect(headers).to have_keys(
					"user-agent" => be == ""
				)
			end
		end

		with "a header that has empty value" do
			let(:headers) {[
				"user-agent:"
			]}

			it "can parse the header" do
				authority, method, target, version, headers, body = server.read_request

				expect(headers).to have_keys(
					"user-agent" => be == ""
				)
			end
		end

		with "a header that has invalid name" do
			let(:headers) {[
				"invalid name: value"
			]}

			it "rejects the request" do
				expect do
					server.read_request
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end

		with "a header that has empty name" do
			let(:headers) {[
				": value"
			]}

			it "rejects the request" do
				expect do
					server.read_request
				end.to raise_exception(Protocol::HTTP1::BadHeader)
			end
		end
	end
end
