--[[
MIT License

Copyright (c) 2026 E God/Fred
]]

local ps = game:GetService("Players")
local tcs = game:GetService("TextChatService")
local hs = game:GetService("HttpService")
local rs = game:GetService("RunService")

local lp = ps.LocalPlayer

local pc = CFrame.new(10000, 10000, 10000)
local of = CFrame.new(0, 0, 2.5)
local cc = 3
local swd = 0.2
local sl = 60
local ct = 8
local md = 3
local dd = "BotLoopData"
local df = "BotLoopData/Data.json"

local ad = {
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
	"sword",
	"blade",
	"katana",
	"saber",
	"sabre",
	"scimitar",
	"cutlass",
	"rapier",
	"claymore",
	"broadsword",
	"longsword",
	"shortsword",
	"greatsword",
	"zweihander",
	"falchion",
	"gladius",
	"dagger",
	"knife",
	"machete",
	"axe",
	"battleaxe",
	"hatchet",
}

local tl = {}
local pl = {}
local bz = {}
local cl = false

local function sd(m)
	local tc = tcs:FindFirstChild("TextChannels")
	local rc = tc and tc:FindFirstChild("RBXGeneral")
	if rc then
		pcall(function()
			rc:SendAsync(m)
		end)
	end
end

local io = isfile and isfolder and makefolder and writefile and readfile

local function rp()
	local ok, r = pcall(function()
		return hs:JSONDecode(readfile(df))
	end)
	if ok and type(r) == "table" then
		local o = {}
		for _, v in ipairs(r) do
			if type(v) == "string" then
				o[#o + 1] = v
			end
		end
		return o
	end
	return {}
end

local function wp()
	if not io then return end
	pcall(writefile, df, hs:JSONEncode(pl))
end

if io then
	if not isfolder(dd) then makefolder(dd) end
	if isfile(df) then
		pl = rp()
	else
		pcall(writefile, df, "[]")
	end
else
	sd("Exe doesnt support file system functions")
end

local function fp(a)
	if not a or a == "" then return nil end
	a = tostring(a):lower()
	local u = tonumber(a)
	if u then
		for _, p in ipairs(ps:GetPlayers()) do
			if p.UserId == u then return p end
		end
	end
	local pt
	for _, p in ipairs(ps:GetPlayers()) do
		local n = p.Name:lower()
		local d = p.DisplayName:lower()
		if n == a or d == a then return p end
		if not pt and (string.find(n, a, 1, true) or string.find(d, a, 1, true)) then
			pt = p
		end
	end
	return pt
end

local function fs()
	local f = {}
	local s = {}
	local function sc(c)
		if not c then return end
		for _, i in ipairs(c:GetChildren()) do
			if i:IsA("Tool") and not s[i] then
				local n = i.Name:lower()
				for _, k in ipairs(sk) do
					if string.find(n, k, 1, true) then
						s[i] = true
						f[#f + 1] = i
						break
					end
				end
			end
		end
	end
	sc(lp:FindFirstChild("Backpack"))
	sc(lp.Character)
	table.sort(f, function(x, y)
		local xn = x.Name:lower()
		local yn = y.Name:lower()
		local xs = (string.find(xn, "classic") and 3 or 0) + (string.find(xn, "sword") and 2 or 0) + (string.find(xn, "blade") and 1 or 0)
		local ys = (string.find(yn, "classic") and 3 or 0) + (string.find(yn, "sword") and 2 or 0) + (string.find(yn, "blade") and 1 or 0)
		return xs > ys
	end)
	return f[1]
end

local function wfc(p, t)
	t = t or ct
	local d = os.clock() + t
	repeat
		local c = p.Character
		if c and c.Parent then
			local h = c:FindFirstChildOfClass("Humanoid")
			local r = c:FindFirstChild("HumanoidRootPart")
			if h and r and h.Parent and r.Parent then
				return c, h, r
			end
		end
		task.wait(0.05)
	until os.clock() >= d
	return nil
end

local cm = workspace.CurrentCamera

local function lk()
	for n in pairs(bz) do
		local p = ps:FindFirstChild(n)
		if p and p.Parent then
			local c = p.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r and r.Parent then
				return r
			end
		end
	end
	return nil
end

rs.RenderStepped:Connect(function()
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local k = lk()
	if k then
		r.CFrame = CFrame.lookAt((k.CFrame * of).Position, k.Position)
	else
		r.CFrame = pc
	end
	if cm and cm.CameraSubject ~= r then
		cm.CameraSubject = r
	end
end)

local function rsm(a, t)
	local tw = fs()
	if not tw then
		warn("[BotLoop] no sword found")
		return
	end
	local ac, ah = wfc(a, ct)
	if not ac then return end
	local tc, th, tr = wfc(t, ct)
	if not tc or th.Health <= 0 then return end
	if not table.find(tl, t.Name) then
		table.insert(tl, t.Name)
	end
	local s = a.Backpack:FindFirstChild(tw.Name) or ac:FindFirstChild(tw.Name)
	if not s then return end
	ah:EquipTool(s)
	task.wait(swd)
	local d = os.clock() + sl
	while os.clock() < d do
		if not t.Parent then break end
		if not (th.Parent and tr.Parent) then
			tc, th, tr = wfc(t, 5)
			if not tc then break end
		end
		if th.Health <= 0 then break end
		if not (ah.Parent and ah.Health > 0) then break end
		if s.Parent ~= ac then break end
		if not table.find(tl, t.Name) then break end
		s:Activate()
		task.wait(swd)
	end
	if ah.Parent then
		ah:UnequipTools()
	end
end

local function sm(a, t)
	if not t or not t.Parent then return end
	local n = t.Name
	if bz[n] then return end
	bz[n] = true
	local ok, e = pcall(rsm, a, t)
	bz[n] = nil
	if not ok then
		warn("[BotLoop] smite error: " .. tostring(e))
	end
end

local function csm(p, a)
	local t = fp(a)
	if t and t ~= p then
		task.spawn(sm, lp, t)
	end
end

local function clp(a)
	local t = fp(a)
	if not t or t == lp then return end
	if not table.find(tl, t.Name) then
		table.insert(tl, t.Name)
	end
	task.spawn(function()
		while t.Parent and table.find(tl, t.Name) do
			if bz[t.Name] then
				task.wait(0.1)
			else
				sm(lp, t)
			end
		end
	end)
end

local function cul(a)
	local t = fp(a)
	local n = t and t.Name or a
	local i = table.find(tl, n)
	if i then
		table.remove(tl, i)
	end
end

local function csl(a)
	local t = fp(a)
	local n = t and t.Name or a
	local ok = t or pcall(function()
		return ps:GetUserIdFromNameAsync(n)
	end)
	if not ok then return end
	if not table.find(pl, n) then
		table.insert(pl, n)
		wp()
	end
end

local function csu(a)
	local t = fp(a)
	local n = t and t.Name or a
	local i = table.find(pl, n)
	if i then
		table.remove(pl, i)
		wp()
	end
end

local anc

local function an()
	if anc then return anc end
	local o = {}
	for _, i in ipairs(ad) do
		local ok, n = pcall(function()
			return ps:GetNameFromUserIdAsync(i)
		end)
		o[#o + 1] = ok and n or ("Failed to load (" .. i .. ")")
	end
	anc = o
	return o
end

local function lo(h, l)
	sd(h)
	if #l == 0 then
		sd("No one.")
		return
	end
	for _, n in ipairs(l) do
		task.wait(md)
		sd(tostring(n))
	end
end

local function scm()
	sd("USE THESE COMMANDS FOR GOOD!!! EXAMPLE: SOMEONE IS REACH EXPLOITING.")
	task.wait(md)
	sd("NOTE: THESE COMMANDS HAVE A WHITELIST SO DO NOT TRY THEM!")
	task.wait(md)
	sd("COMMANDS:")
	task.wait(md)
	sd("/smite [name/display/userid] - kills the player")
	task.wait(md)
	sd("/loop [name/display/userid] - temporarily loops the player for that server")
	task.wait(md)
	sd("/unloop [name/display/userid] - unloops the player")
	task.wait(md)
	sd("/saveloop [name/display/userid] - saves player name to json file in executor workspace to loop them")
	task.wait(md)
	sd("/saveunloop [name/display/userid] - removes player name from the json file in executor workspace")
	task.wait(md)
	sd("/temploops - lets you see what users are in the temporary loop kill list")
	task.wait(md)
	sd("/permloops - lets you see the users of permanently loop killed people")
	task.wait(md)
	sd("/admins - see the list of people whitelisted")
	task.wait(md)
	sd("/cmds - this command you used that shows this list")
end

local function cd(m, p)
	if not table.find(ad, p.UserId) then return end
	if cl then return end
	cl = true

	local a = m:match("^/smite%s+(%S+)")
	local b = m:match("^/loop%s+(%S+)")
	local c = m:match("^/unloop%s+(%S+)")
	local d = m:match("^/saveloop%s+(%S+)")
	local e = m:match("^/saveunloop%s+(%S+)")

	if a then csm(p, a) end
	if b then clp(b) end
	if c then cul(c) end
	if d then csl(d) end
	if e then csu(e) end

	if m:match("^/cmds") then
		task.spawn(scm)
	elseif m:match("^/permloops") then
		task.spawn(lo, "PERM LOOPED PLAYERS:", pl)
	elseif m:match("^/temploops") then
		task.spawn(lo, "TEMP LOOPED PLAYERS:", tl)
	elseif m:match("^/admins") then
		task.spawn(lo, "ADMINS/WHITELISTED PEOPLE:", an())
	end

	task.wait(cc)
	cl = false
end

local function hk(p)
	p.Chatted:Connect(function(m)
		cd(m, p)
	end)
end

ps.PlayerAdded:Connect(hk)
for _, p in ipairs(ps:GetPlayers()) do
	hk(p)
end

task.spawn(function()
	while true do
		task.wait(0.15)
		for _, n in ipairs(pl) do
			local t = ps:FindFirstChild(n)
			if t and t.Parent and not bz[n] then
				task.spawn(sm, lp, t)
			end
		end
	end
end)
