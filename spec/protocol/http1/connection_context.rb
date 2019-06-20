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

require 'socket'

RSpec.shared_context Protocol::HTTP1::Connection do
	let(:sockets) {
		r, w = Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)
		# https://github.com/socketry/protocol-http1/pull/1#discussion_r295598266
		# https://docs.ruby-lang.org/en/2.3.0/IO.html#method-i-gets
		# https://docs.ruby-lang.org/en/2.5.0/IO.html#method-i-gets
		if !($stdin.gets(nil, 0, chomp: true) rescue nil)
			def r.gets(*args, chomp: false)
				chomp ? super(*args).chomp : super(*args)
			end

			def w.gets(*args, chomp: false)
				chomp ? super(*args).chomp : super(*args)
			end
		end

		[r, w]
	}

	let(:client) {Protocol::HTTP1::Connection.new(sockets.first)}
	let(:server) {Protocol::HTTP1::Connection.new(sockets.last)}
end
