--[[			Chicchai
]]--	by Lolzen & Cargor (EU-Nozdormu)

-- Configuration
local maxHeight = 120				-- How high the chat frames are when maximized
local animTime = 0.3				-- How lang the animation takes (in seconds)
local minimizeTime = 10				-- Minimize after X seconds
local minimizedLines = 1			-- Number of chat messages to show in minimized state

local MaximizeOnEnter = true		-- Maximize when entering chat frame, minimize when leaving
local WaitAfterEnter = 0			-- Wait X seconds after entering before maximizing
local WaitAfterLeave = 0			-- Wait X seconds after leaving before minimizing

local LockInCombat = nil			-- Do not maximize in combat

local MaximizeCombatLog = true		-- When the combat log is selected, it will be maximized

FCF_ValidateChatFramePosition = function() end	-- You can move chat frames completely to the bottom

-- Modify this to maximize only on special channels
-- comment/remove it to react on all channels
local channelNumbers = {
	[1] = true,
	[2] = true,
	[3]  = true,
}

local ChatFrameConfig = {	-- Events which maximize the chat for the different windows
	["ChatFrame1"] = {
--		"CHAT_MSG_CHANNEL",
--		"CHAT_MSG_OFFICER",
		"CHAT_MSG_BG_SYSTEM_ALLIANCE",
		"CHAT_MSG_BG_SYSTEM_HORDE",
		"CHAT_MSG_BG_SYSTEM_NEUTRAL",
		"CHAT_MSG_BATTLEGROUND",
		"CHAT_MSG_BATTLEGROUND_LEADER",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
--		"CHAT_MSG_GUILD",
		"CHAT_MSG_SAY",
		"CHAT_MSG_SYSTEM",
		"CHAT_MSG_WHISPER",
--		"CHAT_MSG_WHISPER_INFORM",
--		"CHAT_MSG_LOOT",
		"CHAT_MSG_YELL",
	},
	["ChatFrame3"] = true,
}
-- Configuration End
-- Do not change anything under this line except you know what you're doing (:



local select = select
local UP, DOWN = 1, -1

local function getMinHeight(self)
	local minHeight = 0
	for i=1, minimizedLines do
		local line = select(1+i, self:GetRegions())
		if(line) then
			minHeight = minHeight + line:GetHeight() + 2.5
		end
	end
	if(minHeight == 0) then
		minHeight = select(2, self:GetFont()) + 2.5
	end
	return minHeight
end

local function Update(self, elapsed)
	if(self.WaitTime) then
		self.WaitTime = self.WaitTime - elapsed
		if(self.WaitTime > 0) then return end
		self.WaitTime = nil
		if(self.Frozen) then return self:Hide() end
	end

	self.State = nil

	self.TimeRunning = self.TimeRunning + elapsed
	local animPercent = min(self.TimeRunning/animTime, 1)

	local heightPercent = self.Animate == DOWN and 1-animPercent or animPercent

	local minHeight = getMinHeight(self.Frame)
	self.Frame:SetHeight(minHeight + (maxHeight-minHeight) * heightPercent)

	if(animPercent >= 1) then
		self.State = self.Animate
		self.Animate = nil
		self.TimeRunning = nil
		self:Hide()
		if(self.finishedFunc) then self:finishedFunc() end
	end
end

local function getChicchai(self)
	if(self:GetObjectType() == "Frame") then self = self.Frame  end
	if(self.isDocked) then self = DOCKED_CHAT_FRAMES[1] end
	return self.Chicchai
end

local function SetFrozen(self, isFrozen)
	getChicchai(self).Frozen = isFrozen
end

local function Animate(self, dir, waitTime, finishedFunc)
	local self = getChicchai(self)
	if(self.Frozen) then return end
	if(self.Animate == dir or self.State == dir and not self.Animate) then return end

	if(self.Animate == -dir) then
		self.TimeRunning = animTime - self.TimeRunning
	else
		self.TimeRunning = 0
	end
	self.WaitTime = waitTime
	self.Animate = dir
	self.finishedFunc = finishedFunc
	self:Show()
end

local function Maximize(self) Animate(self, UP) end
local function Minimize(self) Animate(self, DOWN) end

local function MinimizeAfterWait(self)
	Animate(self, DOWN, minimizeTime)
end

local CheckEnterLeave
if(MaximizeOnEnter) then
	CheckEnterLeave = function(self)
		self = getChicchai(self)
		if(MouseIsOver(self.Frame) and not self.wasOver) then
			self.wasOver = true
			Animate(self, UP, WaitAfterEnter)
		elseif(self.wasOver and not MouseIsOver(self.Frame)) then
			self.wasOver = nil
			Animate(self, DOWN, WaitAfterLeave)
		end
	end
end

if(MaximizeCombatLog) then
	hooksecurefunc("FCF_Tab_OnClick", function(self)
		local frame = getChicchai(ChatFrame2)
		if(self == ChatFrame2Tab) then
			Animate(frame, UP)
			SetFrozen(frame, true)
		elseif(frame.Frozen) then
			SetFrozen(frame, nil)
			Animate(frame, DOWN)
		end
	end)
end

local function UpdateHeight(self)
	local self = getChicchai(self)
	if(self.State ~= DOWN) then return end
	self.Frame:ScrollToBottom()
	self.Frame:SetHeight(getMinHeight(self.Frame))
end

local function chatEvent(self)
	if(event == "CHAT_MSG_CHANNEL" and channelNumbers and not channelNumbers[arg8]) then return end

	if(not LockInCombat or not UnitAffectingCombat("player")) then
		Animate(self, UP, nil, MinimizeAfterWait)
	end
end

for chatname, options in pairs(ChatFrameConfig) do
	local chatframe = _G[chatname]
	local chicchai = CreateFrame"Frame"
	if(MaximizeOnEnter) then
		local updater = CreateFrame("Frame", nil, chatframe)
		updater:SetScript("OnUpdate", CheckEnterLeave)
		updater.Frame = chatframe
	end
	chicchai.Frame = chatframe
	chatframe.Chicchai = chicchai
	if(type(options) == "table") then
		for _, event in pairs(options) do
			chicchai:RegisterEvent(event)
		end
	end
	ChatFrameConfig[chatname] = chicchai
	
	chatframe.Maximize = Maximize
	chatframe.Minimize = Minimize
	chatframe.UpdateHeight = UpdateHeight
	chatframe.SetFrozen = SetFrozen

	chicchai:SetScript("OnUpdate", Update)
	chicchai:SetScript("OnEvent", chatEvent)
	chicchai:Hide()

	hooksecurefunc(chatframe, "AddMessage", UpdateHeight)
end

_G.Chicchai = ChatFrameConfig