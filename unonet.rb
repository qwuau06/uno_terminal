require './uno.rb'
require 'socket'
require 'thread'
require 'timeout'

# Server maintains the deck

class Server
	def initialize pc,port=8915
		@mutex = Mutex.new
		@server = 
			begin
				TCPServer.new(port)
			rescue SyscallError => ex
				raise "open port failed, #{ex}"
			end
		@player = 0
		@clients = Array.new
		@thpool = Array.new
		@client_que = Array.new(4) 
		puts "Successfully established. "

		wait_th = Thread.new {
			pc.times do |order|
				th = Thread.fork(@server.accept) do |client|
					@mutex.synchronize do
						@clients.size.times do |n|
							com @clients[n],"msg","player #{client} joined game."
						end
					end
					puts "player #{client} joined game."
					com client,"handshake","#{order}"
					com client,"msg","Connection Established, waiting for others."
					@mutex.synchronize do
						@clients.push(client)
						@client_que.push(Queue.new)
					end

					while str = @clients[order].gets.chomp do
						@client_que[order].push str
					end
				end
				@thpool.push(th)
			end
		}
		puts "Waiting for clients..."

		#control player numbers

		while str = gets.chomp do
			if (@clients.size < pc) && (@clients.size > 1) && (str.eql?"start") then
				(@clients.size...pc).each do |n|
					Thread.kill(@thpool[n])
				end
				Thread.kill(wait_th)
			elsif @clients.size==pc then
				puts "Game Begin"
			else
				puts "Input 'start' to start"
			end
			if @clients.size==pc then
				break
			end
		end

		broadcast "start",@clients.size.to_s

		# go back to main stream
	end

	def clean_up
		@thpool.each do |th|
			Thread.kill(th)
		end
	end

	def get_resp(n)
		return @client_que[n].pop
	end

	def wait_for_client(clt)
		return @clients[clt].gets.chomp
	end

	def com(clt,type,msg="")
		@clients[clt].puts type
		@clients[clt].puts msg.to_s
	end

	def broadcast(type,str)
		@clients.size.times do |clt|
			com clt,type,str
		end
	end
end

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
		@last = "4F"
	end

	def game(ip, port=8915)
		#thread communication
		@recv_que= Queue.new

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
				case sig
				when "msg"
					display @server.gets.chomp
				when "draw"
					@mutex.synchronize do
						@recv_que << 1
						@recv_que << Card.new(@server.gets.chomp) # get new card
					end
				when "turn" 
					turn_info = @server.gets.chomp.split(',')
					@all_hands.size.times do |n|
						@all_hands[n] = turn_info.shift.to_i
					end
					@dir = turn_info.shift.to_i
					@cur = turn_info.shift.to_i
					@mutex.synchronize do
						@recv_que << 2
						@recv_que << Card.new(turn_info.shift) # last card
					end
				when "win"
					@mutex.synchronize do
						@recv_que << 3
					end
				when "handshake"
					@mutex.synchronize do
						@recv_que << 4
						@recv_que <<  @server.gets.chomp.to_i 
					end
				when "start"
					@all_hands = Array.new 5,@server.gets.chomp.to_i # num of players
					setup_display
				else
				end
			end
		}

		mainloop

	end

	def display msg
		#dummy
		puts msg
	end

	def display_msg msg
		#dummy
		puts msg
	end

	def setup_display
		#dummy
	end

	def win
		#dummy
	end

	def mainloop
		loop do
			sig = @recv_que.pop if !@recv_que.empty?
			sig = -1 if !@recv_que.empty?
			case sig
			when 1
				card = nil
				@mutex.synchronize do
					card = @recv_que.pop
				end
				@hand.add(card)
				display "You draw #{card.to_s}"
			when 2
				@mutex.synchronize do
					@last = @recv_que.pop
				end
				display "Last played was #{@last.to_s}"

				if @cur==@order then
					display_msg "Your turn."
					@hand.mark_playable
					play(ask_for_play)
				end
			when 3
				win
			when 4
				@order = @server.gets.chomp.to_i
				display_msg "Your order is #{@order}"
			end
		end
	end

	def ask_for_play
		#dummy
		str = gets.chomp
		return nil if str.eql?""
		return Card.new(str)
	end

	def play(cd)
		@server.puts "p" if cd==nil
		@server.puts cd.to_s unless cd==nil
		@hand.remove(cd) unless cd==nil
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

class UnoGame_Server
	def initialize players=4
		@deck = Deck.new
		@players = players
		@cur = 0
		@dir = 1
		@last = Card.new("4F")
		@hand = Array.new
		@server = Server.new(players)
		@players.times do 
			@hand.push(Hand.new)
		end
		@winners = Array.new
	end

	def game
		#initialize
		game_in_play = true

		4.times do |player|
			5.times do draw(player) end
		end

		#turn and check
		
		loop do
			ct = @players
			ct.times do |player|
				next if @winners.include?player
				wait_for_play(player)
				if @hand[player].empty? then
					win(player)
					if @winners.size == @Players.size then
						game_in_play = false
						break
					end
				end
			end
			break if game_in_play == false
		end
	end

	def infos
		str = ""
		@players.times do |n|
			str += @hand[n].num+","
		end
		str += @dir.to_s + ","
		str += @cur.to_s + ","
		str += @last.to_s + ","
		return str
	end

	def next
		pf = @last[1].to_i(16)
		inc = 1
		if pf==10 then
			@dir = -@dir
		elsif pf==11 then
			inc = 2
		end
		if @dir == 1 then
			@cur+=inc
			while @winners.include?(@cur) do
				@cur = (@cur+1)%4
			end
		else
			@cur-=inc
			while @winners.include?(@cur) do
				@cur = (@cur-1)%4
			end
		end
		@server.broadcast "turn",infos
	end

	def draw(player=@cur)
		if @deck.empty? then
			@deck.reshuffle
		end
		card = @deck.draw
		@hand[player].add(card)
		@server.com @cur,"draw",card.to_s
	end

	def play(player=@cur,card)
		@last = card
		@hand[player].remove(card)
		@deck.discard(card)
		return @hand[player].size
	end

	def wait_for_play
		@server.get_resp @cur
		while ret.eql?"p" do
			draw
		end
		@cur = play(ret)
	end

	def win(player=@cur)
		@winners.push(player)
	end
end
