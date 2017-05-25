require './uno.rb'
require 'socket'
require 'thread'
require 'timeout'
# Client can see his hand, draw card from the deck and play cards, but cannot access the deck itself

# Need a new thread to process server side communication

class Client
	def initialize
		puts "Client start."
		@server = nil
		@order = -1
		@hand = Hand.new
		@all_hands = Array.new
		@mutex = Mutex.new
		@dir = 1
		@cur = -1
		@last = "5F"
	end

	def game(ip, port=8915)
		#thread communication
		@recv_que= Queue.new
		@check_que = Queue.new

		@server = begin
				  Timeout::timeout(2){TCPSocket.open(ip,port)}
			  rescue StandardError, RuntimeError => ex
				  raise "cannot connect to server. #{ex}"
			  end
		puts "Connected."

		# new thread to handle com asynchronically

		@recv_thread = Thread.new {
			loop do
				sig = @server.gets.chomp
				#puts "#{sig}"
				case sig
				when "msg"
					display @server.gets.chomp
				when "draw"
				#	@mutex.synchronize do
						@recv_que << 1
						@recv_que << Card.new(@server.gets.chomp) # get new card
				#	end
				when "turn" 
					turn_info = @server.gets.chomp.split(',')
					@all_hands.size.times do |n|
						@all_hands[n] = turn_info.shift.to_i
					end
					@dir = turn_info.shift.to_i
					@cur = turn_info.shift.to_i
				#	@mutex.synchronize do
						@recv_que << 2
						@recv_que << Card.new(turn_info.shift) # last card
				#	end
				when "win"
				#	@mutex.synchronize do
						@recv_que << 3
				#	end
				when "handshake"
				#	@mutex.synchronize do
						@recv_que << 4
						@recv_que <<  @server.gets.chomp.to_i 
				#	end
				when "start"
					@all_hands = Array.new @server.gets.chomp.to_i # num of players
					setup_display
				when "check"
				#	@mutex.synchronize do
						@check_que << @server.gets.chomp.to_i
				#	end
				else
				end
			end
		}

		mainloop

	end

	def display msg
		#dummy
		@mutex.synchronize do
			puts msg
		end
	end

	def display_msg msg
		#dummy
		@mutex.synchronize do
			puts msg
		end
	end

	def setup_display
		#dummy
	end

	def win
		#dummy
		@mutex.synchronize do
			puts "You win."
		end
	end

	def mainloop
		play_session = false
		played = false
		loop do
			sig = -1
			@mutex.synchronize do
				sig = @recv_que.pop if !@recv_que.empty?
			end
			next if sig==-1
			case sig
			when 1
				card = nil
			#	@mutex.synchronize do
					card = @recv_que.pop
			#	end
				@hand.add(card)
				display "You draw #{card.to_s}"
				if played && play_session then
					next
				end
			when 2
			#	@mutex.synchronize do
					@last = @recv_que.pop
			#	end
				display "Last played was #{@last.to_s}"
				if @cur==@order then
					display_msg "Your turn."
					play_session = true
					played = false
				else
					play_session = false
					played = false
				end
			when 3
				win
			when 4
				@order = @recv_que.pop
				display_msg "Your order is #{@order}"
			end
			if play_session == true then
				@hand.mark_playable(@last)
				display_msg "Remaining Cards: #{@hand.to_s}"
				display_msg "Your playable cards are: #{@hand.show_playable}"
				ret,cd = play(ask_for_play)
				while !ret do
					display_msg "You cannot play this card, choose again."
					ret,cd = play(ask_for_play)
				end
				played = true if cd==nil
			end
		end
	end

	def ask_for_play
		#dummy
		str = gets.chomp
		return nil if str.eql?"p"
		return Card.new(str)
	end

	def play(cd)
		if cd==nil then
			@server.puts "p"
			display_msg "pass, draw new card"
			return true
		else
			@server.puts cd.to_s
			ret = @check_que.pop
			if ret == 1 then
				@hand.play(cd)
				return true,cd
			else
				return false
			end
		end
	end
end

class Prompts
	def initialize
		flag = true
		while flag do
			puts "Create Room (C)"
			puts "Join Room (J)"
			puts "Quit (Q)"
			input = gets.chomp
			if input.upcase.eql?"C" then
				flag = false
				@game = Server.new
				@type = "server"
			elsif input.upcase.eql?"J" then
				flag = false
				@game = Client.new
				@type = "client"
			elsif input.upcase.eql?"Q" then
				exit
			else
				puts "Invalid option"
			end

		end
	end

end
