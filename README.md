# Roblox Bot Systems
These are made to be used on a Roblox Account in order to work.

They are made specifically for Exploits for example: Delta, Kawaii, Potassium, Volcano, Synapse Z, Codex, Velocity, Solara, Xeno, etc.

Licensed under the MIT License.

## Loader (Optional)

**Code:**
```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred & nivalos
]]
-- credits to github contributor: nivalox
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

**Code:**
```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
```

# AI Chat Bot

A Roblox chat bot written in Luau. You bring your own API key and pick either OpenRouter or Google Gemini as the provider. The bot reads chat, asks the AI model, and answers in the game chat. It knows which game it is in, stays near where it started, and can wander around.

Setup and model comments were first drafted with AI, then edited by hand.

## Features

- Works with OpenRouter (including free models) and the Google Gemini API
- Provider is picked automatically from the model name, or set manually
- Range based chat: nearby players just type, far away players use a command prefix
- Knows the game it is in (name, description, creator, place ID, max players, current player count) and uses that when answering
- Optional wandering with pathfinding, so it walks around its start point without getting stuck on walls
- Works with most executors by trying several request functions until one works
- Handles API errors, blocked prompts and empty replies with a short message instead of crashing
- Only handles one question at a time, so it will not spam the API

## Requirements

- An executor that supports HTTP requests (Synapse Z, Delta, Codex, Potassium, Volcano, Velocity, etc.)
- An API key from OpenRouter or Google AI Studio

## Setup

### 1. Get an API key

**OpenRouter**

1. Go to https://openrouter.ai and sign in
2. Open **Keys** and create a new key
3. Copy it (starts with `sk-or-v1-`)

**Gemini**

1. Go to https://aistudio.google.com/apikey and sign in with a Google account
2. Create an API key
3. Copy it (usually starts with `AIza`)

### 2. Fill in the loader

Paste your key into `env.APIKey` and pick a model in `env.AIModel`. If you are using Gemini, change the model to a Gemini one and use the Gemini key.

```luau
--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

env.Provider = "openrouter"
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

Gemini example:

```luau
env.Provider = "gemini"
env.APIKey = "AIzaxxxxxxxxxxxxxxxxxxxxxxxx"
env.AIModel = "gemini-2.5-flash"
```

### 3. Run it

1. Join the game first
2. Execute the script in your executor
3. The console prints the provider, model, game name and chat range when it loads

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| `env.Provider` | `"openrouter"` | `"openrouter"` or `"gemini"`. Optional, see below |
| `env.APIKey` | none | Your API key. Never share the script with this filled in |
| `env.AIModel` | `"minimax/minimax-m3.1-flash:free"` | Model to use. Must match the provider |
| `env.ChatCommand` | `"/ai "` | Prefix to use when you are outside the chat range. Keep the space at the end |
| `env.TokenCount` | `200` | Max length of a reply |
| `env.ChatRadius` | `35` | Range in studs where no prefix is needed |
| `env.Wandering` | `true` | Turns wandering on or off |
| `env.WanderDistance` | `40` | How far from its start point the bot can walk, in studs |
| `env.WanderWait` | `3` | Seconds between wander moves. A random 0 to 3 seconds is added on top |

### How the provider is chosen

If `env.Provider` is not set, the script looks at the model name. A name that starts with `gemini` (like `gemini-2.5-flash`) uses the Gemini API. Everything else uses OpenRouter, including names like `google/gemma-4-31b-it:free`.

If you want to be sure, set `env.Provider` yourself.

## Talking to the bot

- Inside the chat range, type normally
- Outside the range, start your message with the command prefix, for example `/ai hello`
- The bot sends `Thinking...` while it waits for the model, and ignores new messages until it has answered
- While idle, it posts a short tip in chat every 10 seconds explaining how to talk to it

The bot answers messages from the player running the script.

## Models

Model lists change often, so check the provider's site if a model stops working.

### OpenRouter free models (as of late October 2026)

Set `env.AIModel` to any of these. Browse https://openrouter.ai/models and filter by free for the current list.

Top picks:

```
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
```

Other free ones:

```
cohere/north-mini-code:free
poolside/laguna-s-2.1:free
poolside/laguna-xs-2.1:free
xingchen-agi/xing4.0-29b-a4b:free
liquid/lfm-2.5-2.6b:free
dots-studio/dots-3-note-preview:free
recursive/flint-v1.0:free
openrouter/free
```

### Gemini

Use the plain model name, with no `google/` in front. Current names are listed at https://ai.google.dev/gemini-api/docs/models.

```
gemini-2.5-flash
gemini-2.5-flash-lite
```

Notes for Gemini:

- The free tier has rate limits, so you may see errors if people chat with the bot very quickly
- Gemini 2.5 models count their internal thinking toward `env.TokenCount`. If replies come back empty or cut off, raise it to 300 or more
- Prompts blocked by Gemini's safety filters get a short "can't answer that" reply

## Troubleshooting

| Problem | Likely cause |
| --- | --- |
| `API Error 401` or `403` | Bad key, or the key does not match the provider |
| `API Error 404` | The model name is wrong for that provider |
| `API Error 429` | Rate limited. Wait a bit or switch models |
| `No usable request function found` | Your executor does not support HTTP requests |
| Empty or cut off replies | Raise `env.TokenCount` |
| Gemini model not responding | Make sure there is no `google/` prefix and the key starts with `AIza` |
| Bot does not reply | Check you are in range or using the command prefix, and check the console for errors |

## Security

Your API key is stored in plain text in the loader. Remove it before sharing or posting the script.

## License

MIT. Copyright (c) 2026 E God/Fred.
