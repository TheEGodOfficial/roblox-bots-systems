--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
local sv = game:GetService("Players")
local tcs = game:GetService("TextChatService")
local hs = game:GetService("HttpService")
local rs = game:GetService("RunService")
local lp = sv.LocalPlayer
local pc = CFrame.new(10000, 10000, 10000)
local of = CFrame.new(0, 0, 2.5)
local cd = 3
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
	3551233751,
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
local al = {}
local cl = false
local function sd(m)
	local tc = tcs:FindFirstChild("TextChannels")
	local rc = tc and tc:FindFirstChild("RBXGeneral")
	if rc then pcall(function() rc:SendAsync(m) end) end
end
local io2 = isfile and isfolder and makefolder and writefile and refile
local function rp()
	local ok, r = pcall(function() return hs:JSONDecode(refile(df)) end)
	if ok and type(r) == "table" then
		local o = {}
		for _, v in ipairs(r) do
			if type(v) == "string" then o[#o + 1] = v end
		end
		return o
	end
	return {}
end
local function wp()
	if not io2 then return end
	pcall(writefile, df, hs:JSONEncode(pl))
end
if io2 then
	if not isfolder(dd) then makefolder(dd) end
	if isfile(df) then pl = rp() else pcall(writefile, df, "[]") end
else
	sd("Exe doesnt support file system functions")
end
local function fp(a)
	if not a or a == "" then return nil end
	a = tostring(a):lower()
	local u = tonumber(a)
	if u then
		for _, p in ipairs(sv:GetPlayers()) do
			if p.UserId == u then return p end
		end
	end
	local pt
	for _, p in ipairs(sv:GetPlayers()) do
		local n, d = p.Name:lower(), p.DisplayName:lower()
		if n == a or d == a then return p end
		if not pt and (string.find(n, a, 1, true) or string.find(d, a, 1, true)) then
			pt = p
		end
	end
	return pt
end
local function fs()
	local f, sn = {}, {}
	local function sc(c)
		if not c then return end
		for _, i in ipairs(c:GetChildren()) do
			if i:IsA("Tool") and not sn[i] then
				local n = i.Name:lower()
				for _, k in ipairs(sk) do
					if string.find(n, k, 1, true) then
						sn[i] = true
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
		local xn, yn = x.Name:lower(), y.Name:lower()
		local xs = (string.find(xn, "classic") and 3 or 0)
			+ (string.find(xn, "sword") and 2 or 0)
			+ (string.find(xn, "blade") and 1 or 0)
		local ys = (string.find(yn, "classic") and 3 or 0)
			+ (string.find(yn, "sword") and 2 or 0)
			+ (string.find(yn, "blade") and 1 or 0)
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
			if h and r and h.Parent and r.Parent then return c, h, r end
		end
		task.wait(0.05)
	until os.clock() >= d
	return nil
end
local cm = workspace.CurrentCamera
local function lk()
	for n in pairs(bz) do
		local p = sv:FindFirstChild(n)
		if p then
			local c = p.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r and r.Parent then return r end
		end
	end
	return nil
end
local nfActive = false
setsimulationrius(2 ^ 24)
rs.RenderStepped:Connect(function()
	if nfActive then return end
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not r or not h then return end
	local k = lk()
	if k then
		h.PlatformStand = false
		r.CFrame = CFrame.lookAt((k.CFrame * of).Position, k.Position)
		pcall(sethiddenproperty, r, "PhysicsRepRootRef", InstanceHandle.new(k))
	else
		h.PlatformStand = true
		r.CFrame = pc
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
		pcall(sethiddenproperty, r, "PhysicsRepRootRef", InstanceHandle.new(nil))
	end
	if cm and cm.CameraSubject ~= r then cm.CameraSubject = r end
end)
local function nf(targetHrp)
	local c = lp.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local nan = 0 / 0
	local h = c and c:FindFirstChildOfClass("Humanoid")
	nfActive = true
	for i = 1, 60 do
		if h and h.Parent then h.PlatformStand = false end
		if targetHrp and targetHrp.Parent then
			hrp.CFrame = targetHrp.CFrame
			pcall(sethiddenproperty, hrp, "PhysicsRepRootRef", InstanceHandle.new(targetHrp))
		end
		hrp.AssemblyLinearVelocity = Vector3.new(nan, nan, nan)
		hrp.AssemblyAngularVelocity = Vector3.new(nan, nan, nan)
		sethiddenproperty(hrp, "Velocity", Vector3.new(nan, nan, nan))
		sethiddenproperty(hrp, "RotVelocity", Vector3.new(nan, nan, nan))
		task.wait()
	end
	nfActive = false
end
local function gb(tool)
	return tool:FindFirstChild("Blade")
		or tool:FindFirstChild("Handle")
		or tool:FindFirstChildOfClass("MeshPart")
		or tool:FindFirstChildOfClass("UnionOperation")
		or tool:FindFirstChildOfClass("Part")
end
local function rsm(a, t, ld)
	local tw = fs()
	if not tw then warn("[BotLoop] no sword found") return end
	local ac, ah = wfc(a, ct)
	if not ac then return end
	local tc, th, tr = wfc(t, ct)
	if not tc or th.Health <= 0 then return end
	local s = a.Backpack:FindFirstChild(tw.Name) or ac:FindFirstChild(tw.Name)
	if not s then return end
	if ld and math.random(2) == 1 then pcall(nf, tr) end
	ah:EquipTool(s)
	task.wait(swd)
	local bl = gb(s)
	local dl = os.clock() + sl
	while os.clock() < dl do
		if not t.Parent then break end
		if not (th.Parent and tr.Parent) then
			tc, th, tr = wfc(t, 5)
			if not tc then break end
		end
		if th.Health <= 0 then break end
		if not (ah.Parent and ah.Health > 0) then break end
		if s.Parent ~= ac then break end
		if ld and not (table.find(tl, t.Name) or table.find(pl, t.Name)) then break end
		if bl and tr and tr.Parent then
			pcall(firetouchinterest, bl, tr, 0)
		end
		s:Activate()
		task.wait(swd)
		if bl and tr and tr.Parent then
			pcall(firetouchinterest, bl, tr, 1)
		end
	end
	if ah.Parent then ah:UnequipTools() end
end
local function sm(a, t, ld)
	if not t or not t.Parent then return end
	local n = t.Name
	if bz[n] then return end
	bz[n] = true
	local ok, e = pcall(rsm, a, t, ld)
	bz[n] = nil
	if not ok then warn("[BotLoop] attack error: " .. tostring(e)) end
end
local function csm(_, a)
	local t = fp(a)
	if table.find(ad, t.UserId) then return end
	if t and t ~= lp then task.spawn(sm, lp, t, false) end
end
local function clp(a)
	local t = fp(a)
	if table.find(ad, t.UserId) then return end
	if not t or t == lp then return end
	local n = t.Name
	if not table.find(tl, n) then tl[#tl + 1] = n end
	if al[n] then return end
	al[n] = true
	task.spawn(function()
		while sv:FindFirstChild(n) and table.find(tl, n) do
			if bz[n] then task.wait(0.1)
			else sm(lp, t, true) end
		end
		al[n] = nil
	end)
end
local function cul(a)
	local t = fp(a)
	if table.find(ad, t.UserId) then return end
	local n = t and t.Name or a
	local i = table.find(tl, n)
	if i then table.remove(tl, i) end
end
local function csl(a)
	local t = fp(a)
	if table.find(ad, t.UserId) then return end
	local n = t and t.Name or a
	local ok = t or pcall(function() return sv:GetUserIdFromNameAsync(n) end)
	if not ok then return end
	if not table.find(pl, n) then
		pl[#pl + 1] = n
		wp()
	end
end
local function csu(a)
	local t = fp(a)
	if table.find(ad, t.UserId) then return end
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
		local ok, n = pcall(function() return sv:GetNameFromUserIdAsync(i) end)
		o[#o + 1] = ok and n or ("Failed to load (" .. i .. ")")
	end
	anc = o
	return o
end
local function lo(h, l)
	sd(h)
	task.wait(md)
	if #l == 0 then sd("No one."); return end
	for i, n in ipairs(l) do
		sd(tostring(n))
		if i < #l then task.wait(md) end
	end
end
local cmdl = {
	"/smite [name/display/userid] - kills the player",
	"/loop [name/display/userid] - temporarily loops the player for that server",
	"/unloop [name/display/userid] - unloops the player",
	"/saveloop [name/display/userid] - saves player name to json file to loop them persistently",
	"/saveunloop [name/display/userid] - removes player name from the json file",
	"/temploops - shows users in the temporary loop kill list",
	"/permloops - shows users in the permanent loop kill list",
	"/admins - shows the whitelist",
	"/cmds - shows this command list",
}
local function scm()
	sd("USE THESE COMMANDS FOR GOOD!!! EXAMPLE: SOMEONE IS REACH EXPLOITING.")
	task.wait(md)
	sd("NOTE: THESE COMMANDS HAVE A WHITELIST SO DO NOT TRY THEM!")
	for i, line in ipairs(cmdl) do
		task.wait(md)
		sd(line)
	end
end
tcs.MessageReceived:Connect(function(msg)
	if not msg.TextSource then return end
	local spk = sv:GetPlayerByUserId(msg.TextSource.UserId)
	if not spk then return end
	if not table.find(ad, spk.UserId) then return end
	if cl then return end
	cl = true
	local txt = msg.Text
	local lo2 = txt:lower()
	local sa = txt:match("^/smite%s+(.+)")
	local sb = txt:match("^/loop%s+(.+)")
	local sc = txt:match("^/unloop%s+(.+)")
	local se = txt:match("^/saveloop%s+(.+)")
	local sg = txt:match("^/saveunloop%s+(.+)")
	if sa then csm(spk, sa:gsub("^%s+", ""):gsub("%s+$", "")) end
	if sb then clp(sb:gsub("^%s+", ""):gsub("%s+$", "")) end
	if sc then cul(sc:gsub("^%s+", ""):gsub("%s+$", "")) end
	if se then csl(se:gsub("^%s+", ""):gsub("%s+$", "")) end
	if sg then csu(sg:gsub("^%s+", ""):gsub("%s+$", "")) end
	if lo2:match("^/cmds") then
		task.spawn(scm)
	elseif lo2:match("^/permloops") then
		task.spawn(lo, "PERM LOOPED PLAYERS:", pl)
	elseif lo2:match("^/temploops") then
		task.spawn(lo, "TEMP LOOPED PLAYERS:", tl)
	elseif lo2:match("^/admins") then
		task.spawn(lo, "ADMINS/WHITELISTED PEOPLE:", an())
	end
	task.wait(cd)
	cl = false
end)
local function hk(p)
	p.Chatted:Connect(function(m)
		if not table.find(ad, p.UserId) then return end
		if cl then return end
		cl = true
		local lo2 = m:lower()
		local sa = m:match("^/smite%s+(.+)")
		local sb = m:match("^/loop%s+(.+)")
		local sc = m:match("^/unloop%s+(.+)")
		local se = m:match("^/saveloop%s+(.+)")
		local sg = m:match("^/saveunloop%s+(.+)")
		if sa then csm(p, sa:gsub("^%s+", ""):gsub("%s+$", "")) end
		if sb then clp(sb:gsub("^%s+", ""):gsub("%s+$", "")) end
		if sc then cul(sc:gsub("^%s+", ""):gsub("%s+$", "")) end
		if se then csl(se:gsub("^%s+", ""):gsub("%s+$", "")) end
		if sg then csu(sg:gsub("^%s+", ""):gsub("%s+$", "")) end
		if lo2:match("^/cmds") then
			task.spawn(scm)
		elseif lo2:match("^/permloops") then
			task.spawn(lo, "PERM LOOPED PLAYERS:", pl)
		elseif lo2:match("^/temploops") then
			task.spawn(lo, "TEMP LOOPED PLAYERS:", tl)
		elseif lo2:match("^/admins") then
			task.spawn(lo, "ADMINS/WHITELISTED PEOPLE:", an())
		end
		task.wait(cd)
		cl = false
	end)
end
sv.PlayerAdded:Connect(hk)
for _, p in ipairs(sv:GetPlayers()) do hk(p) end
task.spawn(function()
	while true do
		task.wait(0.15)
		for _, n in ipairs(pl) do
			local t = sv:FindFirstChild(n)
			if t and t.Parent and not bz[n] then
				task.spawn(sm, lp, t, true)
			end
		end
	end
end)
