# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

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
					@remaining == 0
				end
				
				def close(error = nil)
					if @remaining != 0
						@stream.close
					end
					
					super
				end
				
				def read
					if @remaining > 0
						if chunk = @stream.readpartial(@remaining)
							@remaining -= chunk.bytesize
							
							return chunk
						else
							raise EOFError, "Stream closed with #{@remaining} bytes remaining!"
						end
					end
				end
				
				def join
					buffer = @stream.read(@remaining)
					
					@remaining = 0
					
					return buffer
				end
				
				def inspect
					"\#<#{self.class} length=#{@length} remaining=#{@remaining}>"
				end
			end
		end
	end
end
