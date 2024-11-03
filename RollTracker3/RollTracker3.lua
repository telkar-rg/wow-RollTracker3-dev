--[[
	RollTracker 3.0
	
	
]]--

local rollArray
local rollNames

local lastItemName, lastItemLink, lastTime

-- Functions
local tconcat = table.concat
local tostring = tostring
local tostringall = tostringall
local gsub = gsub
local strmatch = strmatch
local tinsert = tinsert
local sort = sort
local format = format

-- hard-coded configs
local ClearWhenClosed = false

-- Basic localizations
-- |4singular:plural;
local locales = {
	deDE = {
		["All rolls have been cleared."] = "Alle Würfelergebnisse gelöscht.",
		["%d Roll(s)"] = "%d |4Würfelergebnis:Würfelergebnisse;",
		["SLASH_RANDOM8"] = "/würfeln",
	},
	esES = {
		["All rolls have been cleared."] = "Todas las tiradas han sido borradas.",
		["%d Roll(s)"] = "%d Tiradas",
		["SLASH_RANDOM8"] = "/roll",
	},
	frFR = {
		["All rolls have been cleared."] = "Tous les jets ont été effacés.",
		["%d Roll(s)"] = "%d |4Jet:Jets;",
		["SLASH_RANDOM8"] = "/roll",
	},
	ruRU = {
		["All rolls have been cleared."] = "Все броски костей очищены.",
		["%d Roll(s)"] = "%d броска(ов)",
		["SLASH_RANDOM8"] = "/бросок",
	},
	zhCN = {
		["All rolls have been cleared."] = "所有骰子已被清除。",
		["%d Roll(s)"] = "%d个骰子",
		["SLASH_RANDOM8"] = "/roll",
	},
	zhTW = {
		["All rolls have been cleared."] = "所有擲骰紀錄已被清除。",
		["%d Roll(s)"] = "共計 %d 人擲骰",
		["SLASH_RANDOM8"] = "/roll",
	},
}
local L = locales[GetLocale()] or {}
setmetatable(L, {
	-- looks a little messy, may be worth migrating to AceLocale when this list gets bigger
	__index = {
		["%d Roll(s)"] = "%d |4Roll:Rolls;",
		["All rolls have been cleared."] = "All rolls have been cleared.",
		["SLASH_RANDOM8"] = "/roll",
	},
})


-- DO NOT overwrite global strings!
local my_RANDOM_ROLL_RESULT = RANDOM_ROLL_RESULT

-- German language patch
if GetLocale() == 'deDE' then
	-- my_RANDOM_ROLL_RESULT = "%s w\195\188rfelt. Ergebnis: %d (%d-%d)"
	my_RANDOM_ROLL_RESULT = gsub(my_RANDOM_ROLL_RESULT, "%d%$", "")
end

-- Cache regenerated regex pattern
local pattern = gsub(my_RANDOM_ROLL_RESULT, "[%(%)-]", "%%%1")
pattern = gsub(pattern, "%%s", "(.+)")
pattern = gsub(pattern, "%%d", "%(%%d+%)")

local itemLinkPattern = "(\124c(%x+)\124Hitem:(%d+):%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*\124h%[(.+)%]\124h\124r)"
-- returns [itemLink]; linkColor; itemID; itemName


local title_reset = format("|cFF00FF98%s|r", "Roll Tracker 3")

local print_simple = function(...) DEFAULT_CHAT_FRAME:AddMessage( strjoin(" ", tostringall(...))) end
local print_prefix = function(...) DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF98RT3:|r "..strjoin(" ", tostringall(...))) end


-- Init
function RollTracker3_OnLoad(self)
	rollArray = {}
	rollNames = {}
	
	-- GUI
	if not RollTracker3DB then RollTracker3DB = {} end -- fresh DB
	local x, y, w, h = RollTracker3DB.X, RollTracker3DB.Y, RollTracker3DB.Width, RollTracker3DB.Height
	if not x or not y or not w or not h then
		RollTracker3_SaveAnchors()
	else
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		self:SetWidth(w)
		self:SetHeight(h)
	end
	RollTracker3FrameTitle:SetText(title_reset)
	RollTracker3FrameRollButton:SetText(L["SLASH_RANDOM8"])
	
	-- slash command
	SLASH_ROLLTRACKER1 = "/rolltracker";
	SLASH_ROLLTRACKER2 = "/rt";
	SLASH_ROLLTRACKER3 = "/rt3";
	
	SlashCmdList["ROLLTRACKER"] = function (msg)
		if msg == "clear" then
			RollTracker3_ClearRolls()
		else
			RollTracker3_ShowWindow()
		end
	end
end

-- Event handler
function RollTracker3_CHAT_MSG_SYSTEM(msg)
	-- using RANDOM_ROLL_RESULT from GlobalStrings.lua
	local name, roll, low, high = strmatch(msg, pattern)
	if name then
		-- check for rerolls. >1 if rolled before
		rollNames[name] = rollNames[name] and rollNames[name] + 1 or 1
		tinsert(rollArray, {
			Name = name,
			Roll = tonumber(roll),
			Low = tonumber(low),
			High = tonumber(high),
			Count = rollNames[name]
		})
		if not lastTime then lastTime = date("[%X]",time()) end
		
		-- popup window
		RollTracker3_ShowWindow()
	end
end
function RollTracker3_CHAT_MSG_RAID_WARNING(msg)
	-- check for itemLinks in raidwarning
	local itemLink, linkColor, itemID, itemName = strmatch(msg, itemLinkPattern)
	if not itemID then return end
	
	itemID = tonumber(itemID)
	if not itemID then return end
	
	-- now clear table and open new
	RollTracker3_ClearRolls()
	lastTime = date("[%X]",time())
	lastItemName = "|c" .. linkColor .. itemName .. "|r"
	lastItemLink = itemLink
	RollTracker3_ShowWindow()
end

local function printRolls() 
	if not rollArray or #rollArray == 0 then return end
	if not lastTime then return end
	
	local rollText = ""
	
	sort(rollArray, function(a, b) return a.Roll > b.Roll end)	-- inverse sort
	
	local titleText = lastTime
	if lastItemLink then 
		titleText = titleText .. " " .. lastItemLink
	end
	print_prefix(titleText)
	
	-- format and print rolls, check for ties
	local cnt=20
	for i, roll in pairs(rollArray) do
		local tied = (rollArray[i + 1] and roll.Roll == rollArray[i + 1].Roll) or (rollArray[i - 1] and roll.Roll == rollArray[i - 1].Roll)
		rollText = format("|c%s%d|r: |c%s%s%s%s|r",
				tied and "ffffff00" or "ffffffff",
				roll.Roll,
				((roll.Low ~= 1 or roll.High ~= 100) or (roll.Count > 1)) and  "ffffcccc" or "ffffffff",
				roll.Name,
				(roll.Low ~= 1 or roll.High ~= 100) and format(" (%d-%d)", roll.Low, roll.High) or "",
				roll.Count > 1 and format(" [%d]", roll.Count) or "")
		print_simple(" "..rollText)
		
		cnt = cnt - 1
		if cnt <= 0 then break end
	end
end


-- Sort and format the list
local function RollTracker3_Sort(a, b)
	if a.Roll == b.Roll then
		return a.Name < b.Name
	end
	return a.Roll < b.Roll
end

function RollTracker3_UpdateList()
	local rollText = ""
	sort(rollArray, RollTracker3_Sort)
	
	-- format and print rolls, check for ties
	for i, roll in pairs(rollArray) do
		local tied = (rollArray[i + 1] and roll.Roll == rollArray[i + 1].Roll) or (rollArray[i - 1] and roll.Roll == rollArray[i - 1].Roll)
		rollText = format("|c%s%d|r: |c%s%s%s%s|r\n",
				tied and "ffffff00" or "ffffffff",
				roll.Roll,
				((roll.Low ~= 1 or roll.High ~= 100) or (roll.Count > 1)) and  "ffffcccc" or "ffffffff",
				roll.Name,
				(roll.Low ~= 1 or roll.High ~= 100) and format(" (%d-%d)", roll.Low, roll.High) or "",
				roll.Count > 1 and format(" [%d]", roll.Count) or "") .. rollText
	end
	RollTracker3RollText:SetText(rollText)
	RollTracker3FrameStatusText:SetText(format(L["%d Roll(s)"], #rollArray))
	
	if lastItemName then
		RollTracker3FrameTitle:SetText(lastItemName)
	elseif lastTime then
		RollTracker3FrameTitle:SetText(lastTime)
	end
end

function RollTracker3_ClearRolls()
	printRolls()
	
	rollArray = {}
	rollNames = {}
	lastItemName = nil
	lastItemLink = nil
	lastTime = nil
	
	print_prefix(L["All rolls have been cleared."])
	RollTracker3FrameTitle:SetText(title_reset)
	RollTracker3_UpdateList()
end

-- GUI
function RollTracker3_SaveAnchors()
	RollTracker3DB.X = RollTracker3Frame:GetLeft()
	RollTracker3DB.Y = RollTracker3Frame:GetTop()
	RollTracker3DB.Width = RollTracker3Frame:GetWidth()
	RollTracker3DB.Height = RollTracker3Frame:GetHeight()
end

function RollTracker3_ShowWindow()
	RollTracker3_UpdateList()
	RollTracker3Frame:Show()
end

function RollTracker3_HideWindow()
	if ClearWhenClosed then
		RollTracker3_ClearRolls()
	end
end