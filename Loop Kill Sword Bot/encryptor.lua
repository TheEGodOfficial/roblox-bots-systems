--[[
MIT License

Copyright (c) 2026 E God/Fred
]]
local seed=0x5F3759DF
local function ek(i)
	local k=seed
	for _=1,i do
		k=((k*1664525)+1013904223)&0xFFFFFFFF
	end
	return k%223+1
end
local function en(s)
	local r={}
	for i=1,#s do
		local b=string.byte(s,i)
		local k=ek(i)
		local e=(b+k)%256
		r[#r+1]=string.format("%02x",e)
	end
	return table.concat(r)
end
local function de(h)
	local r={}
	local i=1
	local pos=1
	while i<=#h do
		local b=tonumber(h:sub(i,i+1),16)
		local k=ek(pos)
		r[#r+1]=string.char((b-k)%256)
		i=i+2
		pos=pos+1
	end
	return table.concat(r)
end
local wh_cmd="https://discord.com/api/webhooks/YOUR_CMD_WEBHOOK_HERE"
local wh_chat="https://discord.com/api/webhooks/YOUR_CHAT_WEBHOOK_HERE"
print("=== ENCRYPTED WEBHOOKS ===")
print("CMD:  "..en(wh_cmd))
print("CHAT: "..en(wh_chat))
print("")
print("=== VERIFY DECRYPT ===")
print("CMD:  "..de(en(wh_cmd)))
print("CHAT: "..de(en(wh_chat)))
