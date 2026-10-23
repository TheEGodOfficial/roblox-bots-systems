--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local lp = game:GetService("Players").LocalPlayer

local APIKey = "\65\81\46\65\98\56\82\78\54\73\99\89\95\102\112\68\90\86\57\70\55\67\66\54\78\90\95\49\50\54\115\101\112\112\69\50\85\106\105\71\104\55\75\72\54\82\75\118\100\115\57\69\103\10" -- do not touch please
local AIModel = "gemini-2.0-flash"
local ChatCommand = "/ai "
local TokenCount = 200
local ChatRadius = 35
local Wandering = true
local WanderDistance = 40
local WanderWait = 3

if lp.Name == "SwordFightingClanker" then
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
    local env = (type(getgenv) == "function" and getgenv()) or shared or _G

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
end

APIKey = nil

-- ui lib
local Starlight = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/refs/heads/master/Source.lua"))()

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

env.SecureMode = true

local ver = "V1.0.2"

local win = Starlight:CreateWindow({
    Name = "Bot Loader",
    Subtitle = ver,
    Icon = 11179491521,

    LoadingEnabled = true,

    LoadingSettings = {
        Title = "Bot Loader "..ver,
        Subtitle = "Made by E God/Fred.",
    },

    FileSettings = {
        ConfigFolder = "BotLoaderStuffIDK",
    },

    InterfaceAdvertisingPrompts = false,
})

local tbs = win:CreateTabSection("Bots")

local sfbtb = tbs:CreateTab({
    Name = "Sword Fight Bot",
    Columns = 1,
}, "SFB")

local sfbgb = sfbtb:CreateGroupbox({
    Name = "Loader",
    Columns = 1,
},"SFB2")

local sfbbtn = sfbgb:CreateButton({
    Name = "Load Script",
    Callback = function()
        --[[
        MIT License

        Copyright (c) 2026 E God/Fred
        ]]
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
    end,
}, "SFB3")

local lkbtb = tbs:CreateTab({
    Name = "Loop Kill Sword Bot",
    Columns = 1,
}, "LKB")

local lkbgb = lkbtb:CreateGroupbox({
    Name = "Loader",
    Columns = 1,
}, "LKB2")

local lkbbtn = lkbgb:CreateButton({
    Name = "Load Script",
    Callback = function()
        --[[
        MIT License

        Copyright (c) 2026 E God/Fred
        ]]
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
    end,
}, "LKB3")

local acbtb = tbs:CreateTab({
    Name = "AI Chat Bot",
    Columns = 2,
}, "ACB")

local acbgb = acbtb:CreateGroupbox({
    Name = "Loader",
    Columns = 1,
}, "ACB2")

local acbbtn = acbgb:CreateButton({
    Name = "Load Script",
    Callback = function()
        if APIKey == nil or APIKey == "" then
            local ntf = win:PromptDialog({
                Name = "No API Key",
                Content = "No API Key provided from aistudio.google.com/app/apikey",
                Type = 2,
            })
        else
            --[[
            MIT License

            Copyright (c) 2026 E God/Fred
            ]]
            local env = (type(getgenv) == "function" and getgenv()) or shared or _G

            env.APIKey = APIKey
            env.AIModel = AIModel
            env.ChatCommand = ChatCommand
            env.TokenCount = TokenCount
            env.ChatRadius = ChatRadius
            env.Wandering = Wandering
            env.WanderDistance = WanderDistance
            env.WanderWait = WanderWait

            loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))()
        end
    end,
}, "ACB3")

local acbgb2 = acbtb:CreateGroupbox({
    Name = "Bot Config",
    Columns = 2,
}, "ACB4")

local acbak = acbgb2:CreateInput({
    Name = "API Key",
    CurrentValue = "",
    PlaceholderText = "Get at aistudio.google.com/app/apikey",
    Enter = true,
    Callback = function(Text)
        APIKey = tostring(Text)
    end,
}, "ACB5")

local acbl = acbgb2:CreateLabel({
    Name = "AI Models",
}, "ACB6")

local acbam = acbl:AddDropdown({
	Options = {
	    "gemini-2.0-flash",
	    "gemini-2.5-flash",
	    "gemini-2.5-flash-lite",
	    "gemini-2.0-flash-lite",
	    "gemini-1.5-flash",
	    "gemini-1.5-flash-8b",
	    "gemini-1.5-pro",
	},
    CurrentOption = "gemini-2.0-flash",
    PlaceholderText = "No AI Model",
    MultipleOptions = false,
    Callback = function(Options)
        AIModel = tostring(Options[1])
    end,
}, "ACB7")

local acbcc = acbgb2:CreateInput({
    Name = "Chat Command",
    CurrentValue = "/ai",
    PlaceholderText = "Chat cmd for far interaction.",
    Enter = true,
    Callback = function(Text)
        ChatCommand = tostring(Text).." "
    end,
}, "ACB8")

local acbtc = acbgb2:CreateInput({
    Name = "Token Count",
    CurrentValue = "200",
    PlaceholderText = "Token count (Recommend: 200)",
    Enter = true,
    Numeric = true,
    Callback = function(Text)
        TokenCount = tonumber(Text)
    end,
}, "ACB9")

local acbcr = acbgb2:CreateInput({
    Name = "Chat Radius",
    CurrentValue = "35",
    PlaceholderText = "Chat radius (Recommend: 35)",
    Enter = true,
    Numeric = true,
    Callback = function(Text)
        ChatRadius = tonumber(Text)
    end,
}, "ACB0")

local acbw = acbgb2:CreateToggle({
    Name = "Wandering",
    CurrentValue = true,
    Style = 2,
    Callback = function(Value)
        Wandering = Value
    end,
}, "ACB10")

local acbwd = acbgb2:CreateInput({
    Name = "Wander Distance",
    CurrentValue = "40",
    PlaceholderText = "Wander Distance (Recommend: 40)",
    Enter = true,
    Numeric = true,
    Callback = function(Text)
        WanderDistance = tonumber(Text)
    end,
}, "ACB11")

local acbww = acbgb2:CreateInput({
    Name = "Wander Wait",
    CurrentValue = "3",
    PlaceholderText = "Wander wait (Recommend: 3)",
    Enter = true,
    Numeric = true,
    Callback = function(Text)
        WanderWait = tonumber(Text)
    end,
}, "ACB12")

local contb = tbs:CreateTab({
    Name = "Configs",
    Columns = 1,
}, "ACB13")

contb:BuildConfigGroupbox(1)

Starlight:LoadAutoloadConfig()
