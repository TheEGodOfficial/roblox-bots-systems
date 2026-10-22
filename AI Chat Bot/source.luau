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
Keep answers under 200 characters long and be friendly.
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
	else
		local e = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		if e and e:FindFirstChild("SayMessageRequest") then
			e.SayMessageRequest:FireServer(msg, "All")
		end
	end
end
local function ask(txt)
	local bdy = {
		model = m,
		messages = {
			{role="system", content=pr},
			{role="user", content=txt}
		},
		max_tokens = tk,
		temperature = 0.7
	}
	local ok, res = pcall(function()
		return rq({
			Url = "https://openrouter.ai/api/v1/chat/completions",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. k,
				["HTTP-Referer"] = "https://roblox.com",
				["X-Title"] = "Roblox Range AI Bot"
			},
			Body = h:JSONEncode(bdy)
		})
	end)
	if not ok then return "Request failed: " .. tostring(res) end
	local code = res.StatusCode or res.status or res.Status or 200
	local bd = res.Body or res.body or res
	if code ~= 200 then
		return "API Error " .. tostring(code) .. ": " .. tostring(bd)
	end
	local data = typeof(bd) == "string" and h:JSONDecode(bd) or bd
	if data.choices and data.choices[1] and data.choices[1].message then
		return data.choices[1].message.content
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

function msging(plr, msg)
	if not plr then return end
	local has = string.sub(msg, 1, #c) == c
	local inr = nr(plr)
	local dor = false
	local q = msg
	if inr then
		dor = true
		if has then
			q = string.sub(msg, #c + 1):gsub("^%s+", "")
		end
	else
		if has then
			dor = true
			q = string.sub(msg, #c + 1):gsub("^%s+", "")
		end
	end
	if dor and q ~= "" and plr ~= lp and not busy then
		busy = true
		ch("Thinking...")
		local rpl = ask(q)
		ch(rpl)
		busy = false
	end
end

p.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msg)
		msging(plr, msg)
	end)
end)
	
end)
print("[Range AI Bot] Loaded!")
print("Model:", m)
print("Game:", gnm)
print("Range:", r, "studs")
