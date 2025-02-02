local gui = script.Parent

local reroll = gui.reroll
local discard = gui.discard
local play_hand = gui.play_hand
local give_up = gui.give_up
local sort_rank = gui.sort_rank
local sort_suit = gui.sort_suit

local Players = game:GetService("Players")

---------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- outgoing to server
local reroll_event = ReplicatedStorage.Reroll
local discard_event = ReplicatedStorage.Discard
local play_hand_event = ReplicatedStorage.PlayHand
--local give_up_event = ReplicatedStorage.GiveUp
local sort_rank_event = ReplicatedStorage.SortRank
local sort_suit_event = ReplicatedStorage.SortSuit

-- incoming from server
local highlight_event = ReplicatedStorage.Highlight

local holder_function = ReplicatedStorage.HolderCFrame
local cards_cframe_function = ReplicatedStorage.CardPosition

-- incoming from client
local deselect_event = ReplicatedStorage.Deselect

---------------------------------------------------------------------------------------------------

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local hand_module = require(ReplicatedFirst.hand_module)

local default_color = hand_module.default_color
local selected_color = hand_module.selected_color

---------------------------------------------------------------------------------------------------

local debounce = false
local debounce_time = 0.2

function attempt_debounce()
	if debounce then
		return false
	end

	debounce = true
	return true
end

function finish_debounce()
	task.wait(debounce_time)

	debounce = false
end

---------------------------------------------------------------------------------------------------

local actions = {"reroll", "discard", "play_hand", "give_up", "sort_rank", "sort_suit"}

function action_handler(action)
	if not attempt_debounce() then
		return
	end
	
	if action == actions[1] then
		reroll_event:FireServer()
		
	elseif action == actions[2] then
		discard_request()
		--reset_selection()
		
	elseif action == actions[3] then
		play_hand_event:FireServer()
		--reset_selection()
		
	elseif action == actions[4] then
		gui.check.Visible = true
		
	elseif action == actions[5] then
		list_highlights()
		sort_rank_event:FireServer()
		
	elseif action == actions[6] then
		list_highlights()
		sort_suit_event:FireServer()
	end	
	
	finish_debounce()
end

for _, child in ipairs(gui:GetChildren()) do
	if child.ClassName == "TextButton" then
		child.MouseButton1Click:Connect(function()
			action_handler(child.Name)
		end)
	end
end

---------------------------------------------------------------------------------------------------

--function reset_selection()
--	for _, child in ipairs(gui.Frame:GetChildren()) do
--		if child.ClassName == "TextButton" then
--			child.BorderColor3 = default_color
--		end
--	end
--end

local discard_value = {}

function discard_request()
	discard_value = {}
	
	local discard_list = {}
	
	for _, child in ipairs(gui.Frame:GetChildren()) do
		if child.ClassName == "TextButton" then
			if child.BorderColor3 == selected_color then
				table.insert(discard_list, child.Name)
				child.BorderColor3 = default_color
			end
		end
	end
	
	discard_event:FireServer(discard_list)
end

---------------------------------------------------------------------------------------------------



function list_highlights()
	for _, child in ipairs(gui.Frame:GetChildren()) do
		if child.ClassName == "TextButton" then
			if child.BorderColor3 == selected_color then
				if not table.find(discard_value, child.Text) then
					table.insert(discard_value, child.Text) 
				end
				
				child.BorderColor3 = default_color
			end
		end
	end
end
	
highlight_event.OnClientEvent:Connect(function()
	for _, child in ipairs(gui.Frame:GetChildren()) do
		if child.ClassName == "TextButton" then
			if table.find(discard_value, child.Text) then
				child.BorderColor3 = selected_color
			end
		end
	end
end)

deselect_event.Event:Connect(function(card_text)
	local index = table.find(discard_value, card_text)
	
	if index then
		table.remove(discard_value, index)
	end
end)

---------------------------------------------------------------------------------------------------

holder_function.OnClientInvoke = function()

	local holder = script.Parent.Frame:FindFirstChild("holder")
	
	local absolute_position = holder.AbsolutePosition
	local position = UDim2.new(0, absolute_position.X, 0, absolute_position.Y)

	local absolute_size = holder.AbsoluteSize
	local size = UDim2.new(0, absolute_size.X, 0, absolute_size.Y)

	return position, size
end

cards_cframe_function.OnClientInvoke = function()
	local positions = {}
	local size
	
	local i = 1
	local card_gui = gui.Frame:FindFirstChild(i)
	
	
	
	if card_gui then
		local absolute_size = card_gui.AbsoluteSize
		size = UDim2.new(0, absolute_size.X, 0, absolute_size.Y)
	end
	
	while card_gui do
		local absolute_position = card_gui.AbsolutePosition
		local position = UDim2.new(0, absolute_position.X, 0, absolute_position.Y)

		table.insert(positions, position)
		
		i += 1
		card_gui = gui.Frame:FindFirstChild(i)
	end
	
	return positions, size
end