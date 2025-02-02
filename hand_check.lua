local ReplicatedFirst = game:GetService("ReplicatedFirst")

local hand_module = require(ReplicatedFirst.hand_module)

local hand_types = hand_module.hand_types
local special_hands = hand_module.special_hands

--------------------------------------------------------

local ServerStorage = game:GetService("ServerStorage")

-- incoming from game_script
local hand_request = ServerStorage.hand

--------------------------------------------------------

hand_request.OnInvoke = function(debuff, hand)
	if not table.find(hand_types, debuff) and not table.find(special_hands, debuff) then
		print("error")
		return
	end
	
	local sorted_hand
	
	-- if flush then want sorted by suit | otherwise sorted by rank
	if debuff == hand_types[5] or debuff == hand_types[8] or debuff == hand_types[9] then
		sorted_hand = sort_by_suit(hand)
	else
		sorted_hand = sort_by_rank(hand)
	end
	
	if debuff == hand_types[1] then     -- pair 			(sort by rank)
		return is_pair(sorted_hand)
	
	elseif debuff == hand_types[2] then -- Two Pair 		(sort by rank)
		return is_two_pair(sorted_hand)
	
	elseif debuff == hand_types[3] then -- Three of a Kind 	(sort by rank)
		return is_three(sorted_hand)
	
	elseif debuff == hand_types[4] then -- Straight 		(sort by rank)
		return is_straight(sorted_hand)
	
	elseif debuff == hand_types[5] then -- Flush 			(sort by suit)
		return is_flush(sorted_hand)
	
	elseif debuff == hand_types[6] then -- Full House 		(sort by rank)
		return is_full_house(sorted_hand)
	
	elseif debuff == hand_types[7] then	-- Four of a Kind 	(sort by rank)
		return is_four(sorted_hand)
	
	elseif debuff == hand_types[8] then	-- Straight Flush 	(sort by suit)
		return is_straight_flush(sorted_hand)
	
	elseif debuff == hand_types[9] then	-- Royal Flush 		(sort by suit)
		return is_royal_flush(sorted_hand)
		
	elseif debuff == special_hands[1] then
		return is_blackjack(sorted_hand)
		
	elseif debuff == special_hands[2] then
		return is_every_suit(sorted_hand)
		
	elseif debuff == special_hands[3] then
		return is_pocket_aces(sorted_hand)
		
	elseif debuff == special_hands[4] then
		return is_every_rank(sorted_hand)

	elseif debuff == special_hands[5] then
		return is_jackpot(sorted_hand)
	end
end

-------------------------------------------------

function rank(card)
	local rank = card % 13
	
	if rank == 0 then
		return 13
	end
	
	return rank
end

function suit(card)
	return math.ceil(card / 13)
end

function sort_by_rank(hand)
	local suit_hand = sort_by_suit(hand)
	local rank_hand = {}
	
	while #suit_hand > 0 do
		local min_index = 1
		for i = 2, #suit_hand do
			if rank(suit_hand[min_index]) > rank(suit_hand[i]) then
				min_index = i
			end
		end
		table.insert(rank_hand, table.remove(suit_hand, min_index))
	end
	
	return rank_hand
end

function sort_by_suit(hand)
	local sorted_hand = table.clone(hand)
	table.sort(sorted_hand)
	return sorted_hand
end

function x_of_a_kind(hand, x) -- 2, 3, 4 of a kind
	if #hand < x then
		return false
	end
	
	local x_end = x - 1
	
	for i = 1, (#hand - x_end) do
		if rank(hand[i]) == rank(hand[i + x_end]) then
			local card_rank = rank(hand[i])
			
			while (#hand >= i) and (rank(hand[i]) == card_rank) do
				table.remove(hand, i) -- remove all instances of rank. avoiding hitting true for 4 of a kind when checking 2 pair
			end
			
			return true
		end
	end

	return false
end

local royal_straight = {1, 10, 11, 12, 13}

function is_royal_straight(hand)
	for i in ipairs(royal_straight) do
		local card_exists = false
		
		for k = 0, 3 do	-- check all suits for proper rank
			local searching_card = 13 * k + royal_straight[i]
			
			if table.find(hand, searching_card) then
				card_exists = true
				break
			end
		end
		
		if not card_exists then
			return false
		end
	end
	return true
end

-------------------------------------------------

function is_pair(hand)
	return x_of_a_kind(hand, 2)
end

function is_two_pair(hand)
	return x_of_a_kind(hand, 2) and x_of_a_kind(hand, 2)
end

function is_three(hand)
	return x_of_a_kind(hand, 3)
end

function is_straight(hand)
	for i = 1, (#hand - 4) do -- loop through all cards except last 4 (deck is in rank order)
		if rank(hand[i]) > 9 then -- non-royal straight can only start as low as 9
			break -- cards sorted in rank order, so only 10, J, Q, K left to check. do this under function with royal straight
		end
		
		local straight = true
		
		for  j = 1, 4 do -- check for the following 4 cards
			local card_exists = false
			
			for k = 0, 3 do	-- check all suits for proper following rank
				local searching_card = 13 * k + rank(hand[i]) + j

				if table.find(hand, searching_card) then
					card_exists = true
					break
				end
			end
			
			if not card_exists then
				straight = false
				break
			end
		end
		
		if straight then
			return true
		end
	end
	
	-- failed, so check if royal straight
	return is_royal_straight(hand)
end

function is_flush(hand) -- ordered by suit
	for i = 1, (#hand - 4) do
		if suit(hand[i]) == suit(hand[i + 4]) then
			return true
		end
	end
	
	return false
end

function is_full_house(hand)
	return x_of_a_kind(hand, 3) and x_of_a_kind(hand, 2)
end

function is_four(hand, jokers)
	return x_of_a_kind(hand, 4)
end

-- TODO FIX
function is_straight_flush(hand)
	for i = 1, (#hand - 4) do -- loop through all cards except last 4 (deck is in suit order)
		if suit(hand[i]) ~= suit(hand[i + 4]) then -- if suit of first card doesnt match last in row of 5 then skip
			continue
		end
		
		local straight_flush = true

		for j = 1, 4 do -- check for the following 4 cards
			if hand[i] + j ~= hand[i+j] then
				straight_flush = false
				break
			end
		end

		if straight_flush then
			return true
		end
	end
	
	-- failed, so check if royal flush
	return is_royal_flush(hand)
end

function is_royal_flush(hand)
	if #hand < 5 then
		return false
	end
	
	for k = 0, 3 do -- loop through suits
		local royal_flush = true

		for i in ipairs(royal_straight) do
			local searching_card = 13 * k + royal_straight[i]

			if not table.find(hand, searching_card) then
				royal_flush = false
				break
			end
		end

		if royal_flush then
			return true
		end
	end

	return false
end

function is_blackjack(hand)
	local sum = 0
	
	for _, card in ipairs(hand) do
		sum += math.min(rank(card), 10) -- face cards are value 10
	end
	
	return sum > 21
end

function is_every_suit(hand)
	local suits = {}
	for i = 1, 4 do
		table.insert(suits, i)
	end
	
	for _, card in ipairs(hand) do
		local index = table.find(suits, suit(card))
		if index then
			table.remove(suits, index)
		end
	end

	return #suits == 0
end

function is_pocket_aces(hand)
	local aces = 0

	for _, card in ipairs(hand) do
		if rank(card) == 1 then
			aces += 1

			if aces >= 2 then
				return true
			end

		elseif rank(card) > 1 then
			return false
		end
	end
end

function is_every_rank(hand)
	local ranks = {}
	for i = 1, 13 do
		table.insert(ranks, i)
	end
	
	for _, card in ipairs(hand) do
		local index = table.find(ranks, rank(card))
		if index then
			table.remove(ranks, index)
		end
	end

	return #ranks == 0
end

function is_jackpot(hand)
	local sevens = 0
	
	for _, card in ipairs(hand) do
		if rank(card) == 7 then
			sevens += 1
			
			if sevens >= 3 then
				return true
			end
			
		elseif rank(card) > 7 then
			return false
		end
	end
end