--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

local p = game:GetService("Players")
local t = game:GetService("TextChatService")
local h = game:GetService("HttpService")
local pfs = game:GetService("PathfindingService")
local mps = game:GetService("MarketplaceService")
local lp = p.LocalPlayer
local k = env.APIKey
local m = env.AIModel
local c = env.ChatCommand
local tk = env.TokenCount
local r = env.ChatRadius
local wnd = env.Wandering
local wnddist = env.WanderDistance
local wndwait = env.WanderWait
local busy = false
local pid = game.PlaceId
local uid = game.GameId
local gnm = "Unknown"
local gds = "No description"
local cnm = "Unknown"
local cid = 0
local isg = false
local mxp = game.Players.MaxPlayers
local plg = #p:GetPlayers()
local knownPlayerNames = {}
local playerMemories = {}

local function refreshPlayerNames()
	for _, pl in ipairs(p:GetPlayers()) do
		if pl and pl.Name then
			knownPlayerNames[tostring(pl.UserId)] = pl.Name
		end
	end
end

local function getCurrentPlayerSummaryList()
	local names = {}
	for _, pl in ipairs(p:GetPlayers()) do
		if pl then
			local disp = pl.DisplayName or pl.Name or "Unknown"
			local nick = pl.Name or "Unknown"
			local id = pl.UserId or 0
			table.insert(names, string.format("%s (%s) [UserId: %d]", disp, nick, id))
		end
	end
	table.sort(names)
	return names
end

local function getMemoryListForPlayer(player)
	if not player then return {} end
	local key = tostring(player.UserId or 0)
	if not playerMemories[key] then
		playerMemories[key] = {}
	end
	return playerMemories[key]
end

local function addPlayerMemory(player, fact)
	if not player or not fact then return end
	local cleaned = tostring(fact):gsub("^%s+", ""):gsub("%s+$", "")
	if cleaned == "" then return end
	local list = getMemoryListForPlayer(player)
	for _, existing in ipairs(list) do
		if existing == cleaned then
			return
		end
	end
	table.insert(list, cleaned)
	while #list > 8 do
		table.remove(list, 1)
	end
end

local function extractMemoryFact(msg)
	if not msg then return nil end
	local lower = string.lower(msg)
	local patterns = {
		"remember that ",
		"remember ",
		"note that ",
		"my favorite ",
		"i like ",
		"i love ",
		"my name is ",
		"i am ",
		"i play ",
		"i enjoy ",
		"i hate ",
		"i want ",
		"i live in ",
		"i have a favorite "
	}
	for _, pat in ipairs(patterns) do
		local idx = string.find(lower, pat, 1, true)
		if idx then
			local value = string.sub(msg, idx + string.len(pat))
			value = value:gsub("^%s+", ""):gsub("%s+$", "")
			if value ~= "" and #value <= 220 then
				return value
			end
		end
	end
	return nil
end

local function buildPlayerMemoryText(player)
	local list = getMemoryListForPlayer(player)
	if not list or #list == 0 then
		return "No stored memories for this player."
	end
	local lines = {}
	for _, memory in ipairs(list) do
		table.insert(lines, "- " .. memory)
	end
	return "Player memory:\n" .. table.concat(lines, "\n")
end

pcall(function()
	local i = mps:GetProductInfo(pid)
	if i then
		gnm = i.Name or gnm
		gds = i.Description or gds
		cnm = i.Creator and i.Creator.Name or cnm
		cid = i.Creator and i.Creator.CreatorTargetId or cid
		isg = i.Creator and i.Creator.CreatorType == Enum.CreatorType.Group
	end
end)
local pr = string.format([[
You are a helpful and fun Roblox chatbot inside a game.
You have a message limit of 200 characters so use them correctly and be friendly.
Never use emojis or special symbols in your replies. Only use normal letters, numbers, and basic punctuation like periods, commas, and question marks.
Game Information:
- Name: %s
- Description: %s
- Place ID: %d
- Universe ID: %d
- Creator: %s (%s) [ID: %d]
- Max Players: %d
- Players Currently in Server: %d
Use this information when players ask about the game.
]], gnm, gds, pid, uid, cnm, isg and "Group" or "User", cid, mxp, plg)
local tips = {
	"Come close to me and just talk normally!",
	"If you're far away, type " .. c .. "then your message.",
	"I'm an AI bot, walk up and chat with me!",
	"Far away? Use " .. c .. "before your message.",
	"Near me means no command needed. Far away means use " .. c
}
local b = lp.Character
local hum, hrp
if b then
	local mdl = b
	hum = mdl and mdl:FindFirstChildOfClass("Humanoid")
	hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
end
lp.CharacterAdded:Connect(function(c)
	b = c
	b:WaitForChild("HumanoidRootPart")
	if b then
		local mdl = b
		hum = mdl and mdl:FindFirstChildOfClass("Humanoid")
		hrp = mdl and mdl:FindFirstChild("HumanoidRootPart")
	end
end)
local sp = hrp and hrp.Position or Vector3.new(0,5,0)
local function gp()
	if hrp then return hrp.Position end
	return sp
end
local function gr()
	if typeof(request) == "function" then return request end
	if syn and typeof(syn.request) == "function" then return syn.request end
	if http and typeof(http.request) == "function" then return http.request end
	if typeof(http_request) == "function" then return http_request end
	if fluxus and typeof(fluxus.request) == "function" then return fluxus.request end
	local ok, api = pcall(function()
		return game:GetService("HttpRbxApiService")
	end)
	if ok and api then
		if typeof(api.RequestAsync) == "function" then
			return function(o) return api:RequestAsync(o) end
		end
		if typeof(api.PostAsyncFullUrl) == "function" then
			return function(o)
				local mth = (o.Method or "GET"):upper()
				if mth == "POST" then
					return {StatusCode=200, Body=api:PostAsyncFullUrl(o.Url, o.Body or "", Enum.ThrottlingPriority.Default, Enum.HttpContentType.ApplicationJson)}
				else
					return {StatusCode=200, Body=api:GetAsyncFullUrl(o.Url)}
				end
			end
		end
	end
	if typeof(game.HttpGet) == "function" or typeof(game.HttpGetAsync) == "function" then
		return function(o)
			local u = o.Url
			local mth = (o.Method or "GET"):upper()
			if mth == "POST" and typeof(game.HttpPost) == "function" then
				return {StatusCode=200, Body=game:HttpPost(u, o.Body or "", true)}
			else
				local bd = (game.HttpGetAsync and game:HttpGetAsync(u)) or game:HttpGet(u, true)
				return {StatusCode=200, Body=bd}
			end
		end
	end
	error("No usable request function found")
end
local rq = gr()
local function ch(msg)
	local chn = t.TextChannels:FindFirstChild("RBXGeneral")
	if chn then
		chn:SendAsync(msg)
		print("Debug AI: "..msg)
	else
		local e = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		if e and e:FindFirstChild("SayMessageRequest") then
			e.SayMessageRequest:FireServer(msg, "All")
			print("Debug AI: "..msg)
		end
	end
end
local function buildChatContext(speaker)
	refreshPlayerNames()
	local playerString = table.concat(getCurrentPlayerSummaryList(), ", ")
	if playerString == "" then
		playerString = "No other players currently in server"
	end
	local memoryText = "No stored memories for this player."
	if speaker then
		memoryText = buildPlayerMemoryText(speaker)
		local dname = speaker.DisplayName or speaker.Name or "Unknown"
		local uname = speaker.Name or "Unknown"
		local uidVal = speaker.UserId or 0
		return string.format(
			"Speaker details: display name=%s, username=%s, userId=%d\nPlayer memory:\n%s\nCurrent server players: %s\n\n",
			dname,
			uname,
			uidVal,
			memoryText,
			playerString
		)
	end
	return "Player memory:\n" .. memoryText .. "\nCurrent server players: " .. playerString .. "\n\n"
end
local function ask(txt, speaker)
	local key = env.GeminiKey or env.APIKey
	local model = env.AIModel or "gemini-2.0-flash"
	if not key or key == "" then
		return "Gemini API key missing."
	end

	local promptText = buildChatContext(speaker) .. txt

	local body = {
		systemInstruction = {
			parts = {
				{ text = pr }
			}
		},
		contents = {
			{
				role = "user",
				parts = {
					{ text = promptText }
				}
			}
		},
		generationConfig = {
			maxOutputTokens = tonumber(tk) or 200,
			temperature = 0.7,
			topP = 0.9
		}
	}

	local ok, res = pcall(function()
		return rq({
			Url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. key,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = h:JSONEncode(body)
		})
	end)

	if not ok or not res then
		return "Request failed: " .. tostring(res)
	end

	local responseText = type(res.Body) == "string" and res.Body or h:JSONEncode(res.Body or {})
	local decodeOkay, data = pcall(function()
		return h:JSONDecode(responseText)
	end)

	if not decodeOkay then
		return "Invalid JSON reply from Gemini."
	end

	if data and data.error then
		return "Gemini error: " .. tostring(data.error.message or data.error.code or "unknown")
	end

	if data and data.candidates and data.candidates[1] then
		local candidate = data.candidates[1]
		local parts = candidate and candidate.content and candidate.content.parts
		if type(parts) == "table" then
			local out = {}
			for _, part in ipairs(parts) do
				if type(part) == "table" and type(part.text) == "string" and part.text ~= "" then
					table.insert(out, part.text)
				end
			end
			local text = table.concat(out, "\n")
			if text ~= "" then
				return text:gsub("^%s+", ""):gsub("%s+$", "")
			end
		end
		if type(candidate.text) == "string" and candidate.text ~= "" then
			return candidate.text:gsub("^%s+", ""):gsub("%s+$", "")
		end
	end

	return "No valid reply received."
end
local function nr(plr)
	local char = plr.Character
	if not char then return false end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return (root.Position - gp()).Magnitude <= r
end
task.spawn(function()
	while true do
		task.wait(10)
		if not busy then
			ch(tips[math.random(1, #tips)])
		end
	end
end)
if wnd and hum and hrp then
	task.spawn(function()
		while true do
			task.wait(wndwait + math.random(0, 3))
			local off = Vector3.new(
				math.random(-wnddist, wnddist),
				0,
				math.random(-wnddist, wnddist)
			)
			local goal = sp + off
			local path = pfs:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true
			})
			local ok = pcall(function()
				path:ComputeAsync(hrp.Position, goal)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				local wps = path:GetWaypoints()
				for _, wp in ipairs(wps) do
					if not hum or hum.Health <= 0 then break end
					hum:MoveTo(wp.Position)
					if wp.Action == Enum.PathWaypointAction.Jump then
						hum.Jump = true
					end
					local tm = 0
					while tm < 2 do
						if (hrp.Position - wp.Position).Magnitude < 4 then break end
						tm += task.wait()
					end
				end
			end
		end
	end)
end

t.MessageReceived:Connect(function(msg)
	if not msg.TextSource then return end
	local spk = p:GetPlayerByUserId(msg.TextSource.UserId)
	if not spk then return end
	knownPlayerNames[tostring(spk.UserId)] = spk.Name
	local txt = msg.Text
	local has = string.sub(txt, 1, #c) == c
	local inr = nr(spk)
	local dor = false
	local q = txt
	if inr then
		dor = true
		if has then
			q = string.sub(txt, #c + 1):gsub("^%s+", "")
		end
	else
		if has then
			dor = true
			q = string.sub(txt, #c + 1):gsub("^%s+", "")
		end
	end
	if dor and q ~= "" and spk ~= lp and not busy then
		local memoryFact = extractMemoryFact(q)
		if memoryFact then
			addPlayerMemory(spk, memoryFact)
		end
		busy = true
		ch("Thinking...")
		local rpl = ask(q, spk)
		ch(rpl)
		busy = false
	end
end)
print("[Range AI Bot] Loaded!")
print("Model:", m)
print("Game:", gnm)
print("Range:", r, "studs")
