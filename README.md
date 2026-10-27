# Roblox Bot Systems
These are made to be used on a Roblox Account in order to work.

They are made specifically for Exploits for example: Delta, Kawaii, Potassium, Volcano, Synapse Z, Codex, Velocity, Solara, Xeno, etc.

Licensed under the MIT License.

## Loader (Optional)

**Code:**
```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/loader/loader.luau"))()
```

### Sword Fight Bot

Made entirely in LuaU and mostly made by AI due to it having to be a very big project which would take ages of work.

**Code:**
```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
```

### Loop Kill Bot

Made in LuaU and very little coding made by AI (The only AI coded stuff is tiny changes and silent errors i couldn't figure out.)

NEW:

There is now two new lua files:

encryptor.lua -> use to encrypt your webhooks. (use in a lua runner and it uses pretty much a custom encryption I would say)

config.lua -> Put this on a public pastebin with a password and put the link in the env var (No api required). Make sure you encrypt the webhooks with encryptor.lua and put them in the correct places.

it can work without these but it is recommended

**Code:**
```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
local env = (getgenv and getgenv()) or shared or _G

env.PasswordPasteLink = "PASSWORD_PROTECTED_PASTEBIN_LINK_HERE"

loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
```

### AI Chat Bot

An AI Chat bot using Google Gemini and you supply an API key, change settings, etc. Made in LuaU. The Setup and AI models comments are the only AI generated thing, but even I had to change stuff in them. (Some stuff in the code is now AI generated due to github co-pilot making it work with gemini only)

**Code:**
```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

--[[ !!!OUTDATED INFORMATION USE LOADER FOR UPDATED MODELS!!!
	Google Gemini Range-Based AI Chatbot

	SETUP TUTORIAL:

	1. Get a Gemini API key
	   - Go to https://aistudio.google.com/app/apikey
	   - Sign in with your Google account
	   - Create a new API key
	   - Copy the key

	2. Paste your key
	   - Find the line: env.APIKey = "PASTE_YOUR_GEMINI_KEY_HERE"
	   - Replace the whole string with your real key

	3. Choose a free model (optional)
	   - Find the line: env.AIModel = "gemini-2.0-flash"
	   - Change it to any free model listed below

	4. Optional settings you can change
	   - env.ChatCommand = "/ai "          → command prefix when far away
	   - env.TokenCount = 200              → max reply length
	   - env.ChatRadius = 35               → talk range in studs
	   - env.Wandering = true             → enable/disable wandering
	   - env.WanderDistance = 40          → how far the bot wanders
	   - env.WanderWait = 3               → seconds between wander moves

	5. How to run the script
	   - This script is made for exploit executors (Synapse Z, Delta, Codex, Potassium, Volcano, Velocity, etc.)
	   - Make sure you are in-game.
	   - Execute it with whatever executor you are using.
	   - The bot will start chatting and (if enabled) wandering.

	6. How to talk to the bot
	   - Walk within range (default 35 studs) and just type normally
	   - If you are far away, type the command prefix first: /ai hello
	   - Everyone can chat with it, so have fun!

	AI MODELS:

	FREE MODELS ON GOOGLE GEMINI (as of late October 2026)
	Just change the env.AIModel variable to any of these:

	"gemini-2.0-flash",
	"gemini-2.5-flash",
	"gemini-2.5-flash-lite",
	"gemini-2.0-flash-lite",
	"gemini-1.5-flash",
	"gemini-1.5-flash-8b",
	"gemini-1.5-pro",

	NOTE:
	- gemini-2.0-flash is the safest default choice for most Roblox bots
	- free-tier model availability can vary by account and region
]]

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

env.APIKey = "PASTE_YOUR_GEMINI_KEY_HERE"
env.AIModel = "gemini-3.1-flash-lite"
env.ChatCommand = "/ai "
env.TokenCount = 200
env.ChatRadius = 35
env.Wandering = true
env.WanderDistance = 40
env.WanderWait = 3

loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))()
```
