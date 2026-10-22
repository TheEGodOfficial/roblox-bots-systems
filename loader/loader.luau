--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

-- ui lib
local Starlight = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/refs/heads/master/Source.lua"))()

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

env.SecureMode = true

local ver = "V1.0.0"

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

local APIKey = nil
local AIModel = "minimax/minimax-m3.1-flash:free"
local ChatCommand = "/ai "
local TokenCount = 200
local ChatRadius = 35
local Wandering = true
local WanderDistance = 40
local WanderWait = 3

local acbbtn = acbgb:CreateButton({
    Name = "Load Script",
    Callback = function()
        if APIKey == nil or APIKey == "" then
            local ntf = win:PromptDialog({
                Name = "No API Key",
                Content = "No API Key provided from openrouter.ai",
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
    PlaceholderText = "Get at openrouter.ai",
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
        "minimax/minimax-m3.1-flash:free",
	      "nvidia/nemotron-3.5-super-vl:free",
	      "nvidia/nemotron-3-ultra-550b-a55b:free",
	      "thinkingmachines/inkling:free",
	      "thinkingmachines/inkling-small:free",
	      "google/gemma-4-31b-it:free",
	      "google/gemma-4-26b-a4b-it:free",
	      "nvidia/nemotron-3-super-120b-a12b:free",
	      "nvidia/nemotron-3.5-lightning:free",
	      "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
        "cohere/north-mini-code:free",
	      "poolside/laguna-s-2.1:free",
	      "poolside/laguna-xs-2.1:free",
	      "xingchen-agi/xing4.0-29b-a4b:free",
	      "liquid/lfm-2.5-2.6b:free",
	      "dots-studio/dots-3-note-preview:free",
	      "recursive/flint-v1.0:free",
	      "openrouter/free",
    },
    CurrentOption = "minimax/minimax-m3.1-flash:free",
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
