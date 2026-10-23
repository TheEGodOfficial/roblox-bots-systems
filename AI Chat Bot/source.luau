--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local env = (type(getgenv) == "function" and getgenv()) or shared or _G

env.APIKey = env.APIKey or "PASTE_YOUR_GEMINI_KEY_HERE"
env.AIModel = env.AIModel or "gemini-flash-latest"
env.ChatCommand = env.ChatCommand or "/ai "
env.TokenCount = env.TokenCount or 200
env.ChatRadius = env.ChatRadius or 35
env.Wandering = env.Wandering ~= false
env.WanderDistance = env.WanderDistance or 40
env.WanderWait = env.WanderWait or 3

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
local wd = env.WanderDistance
local ww = env.WanderWait
local bs = false
local pid = game.PlaceId
local uid = game.GameId
local gnm = "Unknown"
local gds = "No description"
local cnm = "Unknown"
local cid = 0
local isg = false
local mxp = game.Players.MaxPlayers
local plg = #p:GetPlayers()
local kn = {}
local pm = {}
local sch = {}
local MSH = 250

local function rpn()
	for _, pl in ipairs(p:GetPlayers()) do
		if pl and pl.Name then
			kn[tostring(pl.UserId)] = pl.Name
		end
	end
end

local function gpl()
	local nms = {}
	for _, pl in ipairs(p:GetPlayers()) do
		if pl then
			local dn = pl.DisplayName or pl.Name or "Unknown"
			local nk = pl.Name or "Unknown"
			local id = pl.UserId or 0
			table.insert(nms, string.format("%s (%s) [UserId: %d]", dn, nk, id))
		end
	end
	table.sort(nms)
	return nms
end

local function gml(plr)
	if not plr then return {} end
	local ky = tostring(plr.UserId or 0)
	if not pm[ky] then
		pm[ky] = {}
	end
	return pm[ky]
end

local function apm(plr, fact)
	if not plr or not fact then return end
	local cln = tostring(fact):gsub("^%s+", ""):gsub("%s+$", "")
	if cln == "" then return end
	local lst = gml(plr)
	for _, ex in ipairs(lst) do
		if ex == cln then
			return
		end
	end
	table.insert(lst, cln)
	while #lst > 8 do
		table.remove(lst, 1)
	end
end

local function emf(msg)
	if not msg then return nil end
	local lo = string.lower(msg)
	local ptns = {
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
	for _, ptn in ipairs(ptns) do
		local idx = string.find(lo, ptn, 1, true)
		if idx then
			local v = string.sub(msg, idx + string.len(ptn))
			v = v:gsub("^%s+", ""):gsub("%s+$", "")
			if v ~= "" and #v <= 220 then
				return v
			end
		end
	end
	return nil
end

local function bpmt(plr)
	local lst = gml(plr)
	if not lst or #lst == 0 then
		return "No stored memories for this player."
	end
	local lns = {}
	for _, mem in ipairs(lst) do
		table.insert(lns, "- " .. mem)
	end
	return "Player memory:\n" .. table.concat(lns, "\n")
end

local function ash(plr, tx)
	local cln = tostring(tx):gsub("^%s+", ""):gsub("%s+$", "")
	if cln == "" then return end

	table.insert(sch, {
		playerName = plr and (plr.DisplayName or plr.Name or "Unknown") or "Unknown",
		username = plr and (plr.Name or "Unknown") or "Unknown",
		userId = plr and (plr.UserId or 0) or 0,
		text = cln
	})

	while #sch > MSH do
		table.remove(sch, 1)
	end
end

local function bshp()
	if #sch == 0 then
		return "Server chat history: none yet."
	end

	local lns = { "Server chat history:" }
	for _, en in ipairs(sch) do
		table.insert(lns, string.format(
			"%s (%s) [UserId: %d]: %s",
			en.playerName,
			en.username,
			en.userId,
			en.text
		))
	end
	return table.concat(lns, "\n")
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
Reply with plain text only: no markdown, no asterisks, no bullet points, no lists. One or two short sentences maximum.
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
local tps = {
	"Come close to me and just talk normally!",
	"If you're far away, type " .. c .. "then your message.",
	"I'm an AI bot, walk up and chat with me!",
	"Far away? Use " .. c .. "before your message.",
	"Near me means no command needed. Far away means use " .. c
}
local b = lp.Character
local hum, hrp
if b then
	hum = b:FindFirstChildOfClass("Humanoid")
	hrp = b:FindFirstChild("HumanoidRootPart")
end
lp.CharacterAdded:Connect(function(chr)
	b = chr
	chr:WaitForChild("HumanoidRootPart")
	hum = b:FindFirstChildOfClass("Humanoid")
	hrp = b:FindFirstChild("HumanoidRootPart")
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
	if typeof(game.HttpGet) == "function" or typeof(game.HttpGetAsync) == "function" then
		return function(o)
			local u = o.Url or o.url
			local mth = tostring(o.Method or o.method or "GET"):upper()
			if mth == "POST" and typeof(game.HttpPost) == "function" then
				return { StatusCode = 200, Body = game:HttpPost(u, o.Body or o.body or "", true) }
			else
				local bd = (game.HttpGetAsync and game:HttpGetAsync(u)) or game:HttpGet(u, true)
				return { StatusCode = 200, Body = bd }
			end
		end
	end
	error("No usable request function found - your executor may be blocking HTTP")
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
local function bcc(spk)
	rpn()
	local pls = table.concat(gpl(), ", ")
	if pls == "" then
		pls = "No other players currently in server"
	end
	local mem = "No stored memories for this player."
	if spk then
		mem = bpmt(spk)
		local dn = spk.DisplayName or spk.Name or "Unknown"
		local un = spk.Name or "Unknown"
		local uid2 = spk.UserId or 0
		return string.format(
			"Speaker details: display name=%s, username=%s, userId=%d\nPlayer memory:\n%s\nCurrent server players: %s\n\n%s\n\n",
			dn,
			un,
			uid2,
			mem,
			pls,
			bshp()
		)
	end
	return "Player memory:\n" .. mem .. "\nCurrent server players: " .. pls .. "\n\n" .. bshp() .. "\n\n"
end
local FBM = {
	"gemini-flash-latest",
	"gemini-flash-lite-latest",
}
local function aq(txt, spk)
	if not k or k == "" then
		return "Gemini API key missing."
	end

	local function clm(mdl)
		mdl = tostring(mdl or "")
		mdl = mdl:gsub('[%s"\']', "")
		return mdl
	end

	local mdl = clm(m)
	if mdl == "" then mdl = "gemini-flash-latest" end

	if not mdl:match("^[%w%.%-]+$") then
		return "Invalid model name, check your AIModel setting"
	end

	local pt = bcc(spk) .. txt
	local mt = tonumber(tk) or 200

	local function bb(mdl)
		local bd = {
			systemInstruction = { parts = { { text = pr } } },
			contents = {
				{ role = "user", parts = { { text = pt } } }
			},
			generationConfig = {
				maxOutputTokens = mt,
				temperature = 0.7,
				topP = 0.9,
			},
		}
		local tc
		if mdl:find("^gemini%-2%.5%-flash") then
			tc = { thinkingBudget = 0 }
		elseif mdl:find("^gemini%-2%.5%-pro") then
			tc = { thinkingBudget = 128 }
		elseif mdl:find("^gemini%-3") or mdl:find("^gemini%-4") or mdl:find("%-latest$") then
			tc = { thinkingLevel = "minimal" }
		end
		if tc then
			bd.generationConfig.thinkingConfig = tc
		end
		return bd
	end

	local hdrs = {
		["Content-Type"] = "application/json",
		["x-goog-api-key"] = tostring(k),
	}

	local function snd(mdl, bd)
		local js = h:JSONEncode(bd)
		local u = "https://generativelanguage.googleapis.com/v1beta/models/" .. mdl .. ":generateContent"
		print("Debug AI: calling " .. mdl)
		local opt = {
			Url = u,         url = u,
			Method = "POST", method = "POST",
			Headers = hdrs,  headers = hdrs,
			Body = js,       body = js,
		}
		local ok, res = pcall(function()
			return rq(opt)
		end)
		if not ok or not res then return nil, tostring(res) end
		local rb = type(res.Body) == "string" and res.Body
			or (type(res.body) == "string" and res.body)
			or h:JSONEncode(res.Body or res.body or {})
		local dok, d = pcall(function()
			return h:JSONDecode(rb)
		end)
		if not dok then return nil, "Invalid JSON reply from Gemini" end
		return d, nil
	end

	local att = {}
	local function trm(mdl)
		if att[mdl] then return nil, nil end
		att[mdl] = true
		return snd(mdl, bb(mdl))
	end

	local d, er = trm(mdl)
	if not d then
		for _, fb in ipairs(FBM) do
			local d2, e2 = trm(fb)
			if d2 then
				d = d2
				break
			end
			if e2 then
				er = e2
			end
		end
	end

	if not d and er and er:lower():find("thinking") then
		local bd = bb(mdl)
		bd.generationConfig.thinkingConfig = nil
		d, er = snd(mdl, bd)
	end

	if not d then
		return "Gemini request failed: " .. tostring(er)
	end
	if d.error then
		return "Gemini error: " .. tostring(d.error.message or d.error.code or "unknown")
	end
	if d.promptFeedback and d.promptFeedback.blockReason then
		return "Reply blocked: " .. tostring(d.promptFeedback.blockReason)
	end
	if d.candidates and d.candidates[1] then
		local cd = d.candidates[1]
		local pts = cd.content and cd.content.parts
		local ot = {}
		if type(pts) == "table" then
			for _, prt in ipairs(pts) do
				if type(prt) == "table" and type(prt.text) == "string" and prt.text ~= "" then
					table.insert(ot, prt.text)
				end
			end
		end
		local tx = table.concat(ot, "\n")
		tx = tx:gsub("%*+", ""):gsub("`+", "")
		tx = tx:gsub("^%s+", ""):gsub("%s+$", "")
		if tx ~= "" then
			return tx
		end
		return "Empty reply (finishReason: " .. tostring(cd.finishReason) .. ")"
	end
	return "No valid reply received."
end
local function nr(plr)
	local chr = plr.Character
	if not chr then return false end
	local rt = chr:FindFirstChild("HumanoidRootPart")
	if not rt then return false end
	return (rt.Position - gp()).Magnitude <= r
end
task.spawn(function()
	while true do
		task.wait(10)
		if not bs then
			ch(tps[math.random(1, #tps)])
		end
	end
end)

local MPA = 3

local function pwg()
	local off = Vector3.new(
		math.random(-wd, wd),
		0,
		math.random(-wd, wd)
	)
	return sp + off
end

local function cwp(fr, gl)
	local pth = pfs:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	local ok = pcall(function()
		pth:ComputeAsync(fr, gl)
	end)
	if ok and pth.Status == Enum.PathStatus.Success then
		return pth, true
	end
	return pth, false
end

local function fp(pth)
	local wps = pth:GetWaypoints()
	for _, wp in ipairs(wps) do
		if not hum or not hum.Parent or hum.Health <= 0 then return false end
		if not hrp or not hrp.Parent then return false end

		hum:MoveTo(wp.Position)
		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
		end
		if hum.Sit == true then
			task.spawn(function()
				task.wait(0.75)
				if hum then
					hum.Jump = true
					hum.Sit = false
				end
			end)
		end

		local tm = 0
		local rch = false
		while tm < 2 do
			if not hum or not hum.Parent or hum.Health <= 0 then return false end
			if not hrp or not hrp.Parent then return false end
			local cur = hrp.Position
			local dt = task.wait()
			local now = hrp.Position
			if (now - wp.Position).Magnitude < 4 then
				rch = true
				break
			end
			if (now - cur).Magnitude > math.max(hum.WalkSpeed, 30) * dt + 15 then
				break
			end
			tm += dt
		end

		if not rch then
			if hum then hum.Jump = true end
			return false
		end
	end
	return true
end

if wnd and hum and hrp then
	task.spawn(function()
		while true do
			task.wait(ww + math.random(0, 3))

			if not hum or not hum.Parent or not hrp or not hrp.Parent or hum.Health <= 0 then
				continue
			end

			local gl = pwg()

			for at = 1, MPA do
				local pth, ok = cwp(hrp.Position, gl)

				if ok then
					local wlk = fp(pth)
					if wlk then break end
				end

				if at < MPA then
					if at >= 2 then
						gl = pwg()
					end
					task.wait(0.25)
				end
			end
		end
	end)
end

t.MessageReceived:Connect(function(msg)
	if not msg.TextSource then return end
	local spk = p:GetPlayerByUserId(msg.TextSource.UserId)
	if not spk then return end
	kn[tostring(spk.UserId)] = spk.Name
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
	if dor and q ~= "" and spk ~= lp and not bs then
		local mf = emf(q)
		if mf then
			apm(spk, mf)
		end
		ash(spk, q)
		bs = true
		ch("Thinking...")
		local rpl = aq(q, spk)
		ch(rpl)
		bs = false
	end
end)
print("[Range AI Bot] Loaded!")
print("Model:", m)
print("Game:", gnm)
print("Range:", r, "studs")
