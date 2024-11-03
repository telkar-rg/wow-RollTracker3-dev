--[[
	RollTracker 3.0
	
	
]]--

local rollArray
local rollNames

-- hard-coded configs
local ClearWhenClosed = true

-- Basic localizations
local locales = {
	deDE = {
		["All rolls have been cleared."] = "Alle Würfelergebnisse gelöscht.",
		["%d Roll(s)"] = "%d Würfelergebnisse",
	},
	esES = {
		["All rolls have been cleared."] = "Todas las tiradas han sido borradas.",
		["%d Roll(s)"] = "%d Tiradas",
	},
	frFR = {
		["All rolls have been cleared."] = "Tous les jets ont été effacés.",
		["%d Roll(s)"] = "%d Jet(s)",
	},
	ruRU = {
		["All rolls have been cleared."] = "Все броски костей очищены.",
		["%d Roll(s)"] = "%d броска(ов)",
	},
	zhCN = {
		["All rolls have been cleared."] = "所有骰子已被清除。",
		["%d Roll(s)"] = "%d个骰子",
	},
	zhTW = {
		["All rolls have been cleared."] = "所有擲骰紀錄已被清除。",
		["%d Roll(s)"] = "共計 %d 人擲骰",
	},
}
local L = locales[GetLocale()] or {}
setmetatable(L, {
	-- looks a little messy, may be worth migrating to AceLocale when this list gets bigger
	__index = {
		["%d Roll(s)"] = "%d Roll(s)",
		["All rolls have been cleared."] = "All rolls have been cleared.",
	},
})

-- DO NOT overwrite global strings!
local my_RANDOM_ROLL_RESULT = RANDOM_ROLL_RESULT

-- German language patch
if GetLocale() == 'deDE' then
	-- my_RANDOM_ROLL_RESULT = "%s w\195\188rfelt. Ergebnis: %d (%d-%d)"
	my_RANDOM_ROLL_RESULT = string.gsub(my_RANDOM_ROLL_RESULT, "%d%$", "")
end
-- Cache regenerated regex pattern
local pattern = string.gsub(my_RANDOM_ROLL_RESULT, "[%(%)-]", "%%%1")
pattern = string.gsub(pattern, "%%s", "(.+)")
pattern = string.gsub(pattern, "%%d", "%(%%d+%)")

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
	
	-- slash command
	SLASH_ROLLTRACKER1 = "/rolltracker";
	SLASH_ROLLTRACKER2 = "/rt";
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
	-- %s rolls %d (%d-%d) to (.+) rolls (%d+) %((%d+)-(%d+)%)
	-- "%1$s würfelt. Ergebnis: %2$d (%3$d-%4$d)"
	-- "([^%s]+) w\195\188rfelt. Ergebnis: (%d+) %((%d+)%-(%d+)%)$"
	-- "xxx würfelt. Ergebnis: 123 (1-100)"
	for name, roll, low, high in string.gmatch(msg, pattern) do
		-- check for rerolls. >1 if rolled before
		rollNames[name] = rollNames[name] and rollNames[name] + 1 or 1
		table.insert(rollArray, {
			Name = name,
			Roll = tonumber(roll),
			Low = tonumber(low),
			High = tonumber(high),
			Count = rollNames[name]
		})
		-- popup window
		RollTracker3_ShowWindow()
	end
end

-- Sort and format the list
local function RollTracker3_Sort(a, b)
	return a.Roll < b.Roll
end

function RollTracker3_UpdateList()
	local rollText = ""
	table.sort(rollArray, RollTracker3_Sort)
	
	-- format and print rolls, check for ties
	for i, roll in pairs(rollArray) do
		local tied = (rollArray[i + 1] and roll.Roll == rollArray[i + 1].Roll) or (rollArray[i - 1] and roll.Roll == rollArray[i - 1].Roll)
		rollText = string.format("|c%s%d|r: |c%s%s%s%s|r\n",
				tied and "ffffff00" or "ffffffff",
				roll.Roll,
				((roll.Low ~= 1 or roll.High ~= 100) or (roll.Count > 1)) and  "ffffcccc" or "ffffffff",
				roll.Name,
				(roll.Low ~= 1 or roll.High ~= 100) and format(" (%d-%d)", roll.Low, roll.High) or "",
				roll.Count > 1 and format(" [%d]", roll.Count) or "") .. rollText
	end
	RollTracker3RollText:SetText(rollText)
	RollTracker3FrameStatusText:SetText(string.format(L["%d Roll(s)"], table.getn(rollArray)))
end

function RollTracker3_ClearRolls()
	rollArray = {}
	rollNames = {}
	DEFAULT_CHAT_FRAME:AddMessage(L["All rolls have been cleared."])
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
	RollTracker3Frame:Show()
	RollTracker3_UpdateList()
end

function RollTracker3_HideWindow()
	if ClearWhenClosed then
		RollTracker3_ClearRolls()
	end
end