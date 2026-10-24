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
local rs = game:GetService("RunService")
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
local MPA = 3

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
	if not pm[ky] then pm[ky] = {} end
	return pm[ky]
end

local function apm(plr, fact)
	if not plr or not fact then return end
	local cln = tostring(fact):gsub("^%s+", ""):gsub("%s+$", "")
	if cln == "" then return end
	local lst = gml(plr)
	for _, ex in ipairs(lst) do
		if ex == cln then return end
	end
	table.insert(lst, cln)
	while #lst > 8 do table.remove(lst, 1) end
end

local function emf(msg)
	if not msg then return nil end
	local lo = string.lower(msg)
	local ptns = {
		"remember that ", "remember ", "note that ",
		"my favorite ", "i like ", "i love ", "my name is ",
		"i am ", "i play ", "i enjoy ", "i hate ",
		"i want ", "i live in ", "i have a favorite "
	}
	for _, ptn in ipairs(ptns) do
		local idx = string.find(lo, ptn, 1, true)
		if idx then
			local v = string.sub(msg, idx + #ptn):gsub("^%s+", ""):gsub("%s+$", "")
			if v ~= "" and #v <= 220 then return v end
		end
	end
	return nil
end

local function bpmt(plr)
	local lst = gml(plr)
	if not lst or #lst == 0 then return "No stored memories for this player." end
	local lns = {}
	for _, mem in ipairs(lst) do table.insert(lns, "- " .. mem) end
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
	while #sch > MSH do table.remove(sch, 1) end
end

local function bshp()
	if #sch == 0 then return "Server chat history: none yet." end
	local lns = { "Server chat history:" }
	for _, en in ipairs(sch) do
		table.insert(lns, string.format("%s (%s) [UserId: %d]: %s", en.playerName, en.username, en.userId, en.text))
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
	"Near me means no command needed. Far away means use " .. c,
	"I do not support voice chat. Type your message in chat to talk to me.",
	"I can remember things you tell me. Try saying my name is or I like.",
	"I am powered by Gemini AI. I might make mistakes sometimes.",
	"I can only read text chat. I cannot hear you if you are using voice chat.",
	"Ask me anything about this game and I will try to help.",
	"I remember up to 8 things about you per session.",
	"I respond to anyone close to me or anyone who uses " .. c .. "before their message.",
	"I am a bot, not a real player. Do not report me.",
	"My replies are limited to 200 characters so I keep things short.",
	"I can see the names of everyone in this server.",
	"I cannot send friend requests, trade, or join other games.",
	"I cannot see images or links, only text messages.",
	"Each reply is generated fresh. I do not have a memory of past sessions.",
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

local sp = hrp and hrp.Position or Vector3.new(0, 5, 0)
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
		print("Debug AI: " .. msg)
	else
		local e = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		if e and e:FindFirstChild("SayMessageRequest") then
			e.SayMessageRequest:FireServer(msg, "All")
			print("Debug AI: " .. msg)
		end
	end
end

local function bcc(spk)
	rpn()
	local pls = table.concat(gpl(), ", ")
	if pls == "" then pls = "No other players currently in server" end
	local mem = "No stored memories for this player."
	if spk then
		mem = bpmt(spk)
		local dn = spk.DisplayName or spk.Name or "Unknown"
		local un = spk.Name or "Unknown"
		local uid2 = spk.UserId or 0
		return string.format(
			"Speaker details: display name=%s, username=%s, userId=%d\nPlayer memory:\n%s\nCurrent server players: %s\n\n%s\n\n",
			dn, un, uid2, mem, pls, bshp()
		)
	end
	return "Player memory:\n" .. mem .. "\nCurrent server players: " .. pls .. "\n\n" .. bshp() .. "\n\n"
end

local FBM = {
	"gemini-flash-latest",
	"gemini-flash-lite-latest",
}

local function aq(txt, spk)
	if not k or k == "" then return "Gemini API key missing." end

	local function clm(mdl)
		return tostring(mdl or ""):gsub('[%s"\']', "")
	end

	local mdl = clm(m)
	if mdl == "" then mdl = "gemini-flash-latest" end
	if not mdl:match("^[%w%.%-]+$") then
		return "Invalid model name, check your AIModel setting"
	end

	local pt = bcc(spk) .. txt
	local mt = tonumber(tk) or 200

	local function bb(model)
		local bd = {
			model = model,
			messages = {
				{ role = "system", content = pr },
				{ role = "user", content = pt },
			},
			max_tokens = mt,
			temperature = 0.7,
			top_p = 0.9,
		}
		local re
		if model:find("^gemini%-2%.5%-flash") then
			re = "none"
		elseif model:find("^gemini%-2%.5%-pro") then
			re = "low"
		end
		if re then bd.reasoning_effort = re end
		return bd
	end

	local hdrs = {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. tostring(k),
		["x-goog-api-key"] = tostring(k),
	}

	local function snd(model, bd)
		local js = h:JSONEncode(bd)
		local u = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
		warn("Debug AI: calling " .. model .. " via [" .. u .. "]")

		local attempts = {
			function()
				return rq({ Url = u, url = u, uri = u, Method = "POST", method = "POST", Headers = hdrs, headers = hdrs, Body = js, body = js })
			end,
			function()
				return rq({ Url = u, Method = "POST", Headers = hdrs, Body = js })
			end,
			function()
				local r2 = hs:RequestAsync({ Url = u, Method = "POST", Headers = hdrs, Body = js })
				return { StatusCode = r2.StatusCode, Body = r2.Body }
			end,
			function()
				return { StatusCode = 200, Body = game:HttpPost(u, js, true) }
			end,
		}

		local lastErr = "unknown"
		for i, fn in ipairs(attempts) do
			local ok, res = pcall(fn)
			if ok and res then
				local rb = type(res.Body) == "string" and res.Body
					or (type(res.body) == "string" and res.body)
					or h:JSONEncode(res.Body or res.body or {})
				local dok, d = pcall(function() return h:JSONDecode(rb) end)
				if dok then
					warn("Debug AI: transport " .. i .. " worked")
					return d, nil
				end
			elseif not ok then
				lastErr = tostring(res)
				warn("Debug AI: transport " .. i .. " failed: " .. lastErr)
			end
		end
		return nil, lastErr
	end

	local att = {}
	local function trm(model)
		if att[model] then return nil, nil end
		att[model] = true
		return snd(model, bb(model))
	end

	local d, er = trm(mdl)
	if not d then
		for _, fb in ipairs(FBM) do
			local d2, e2 = trm(fb)
			if d2 then d = d2; break end
			if e2 then er = e2 end
		end
	end

	if not d and er and (er:lower():find("reasoning") or er:lower():find("effort")) then
		local bd = bb(mdl)
		bd.reasoning_effort = nil
		d, er = snd(mdl, bd)
	end

	if not d then
		return "Gemini request failed: " .. tostring(er)
	end

	if d.error then
		return "Gemini error: " .. tostring(d.error.message or d.error.code or "unknown")
	end

	if type(d.choices) ~= "table" or #d.choices == 0 then
		if d.promptFeedback then
			return "Blocked by safety filter: " .. tostring(d.promptFeedback.blockReason or "unknown")
		end
		warn("Debug AI: empty choices - full response: " .. h:JSONEncode(d))
		return "No reply from Gemini."
	end

	local choice = d.choices[1]
	if not choice or type(choice) ~= "table" then
		return "Malformed choice from Gemini."
	end

	local msg2 = choice.message
	if not msg2 or type(msg2) ~= "table" then
		return "No message in Gemini choice."
	end

	local tx = msg2.content

	if type(tx) == "table" then
		local parts = {}
		for _, part in ipairs(tx) do
			if type(part) == "table" and type(part.text) == "string" then
				table.insert(parts, part.text)
			elseif type(part) == "string" then
				table.insert(parts, part)
			end
		end
		tx = table.concat(parts, " ")
	end

	if type(tx) == "string" then
		tx = tx:gsub("%*+", ""):gsub("`+", "")
		tx = tx:gsub("^%s+", ""):gsub("%s+$", "")
		if tx ~= "" then return tx end
	end

	return "Empty reply (finish_reason: " .. tostring(choice.finish_reason or "none") .. ")"
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

local function pwg(origin, range)
	origin = origin or sp
	range = range or wd
	local ws = game:GetService("Workspace")
	local best = nil
	local bestScore = -math.huge

	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local dist = math.random(math.floor(range * 0.3), range)
		local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local candidate = origin + offset

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { lp.Character or ws }

		local hit = ws:Raycast(candidate + Vector3.new(0, 80, 0), Vector3.new(0, -160, 0), rayParams)
		if hit then
			local pos = hit.Position + Vector3.new(0, 3, 0)
			local score = math.random()
			if best == nil or score > bestScore then
				best = pos
				bestScore = score
			end
		end
	end

	return best or (origin + Vector3.new(math.random(-range, range), 0, math.random(-range, range)))
end

local function cwp(fr, gl)
	local pth = pfs:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 75,
		Costs = { Water = 20, Climb = 5 },
	})
	local ok = pcall(function() pth:ComputeAsync(fr, gl) end)
	if ok and pth.Status == Enum.PathStatus.Success then return pth, true end
	return pth, false
end

local autoJumpConn = nil
local unseatConn = nil
local isMoving = false

local function startUnseat()
	if unseatConn then unseatConn:Disconnect() end
	local sitTime = 0
	unseatConn = rs.Heartbeat:Connect(function(dt)
		if not hum or not hum.Parent then
			unseatConn:Disconnect()
			unseatConn = nil
			return
		end
		if hum.Sit then
			sitTime += dt
			hum.Sit = false
			if sitTime >= 0.1 then hum.Jump = true end
			if sitTime >= 0.3 then
				hum.Jump = true
				sitTime = 0
			end
		else
			sitTime = 0
		end
	end)
end

local function stopUnseat()
	if unseatConn then
		unseatConn:Disconnect()
		unseatConn = nil
	end
end

local function startAutoJump()
	if autoJumpConn then autoJumpConn:Disconnect() end
	local jumpCooldown = 0
	local edgeCooldown = 0
	local ws = game:GetService("Workspace")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	autoJumpConn = rs.Heartbeat:Connect(function(dt)
		if not hum or not hum.Parent or not hrp or not hrp.Parent then
			autoJumpConn:Disconnect()
			autoJumpConn = nil
			return
		end

		jumpCooldown = math.max(0, jumpCooldown - dt)
		edgeCooldown = math.max(0, edgeCooldown - dt)
		rayParams.FilterDescendantsInstances = { b }

		local cf = hrp.CFrame
		local forward = cf.LookVector
		local right = cf.RightVector
		local pos = hrp.Position
		local speed = hum.MoveDirection.Magnitude

		-- obstacle wall detection
		if speed > 0.1 and jumpCooldown <= 0 then
			local hit = false
			local yOffsets = { -2.5, -1.5, -0.5, 0.5, 1.2 }
			local xOffsets = { -1.2, -0.6, 0, 0.6, 1.2 }

			for _, xOff in ipairs(xOffsets) do
				if hit then break end
				for _, yOff in ipairs(yOffsets) do
					local origin = pos + right * xOff + Vector3.new(0, yOff, 0)
					if ws:Raycast(origin, forward * 3.5, rayParams) then
						hit = true
						break
					end
				end
			end

			-- step/ledge detection ahead
			if not hit then
				local probeOrigin = pos + forward * 3 + Vector3.new(0, 10, 0)
				local downRes = ws:Raycast(probeOrigin, Vector3.new(0, -15, 0), rayParams)
				local groundOrigin = pos + Vector3.new(0, 10, 0)
				local groundRes = ws:Raycast(groundOrigin, Vector3.new(0, -15, 0), rayParams)
				if downRes and groundRes and (downRes.Position.Y - groundRes.Position.Y > 0.8) then
					hit = true
				end
			end

			if hit then
				hum.Jump = true
				jumpCooldown = 0.45
			end
		end

		-- parkour: gap detection (jump over gaps)
		if speed > 0.1 and jumpCooldown <= 0 then
			local frontProbe = pos + forward * 2.5 + Vector3.new(0, 5, 0)
			local frontGround = ws:Raycast(frontProbe, Vector3.new(0, -10, 0), rayParams)
			local myGround = ws:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), rayParams)

			if myGround and not frontGround then
				-- gap ahead, jump
				hum.Jump = true
				jumpCooldown = 0.6
			end
		end

		-- edge jump: if about to walk off a ledge, jump forward instead of falling
		if speed > 0.1 and edgeCooldown <= 0 then
			local edgeProbe = pos + forward * 1.8 + Vector3.new(0, 2, 0)
			local edgeRes = ws:Raycast(edgeProbe, Vector3.new(0, -8, 0), rayParams)
			local groundCheck = ws:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)

			if groundCheck and not edgeRes then
				hum.Jump = true
				edgeCooldown = 0.8
				jumpCooldown = 0.4
			end
		end

		-- wall run attempt: if stuck against a wall and airborne, jump again
		if jumpCooldown <= 0 then
			local myGround2 = ws:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -5, 0), rayParams)
			if not myGround2 then
				-- airborne, check for wall to push off of
				local wallHit = ws:Raycast(pos, forward * 2.5, rayParams)
					or ws:Raycast(pos, right * 2.5, rayParams)
					or ws:Raycast(pos, -right * 2.5, rayParams)
				if wallHit then
					hum.Jump = true
					jumpCooldown = 0.5
				end
			end
		end
	end)
end

local function stopAutoJump()
	if autoJumpConn then
		autoJumpConn:Disconnect()
		autoJumpConn = nil
	end
	stopUnseat()
end

local function fp(pth, goal)
	local wps = pth:GetWaypoints()
	if not wps or #wps == 0 then return false end
	startAutoJump()
	startUnseat()

	local ws = game:GetService("Workspace")
	local recalcCooldown = 0
	local lastRecalcPos = hrp and hrp.Position or Vector3.new()

	for i, wp in ipairs(wps) do
		if not hum or not hum.Parent or hum.Health <= 0 then stopAutoJump(); return false end
		if not hrp or not hrp.Parent then stopAutoJump(); return false end

		hum:MoveTo(wp.Position)

		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
			task.delay(0.1, function() if hum then hum.Jump = true end end)
			task.delay(0.25, function() if hum then hum.Jump = true end end)
		end

		local timeout = math.max(2.5, (wp.Position - hrp.Position).Magnitude / math.max(hum.WalkSpeed, 1) * 2.8)
		local elapsed = 0
		local stuckT = 0
		local lastPos = hrp.Position
		local reached = false

		while elapsed < timeout do
			if not hum or not hum.Parent or hum.Health <= 0 then stopAutoJump(); return false end
			if not hrp or not hrp.Parent then stopAutoJump(); return false end

			local dt2 = task.wait(0.1)
			elapsed += dt2
			recalcCooldown = math.max(0, recalcCooldown - dt2)

			local cur = hrp.Position

			if (cur - wp.Position).Magnitude < 3.5 then
				reached = true
				break
			end

			local moved = (cur - lastPos).Magnitude
			lastPos = cur

			-- stuck detection
			if hum.MoveDirection.Magnitude > 0.1 and moved < 0.08 then
				stuckT += dt2

				if stuckT > 0.8 then
					-- try jumping out of stuck
					hum.Jump = true
					task.wait(0.15)
					hum:MoveTo(wp.Position)
				end

				if stuckT > 2 and recalcCooldown <= 0 and goal then
					-- recalculate path from current position
					recalcCooldown = 3
					local newPth, ok = cwp(cur, goal)
					if ok then
						stopAutoJump()
						return fp(newPth, goal)
					else
						-- goal unreachable, try a midpoint
						local mid = cur + (goal - cur) * 0.5
						mid = mid + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
						local midPth, midOk = cwp(cur, mid)
						if midOk then
							stopAutoJump()
							return fp(midPth, goal)
						end
					end
					stopAutoJump()
					return false
				end
			else
				stuckT = 0
			end

			-- dynamic obstacle check: if something suddenly blocks path, recalc
			if recalcCooldown <= 0 and goal and (cur - lastRecalcPos).Magnitude > 12 then
				lastRecalcPos = cur
				local rayParams2 = RaycastParams.new()
				rayParams2.FilterType = Enum.RaycastFilterType.Exclude
				rayParams2.FilterDescendantsInstances = { b }
				local dir = (wp.Position - cur)
				if dir.Magnitude > 1 then
					local blocked = ws:Raycast(cur + Vector3.new(0, 1, 0), dir.Unit * math.min(dir.Magnitude, 6), rayParams2)
					if blocked then
						recalcCooldown = 2
						local newPth, ok = cwp(cur, goal)
						if ok then
							stopAutoJump()
							return fp(newPth, goal)
						end
					end
				end
			end
		end

		if not reached and i == #wps then
			stopAutoJump()
			return false
		end
	end

	stopAutoJump()
	return true
end

if wnd and hum and hrp then
	task.spawn(function()
		local failStreak = 0
		local lastGoal = nil

		while true do
			local pause = ww + math.random(0, 3)
			if failStreak > 3 then pause = math.max(0.5, ww - 1) end
			task.wait(pause)

			if not hum or not hum.Parent or not hrp or not hrp.Parent or hum.Health <= 0 then
				continue
			end

			local origin = hrp.Position
			local searchRange = math.min(wd * (1 + failStreak * 0.3), wd * 2.5)
			local gl = pwg(origin, searchRange)
			lastGoal = gl

			local success = false

			for at = 1, MPA + 2 do
				if not hrp or not hrp.Parent then break end

				local pth, ok = cwp(hrp.Position, gl)

				if ok then
					local walked = fp(pth, gl)
					if walked then
						success = true
						break
					end
				end

				-- progressively try closer goals on failure
				if at <= MPA then
					local t2 = at / MPA
					local closer = origin + (gl - origin) * (1 - t2 * 0.4)
					closer = closer + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))

					local hit = game:GetService("Workspace"):Raycast(
						closer + Vector3.new(0, 80, 0),
						Vector3.new(0, -160, 0),
						RaycastParams.new()
					)
					if hit then
						gl = hit.Position + Vector3.new(0, 3, 0)
					else
						gl = pwg(origin, searchRange * (1 - t2 * 0.3))
					end
				end

				task.wait(0.3)
			end

			if success then
				failStreak = 0
			else
				failStreak += 1
				if failStreak >= 5 and hrp and hrp.Parent then
					warn("Debug AI: wander stuck hard, teleporting slightly")
					hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-6, 6), 2, math.random(-6, 6))
					failStreak = 0
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
		if has then q = string.sub(txt, #c + 1):gsub("^%s+", "") end
	elseif has then
		dor = true
		q = string.sub(txt, #c + 1):gsub("^%s+", "")
	end
	if dor and q ~= "" and spk ~= lp and not bs then
		local mf = emf(q)
		if mf then apm(spk, mf) end
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
