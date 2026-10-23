--!nonstrict
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

local lp = game:GetService("Players").LocalPlayer
local HttpService = game:GetService("HttpService")

local APIKey = nil
local AIModel = "gemini-flash-latest"
local ChatCommand = "/ai "
local TokenCount = 200
local ChatRadius = 35
local Wandering = true
local WanderDistance = 40
local WanderWait = 3

--[[if lp.Name == "SwordFightingClanker" then
	--[[
    MIT License

    Copyright (c) 2026 E God/Fred
    ]]
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
	return
elseif lp.Name == "RoadBlocksV1" then
	--[[
    MIT License

    Copyright (c) 2026 E God/Fred
    ]]
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
	return
elseif lp.Name == "Slop_AI" then
	--[[
    MIT License

    Copyright (c) 2026 E God/Fred
    ]]
																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																						APIKey = "\65\81\46\65\98\56\82\78\54\75\104\55\79\55\53\73\75\104\105\52\122\119\80\66\104\114\69\81\55\57\120\106\112\83\97\71\48\76\53\68\113\121\84\55\111\52\119\49\51\102\77\104\103\10" -- do not touch please
    env.APIKey = APIKey
    env.AIModel = AIModel
    env.ChatCommand = ChatCommand
    env.TokenCount = TokenCount
    env.ChatRadius = ChatRadius
    env.Wandering = Wandering
    env.WanderDistance = WanderDistance
    env.WanderWait = WanderWait

    loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))()
	return
end]]]

APIKey = nil

-- ui lib
local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/Nova-UI-Library/refs/heads/main/NovaUILib.lua"))()

local ver = "V1.0.3"

local hiddenUI
do
	local ok, hui = pcall(function()
		return (type(gethui) == "function" and gethui()) or nil
	end)
	if ok and hui then
		hiddenUI = hui
	else
		local ok2, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		hiddenUI = (ok2 and core) or lp:WaitForChild("PlayerGui")
	end
end

function Nova.ScreenGui(name, displayOrder)
	local gui = Instance.new("ScreenGui")
	gui.Name = name or "NovaUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 10
	gui.Parent = hiddenUI
	return gui
end

local FS = {}

local function hasFn(fn)
	return type(rawget(env, fn)) == "function" or type(env[fn]) == "function"
end

FS.write = env.writefile or writefile
FS.read = env.readfile or readfile
FS.isFile = env.isfile or isfile
FS.isFolder = env.isfolder or isfolder
FS.makeFolder = env.makefolder or makefolder
FS.listFiles = env.listfiles or listfiles
FS.deleteFile = env.delfile or delfile

local CONFIG_FOLDER = "BotLoaderStuffIDK"

local function ensureFolder()
	if not FS.makeFolder then
		return false
	end
	local ok = pcall(function()
		if not (FS.isFolder and FS.isFolder(CONFIG_FOLDER)) then
			FS.makeFolder(CONFIG_FOLDER)
		end
	end)
	return ok
end

local function configPath(name)
	return CONFIG_FOLDER .. "/" .. tostring(name) .. ".json"
end

local function sanitizeName(name)
	name = tostring(name or "")
	name = name:gsub('[%p%s]', "_") -- strip punctuation/whitespace
	if #name == 0 then
		return nil
	end
	return name
end

local function listConfigs()
	if not (FS.listFiles and FS.isFolder and FS.isFolder(CONFIG_FOLDER)) then
		return {}
	end
	local out = {}
	local ok, files = pcall(FS.listFiles, CONFIG_FOLDER)
	if not ok or type(files) ~= "table" then
		return {}
	end
	for _, f in files do
		local base = f:match("([^/\\]+)$") or f
		local name = base:match("^(.-)%.json$")
		if name then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

local win = Nova.Window{
	Title = "Bot Loader",
	Subtitle = ver,
	ToggleKey = Enum.KeyCode.RightShift,
}

Nova.Notify{
	Title = "Bot Loader " .. ver,
	Text = "Made by E God/Fred. Press RightShift to toggle.",
	Type = "info",
	Duration = 5,
}

local sfb = win:AddTab("Sword Fight Bot", "⚔️")
sfb:AddSection("Loader")
sfb:AddButton{
	Text = "Load Script",
	Callback = function()
		--[[
		MIT License

		Copyright (c) 2026 E God/Fred
		]]
		loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
	end,
}

local lkb = win:AddTab("Loop Kill Sword Bot", "🗡️")
lkb:AddSection("Loader")
lkb:AddButton{
	Text = "Load Script",
	Callback = function()
		--[[
		MIT License

		Copyright (c) 2026 E God/Fred
		]]
		loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
	end,
}

local Handles = {}

local acb = win:AddTab("AI Chat Bot", "🤖")

acb:AddSection("Loader")
acb:AddButton{
	Text = "Load Script",
	Callback = function()
		if APIKey == nil or APIKey == "" then
			Nova.Dialog{
				Title = "No API Key",
				Text = "No API Key provided from aistudio.google.com/app/apikey",
				Dismissible = true,
				Buttons = {
					{ Text = "OK", Primary = true },
				},
			}
			return
		end
		--[[
		MIT License

		Copyright (c) 2026 E God/Fred
		]]
		env.APIKey = APIKey
		env.AIModel = AIModel
		env.ChatCommand = ChatCommand
		env.TokenCount = TokenCount
		env.ChatRadius = ChatRadius
		env.Wandering = Wandering
		env.WanderDistance = WanderDistance
		env.WanderWait = WanderWait

		loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))()
	end,
}

acb:AddSection("Bot Config")

Handles.APIKey = acb:AddTextInput{
	Text = "API Key",
	Placeholder = "Get at aistudio.google.com/app/apikey",
	Callback = function(text)
		APIKey = tostring(text)
	end,
}

Handles.AIModel = acb:AddDropdown{
	Text = "AI Model",
	Options = {
		"gemini-flash-latest",
		"gemini-flash-lite-latest",
		"gemini-3.8-flash",
		"gemini-3.6-flash",
		"gemini-3.5-flash-lite",
		"gemini-3.1-flash-lite",
		"gemini-2.5-flash",
		"gemini-2.5-flash-lite",
	},
	Default = "gemini-flash-latest",
	Callback = function(option)
		AIModel = tostring(option)
	end,
}

local function numericInput(key, o, apply)
	local current = o.Default
	Handles[key] = acb:AddTextInput{
		Text = o.Text,
		Default = tostring(o.Default),
		Placeholder = o.Placeholder,
		Callback = function(text)
			local n = tonumber(text)
			if n then
				current = n
				apply(n)
			else
				Nova.Notify{
					Title = "Invalid number",
					Text = o.Text .. " must be a number.",
					Type = "error",
					Duration = 3,
				}
			end
		end,
	}
end

Handles.ChatCommand = acb:AddTextInput{
	Text = "Chat Command",
	Default = "/ai",
	Placeholder = "Chat cmd for far interaction.",
	Callback = function(text)
		ChatCommand = tostring(text) .. " "
	end,
}

numericInput("TokenCount", { Text = "Token Count", Default = 200, Placeholder = "Token count (Recommend: 200)" }, function(n)
	TokenCount = n
end)

numericInput("ChatRadius", { Text = "Chat Radius", Default = 35, Placeholder = "Chat radius (Recommend: 35)" }, function(n)
	ChatRadius = n
end)

Handles.Wandering = acb:AddToggle{
	Text = "Wandering",
	Default = true,
	Callback = function(value)
		Wandering = value
	end,
}

numericInput("WanderDistance", { Text = "Wander Distance", Default = 40, Placeholder = "Wander Distance (Recommend: 40)" }, function(n)
	WanderDistance = n
end)

numericInput("WanderWait", { Text = "Wander Wait", Default = 3, Placeholder = "Wander wait (Recommend: 3)" }, function(n)
	WanderWait = n
end)

local Schema = {
	APIKey = "text",       -- TextInput.Set(string)
	AIModel = "dropdown",  -- Dropdown.Set(value)
	ChatCommand = "text",
	TokenCount = "number", -- TextInput.Set(string) — numbers saved as strings
	ChatRadius = "number",
	Wandering = "toggle",  -- Toggle.Set(boolean)
	WanderDistance = "number",
	WanderWait = "number",
}

local function collectConfig()
	local data = {}
	for key, h in Handles do
		local ok, v = pcall(function()
			return h.Get()
		end)
		if ok then
			data[key] = v
		end
	end
	return data
end

local function applyConfig(data)
	if type(data) ~= "table" then
		return false
	end
	for key, kind in Schema do
		local h = Handles[key]
		local v = data[key]
		if h and v ~= nil then
			pcall(function()
				if kind == "toggle" then
					h:Set(v == true)
				elseif kind == "number" then
					h:Set(tostring(v))
				else
					h:Set(tostring(v))
				end
			end)
		end
	end
	return true
end

local function saveConfig(name)
	if not FS.write then
		Nova.Notify{ Title = "Config error", Text = "Your executor has no writefile support.", Type = "error" }
		return false
	end
	if not ensureFolder() and not (FS.isFolder and FS.isFolder(CONFIG_FOLDER)) then
		Nova.Notify{ Title = "Config error", Text = "Could not create config folder.", Type = "error" }
		return false
	end
	local ok, err = pcall(function()
		FS.write(configPath(name), HttpService:JSONEncode(collectConfig()))
	end)
	if ok then
		Nova.Notify{ Title = "Config saved", Text = name .. ".json", Type = "success", Duration = 3 }
	else
		Nova.Notify{ Title = "Config error", Text = tostring(err), Type = "error", Duration = 5 }
	end
	return ok
end

local function loadConfig(name)
	if not (FS.read and FS.isFile and FS.isFile(configPath(name))) then
		Nova.Notify{ Title = "Config missing", Text = name .. ".json not found.", Type = "warning" }
		return false
	end
	local ok, raw = pcall(FS.read, configPath(name))
	if not ok then
		Nova.Notify{ Title = "Config error", Text = "Could not read " .. name .. ".json", Type = "error" }
		return false
	end
	local ok2, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok2 or type(data) ~= "table" then
		Nova.Notify{ Title = "Config error", Text = name .. ".json is corrupt.", Type = "error" }
		return false
	end
	applyConfig(data)
	Nova.Notify{ Title = "Config loaded", Text = name .. ".json", Type = "success", Duration = 3 }
	return true
end

local function deleteConfig(name)
	if not (FS.deleteFile and FS.isFile and FS.isFile(configPath(name))) then
		Nova.Notify{ Title = "Config missing", Text = name .. ".json not found.", Type = "warning" }
		return
	end
	local ok = pcall(FS.deleteFile, configPath(name))
	Nova.Notify{
		Title = ok and "Config deleted" or "Config error",
		Text = name .. ".json",
		Type = ok and "success" or "error",
		Duration = 3,
	}
end

local contb = win:AddTab("Configs", "💾")
contb:AddSection("Save / Load")

local nameInput
nameInput = contb:AddTextInput{
	Text = "Config name",
	Placeholder = "e.g. mysetup",
	Callback = nil,
}

local function refreshConfigDropdown()
	if FS.listFiles then
		configDropdown:SetOptions(listConfigs())
	end
end

local configDropdown = contb:AddDropdown{
	Text = "Existing configs",
	Options = listConfigs(),
	Default = nil,
	Callback = function(option)
		if nameInput then
			nameInput:Set(tostring(option)) -- prefill the name box with the picked config
		end
	end,
}

local function currentName()
	local n = sanitizeName(nameInput and nameInput:Get())
	if not n then
		Nova.Notify{ Title = "No name", Text = "Enter a config name first.", Type = "warning", Duration = 3 }
	end
	return n
end

contb:AddButton{
	Text = "Save Config",
	Callback = function()
		local n = currentName()
		if n then
			if saveConfig(n) then
				refreshConfigDropdown()
			end
		end
	end,
}

contb:AddButton{
	Text = "Load Config",
	Callback = function()
		local n = currentName()
		if n then
			loadConfig(n)
		end
	end,
}

contb:AddButton{
	Text = "Delete Config",
	Callback = function()
		local n = currentName()
		if n then
			deleteConfig(n)
			refreshConfigDropdown()
		end
	end,
}

contb:AddSection("Default (autoload)")

contb:AddButton{
	Text = "Save as Default",
	Callback = function()
		if saveConfig("default") then
			refreshConfigDropdown()
		end
	end,
}

contb:AddLabel(
	'Save as "default" to auto-load these settings every time the loader starts. '
	.. "Configs are stored in workspace/BotLoaderStuffIDK as JSON."
)

if FS.read and FS.isFile and FS.isFile(configPath("default")) then
	task.defer(function()
		loadConfig("default")
	end)
end
