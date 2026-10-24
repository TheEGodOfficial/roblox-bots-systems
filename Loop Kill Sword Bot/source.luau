--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local ps = game:GetService("Players")
local tcs = game:GetService("TextChatService")
local http = game:GetService("HttpService")
local rsv = game:GetService("RunService")
local lp = ps.LocalPlayer

rsv.RenderStepped:Connect(function()
	if is == false then
		pcall(function()
			if lp.Character then
				local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
				if hrp then hrp.CFrame = CFrame.new(10000, 10000, 10000) if workspace.CurrentCamera then workspace.CurrentCamera.CameraSubject = hrp end end
			end
		end)
	end
end)

local adms = {
	4603013888,
	545411642,
	2479604659,
	1989184574,
	197754,
	12688824,
	4728731970,
	8862410838,
	9930046160,
	7738395778,
	2023199971,
	1652581361,
	9996892482,
	1503830744,
	3169142432,
	3581406752,
	653200119,
	3807957373,
	1905611290,
	8426779972,
	8298772004,
	3118918860,
	10859261172,
	8862476082,
	8862428821,
	8862502214,
	8862470745,
	8862543096,
	2576615014,
	5793728311,
	1010936055,
}

local sk = {
	"sword","blade","katana","saber","sabre","scimitar","cutlass","rapier",
	"claymore","broadsword","longsword","shortsword","greatsword","zweihander",
	"falchion","gladius","dagger","knife","machete","axe","battleaxe","hatchet",
}

local cd, ad, to, msgcd = 3, 0.2, 60, 3
local is, db = false, false
local data, lpd = {}, {}

local function srd()
	local s, r = pcall(function()
		if not readfile then return {} end
		return http:JSONDecode(readfile("BotLoopData/Data.json"))
	end)
	return (s and type(r) == "table") and r or {}
end

local function swd(t)
	pcall(function()
		if writefile then
			writefile("BotLoopData/Data.json", http:JSONEncode(t))
		end
	end)
end

if isfile and isfolder and makefolder and writefile and readfile then
	pcall(function()
		if not isfolder("BotLoopData") then makefolder("BotLoopData") end
		if not isfile("BotLoopData/Data.json") then
			data = {}
			writefile("BotLoopData/Data.json", http:JSONEncode(data))
		else
			data = srd()
		end
	end)
else
	pcall(function()
		tcs:WaitForChild("TextChannels"):WaitForChild("RBXGeneral"):SendAsync("Exe doesnt support file system functions")
	end)
end

local function gp(arg)
	if not arg or arg == "" then return nil end
	arg = tostring(arg):lower()

	local uid = tonumber(arg)
	if uid then
		for _, p in ipairs(ps:GetPlayers()) do
			if p.UserId == uid then return p end
		end
	end

	for _, p in ipairs(ps:GetPlayers()) do
		if p.Name:lower() == arg or p.DisplayName:lower() == arg then
			return p
		end
	end

	local m = {}
	for _, p in ipairs(ps:GetPlayers()) do
		if string.find(p.Name:lower(), arg, 1, true) or string.find(p.DisplayName:lower(), arg, 1, true) then
			table.insert(m, p)
		end
	end
	return m[1]
end

local function fs()
	local ft, sn = {}, {}
	local function sc(c)
		if not c then return end
		for _, i in ipairs(c:GetChildren()) do
			if i:IsA("Tool") and not sn[i] then
				local nl = string.lower(i.Name)
				for _, k in ipairs(sk) do
					if string.find(nl, k, 1, true) then
						sn[i] = true
						table.insert(ft, i)
						break
					end
				end
			end
		end
	end
	sc(lp:FindFirstChild("Backpack"))
	sc(lp.Character)

	table.sort(ft, function(a, b)
		local an, bn = string.lower(a.Name), string.lower(b.Name)
		local as = (string.find(an, "classic") and 3 or 0) + (string.find(an, "sword") and 2 or 0) + (string.find(an, "blade") and 1 or 0)
		local bs = (string.find(bn, "classic") and 3 or 0) + (string.find(bn, "sword") and 2 or 0) + (string.find(bn, "blade") and 1 or 0)
		return as > bs
	end)
	return ft[1]
end

local function wfc(plr, tmo)
	tmo = tmo or 10
	local st = os.clock()
	local ch = plr.Character

	if not ch or not ch.Parent then
		local done, cn = false, nil
		cn = plr.CharacterAdded:Connect(function(c)
			ch = c
			done = true
			cn:Disconnect()
		end)
		while not done and os.clock() - st < tmo do
			task.wait(0.1)
			if plr.Character and plr.Character.Parent then
				ch = plr.Character
				done = true
				if cn then cn:Disconnect() end
			end
		end
		if cn then cn:Disconnect() end
	end

	if not ch or not ch.Parent then return nil end

	local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", tmo)
	local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:WaitForChild("HumanoidRootPart", tmo)

	if hum and hrp and hum.Parent and hrp.Parent then
		return ch, hum, hrp
	end
	return nil
end

local function smite(adm, trg)
	if not trg or not trg.Parent then return end

	local t = fs()
	if not t then
		warn("No sword found.")
		return
	end

	local ac, ah, ar = wfc(adm, 8)
	if not ac then return end

	local tc, th, tr = wfc(trg, 8)
	if not tc then return end
	if th.Health <= 0 then return end

	if not table.find(lpd, trg.Name) then
		table.insert(lpd, trg.Name)
	end
	is = true

	local s
	pcall(function()
		s = adm.Backpack:FindFirstChild(t.Name) or ac:FindFirstChild(t.Name)
	end)
	if not s then
		is = false
		return
	end

	pcall(function() ah:EquipTool(s) end)
	task.wait(0.2)

	local st = os.clock()
	while true do
		if os.clock() - st >= to then break end
		if not trg.Parent then break end
		if not th.Parent or not tr.Parent then
			tc, th, tr = wfc(trg, 5)
			if not tc then break end
		end
		if th.Health <= 0 then break end
		if not ah.Parent or ah.Health <= 0 or s.Parent ~= ac then break end
		if not table.find(lpd, trg.Name) then break end

		pcall(function()
			ar.CFrame = CFrame.lookAt((tr.CFrame * CFrame.new(0, 0, 2.5)).Position, tr.Position)
			s:Activate()
		end)
		task.wait(ad)
	end

	pcall(function()
		if ah and ah.Parent then ah:UnequipTools() end
	end)
	is = false
end

function cmds(msg, plr)
	if not table.find(adms, plr.UserId) then return end
	if db then return end
	db = true

	local ck = msg:match("^/smite%s+(%S+)")
	local cl = msg:match("^/loop%s+(%S+)")
	local cu = msg:match("^/unloop%s+(%S+)")
	local cs = msg:match("^/saveloop%s+(%S+)")
	local csu = msg:match("^/saveunloop%s+(%S+)")
	local ch = msg:match("^/cmds")
	local cp = msg:match("^/permloops")
	local ct = msg:match("^/temploops")
	local ca = msg:match("^/admins")

	if ck then
		local trg = gp(ck)
		if trg and trg ~= plr then
			task.spawn(function() pcall(smite, lp, trg) end)
		end
	end

	if cl then
		local trg = gp(cl)
		if trg and trg ~= plr then
			task.spawn(function()
				while true do
					task.wait(0.1)
					if not table.find(lpd, trg.Name) or not trg.Parent then break end
					pcall(smite, lp, trg)
				end
			end)
		end
	end

	if cu then
		local trg = gp(cu)
		local n = trg and trg.Name or cu
		local i = table.find(lpd, n)
		if i then table.remove(lpd, i) end
	end

	if cs then
		local trg = gp(cs)
		local n = trg and trg.Name or cs
		local ok = trg or pcall(function() return ps:GetUserIdFromNameAsync(n) end)
		if ok then
			data = srd()
			if not table.find(data, n) then
				table.insert(data, n)
				swd(data)
			end
		end
	end

	if csu then
		local trg = gp(csu)
		local n = trg and trg.Name or csu
		data = srd()
		local i = table.find(data, n)
		if i then
			table.remove(data, i)
			swd(data)
		end
	end

	if ch then
		task.spawn(function()
			pcall(function()
				local c = tcs:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
				c:SendAsync("USE THESE COMMANDS FOR GOOD!!! EXAMPLE: SOMEONE IS REACH EXPLOITING.")
				task.wait(msgcd)
				c:SendAsync("NOTE: THESE COMMANDS HAVE A WHITELIST SO DO NOT TRY THEM!")
				task.wait(msgcd)
				c:SendAsync("COMMANDS:")
				task.wait(msgcd)
				c:SendAsync("/smite [name/display/userid] - kills the player")
				task.wait(msgcd)
				c:SendAsync("/loop [name/display/userid] - temporarily loops the player for that server")
				task.wait(msgcd)
				c:SendAsync("/unloop [name/display/userid] - unloops the player")
				task.wait(msgcd)
				c:SendAsync("/saveloop [name/display/userid] - saves player name to json file in executor workspace to loop them")
				task.wait(msgcd)
				c:SendAsync("/saveunloop [name/display/userid] - removes player name from the json file in executor workspace")
				task.wait(msgcd)
				c:SendAsync("/temploops - lets you see what users are in the temporary loop kill list")
				task.wait(msgcd)
				c:SendAsync("/permloops - lets you see the users of permanently loop killed people")
				task.wait(msgcd)
				c:SendAsync("/admins - see the list of people whitelisted")
				task.wait(msgcd)
				c:SendAsync("/cmds - this command you used that shows this list")
			end)
		end)
	end

	if cp then
		task.spawn(function()
			pcall(function()
				local c = tcs:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
				c:SendAsync("PERM LOOPED PLAYERS:")
				local l = srd()
				if #l == 0 then
					c:SendAsync("No one.")
				else
					for _, n in pairs(l) do
						task.wait(msgcd)
						c:SendAsync(tostring(n))
					end
				end
			end)
		end)
	end

	if ct then
		task.spawn(function()
			pcall(function()
				local c = tcs:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
				c:SendAsync("TEMP LOOPED PLAYERS:")
				if #lpd == 0 then
					c:SendAsync("No one.")
				else
					for _, n in pairs(lpd) do
						task.wait(msgcd)
						c:SendAsync(tostring(n))
					end
				end
			end)
		end)
	end

	if ca then
		task.spawn(function()
			pcall(function()
				local c = tcs:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
				c:SendAsync("ADMINS/WHITELISTED PEOPLE:")
				for _, id in pairs(adms) do
					task.wait(msgcd)
					local s, n = pcall(function() return ps:GetNameFromUserIdAsync(id) end)
					c:SendAsync(s and n or "Failed to load.")
				end
			end)
		end)
	end

	task.wait(cd)
	db = false
end

ps.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msg) cmds(msg, plr) end)
end)

task.spawn(function()
	for _, plr in pairs(ps:GetPlayers()) do
		plr.Chatted:Connect(function(msg) cmds(msg, plr) end)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.15)
		task.spawn(function()
			local l = srd()
			for _, n in pairs(l) do
				local trg = ps:FindFirstChild(n)
				if trg then pcall(smite, lp, trg) end
			end
		end)
	end
end)
