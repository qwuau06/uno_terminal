class Card
	POOL = ['0','1','2','3','4','5','6','7','8','9','B','S','D','CC','PF',"N/A"]
	COLOR = ['R','G','B','Y','B','N/A']

	def initialize(str)
		@color = str[0].to_i
		@num = str[1].to_i(16)
	end

	def clr
		return @color
	end

	def num
		return @num
	end

	def to_s
		return @color.to_s + @num.to_s(16)
	end

	def playable? cd
		return true if @num==14
		return true if @num==13 && cd.num<14
		return true if cd.clr==@color && cd.clr< 4
		return true if cd.num==@num && cd.num < 13
		return false
	end

	def self.strnize(num,color)
		return color.to_s+num.to_s(16)
	end
end

class Deck
	def initialize
		@deck = Array.new
		4.times do |color|
		(1..12).each do |num|
			str = Card.strnize(num,color)
			@deck.push(Card.new(str))
			@deck.push(Card.new(str))
		end
		end
		4.times do |color|
			@deck.push(Card.new(Card.strnize(0,color)))
			@deck.push(Card.new(Card.strnize(13,4)))
			@deck.push(Card.new(Card.strnize(14,4)))
		end
		@deck.shuffle

		@garbage = Array.new
	end

	def reshuffle
		@deck.concat @garbage
		@deck.shuffle
		@garbage = Array.new
	end

	def draw
		return @deck.shift
	end

	def discard(cd)
		@garbage.push(cd)
	end

	def empty?
		return true if @deck.size == 0
		return false 
	end
end

class Hand
	RED = 0
	GREEN = 1
	BLUE = 2
	YELLOW = 3
	NA = 4
	REAR = 5

	def initialize 
		@hand = Array.new
		@df = Array.new [0,0,0,0,0,0]
	end

	def add(cd)
		place = 0
		(@df[cd.clr]...@df[cd.clr+1]).each do |card|
			next if @hand[card].num < cd.num
			place = card
			break
		end
		@hand.insert(place,cd)
		(cd.clr+1..5).each do |pt|
			@df[pt]+=1
		end
	end

	def num
		return @df[REAR]
	end

	def empty?
		return true if @df[REAR] == 0
		return false
	end

	def play(cd)
		@hand-=[cd]
		@playable-=[cd]
		(cd.clr+1..5).each do |pt|
			@df[pt]-=1
		end
	end

	def has_playable?(cd)
		mark_playable
		return true if @playable.size>0
		return false
	end

	def mark_playable(cd)
		@playable = Array.new
		@hand.each do |cur|
			@playable.push cur if cur.playable?(cd)
		end
		return @playable
	end
end
