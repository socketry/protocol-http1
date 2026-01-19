# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

describe Protocol::HTTP1::BadRequest do
	it "should be a subclass of Protocol::HTTP::BadRequest" do
		expect(Protocol::HTTP1::BadRequest).to be < Protocol::HTTP::BadRequest
	end
end
