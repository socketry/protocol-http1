# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require 'protocol/http/body/readable'

module Protocol
	module HTTP1
		module Body
			class Chunked < HTTP::Body::Readable
				CRLF = "\r\n"
				
				def initialize(stream, headers)
					@stream = stream
					@finished = false
					
					@headers = headers
					
					@length = 0
					@count = 0
				end
				
				def empty?
					@finished
				end
				
				def close(error = nil)
					# We only close the connection if we haven't completed reading the entire body:
					unless @finished
						@stream.close
						@finished = true
					end
					
					super
				end
				
				VALID_CHUNK_LENGTH = /\A[0-9a-fA-F]+\z/
				
				# Follows the procedure outlined in https://tools.ietf.org/html/rfc7230#section-4.1.3
				def read
					return nil if @finished
					
					length, _extensions = read_line.split(";", 2)
					
					unless length =~ VALID_CHUNK_LENGTH
						raise BadRequest, "Invalid chunk length: #{length.inspect}"
					end
					
					# It is possible this line contains chunk extension, so we use `to_i` to only consider the initial integral part:
					length = Integer(length, 16)
					
					if length == 0
						@finished = true
						
						read_trailer
						
						return nil
					end
					
					# Read trailing CRLF:
					chunk = @stream.read(length + 2)
					
					# ...and chomp it off:
					chunk.chomp!(CRLF)
					
					@length += length
					@count += 1
					
					return chunk
				end
				
				def inspect
					"\#<#{self.class} #{@length} bytes read in #{@count} chunks>"
				end
				
				private
				
				def read_line?
					@stream.gets(CRLF, chomp: true)
				end
				
				def read_line
					read_line? or raise EOFError
				end
				
				def read_trailer
					while line = read_line?
						# Empty line indicates end of trailer:
						break if line.empty?
						
						if match = line.match(HEADER)
							@headers.add(match[1], match[2])
						else
							raise BadHeader, "Could not parse header: #{line.inspect}"
						end
					end
				end
			end
		end
	end
end
