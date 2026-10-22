--[[
MIT License

Copyright (c) 2026 E God/Fred & nivalos
]]


-- Loader Library
local Loader = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/loader/NivalosLoader.lua"))()

-- Buttons
Loader:AddButton("Sword Fighter", function() loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))() end)

Loader:AddButton("Loop Kill Sword Bot", function() loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))() end)

Loader:AddButton("AI Chat Bot", function() loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))() end)
