# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'protocol/http/body/readable'

module Protocol
	module HTTP1
		module Body
			class Fixed < HTTP::Body::Readable
				def initialize(stream, length)
					@stream = stream
					@length = length
					@remaining = length
				end
				
				attr :length
				attr :remaining
				
				def empty?
					@stream.nil? or @remaining == 0
				end
				
				def close(error = nil)
					if @stream
						# If we are closing the body without fully reading it, the underlying connection is now in an undefined state.
						if @remaining != 0
							@stream.close_read
						end
						
						@stream = nil
					end
					
					super
				end
				
				# @raises EOFError if the stream is closed before the expected length is read.
				def read
					if @remaining > 0
						if @stream
							# `readpartial` will raise `EOFError` if the stream is closed/finished:
							if chunk = @stream.readpartial(@remaining)
								@remaining -= chunk.bytesize
								
								return chunk
							end
						end
						
						raise EOFError, "Stream closed before expected length was read!"
					end
				end
				
				def inspect
					"\#<#{self.class} length=#{@length} remaining=#{@remaining} state=#{@stream ? 'open' : 'closed'}>"
				end
			end
		end
	end
end
