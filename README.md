# Roblox Bot Systems
These are made to be used on a Roblox Account in order to work.

They are made specifically for Exploits for example: Delta, Potassium, Volcano, Synapse Z, Codex, Velocity, Solara, Xeno, etc.

Licensed under the MIT License.

## Loader (Optional)

**Code:**
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/loader/loader.luau"))()
```

### Sword Fight Bot

Made entirely in LuaU and mostly made by AI due to it having to be a very big project which would take ages of work.

**Code:**
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
```

### Loop Kill Bot

Made in LuaU and very little coding made by AI (The only AI coded stuff is tiny changes and silent errors i couldn't figure out.)

**Code:**
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
```

### AI Chat Bot

An AI Chat bot using OpenRouter and you supply an API key, change settings, etc. Made in LuaU. The Setup and AI models comments are the only AI generated thing, but even I had to change stuff in them.

**Code:**
```luau
--[[
	OpenRouter Range-Based AI Chatbot

	SETUP TUTORIAL:

	1. Get a free OpenRouter API key
	   - Go to https://openrouter.ai
	   - Create an account / log in
	   - Go to Keys and create a new key
	   - Copy the key (starts with sk-or-v1-...)

	2. Paste your key
	   - Find the line: env.APIKey = "sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx"
	   - Replace the whole string with your real key

	3. Choose a free model (optional)
	   - Find the line: env.AIModel = "minimax/minimax-m3.1-flash:free"
	   - Change it to any free model listed below

	4. Optional settings you can change
	   - env.ChatCommand = "/ai "          → command prefix when far away
	   - env.TokenCount = 200            → max reply length
	   - env.ChatRadius = 35              → talk range in studs
	   - env.Wandering = true          → enable/disable wandering
	   - env.WanderDistance = 40        → how far the bot wanders
	   - env.WanderWait = 3         → seconds between wander moves

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

	FREE MODELS ON OPENROUTER (as of late October 2026)
	Just change the m variable to any of these:

	-- Top / Recommended
	minimax/minimax-m3.1-flash:free
	nvidia/nemotron-3.5-super-vl:free
	nvidia/nemotron-3-ultra-550b-a55b:free
	thinkingmachines/inkling:free
	thinkingmachines/inkling-small:free
	google/gemma-4-31b-it:free
	google/gemma-4-26b-a4b-it:free
	nvidia/nemotron-3-super-120b-a12b:free
	nvidia/nemotron-3.5-lightning:free
	nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free

	-- Other free ones
	cohere/north-mini-code:free
	poolside/laguna-s-2.1:free
	poolside/laguna-xs-2.1:free
	xingchen-agi/xing4.0-29b-a4b:free
	liquid/lfm-2.5-2.6b:free
	dots-studio/dots-3-note-preview:free
	recursive/flint-v1.0:free
	openrouter/free
]]

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

env.APIKey = "sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx"
env.AIModel = "minimax/minimax-m3.1-flash:free"
env.ChatCommand = "/ai "
env.TokenCount = 200
env.ChatRadius = 35
env.Wandering = true
env.WanderDistance = 40
env.WanderWait = 3

loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/AI%20Chat%20Bot/source.luau"))()
```
