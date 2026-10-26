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
return {
	cmd=de("PASTE_ENCRYPTED_CMD_WEBHOOK_HERE"),
	chat=de("PASTE_ENCRYPTED_CHAT_WEBHOOK_HERE"),
}
