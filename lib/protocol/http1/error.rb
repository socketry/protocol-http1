# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http/error'

module Protocol
	module HTTP1
		class Error < HTTP::Error
		end
		
		# The request was not able to be parsed correctly, or failed some kind of validation.
		class BadRequest < Error
		end
		
		# A header name or value was invalid, e.g. contains invalid characters.
		class BadHeader < BadRequest
		end
		
		# Indicates that the request is invalid for some reason, e.g. syntax error, invalid headers, etc.
		class InvalidRequest < BadRequest
		end
		
		# The specified content length and the given content's length do not match.
		class ContentLengthError < Error
		end
	end
end
