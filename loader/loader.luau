--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local lp = game:GetService("Players").LocalPlayer

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

local APIKey = nil
local AIModel = "gemini-flash-latest"
local ChatCommand = "/ai "
local TokenCount = 200
local ChatRadius = 35
local Wandering = true
local WanderDistance = 40
local WanderWait = 3

local GistToken = nil
local GistLink = nil

local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/Nova-UI-Library/refs/heads/main/NovaUILib.lua"))()

local win = Nova.Window{
    Title = "Bot Loader",
    Subtitle = "V1.0.4",
    ToggleKey = Enum.KeyCode.RightShift,
}

local sfbTab = win:AddTab("Sword Fight Bot", "⚔️")

sfbTab:AddSection("Loader")
sfbTab:AddLabel("Loads the Sword Fighter bot script onto your character.")
sfbTab:AddButton{
    Text = "Load Script",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
        Nova.Notify{ Title = "Sword Fight Bot", Text = "Script loaded.", Type = "success", Duration = 3 }
    end,
}

local lkbTab = win:AddTab("Loop Kill Bot", "🔁")

lkbTab:AddSection("Loader")
lkbTab:AddButton{
    Text = "Load Script",
    Callback = function()
        local env = (getgenv and getgenv()) or shared or _G

        env.GistToken = GistToken or nil
        env.GistLink = GistLink or nil

        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
        Nova.Notify{ Title = "Loop Kill Bot", Text = "Script loaded.", Type = "success", Duration = 3 }
    end,
}

lkbTab:AddSection("Webhook Config (Optional)")

lkbTab:AddLabel("Read README.md for more information about how to use this.")

lkbTab:AddTextInput{
    Text = "Gist Token",
    Key = "gistToken",
    Placeholder = "Make a classic token",
    Callback = function(text, enter)
        if enter then GistToken = text ~= "" and text or nil end
    end,
}

lkbTab:AddTextInput{
    Text = "Gist Link",
    Key = "gistLink",
    Placeholder = "Private raw gist link",
    Callback = function(text, enter)
        if enter then GistLink = text ~= "" and text or nil end
    end,
}

local acbTab = win:AddTab("AI Chat Bot", "🤖")

acbTab:AddSection("Loader")
acbTab:AddButton{
    Text = "Load Script",
    Callback = function()
        if APIKey == nil or APIKey == "" then
            Nova.Dialog{
                Title = "No API Key",
                Text = "No API Key provided. Get one at aistudio.google.com/app/apikey then enter it in Bot Config.",
                Buttons = { { Text = "OK", Primary = true } },
            }
            return
        end

        env.APIKey = APIKey
        env.AIModel = AIModel
        env.ChatCommand = ChatCommand
        env.TokenCount = TokenCount
        env.ChatRadius = ChatRadius
        env.Wandering = Wandering
        env.WanderDistance = WanderDistance
        env.WanderWait = WanderWait
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))()
        Nova.Notify{ Title = "AI Chat Bot", Text = "Script loaded.", Type = "success", Duration = 3 }
    end,
}

acbTab:AddSection("Bot Config")

acbTab:AddTextInput{
    Text = "API Key",
    Key = "apiKey",
    Placeholder = "Get at aistudio.google.com/app/apikey",
    Callback = function(text, enter)
        if enter then APIKey = text ~= "" and text or nil end
    end,
}

acbTab:AddDropdown{
    Text = "AI Model",
    Key = "aiModel",
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
    Callback = function(v) AIModel = v end,
}

acbTab:AddTextInput{
    Text = "Chat Command",
    Key = "chatCommand",
    Default = "/ai",
    Placeholder = "Chat cmd for far interaction",
    Callback = function(text, enter)
        if enter then ChatCommand = text .. " " end
    end,
}

acbTab:AddSlider{
    Text = "Token Count",
    Key = "tokenCount",
    Min = 50,
    Max = 1000,
    Default = 200,
    Increment = 10,
    Callback = function(v) TokenCount = v end,
}

acbTab:AddSlider{
    Text = "Chat Radius",
    Key = "chatRadius",
    Min = 5,
    Max = 150,
    Default = 35,
    Increment = 1,
    Suffix = " st",
    Callback = function(v) ChatRadius = v end,
}

acbTab:AddSection("Wandering")

acbTab:AddToggle{
    Text = "Wandering",
    Key = "wandering",
    Default = true,
    Callback = function(v) Wandering = v end,
}

acbTab:AddSlider{
    Text = "Wander Distance",
    Key = "wanderDistance",
    Min = 5,
    Max = 200,
    Default = 40,
    Increment = 5,
    Suffix = " st",
    Callback = function(v) WanderDistance = v end,
}

acbTab:AddSlider{
    Text = "Wander Wait",
    Key = "wanderWait",
    Min = 1,
    Max = 30,
    Default = 3,
    Increment = 1,
    Suffix = "s",
    Callback = function(v) WanderWait = v end,
}

local cfgTab = win:AddTab("Config", "⚙️")
cfgTab:MountConfig()

local thmTab = win:AddTab("Theme",  "🎨")
thmTab:MountTheme()

Nova.AutoLoadConfig()
Nova.AutoLoadTheme()
