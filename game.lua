local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Tween = game:GetService("TweenService")

------------------------------------------------------------------

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local hand_module = require(ReplicatedFirst.hand_module)

local suits = hand_module.suits
local colors = hand_module.colors
local values = hand_module.values
local hand_types = hand_module.hand_types

local special_rounds = hand_module.special_rounds
local special_hands = hand_module.special_hands
local special_text = hand_module.special_text

local selected_color = hand_module.selected_color
local default_color = hand_module.default_color

------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- incoming from clients
local play_event = ReplicatedStorage.Play

local reroll_event = ReplicatedStorage.Reroll
local discard_event = ReplicatedStorage.Discard
local play_hand_event = ReplicatedStorage.PlayHand
local give_up_event = ReplicatedStorage.GiveUp
local sort_rank_event = ReplicatedStorage.SortRank
local sort_suit_event = ReplicatedStorage.SortSuit

-- outgoing to client
local highlight_event = ReplicatedStorage.Highlight

local holder_function = ReplicatedStorage.HolderCFrame
local cards_cframe_function = ReplicatedStorage.CardPosition

local ServerStorage = game:GetService("ServerStorage")

-- outgoing to server
local hand_request = ServerStorage.hand

------------------------------------------------------------------

local decks = {}
local hands = {}
local debuffs = {}
local debuffs_this_round = {}

local rerolls = {}
local discards = {}
local rounds = {}

local anim_time = 0.15

function player_exists(player)
	return player and player.PlayerGui
end

------------------------------------------------------------------

local BadgeService = game:GetService("BadgeService")

local badges = {
	round_10 = 2531781344260768,
	round_20 = 775354937763622,
	round_30 = 4244103022191355,
	round_40 = 2726450634725177,
	round_49 = 1052079834871593
}

------------------------------------------------------------------

function card_sound(player)
	local card_sound = player.PlayerGui.sounds.page
	card_sound:Play()
end

function deck_sound(player)
	--local deck_sound = player.PlayerGui.sounds.bow1
	local deck_sound = player.PlayerGui.sounds.Swish
	deck_sound:Play()
end

------------------------------------------------------------------

function create_deck(player)
	local player_id = player.UserId
	
	decks[player_id] = {}
	
	local deck = decks[player_id]
	
	for i = 1, 52 do
		table.insert(deck, i)
	end
end

function init_game_tables(player)
	local player_id = player.UserId
	
	hands[player_id] = {}
	rerolls[player_id] = 1
	discards[player_id] = 1
	rounds[player_id] = 1
	debuffs_this_round[player_id] = {}
end

function reset_gui(player)
	local game_gui = player.PlayerGui.Game
	local hand_gui = game_gui.Frame
	
	for _, child in ipairs(hand_gui:GetChildren()) do
		if child.ClassName == "TextButton" and child.Name ~= "template" then
			child:Destroy()
		end
	end
	
	game_gui.reroll.Text = "Reroll (" .. 1 .. ")"
	game_gui.discard.Text = "Discard (" .. 1 .. ")"
	game_gui.round.Text = "Round " .. 1
end

--------------------------------------------------------------

function update_card_size(player)
	local frame = player.PlayerGui.Game.Frame
	local player_id = player.UserId
	local hand = hands[player_id]
		
	if #hand == 1 then
		frame.UIGridLayout.CellSize = UDim2.new(.185, 0, .9, 0)
	elseif #hand == 6 then
		frame.UIGridLayout.CellSize = UDim2.new(.15, 0, .475, 0)
	elseif #hand == 13 then
		frame.UIGridLayout.CellSize = UDim2.new(.1, 0, .475, 0)
	elseif #hand == 19 then
		frame.UIGridLayout.CellSize = UDim2.new(.07, 0, .465, 0)
	elseif #hand == 25 then
		frame.UIGridLayout.CellSize = UDim2.new(.09, 0, .3, 0)
	elseif #hand == 31 then
		frame.UIGridLayout.CellSize = UDim2.new(.07, 0, .3, 0)
	elseif #hand == 37 then
		frame.UIGridLayout.CellSize = UDim2.new(.06, 0, .3, 0)
	elseif #hand == 43 then
		frame.UIGridLayout.CellSize = UDim2.new(.05, 0, .3, 0)
	end
end

function translate_card(number)
	number = tonumber(number)

	local value = values[number % 13]
	if number % 13 == 0 then
		value = values[13]
	end

	local card_group = math.ceil(number / 13)
	local suit = suits[card_group]
	local color = BrickColor.new(colors[card_group])

	return value .. suit, color
end

function give_card(player)
	local player_id = player.UserId
	
	local deck = decks[player_id]
	local hand = hands[player_id]

	local card = table.remove(deck, math.random(1, #deck))
	table.insert(hand, card)
	update_card_size(player)
	
	local game_gui = player.PlayerGui.Game
	local frame_gui = game_gui.Frame
	local template_frame = game_gui.template_frame
	
	local card_gui = template_frame.template:Clone()
	card_gui.Name = tostring(#hand)
	card_gui.Visible = true

	local face, color = translate_card(card)
	card_gui.Text = face
	card_gui.TextColor = color
	
	-- holds card's place
	local holder = frame_gui.Frame:Clone()
	holder.Visible = true
	holder.Parent = frame_gui
	holder.Name = "holder"

	local position, size = holder_function:InvokeClient(player)

	card_gui.Size = size
	card_gui.Position = UDim2.new(card_gui.Position.X, position.Y)
	card_gui.Parent = template_frame

	local goal = {}
	goal.Position = position
	
	local anim_time = 0.1
	local tweenInfo = TweenInfo.new(anim_time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = Tween:Create(card_gui, tweenInfo, goal)
	
	tween:Play()
	card_sound(player)
	
	task.wait(anim_time)
	holder:Destroy()
	card_gui.Parent = frame_gui
end

function update_hand(player)
	local frame = player.PlayerGui.Game.Frame
	local player_id = player.UserId
	local hand = hands[player_id]
	
	local play_once = false
		
	-- get card absolute positions
	local card_pos, card_size = cards_cframe_function:InvokeClient(player)
	
	-- animate
	for _, child in ipairs(frame:GetChildren()) do
		if child.ClassName ~= "TextButton" then
			continue
		end
		
		child.Parent = frame.Parent.template_frame
		child.Position = card_pos[tonumber(child.Name)]
		child.Size = card_size
		
		for i = 1, #hand do
			local card = hand[i]
			local face, color = translate_card(card)
			
			if face == child.Text and i ~= tonumber(child.Name) then
				if not play_once then
					play_once = true
					deck_sound(player)
				end
				
				local goal = {}
				goal.Position = card_pos[i]

				local tweenInfo = TweenInfo.new(anim_time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
				local tween = Tween:Create(child, tweenInfo, goal)

				tween:Play()
				
				break
			end
		end
	end
	
	task.wait(anim_time)
	
	-- return cards to frame
	for i = 1, #hand do
		local card = hand[i]
		local face, color = translate_card(card)

		local card_gui = frame.Parent.template_frame:FindFirstChild(i)
		card_gui.Parent = frame

		if card_gui.Text == face then
			continue
		end

		card_gui.Text = face
		card_gui.TextColor = color
	end
		
		--for i = 1, #hand do
		--	local card = hand[i]
		--	local face, color = translate_card(card)

		--	local card_gui = frame:FindFirstChild(i)

		--	if card_gui.Text == face then
		--		continue
		--	end
			
		--	if not play_once then
		--		play_once = true
		--		deck_sound(player)
		--	end

		--	card_gui.Text = face
		--	card_gui.TextColor = color
		--end
	
	-- help client to move the discard highlight after reorder
	highlight_event:FireClient(player)
end

function rank(card)
	local rank = card % 13

	if rank == 0 then
		return 13
	end

	return rank
end

function sort_by_rank(player)
	local player_id = player.UserId
	local hand = hands[player_id]
	
	sort_by_suit(player)
	
	local suit_hand = table.clone(hand)
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

	hands[player_id] = rank_hand
end

function sort_by_suit(player)
	local player_id = player.UserId
	local hand = hands[player_id]

	table.sort(hand)
end

----------------------------------------------------------------

function discard_cards(player, discarded_cards)
	local player_id = player.UserId
	
	local deck = decks[player_id]
	local hand = hands[player_id]
	
	-- replace values
	for i, card_index in ipairs(discarded_cards) do
		card_index = tonumber(card_index)

		local interval = #deck - (i - 1)
		if interval < 1 then
			interval = #deck
		end

		local card = table.remove(deck, math.random(1, interval))	
		table.insert(deck, hand[card_index])
		hand[card_index] = card

		--local card_gui = player.PlayerGui.Game.Frame:FindFirstChild(card_index)

		--local face, color = translate_card(card)

		--card_gui.Text = face
		--card_gui.TextColor = color
	end
	
	local game_gui = player.PlayerGui.Game
	local frame = game_gui.Frame
	local template_frame = game_gui.template_frame
	
	local card_pos, card_size = cards_cframe_function:InvokeClient(player)
	local plays = 0
	
	-- animate
	for _, child in ipairs(frame:GetChildren()) do
		if child.ClassName ~= "TextButton" then
			continue
		end

		child.Parent = template_frame
		child.Position = card_pos[tonumber(child.Name)]
		child.Size = card_size

		for i = 1, #hand do
			local card = hand[i]
			local face, color = translate_card(card)

			if face ~= child.Text and i == tonumber(child.Name) then
				child.BackgroundTransparency = 1
				child.Text = ""
				
				local animation_card = template_frame.template:Clone()
				animation_card.Parent = template_frame
				animation_card.Size = card_size
				animation_card.Text = face
				animation_card.TextColor = color
				animation_card.Visible = true
				
				plays += 1

				local goal = {}
				goal.Position = card_pos[i]

				local tweenInfo = TweenInfo.new(anim_time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
				local tween = Tween:Create(animation_card, tweenInfo, goal)

				tween:Play()
				
				Debris:AddItem(animation_card, anim_time)

				break
			end
		end
	end
	
	if plays == 1 then
		card_sound(player)
	elseif plays > 1 then
		deck_sound(player)
	end
	
	task.wait(anim_time)

	-- return cards to frame
	for i = 1, #hand do
		local card = hand[i]
		local face, color = translate_card(card)

		local card_gui = frame.Parent.template_frame:FindFirstChild(i)
		card_gui.Parent = frame

		if card_gui.Text == face then
			continue
		end
		
		card_gui.BackgroundTransparency = 0

		card_gui.Text = face
		card_gui.TextColor = color
	end
end

function choose_debuff(player)
	local player_id = player.UserId
	local player_gui = player.PlayerGui.Game
	
	local reroll_gui = player_gui.reroll	
	local debuff_gui = player_gui.dont
	
	local special_round_number = table.find(special_rounds, tonumber(rounds[player_id]))
	if special_round_number then
		debuffs[player_id] = special_hands[special_round_number]
		debuff_gui.Text = special_text[special_round_number]
		
		debuff_gui.debuff.Enabled = false
		debuff_gui.special.Enabled = true
		
		reroll_gui.Interactable = false
		reroll_gui.BackgroundColor3 = Color3.fromRGB(0,0,0)
		
		return
	end		
	
	debuff_gui.debuff.Enabled = true
	debuff_gui.special.Enabled = false
	
	reroll_gui.Interactable = true
	reroll_gui.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	
	-- if rerolled through 8 and on the 9th now, then drop previous 8 and add back to pool. then add current to already had debuffs
	if #debuffs_this_round[player_id] == 8 then
		debuffs_this_round[player_id] = {}
	end
	
	-- if we have a current debuff
	if debuffs[player.UserId] then
		table.insert(debuffs_this_round[player_id], debuffs[player.UserId])
	end
	
	-- ensure new debuff from any this round
	while debuffs[player.UserId] == nil or table.find(debuffs_this_round[player_id], debuffs[player_id]) do
		local debuff_index = math.random(1, #hand_types)

		debuffs[player.UserId] = hand_types[debuff_index]
	end
	
	debuff_gui.Text = debuffs[player.UserId]
end

------------------------------------------------------------------

function valid_hand(player)
	-- TODO
	return true
end

function play(player)
	local player_gui = player.PlayerGui
	
	player_gui.Start.Enabled = false
	player_gui.Game.Enabled = true
	player_gui.Game.game_over.Visible = false
	
	create_deck(player)
	
	init_game_tables(player)
	
	reset_gui(player)
	
	give_card(player)
	
	choose_debuff(player)
end

function game_over(player)
	local leaderstats = player.leaderstats
	local highscore_attribute = leaderstats and leaderstats:FindFirstChild("High Score")
	
	local player_id = player.UserId
	local hand = hands[player_id]
	
	local over_gui = player.PlayerGui.Game.game_over
	over_gui.Visible = true
	over_gui.score.Text = #hand
	
	--if #hand == 49 then
	--	over_gui.title.Text = "YOU WIN"
	--	over_gui.title.TextColor = BrickColor.new(Color3.fromRGB(0,255,0))
	--else
		over_gui.title.Text = "GAME OVER"
		over_gui.title.TextColor = BrickColor.new(Color3.fromRGB(255, 0, 0))
	--end
	
	if highscore_attribute.Value < #hand then
		highscore_attribute.Value = #hand
		
		over_gui.highscore.Visible = true
	end
end

function create_warning(player, text)
	local game_gui = player.PlayerGui.Game
	
	local warning = game_gui.warning_template:Clone()
	
	local other_warning = game_gui:FindFirstChild("warning")
	if other_warning then
		other_warning:Destroy()
	end
	
	warning.Text = text
	warning.Name = "warning"
	warning.Visible = true
	warning.Parent = game_gui
	Debris:AddItem(warning, 3)
	
	for i = 1, 10 do
		task.wait(.3)
		warning.TextTransparency = i * .1
	end
end

function badge_handler(player)
	local player_id = player.UserId
	local badge_id = badges["round_" .. rounds[player_id]]
	
	if not badge_id then
		return
	end
	
	local success, badge_info = pcall(BadgeService.GetBadgeInfoAsync, BadgeService, badge_id)
	if success then
		-- Confirm that badge can be awarded
		if badge_info.IsEnabled then
			-- Award badge
			local awarded, err = pcall(BadgeService.AwardBadge, BadgeService, player_id, badge_id)
			if not awarded then
				warn("Error while awarding badge:", err)
			end
		end
	else
		warn("Error while fetching badge info!")
	end
end

------------------------------------------------------------------

play_event.OnServerEvent:Connect(function(player)
	if not player_exists(player) then
		return
	end
	
	play(player)
end)

reroll_event.OnServerEvent:Connect(function(player)
	if not player_exists(player) then
		return
	end
	
	if rerolls[player.UserId] < 1 then
		local text = "You are out of rerolls!"
		create_warning(player, text)
		return -- not enough rerolls
	end
	
	rerolls[player.UserId] -= 1
	
	choose_debuff(player)
	
	player.PlayerGui.Game.reroll.Text = "Reroll (" .. rerolls[player.UserId] .. ")"
end)

discard_event.OnServerEvent:Connect(function(player, discarded_cards)
	if not player_exists(player) then
		return
	end
	
	if #discarded_cards == 0 then
		local text = "Select cards to discard!"
		create_warning(player, text)
		return
	end
	
	local player_id = player.UserId
	
	if discards[player_id] == 0 then
		local text = "You are out of discards!"
		create_warning(player, text)
		return
	end
	
	if discards[player_id] < #discarded_cards then	
		local text = "Not enough discards for selected cards!"
		create_warning(player, text)
		return
	end
	
	discards[player_id] -= #discarded_cards
	
	discard_cards(player, discarded_cards)
	
	player.PlayerGui.Game.discard.Text = "Discard (" .. discards[player.UserId] .. ")"
end)


play_hand_event.OnServerEvent:Connect(function(player)
	if not player_exists(player) then
		return
	end
	
	local player_id = player.UserId
	
	if hand_request:Invoke(debuffs[player_id], hands[player_id]) then
		if rerolls[player_id] == 0 and discards[player_id] == 0 then
			game_over(player)
		else
			local text = "Use rerolls and discards to pass this round!"
			create_warning(player, text)
		end
		
		return
	end
	
	local game_gui = player.PlayerGui.Game
	
	rerolls[player_id] += 1
	discards[player_id] += 1
	rounds[player_id] += 1
	debuffs_this_round[player_id] = {}
	
	game_gui.reroll.Text = "Reroll (" .. rerolls[player_id] .. ")"
	game_gui.discard.Text = "Discard (" .. discards[player_id] .. ")"
	game_gui.round.Text = "Round " .. rounds[player_id]
	
	badge_handler(player)
	
	choose_debuff(player)
	
	give_card(player)
	
	--if #hands[player_id] == 49 then
	--	game_over(player)
	--end
end)

give_up_event.OnServerEvent:Connect(function(player)
	if not player_exists(player) then
		return
	end
	
	game_over(player)
end)

sort_rank_event.OnServerEvent:Connect(function(player)
	if not player_exists(player) then
		return
	end
	
	local player_id = player.UserId
	local hand = hands[player_id]
	
	sort_by_rank(player)

	update_hand(player)
end)

sort_suit_event.OnServerEvent:Connect(function(player)
	if not player_exists(player) then
		return
	end

	local player_id = player.UserId
	local hand = hands[player_id]

	sort_by_suit(player)
	
	update_hand(player)
end)


------------------------------------------------------------------