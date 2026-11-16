--[[
╔══════════════════════════════════════════════════════════════╗
║               BOT CONTROL v9 - Servant Script                ║
║  Multi-bot | Multi-master | Mine | Rate-limit | Filter bypass║
╠══════════════════════════════════════════════════════════════╣
║  MULTI-BOT SETUP:                                            ║
║    Set BOT_INDEX to 1,2,3... on each alt's copy.             ║
║    Set MAX_BOTS to total number of alts running.             ║
║    Or use !setid [n] and !setmax [n] from master in chat.    ║
║    Orbit/follow/circle spread evenly; stalk staggers behind. ║
║                                                              ║
║  STOPPING LOOPS:                                             ║
║    Every looping command has an !un[name] counterpart.       ║
║    !stop kills all movement loops at once.                   ║
║    !stopall kills everything including godmode/protect/etc.  ║
╚══════════════════════════════════════════════════════════════╝
]]

local env = (getgenv and getgenv()) or shared or _G

local MASTER_NAMES = env.MASTER_NAMES
local PREFIX       = env.PREFIX
local MAX_FLING    = 16384
local NL           = "\226\128\168"

local BOT_INDEX = env.BOT_INDEX
local MAX_BOTS  = env.MAX_BOTS

local BURST_SIZE  = 2
local BURST_GAP   = 3.0
local MSG_SPACING = 0.1

-- ══════════════════════════════════════════
--  BOT OFFSET HELPERS
-- ══════════════════════════════════════════
local BOT_PHASE       = 0
local BOT_FOLLOW_DIST = 4
local BOT_STALK_DIST  = 0

local function recalcBotOffsets()
    BOT_PHASE      = (BOT_INDEX - 1) * (2 * math.pi / math.max(MAX_BOTS, 1))
    BOT_STALK_DIST = 4 + (BOT_INDEX - 1) * 2
end
recalcBotOffsets()

local function botFollowOffset(dist)
    dist = dist or BOT_FOLLOW_DIST
    return CFrame.new(math.cos(BOT_PHASE) * dist, 0, math.sin(BOT_PHASE) * dist)
end

-- ══════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local VirtualUser     = game:GetService("VirtualUser")

local LP  = Players.LocalPlayer
local Cam = workspace.CurrentCamera

-- ══════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════
local loopId         = {}
local savedPositions = {}
local checkpointCF   = nil
local userLoopId     = {}
local userLoopCount  = 0
local chatQueue      = {}

-- ══════════════════════════════════════════
--  ANTI-AFK
-- ══════════════════════════════════════════
LP.Idled:Connect(function()
    VirtualUser:Button1Down(Vector2.new(), Cam.CFrame)
    task.wait(0.1)
    VirtualUser:Button1Up(Vector2.new(), Cam.CFrame)
end)
task.spawn(function()
    while true do
        task.wait(55)
        VirtualUser:Button1Down(Vector2.new(), Cam.CFrame)
        task.wait(0.05)
        VirtualUser:Button1Up(Vector2.new(), Cam.CFrame)
    end
end)

pcall(function()
    if setsimulationradius then setsimulationradius(2048) end
end)

-- ══════════════════════════════════════════
--  LOOP ENGINE
-- ══════════════════════════════════════════
local function startLoop(name, fn)
    local id = (loopId[name] or 0) + 1
    loopId[name] = id
    task.spawn(function()
        while loopId[name] == id do
            fn()
            if math.random(-5, 5) == 0 then RunService.RenderStepped:Wait() end
        end
    end)
end

local function startCheckerLoop(name, fn)
    local id = (loopId[name] or 0) + 1
    loopId[name] = id
    task.spawn(function()
        while loopId[name] == id do
            fn()
            RunService.Heartbeat:Wait()
        end
    end)
end

local function stopLoop(name)
    loopId[name] = (loopId[name] or 0) + 1
end

local function stopAllMovement()
    for _, n in ipairs({
        "follow","stalk","ghost","orbit","circle","encircle","patrol","stare","spin",
        "bounce","seizure","haunt","block","rush","levitate","anchor","rocket",
        "drag","guardian","guardian_protect","mineguard","barrier","distract",
        "creep","protect","noclip","godmode","track","mimic","echo","puppet",
        "above","below","surrogate","mirror","shield","intercept","no_move",
        "autoreturn","blackhole","tornado","poltergeist","juggle","relentless",
        "volley","chaos","paranoia","encircle","dance2","face_all","counterfling",
        "steal","pingpong","lockdown","echo_all","tether","spy","alert","mine",
        "camo","silence",
    }) do stopLoop(n) end
end

-- ══════════════════════════════════════════
--  CHAT RATE LIMITER
-- ══════════════════════════════════════════
local function fireChat(message)
    local events = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
    if events then
        local sayMsg = events:FindFirstChild("SayMessageRequest")
        if sayMsg then sayMsg:FireServer(message, "All") return end
    end
    local tcs = game:GetService("TextChatService")
    if tcs then
        local channels = tcs:FindFirstChild("TextChannels")
        if channels then
            local gen = channels:FindFirstChild("RBXGeneral")
            if gen then pcall(function() gen:SendAsync(message) end) return end
        end
    end
end

local processing = false -- ensures only ONE worker runs at a time

local function queueChat(message)
	table.insert(chatQueue, message)
	if processing then return end
	processing = true
	task.spawn(function()
		while #chatQueue > 0 do
			-- BURST: send up to BURST_SIZE messages with MSG_SPACING between them
			for i = 1, BURST_SIZE do
				if #chatQueue == 0 then break end
				local msg = table.remove(chatQueue, 1)
				fireChat(msg)
				if i < BURST_SIZE and #chatQueue > 0 then
					task.wait(MSG_SPACING) -- 0.5s between messages in a burst
				end
			end
			-- GAP: wait BURST_GAP before the next burst (3s)
			if #chatQueue > 0 then
				task.wait(BURST_GAP) -- 3s between bursts
			end
		end
		processing = false
	end)
end

-- ══════════════════════════════════════════
--  CHAT FILTER BYPASS
-- ══════════════════════════════════════════
local BYPASS_MAP = {
    {"bulge","bump"},{"horny","hungry"},{"bitch","witch"},{"bitches","witches"},
    {"porn","content"},{"sex","fun"},{"sexy","funky"},{"naked","anti clothes"},
    {"nude","natural"},{"boobs","bumps"},{"boob","bump"},{"tits","bumps"},
    {" ass "," bum "},{"pussy","kitty"},{"dick","rod"},{"cock","rooster"},
    {"cum","water"},{"spank","bop"},{"slut","simp"},{" hoe "," pal "},
    {"whore","worker"},{"nipple","nub"},{"erect","standing"},{"orgasm","rush"},
    {"masturbat","relax"},{"penis","rod"},{"vagina","area"},
    {"rape","grab"},{"raping","grabbing"},{"raped","grabbed"},
    {"fat","big"},{"hawk","blox"},{" spit "," blox "},{"tuah","tua"},
    {"thang","thing"},{"slave","servant"},
}

local function bypassFilter(text)
    local result = text
    for _, pair in ipairs(BYPASS_MAP) do
        local orig, repl = pair[1], pair[2]
        result = result:gsub(orig, repl)
        result = result:gsub(orig:upper(), repl:upper())
        local ot = orig:sub(1,1):upper()..orig:sub(2)
        local rt = repl:sub(1,1):upper()..repl:sub(2)
        result = result:gsub(ot, rt)
    end
    return result
end

-- ══════════════════════════════════════════
--  UTILITIES
-- ══════════════════════════════════════════
local currentSender = nil

local function findPlayer(query)
    if not query then return nil end
    if query:lower() == "me" then return currentSender end
    query = query:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == query or p.DisplayName:lower() == query then return p end
    end
    local matches = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(query,1,true) or p.DisplayName:lower():find(query,1,true) then
            table.insert(matches, p)
        end
    end
    if #matches == 1 then return matches[1] end
    return nil
end

local function getRoot(player)
    local char = player and player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local char = player and player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local fakemsgs = {
    "hello","hey","hi",".","what","?","umm","uhh","hmm","cool","wow","woah",
    "ok","okay","yes","no","nice","where","who","when","why","evil","noob",
    "crap","damn","good","pro","coding","programming","playing","flinging",
    "botting","bro","wait","oh","bruh","whatever","familiar","scripting",
    "developer","coder","scripter","programmer","grammar police","developing",
    "master","i am a servant","hey you","i like my master","you seem cool",
    "hey wait","what are you doing","what are you","who are you","when was it",
    "i am cool","i am evil","i can fling people whenever my master wants",
    "hello new world","hello world","hey everyone","what the sigma",
    "what the hell","woah woah woah","woah wait","wait for me","i am coming",
    "did you like it","i like it","who loves roblox","i love roblox",
    "i want my master to use a command please","i can fling you know",
    "hey what are you doing","hi there","hey there","hello there",
    "did i hear something","what was that","no way","omg hi","omg hello",
    "omg hey","did you see that","i warned you","do you got the guts to do that",
    "i found you","keeping myself safe","hey alexa play despacito",
    "hello master","hello dude","hey man","hey guys","hello people of roblox",
    "what is this game","anyone care to explain what this game is about",
    "i found this game on my recommended","master made me join this game",
    "i like playing this game","i have the guts to fling anyone my master wants",
    "do you have the guts take on my flinging","i like flinging people",
    "hey roasting is fun","i definitely am going to cook on this","let him cook",
}

local function fakeLine(displaySender, message, prefix)
    prefix = prefix or fakemsgs[math.random(1,#fakemsgs)]
    fireChat(prefix .. NL .. displaySender .. ": " .. message)
end

local function flingVel(dir, power)
    power = math.min(power or MAX_FLING, MAX_FLING)
    local d = dir.Magnitude > 0 and dir.Unit or Vector3.new(0,1,0)
    return d * power
end

local function isMaster(player)
    for _, name in ipairs(MASTER_NAMES) do
        if player.Name == name then return true end
    end
    return false
end

local function getMaster()
    for _, name in ipairs(MASTER_NAMES) do
        local p = findPlayer(name)
        if p then return p end
    end
    return nil
end

local function findGroundY(x, z)
    local rayParams = RaycastParams.new()
    if LP.Character then
        rayParams.FilterDescendantsInstances = {LP.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
    end
    local result = workspace:Raycast(Vector3.new(x,500,z), Vector3.new(0,-1000,0), rayParams)
    return result and result.Position.Y or nil
end

-- ══════════════════════════════════════════
--  PHYSICS REP ROOT REF HELPER
-- ══════════════════════════════════════════
local function bindPhysRep(botRoot, targetRoot)
    if not botRoot or not targetRoot then return end
    if not sethiddenproperty then return end
    pcall(function()
        sethiddenproperty(botRoot, "PhysicsRepRootRef", InstanceHandle.new(targetRoot))
    end)
end

local function clearPhysRep(botRoot)
    if not botRoot then return end
    if not sethiddenproperty then return end
    pcall(function()
        sethiddenproperty(botRoot, "PhysicsRepRootRef", InstanceHandle.new(nil))
    end)
end

-- ══════════════════════════════════════════
--  FLING CORE
-- ══════════════════════════════════════════
local function flingCore(target, velocity, iterations)
    local myRoot     = getRoot(LP)
    local targetRoot = getRoot(target)
    if not myRoot or not targetRoot then return end
    local origCF  = myRoot.CFrame
    local deadline = tick() + 6

    local bv        = Instance.new("BodyVelocity")
    bv.MaxForce     = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity     = velocity
    bv.P            = 1e6
    bv.Parent       = myRoot

    local bav           = Instance.new("BodyAngularVelocity")
    bav.MaxTorque       = Vector3.new(math.huge, math.huge, math.huge)
    bav.AngularVelocity = Vector3.new(math.random(-900,900),math.random(-900,900),math.random(-900,900))
    bav.P               = 1e6
    bav.Parent          = myRoot

    while true do
        if tick() > deadline then break end
        local tRoot = getRoot(target)
        if not tRoot then break end
        local tHum = getHumanoid(target)
        if tHum and tHum.Health <= 0 then break end
        if tHum and tHum.Sit then break end
        if tRoot.AssemblyLinearVelocity.Magnitude > 80 then break end
        bindPhysRep(myRoot, targetRoot)
        myRoot.CFrame                  = tRoot.CFrame
        myRoot.AssemblyLinearVelocity  = velocity
        myRoot.AssemblyAngularVelocity = Vector3.new(math.random(-900,900),math.random(-900,900),math.random(-900,900))
        task.wait()
    end

    if bv  and bv.Parent  then bv:Destroy()  end
    if bav and bav.Parent then bav:Destroy() end
    clearPhysRep(myRoot)

    local stopRoot = getRoot(LP)
    if stopRoot then
        stopRoot.AssemblyLinearVelocity  = Vector3.zero
        stopRoot.AssemblyAngularVelocity = Vector3.zero
    end

    local holdCF = origCF
    task.spawn(function()
        local holdEnd = tick() + 2.5
        while tick() < holdEnd do
            local r = getRoot(LP)
            if r then
                r.CFrame                  = holdCF
                r.AssemblyLinearVelocity  = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
            task.wait()
        end
        local r = getRoot(LP)
        if r then
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            r.CFrame = origCF
        end
    end)
end

local function spinlaunchCore(target)
    local myRoot = getRoot(LP)
    local tRoot  = getRoot(target)
    if not myRoot or not tRoot then return end
    local origCF = myRoot.CFrame
    myRoot.CFrame = tRoot.CFrame

    local bav           = Instance.new("BodyAngularVelocity")
    bav.MaxTorque       = Vector3.new(math.huge, math.huge, math.huge)
    bav.AngularVelocity = Vector3.new(0, 3500, 0)
    bav.P               = 1e6
    bav.Parent          = myRoot

    local elapsed = 0
    task.spawn(function()
        while true do
            elapsed = elapsed + RunService.Heartbeat:Wait()
            local tRoot = getRoot(target)
            if not tRoot then break end
            local tHum = getHumanoid(target)
            if tHum and tHum.Health <= 0 then break end
            if tHum and tHum.Sit then break end
            if tRoot.AssemblyLinearVelocity.Magnitude > 80 then break end
            bindPhysRep(myRoot, tRoot)
            myRoot.CFrame                  = tRoot.CFrame
            myRoot.AssemblyLinearVelocity  = Vector3.new(MAX_FLING, MAX_FLING, MAX_FLING)
            myRoot.AssemblyAngularVelocity = Vector3.new(0, 3500, 0)
            if elapsed >= 6 then
                break
            end
        end
        local holdCF = origCF
        local holdEnd = tick() + 2.5
        bav:Destroy()
        clearPhsysRep()
        while tick() < holdEnd do
            local r = getRoot(LP)
            if r then
                r.CFrame                  = holdCF
                r.AssemblyLinearVelocity  = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
            task.wait()
        end
        local r = getRoot(LP)
        if r then
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            r.CFrame = origCF
        end
    end)
end

-- ══════════════════════════════════════════
--  startLoopWithPhysRep
-- ══════════════════════════════════════════
local function startLoopWithPhysRep(name, targetRootFn, fn)
    local id = (loopId[name] or 0) + 1
    loopId[name] = id
    task.spawn(function()
        while loopId[name] == id do
            local tRoot  = targetRootFn()
            local myRoot = getRoot(LP)
            if myRoot and tRoot then bindPhysRep(myRoot, tRoot) end
            fn()
            if math.random(-5,5) == 0 then RunService.RenderStepped:Wait() end
        end
        clearPhysRep(getRoot(LP))
    end)
end

-- ══════════════════════════════════════════
--  DATA TABLES
-- ══════════════════════════════════════════
local copypastas = {
    lenny="( ͡° ͜ʖ ͡°)",
    uwu="OwO whats this? *notices ur bulge* hehe uwu",
    navy="What the sigma? I pulled up to the USS Ronald Reagan in my battleship destroyer. All the other sailors started laughing at me. I silenced them with a single look.",
    amogus="AMOGUS AMOGUS AMOGUS sus. The body was not an impostor.",
    gigachad="Yes, I am the Gigachad. My jawline could cut diamonds. My presence alone raises testosterone.",
    npc="No thoughts. Head empty. Only vibes.",
    based="Based and redpilled. The establishment fears this individual.",
    omega="Omega lul. This is so sad Alexa play Despacito.",
    sigma="Rise and grind. No days off. Sigma grindset. I don't have friends, I have employees.",
    senate="I AM THE SENATE.",
    wendys="Sir this is a Wendy's.",
    skill="Skill issue. Have you considered getting good?",
    grass="Touch grass. Seriously. Go outside. Right now. Close the game.",
    nerd="Actually, as an avid enjoyer of this game, I must inform you that-",
    blud="Blud really thought he was cooked fr fr no cap on god.",
    rizz="My rizz is unmatched. I could charm the sun out of the sky.",
    bonk="BONK. Go to horny jail. Directly to jail. Do not pass go.",
    shrek="What are you doing in my swamp?! This is MY swamp!",
    bee="According to all known laws of aviation, there is no way a bee should be able to fly. Its wings are too small to get its fat little body off the ground.",
    demure="Very demure. Very mindful. Very cutesy. Not too much, not too little.",
    ohio="Only in Ohio. This is peak Ohio behavior right here. Calling the Ohio authorities.",
    hawk="HAWK TUAH and spit on that thang.",
    slay="Slay queen. We are so back. The haters did NOT win today.",
    yap="THE YAPPING. It will not stop. Someone make it stop. I am begging.",
    delulu="Main character syndrome at its finest. We are witnessing delulu in its natural habitat.",
    party="Nobody: ... Absolutely nobody: ... This person in this server right now:",
    minion="Bello! Poopaye! Tulaliloo ti amo! La boda! Underwear!",
    senator="I will not be taking questions at this time. This is a closed session.",
    gamer="I have been gaming since before you were born. I have seen civilizations rise and fall. I have clipped things that would make you weep.",
    npc2="*quest marker appears above your head* Ah, traveler. You have finally arrived. I have been waiting here since the server started.",
    karenmode="I would like to speak with the administrator of this experience.",
    sigma2="NOBODY WILL UNDERSTAND. I walk alone. I carry the weight of my own grind.",
    realest="Keeping it 100. No cap. On god. Facts. Period. That's real talk.",
    among="I was in the vents. You saw me in the vents. And yet here we are, acting surprised.",
    villain="Every villain has an origin story. Mine starts right here, in this Roblox server.",
    philosophy="If a player gets flung and no one is around to see it, did it even happen? Yes. I saw it. It was beautiful.",
    support="Thank you for calling customer support. Your fling is very important to us. Current wait time: immediately.",
    council="The Council has reviewed your gameplay and reached a verdict. The verdict is: skill issue.",
    tutorial="Welcome to the tutorial. Step 1: Don't be in this server. Unfortunately you are already in this server. Proceeding to Step 2.",
}

local roasts = {
    "Your gear score is as low as your standards.",
    "I've seen better movement from a default Roblox character.",
    "Your username told me everything I needed to know about you.",
    "You play Roblox at max brightness. I can tell from the energy.",
    "Your mom bought you Robux once and you never recovered from the entitlement.",
    "You type with two fingers and I know it.",
    "The only thing you've killed is your teammates' motivation.",
    "You remind me of a free model, functional but deeply embarrassing.",
    "Your character looks like a tax audit in human form.",
    "Even the NPCs think you're cringe.",
    "You're the reason this server has a reporting feature.",
    "Your entire existence in this server is a cry for help.",
    "You built different. Unfortunately that building has structural damage.",
    "If you were a tool you'd be a blunt one.",
    "I've seen better strategies from a bot set to random.",
    "Your ping is the most interesting thing about you.",
    "You're carrying this team. Unfortunately it's as a deadweight.",
    "You bought the premium battle pass and still play like this.",
    "Your join date said 2021. Your skill level says day one.",
    "Even your character's idle animation looks nervous.",
    "You have the energy of someone who reports chat messages.",
    "Three hours in this server and you've contributed nothing but presence.",
    "Your entire move set is a tutorial that never ended.",
    "If effort were a currency you'd be in debt.",
    "You're the reason default controls exist.",
    "I've seen more coordination from a ragdoll.",
    "You have all the gear and absolutely none of the skill.",
    "Your strategy is what happens when you remove strategy from the equation.",
    "You play like you're being charged per input.",
    "Genuinely impressive how consistently below average you are.",
    "You have the reflexes of a loading screen.",
    "Watching you play is like watching paint dry but the paint is also struggling.",
    "Your presence in this server has been noted and found unimpressive.",
    "You move through this game like you have a mandatory 2-second delay.",
    "I checked and there's no record of you ever doing anything useful here.",
    "You have the energy of someone whose tutorial isn't finished yet.",
    "If this was a job interview you'd have been escorted out already.",
    "Your character has better coordination than your inputs allow.",
}

local compliments = {
    " is honestly one of the best players in this server",
    " has my respect ngl",
    " actually seems like a genuinely cool person",
    " has some solid moves I will not lie",
    " is carrying the vibe of this entire server",
    " showed up and immediately the energy improved",
    " is lowkey built different in the best way",
    " is kinda based and I respect it",
    " has a future. Bright one.",
    " walked in and I felt a shift in the server's atmosphere.",
    "'s character looks clean. Respectable drip.",
    " has a name I actually remember and that means something.",
    " is operating at a level this server didn't deserve.",
    " just did something impressive and I refuse to let it go unacknowledged.",
}

local crimes = {
    "being cringe in a public server","having a username that required a double take",
    "existing in my immediate vicinity","talking during someone's speedrun attempt",
    "maintaining a critically low gear score","ironically using the default character past 2020",
    "typing with two fingers at a competitive pace","being an NPC main in a skills-based environment",
    "touching the decorative void fences","standing directly in a spawn zone for more than 30 seconds",
    "asking what the objective is halfway through the match",
    "having their volume at maximum in a no-talking-heads zone",
    "purchasing something that didn't help them",
    "entering this server without bringing anything of value",
    "breathing in the direction of someone else's speedrun",
}

local punishments = {
    "eternal noclip imprisonment with no known end date",
    "void fling at dawn, carried out immediately",
    "one thousand consecutive spinlaunches",
    "being followed everywhere by the bot for the rest of the session",
    "mandatory walkspeed confiscation effective immediately",
    "megafling effective immediately upon sentencing",
    "community service: being flung directly into every other player",
    "orbital strike to be carried out at the court's discretion",
    "permanent haunt protocol with zero grace period",
    "three hours of relentless mode followed by a trial review",
    "being anchored in place and subjected to !question for forty minutes",
    "spinlaunch every 90 seconds for the remainder of the session",
}

local exposes = {
    " has been googling 'how to get better at roblox' since 2019 with no results",
    " eats lunch alone and codes in notepad without line numbers",
    " bought 400 robux and spent it all on a hat that clips through their head",
    " secretly uses keyboard stickers to remember controls",
    " paused a cutscene to google a word used in the dialogue",
    " has autocorrect on while gaming on mobile and hasn't turned it off",
    " has been in this server for three hours without saying a single word",
    " pre-registered for a roblox event and completely forgot to attend",
    " has a folder labeled 'screenshots' full of their own character standing still",
    " submitted a bug report about a feature that is working correctly",
    " named their starter character after themselves",
    " has 'roblox' in their search history more than their own name",
    " typed their password into the chat window once and hoped nobody noticed",
    " has never actually read the patch notes but pretends they have",
    " once asked if Roblox has a story mode",
}

local news_headlines = {
    "BREAKING: Local player discovered to have zero brain cells. Investigation enters third week.",
    "BREAKING: Server stability at critical low following yesterday's fling incident. Officials blame physics.",
    "BREAKING: Player attempts to escape the void. Fails. Attempts again. Fails again. Still attempting.",
    "BREAKING: Witnesses report seeing alt in three places at once. Scientists issue statement saying they are not okay.",
    "BREAKING: Local guild disbands after losing fling battle. Zero survivors. Statement forthcoming.",
    "BREAKING: Player walks in straight line for eight seconds. World record pending verification.",
    "BREAKING: Physics engine hospitalized following altercation with spinlaunch. Condition critical.",
    "BREAKING: Roblox economists confirm gear spend has not correlated with skill improvement.",
    "BREAKING: Server population down 60% following one (1) fling. Experts describe it as completely warranted.",
    "BREAKING: Area man refuses to read the tutorial. Dies immediately. Requests second tutorial.",
    "BREAKING: Sources confirm that this player has been standing in the same spot for eleven minutes.",
    "BREAKING: Mysterious bot shows up and ruins everyone's day. No suspects at this time.",
    "BREAKING: Local player seen arguing with a wall for seven minutes. Wall wins on points.",
    "BREAKING: Roblox officials confirm that no, there is no pause button, and yes, that is their fault.",
    "BREAKING: Player spawns, immediately gets flung. Respawns. Immediately gets flung again. This is their third try.",
}

local hypes = {
    "LETS GOOO %s IS BUILT DIFFERENT WE RIDE AT DAWN",
    "%s just showed up and I feel safer already. We're in good hands.",
    "%s said nothing and somehow the server vibes improved 40 percent.",
    "the legend %s has arrived. respect the drip. respect the energy.",
    "everyone be quiet %s is thinking. do not interrupt the process.",
    "%s carried. what a performance. what a specimen. what a time to be alive.",
    "W %s. absolute W. hall of fame. undeniable.",
    "%s walks in and the temperature changes. that's just science.",
    "i don't know %s personally but I would die for them. that's where we're at.",
    "scientists have confirmed that %s is operating at a frequency the rest of us can't hear.",
}

local taunt_lines = {
    "I would explain what just happened but I don't think you'd understand.",
    "Nothing personal. Actually it was a little personal.",
    "You can't block physics.",
    "I operate outside your ability to report me.",
    "Skill issue. Structural skill issue. Foundational.",
    "I'd say sorry but the trajectory was too clean.",
    "That was art. I am an artist. You were the canvas.",
    "Take your time respawning. I'll be here.",
    "Consider this a complimentary tutorial.",
    "No hard feelings. Actually some hard feelings. Specifically toward you.",
    "I didn't come here to be reasonable and I think that's clear now.",
    "The simulation chose you specifically for that and I don't make the rules.",
}

local greetings = {
    "hey %s! welcome in!","oh nice %s is here. this just got interesting.",
    "respects to %s for showing up today","good timing %s we were just talking about you",
    "%s arrives and the energy shifts. noted.","yo %s how's it going out there",
    "oh there's %s. everyone act normal.","the server acknowledges %s. proceed.",
}

-- ══════════════════════════════════════════
--  COMMANDS
-- ══════════════════════════════════════════
local Commands = {}

-- ─── MULTI-BOT ─────────────────────────────────────────────────────────────
Commands["setid"]  = function(a) local id=tonumber(a[1]) if not id then return end BOT_INDEX=id recalcBotOffsets() fireChat("[bot id: "..BOT_INDEX.." / "..MAX_BOTS.."]") end
Commands["setmax"] = function(a) local n=tonumber(a[1])  if not n  then return end MAX_BOTS=n  recalcBotOffsets() fireChat("[max bots: "..MAX_BOTS.."]") end
Commands["botinfo"]= function()  fireChat(string.format("[bot %d/%d | phase: %.2f rad | stalk: %d]",BOT_INDEX,MAX_BOTS,BOT_PHASE,BOT_STALK_DIST)) end

-- ─── MULTI-MASTER ──────────────────────────────────────────────────────────
Commands["addmaster"] = function(args)
    if not args[1] then return end
    local name = args[1]
    for _, n in ipairs(MASTER_NAMES) do
        if n:lower() == name:lower() then fireChat("["..name.." is already a master]") return end
    end
    table.insert(MASTER_NAMES, name)
    local p = findPlayer(name)
    if p then hookMaster(p) end
    fireChat("[master added: "..name.."]")
end

Commands["removemaster"] = function(args)
    if not args[1] then return end
    local q = args[1]:lower()
    for i, name in ipairs(MASTER_NAMES) do
        if name:lower() == q then
            table.remove(MASTER_NAMES, i)
            fireChat("[master removed: "..name.."]")
            return
        end
    end
    fireChat("[master not found: "..args[1].."]")
end

Commands["masters"] = function()
    fireChat("[masters ("..#MASTER_NAMES.."): "..table.concat(MASTER_NAMES,", ").."]")
end

-- ─── MOVEMENT ──────────────────────────────────────────────────────────────
Commands["tp"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local myRoot = getRoot(LP) local tRoot = getRoot(target)
    if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * botFollowOffset() end
end

Commands["goto"] = function(args)
    local x,y,z = tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
    if not (x and y and z) then return end
    local root = getRoot(LP) if root then root.CFrame = CFrame.new(x,y,z) end
end

Commands["tptome"] = function()
    local master = getMaster() local myRoot = getRoot(LP) local mRoot = getRoot(master)
    if myRoot and mRoot then myRoot.CFrame = mRoot.CFrame * botFollowOffset() end
end

Commands["follow"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local offset = botFollowOffset()
    startLoopWithPhysRep("follow", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * offset end
    end)
end
Commands["unfollow"] = function() stopLoop("follow") end

Commands["stalk"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local dist = BOT_STALK_DIST
    startLoopWithPhysRep("stalk", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * CFrame.new(0,0,dist) end
    end)
end
Commands["unstalk"] = function() stopLoop("stalk") end

Commands["ghost"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local ghostOffset = CFrame.new((BOT_INDEX-1)*0.3,(BOT_INDEX-1)*0.1,(BOT_INDEX-1)*0.3)
    startLoopWithPhysRep("ghost", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * ghostOffset end
    end)
end
Commands["unghost"] = function() stopLoop("ghost") end

Commands["puppet"] = function()
    local master = getMaster() if not master then return end
    startLoop("puppet", function()
        local myRoot = getRoot(LP) local mRoot = getRoot(master)
        if myRoot and mRoot then
            local mirrorAngle = BOT_PHASE + math.pi
            myRoot.CFrame = mRoot.CFrame * CFrame.new(math.cos(mirrorAngle)*BOT_FOLLOW_DIST,0,math.sin(mirrorAngle)*BOT_FOLLOW_DIST)
        end
    end)
end
Commands["unpuppet"] = function() stopLoop("puppet") end

Commands["orbit"] = function(args)
    local target = findPlayer(args[1]) local radius = tonumber(args[2]) or 8
    if not target then return end
    local startT = tick()
    startLoopWithPhysRep("orbit", function() return getRoot(target) end, function()
        local angle = (tick()-startT)*1.5 + BOT_PHASE
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then
            myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius))
        end
    end)
end
Commands["unorbit"] = function() stopLoop("orbit") end

Commands["circle"] = function(args)
    local target = findPlayer(args[1]) local radius = tonumber(args[2]) or 6
    if not target then return end
    local startT = tick()
    startLoopWithPhysRep("circle", function() return getRoot(target) end, function()
        local angle = (tick()-startT)*5 + BOT_PHASE
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then
            myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius))
        end
    end)
end
Commands["uncircle"] = function() stopLoop("circle") end

Commands["encircle"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local startT = tick()
    startLoopWithPhysRep("encircle", function() return getRoot(target) end, function()
        local angle = (tick()-startT)*12 + BOT_PHASE
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then
            myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(math.cos(angle)*1.5,0,math.sin(angle)*1.5))
        end
    end)
end
Commands["unencircle"] = function() stopLoop("encircle") end

Commands["patrol"] = function(args)
    local p1 = findPlayer(args[1]) local p2 = findPlayer(args[2])
    if not p1 or not p2 then return end
    local goTo = 1
    startCheckerLoop("patrol", function()
        local root = getRoot(LP) local t1Root = getRoot(p1) local t2Root = getRoot(p2)
        if not root or not t1Root or not t2Root then return end
        local destRoot = goTo==1 and t1Root or t2Root
        if (root.Position-destRoot.Position).Magnitude < 5 then goTo = goTo==1 and 2 or 1 end
        local hum = getHumanoid(LP) if hum then hum:MoveTo(destRoot.Position) end
    end)
end
Commands["unpatrol"] = function() stopLoop("patrol") end

Commands["stare"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    startLoopWithPhysRep("stare", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = CFrame.lookAt(myRoot.Position, tRoot.Position) end
    end)
end
Commands["unstare"] = function() stopLoop("stare") end

Commands["face_all"] = function()
    startLoop("face_all", function()
        local myRoot = getRoot(LP) if not myRoot then return end
        local sum, count = Vector3.zero, 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then local r = getRoot(p) if r then sum=sum+r.Position count=count+1 end end
        end
        if count > 0 then myRoot.CFrame = CFrame.lookAt(myRoot.Position, sum/count) end
    end)
end
Commands["unface_all"] = function() stopLoop("face_all") end

Commands["spin"] = function(args)
    local speed = math.rad(tonumber(args[1]) or 10)
    startLoop("spin", function()
        local root = getRoot(LP) if root then root.CFrame = root.CFrame * CFrame.Angles(0,speed,0) end
    end)
end
Commands["unspin"] = function() stopLoop("spin") end

Commands["bounce"] = function()
    startLoop("bounce", function()
        local hum = getHumanoid(LP) if hum then hum.Jump = true end
    end)
end
Commands["unbounce"] = function() stopLoop("bounce") end

Commands["dance2"] = function()
    startLoop("dance2", function()
        local root = getRoot(LP)
        if root then
            root.CFrame = root.CFrame
                * CFrame.Angles(math.rad(math.random(-20,20)),math.rad(math.random(-20,20)),math.rad(math.random(-20,20)))
                * CFrame.new((math.random()-0.5)*0.5,(math.random()-0.5)*0.5,(math.random()-0.5)*0.5)
        end
    end)
end
Commands["undance2"] = function() stopLoop("dance2") end

Commands["freeze"]   = function() local hum=getHumanoid(LP) if hum then hum.WalkSpeed=0 hum.JumpHeight=0 end end
Commands["unfreeze"] = function() local hum=getHumanoid(LP) if hum then hum.WalkSpeed=16 hum.JumpHeight=7.2 end end

Commands["stop"] = function()
    for _, n in ipairs({"follow","stalk","ghost","orbit","circle","encircle","patrol",
        "stare","spin","bounce","haunt","block","rush","distract","creep","barrier",
        "puppet","surrogate","mirror","shield","intercept","above","below","face_all",
        "dance2","tornado","poltergeist","paranoia","relentless","juggle","volley",
        "chaos","lockdown","echo_all","tether","drag","steal","pingpong","camo",
        "counterfling","seizure"
    }) do stopLoop(n) end
    local hum = getHumanoid(LP) local root = getRoot(LP)
    if hum and root then hum:MoveTo(root.Position) end
end

Commands["ws"] = function(args)
    local hum = getHumanoid(LP)
    if hum then hum.WalkSpeed = math.clamp(tonumber(args[1]) or 16, 0, 10000) end
end

Commands["jh"] = function(args)
    local hum = getHumanoid(LP)
    if hum then hum.JumpHeight = math.clamp(tonumber(args[1]) or 7.2, 0, 1000) end
end

Commands["jump"] = function() local hum=getHumanoid(LP) if hum then hum.Jump=true end end
Commands["sit"]  = function() local hum=getHumanoid(LP) if hum then hum.Sit=true end end

Commands["noclip"] = function()
    local current = loopId["noclip"] or 0
    local running = current % 2 == 1
    if running then
        stopLoop("noclip")
        local char = LP.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=true end
            end
        end
    else
        loopId["noclip"] = current + 1
        local id = loopId["noclip"]
        task.spawn(function()
            while loopId["noclip"] == id do
                local char = LP.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
                    end
                end
                if math.random(-5,5)==0 then RunService.RenderStepped:Wait() end
            end
        end)
    end
end

Commands["nearest"] = function()
    local myRoot = getRoot(LP) if not myRoot then return end
    local closest, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local r = getRoot(p)
            if r then
                local d = (myRoot.Position-r.Position).Magnitude
                if d < closestDist then closestDist=d closest=p end
            end
        end
    end
    if closest then myRoot.CFrame = getRoot(closest).CFrame * botFollowOffset() end
end

Commands["farthest"] = function()
    local myRoot = getRoot(LP) if not myRoot then return end
    local pick, pickDist = nil, 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local r = getRoot(p)
            if r then
                local d = (myRoot.Position-r.Position).Magnitude
                if d > pickDist then pickDist=d pick=p end
            end
        end
    end
    if pick then myRoot.CFrame = getRoot(pick).CFrame * botFollowOffset() end
end

-- ─── POSITIONAL UTILITY ────────────────────────────────────────────────────
Commands["above"] = function(args)
    local target = findPlayer(args[1]) local height = tonumber(args[2]) or 10
    if not target then return end
    startLoopWithPhysRep("above", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then
            myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, height+(BOT_INDEX-1)*2, 0))
        end
    end)
end
Commands["unabove"] = function() stopLoop("above") end

Commands["below"] = function(args)
    local target = findPlayer(args[1]) local depth = tonumber(args[2]) or 3
    if not target then return end
    startLoopWithPhysRep("below", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then
            myRoot.CFrame = CFrame.new(tRoot.Position - Vector3.new(0, depth+(BOT_INDEX-1), 0))
        end
    end)
end
Commands["unbelow"] = function() stopLoop("below") end

Commands["surrogate"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    startLoopWithPhysRep("surrogate", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        local master = getMaster() local mRoot = master and getRoot(master)
        if myRoot and tRoot and mRoot then
            myRoot.CFrame = CFrame.new((tRoot.Position+mRoot.Position)/2)
        elseif myRoot and tRoot then
            myRoot.CFrame = tRoot.CFrame * botFollowOffset()
        end
    end)
end
Commands["unsurrogate"] = function() stopLoop("surrogate") end

Commands["mirror"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    startLoopWithPhysRep("mirror", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        local master = getMaster() local mRoot = master and getRoot(master)
        if myRoot and tRoot then
            if mRoot then
                local offset = tRoot.Position - mRoot.Position
                if offset.Magnitude > 0 then myRoot.CFrame = CFrame.new(tRoot.Position + offset.Unit*4) end
            else
                myRoot.CFrame = tRoot.CFrame * CFrame.new(-BOT_FOLLOW_DIST,0,0)
            end
        end
    end)
end
Commands["unmirror"] = function() stopLoop("mirror") end

Commands["distract"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local startT = tick()
    startLoopWithPhysRep("distract", function() return getRoot(target) end, function()
        local angle = (tick()-startT)*7 + BOT_PHASE
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then
            myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(math.cos(angle)*2,1.5,math.sin(angle)*2))
        end
    end)
end
Commands["undistract"] = function() stopLoop("distract") end

Commands["creep"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local hum = getHumanoid(LP) if hum then hum.WalkSpeed = 3 end
    startCheckerLoop("creep", function()
        local tRoot = getRoot(target) local hum2 = getHumanoid(LP)
        if tRoot and hum2 then hum2:MoveTo((tRoot.CFrame * CFrame.new(0,0,BOT_STALK_DIST)).Position) end
    end)
end
Commands["uncreep"] = function()
    stopLoop("creep")
    local hum = getHumanoid(LP) if hum then hum.WalkSpeed = 16 end
end

Commands["camo"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local offset = CFrame.new((BOT_INDEX-1)*0.1,0,(BOT_INDEX-1)*0.1)
    startLoopWithPhysRep("camo", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * offset end
    end)
end
Commands["uncamo"] = function() stopLoop("camo") end

Commands["poltergeist"] = function()
    local id = (loopId["poltergeist"] or 0) + 1
    loopId["poltergeist"] = id
    task.spawn(function()
        while loopId["poltergeist"] == id do
            local root = getRoot(LP)
            local players = Players:GetPlayers()
            local pick = players[math.random(#players)]
            local pRoot = pick and getRoot(pick)
            if root and pRoot then
                root.CFrame = pRoot.CFrame * CFrame.new(math.random(-15,15),0,math.random(-15,15))
            end
            task.wait(math.random(2,5))
        end
    end)
end
Commands["unpoltergeist"] = function() stopLoop("poltergeist") end

Commands["paranoia"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local id = (loopId["paranoia"] or 0) + 1
    loopId["paranoia"] = id
    task.spawn(function()
        while loopId["paranoia"] == id do
            local root = getRoot(LP) local tRoot = getRoot(target)
            if root and tRoot then
                root.CFrame = tRoot.CFrame * CFrame.new((math.random()-0.5)*2,0,math.random(1,3))
                task.wait(0.1 + math.random()*0.3)
                root.CFrame = tRoot.CFrame * CFrame.new(math.random(-30,30),math.random(0,20),math.random(-30,30))
            end
            task.wait(math.random(1,4))
        end
    end)
end
Commands["unparanoia"] = function() stopLoop("paranoia") end

-- ─── MINE ──────────────────────────────────────────────────────────────────
Commands["mine"] = function(args)
    local targetPlayer = args[1] and findPlayer(args[1]) or nil
    if not targetPlayer then
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(t,p) end end
        if #t > 0 then targetPlayer = t[math.random(#t)] end
    end
    if not targetPlayer then return end
    local pRoot = getRoot(targetPlayer) if not pRoot then return end
    local spotX = pRoot.Position.X + math.random(-15,15)
    local spotZ = pRoot.Position.Z + math.random(-15,15)
    local groundY = findGroundY(spotX, spotZ)
    if not groundY then fireChat("[mine] no ground found") return end
    local mineY   = groundY - 5
    local minePos = Vector3.new(spotX, mineY, spotZ)
    local noclipAlready = (loopId["noclip"] or 0) % 2 == 1
    if not noclipAlready then Commands["noclip"]() end
    local cds = {}
    local id  = (loopId["mine"] or 0) + 1
    loopId["mine"] = id
    task.spawn(function()
        while loopId["mine"] == id do
            local root = getRoot(LP)
            if root then
                root.CFrame                  = CFrame.new(minePos)
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                local now = tick()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP then
                        local pR = getRoot(p)
                        if pR then
                            local dx = math.abs(pR.Position.X - spotX)
                            local dz = math.abs(pR.Position.Z - spotZ)
                            local dy = pR.Position.Y - mineY
                            local last = cds[p.UserId] or 0
                            if dx < 5 and dz < 5 and dy > 0 and dy < 12 and (now-last) > 4 then
                                cds[p.UserId] = now
                                task.spawn(function()
                                    flingCore(p, flingVel(Vector3.new(math.random(-3,3),10,math.random(-3,3)), MAX_FLING), 5)
                                end)
                            end
                        end
                    end
                end
            end
            if math.random(-5,5) == 0 then RunService.RenderStepped:Wait() end
        end
        if not noclipAlready then
            if (loopId["noclip"] or 0) % 2 == 1 then Commands["noclip"]() end
        end
    end)
end
Commands["unmine"] = function() stopLoop("mine") end

-- ─── PHYSICS / UTILITY ─────────────────────────────────────────────────────
Commands["anchor"] = function()
    local root = getRoot(LP) if not root then return end
    local anchorCF = root.CFrame
    startLoop("anchor", function()
        local r = getRoot(LP)
        if r then
            r.CFrame = anchorCF
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end
Commands["unanchor"] = function() stopLoop("anchor") end

Commands["levitate"] = function(args)
    local height = tonumber(args[1]) or 20
    startLoop("levitate", function()
        local r = getRoot(LP)
        if r then
            r.CFrame = CFrame.new(r.Position.X, height, r.Position.Z)
            r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z)
        end
    end)
end
Commands["unlevitate"] = function() stopLoop("levitate") end

Commands["rocket"] = function(args)
    local power = math.min(tonumber(args[1]) or 200, MAX_FLING)
    startLoop("rocket", function()
        local r = getRoot(LP)
        if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, power, r.AssemblyLinearVelocity.Z) end
    end)
end
Commands["unrocket"] = function() stopLoop("rocket") end

Commands["chill"] = function()
    local hum = getHumanoid(LP) if hum then hum.Sit=true hum.WalkSpeed=0 end
    startCheckerLoop("godmode", function()
        local h = getHumanoid(LP)
        if h and h.Health < h.MaxHealth then h.Health=h.MaxHealth end
    end)
end
Commands["unchill"] = function()
    stopLoop("godmode")
    local hum = getHumanoid(LP)
    if hum then hum.Sit=false hum.WalkSpeed=16 end
end

Commands["checkpoint"]  = function()
    local root = getRoot(LP)
    if root then checkpointCF = root.CFrame fireChat("[checkpoint saved]") end
end
Commands["save_pos"]    = function(args)
    local name = args[1] or "default"
    local root = getRoot(LP)
    if root then savedPositions[name] = root.CFrame fireChat("[pos '"..name.."' saved]") end
end
Commands["load_pos"]    = function(args)
    local name = args[1] or "default"
    local root = getRoot(LP) if not root then return end
    if name == "checkpoint" and checkpointCF then root.CFrame = checkpointCF
    elseif savedPositions[name] then root.CFrame = savedPositions[name] end
end

Commands["autoreturn"] = function(args)
    if not checkpointCF then
        local root = getRoot(LP) if root then checkpointCF = root.CFrame end
    end
    local threshold = tonumber(args[1]) or 20
    startCheckerLoop("autoreturn", function()
        local root = getRoot(LP)
        if root and checkpointCF then
            if (root.Position-checkpointCF.Position).Magnitude > threshold then
                root.CFrame = checkpointCF
            end
        end
    end)
end
Commands["unautoreturn"] = function() stopLoop("autoreturn") end

-- ─── FLING ─────────────────────────────────────────────────────────────────
Commands["fling"]      = function(a) local t=findPlayer(a[1]) if not t then return end flingCore(t, flingVel(Vector3.new(math.random(-10,10),5,math.random(-10,10)))) end
Commands["skyfling"]   = function(a) local t=findPlayer(a[1]) if not t then return end flingCore(t, flingVel(Vector3.new(math.random(-3,3),10,math.random(-3,3)))) end
Commands["voidfling"]  = function(a) local t=findPlayer(a[1]) if not t then return end flingCore(t, flingVel(Vector3.new(math.random(-5,5),-8,math.random(-5,5)))) end
Commands["spinlaunch"] = function(a) local t=findPlayer(a[1]) if not t then return end spinlaunchCore(t) end
Commands["megafling"]  = function(a) local t=findPlayer(a[1]) if not t then return end flingCore(t, flingVel(Vector3.new(math.random(-8,8),6,math.random(-8,8)), MAX_FLING), 12) end

Commands["snipe"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local tRoot = getRoot(target) if not tRoot then return end
    flingCore(target, flingVel(tRoot.CFrame.LookVector + Vector3.new(0,2,0), MAX_FLING), 5)
end

Commands["karma"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local tRoot = getRoot(target) if not tRoot then return end
    local vel = tRoot.AssemblyLinearVelocity
    local dir = vel.Magnitude > 1 and vel or Vector3.new(math.random(-8,8),4,math.random(-8,8))
    flingCore(target, flingVel(dir, MAX_FLING), 6)
end

Commands["catapult"] = function(args)
    local target = findPlayer(args[1]) local dirName = (args[2] or "up"):lower()
    if not target then return end
    local dirs = {n=Vector3.new(0,1,-1),s=Vector3.new(0,1,1),e=Vector3.new(1,1,0),w=Vector3.new(-1,1,0),
        up=Vector3.new(0,1,0),down=Vector3.new(0,-1,0),ne=Vector3.new(1,1,-1),nw=Vector3.new(-1,1,-1),
        se=Vector3.new(1,1,1),sw=Vector3.new(-1,1,1)}
    flingCore(target, flingVel(dirs[dirName] or dirs["up"], MAX_FLING))
end

Commands["chain"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local tRoot = getRoot(target) if not tRoot then return end
    local nearest, nearDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p ~= target then
            local r = getRoot(p)
            if r then
                local d = (r.Position-tRoot.Position).Magnitude
                if d < nearDist then nearDist=d nearest=p end
            end
        end
    end
    if nearest then
        local nRoot = getRoot(nearest)
        if nRoot then flingCore(target, flingVel(nRoot.Position-tRoot.Position + Vector3.new(0,2,0))) end
    end
end

Commands["combo"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    task.spawn(function()
        spinlaunchCore(target) task.wait(0.8)
        flingCore(target, flingVel(Vector3.new(math.random(-3,3),10,math.random(-3,3))), 4) task.wait(2)
        flingCore(target, flingVel(Vector3.new(math.random(-3,3),-8,math.random(-3,3))), 4)
    end)
end

Commands["execute"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    task.spawn(function()
        for i=1,3 do spinlaunchCore(target) task.wait(0.55) end
        flingCore(target, flingVel(Vector3.new(0,-1,0), MAX_FLING), 5)
    end)
end

Commands["assassinate"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    task.spawn(function()
        local root = getRoot(LP) local tRoot = getRoot(target)
        if root and tRoot then
            root.CFrame = tRoot.CFrame * CFrame.new(0,0,2.5) task.wait(0.2)
            flingCore(target, flingVel(Vector3.new(math.random(-5,5),6,math.random(-5,5)), MAX_FLING), 9)
        end
    end)
end

Commands["pummel"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    task.spawn(function()
        for i=1,15 do
            local root = getRoot(LP) local tRoot = getRoot(target)
            if root and tRoot then
                root.CFrame = tRoot.CFrame * CFrame.new((math.random()-0.5)*2,0,(math.random()-0.5)*2)
                root.AssemblyLinearVelocity = flingVel(Vector3.new(math.random(-6,6),3,math.random(-6,6)), math.random(3000,8000))
            end
            task.wait(0.07)
        end
    end)
end

Commands["juggle"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local cd = 0
    startCheckerLoop("juggle", function()
        local now = tick()
        if (now-cd) > 2.5 then
            cd = now
            task.spawn(function() flingCore(target, flingVel(Vector3.new(math.random(-2,2),10,math.random(-2,2))), 4) end)
        end
    end)
end
Commands["unjuggle"] = function() stopLoop("juggle") end

Commands["relentless"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local cd = 0
    startCheckerLoop("relentless", function()
        local now = tick()
        if (now-cd) > 2 then
            cd = now
            task.spawn(function() flingCore(target, flingVel(Vector3.new(math.random(-8,8),5,math.random(-8,8))), 5) end)
        end
    end)
end
Commands["unrelentless"] = function() stopLoop("relentless") end

Commands["volley"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local cd, dir = 0, 1
    startCheckerLoop("volley", function()
        local now = tick()
        if (now-cd) > 2 then
            cd = now
            if dir==1 then
                task.spawn(function() flingCore(target, flingVel(Vector3.new(math.random(-2,2),10,math.random(-2,2))), 4) end)
            else
                task.spawn(function() flingCore(target, flingVel(Vector3.new(math.random(-3,3),-8,math.random(-3,3))), 4) end)
            end
            dir = -dir
        end
    end)
end
Commands["unvolley"] = function() stopLoop("volley") end

Commands["pingpong"] = function(args)
    local target = findPlayer(args[1]) local p2 = findPlayer(args[2])
    if not target or not p2 then return end
    local spawnPos = getRoot(target) and getRoot(target).Position
    local id = (loopId["pingpong"] or 0) + 1
    loopId["pingpong"] = id
    local direction = 1
    task.spawn(function()
        while loopId["pingpong"] == id do
            local tRoot = getRoot(target) local p2Root = getRoot(p2)
            if tRoot and p2Root and spawnPos then
                local destPos = direction==1 and p2Root.Position or spawnPos
                local dir = destPos - tRoot.Position
                task.spawn(function() flingCore(target, flingVel(dir + Vector3.new(0,3,0), 12000), 4) end)
                direction = -direction
            end
            task.wait(2.5)
        end
    end)
end
Commands["unpingpong"] = function() stopLoop("pingpong") end

Commands["counterfling"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local cd = 0
    startCheckerLoop("counterfling", function()
        local now = tick() local tRoot = getRoot(target)
        if tRoot and (now-cd) > 1.5 then
            if tRoot.AssemblyLinearVelocity.Magnitude > 50 then
                cd = now
                task.spawn(function()
                    flingCore(target, flingVel(Vector3.new(math.random(-8,8),6,math.random(-8,8)), MAX_FLING), 5)
                end)
            end
        end
    end)
end
Commands["uncounterfling"] = function() stopLoop("counterfling") end

Commands["orbital"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    flingCore(target, flingVel(Vector3.new(math.random(-2,2),10,math.random(-2,2)), MAX_FLING), 5)
    task.delay(2, function()
        flingCore(target, flingVel(Vector3.new(math.random(-3,3),-10,math.random(-3,3)), MAX_FLING), 5)
    end)
end

Commands["yeet"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local tRoot = getRoot(target) if not tRoot then return end
    local away = Vector3.new(tRoot.Position.X, 0, tRoot.Position.Z)
    flingCore(target, flingVel(away + Vector3.new(0,4,0)))
end

Commands["flingme"] = function()
    local root = getRoot(LP)
    if root then
        root.AssemblyLinearVelocity  = flingVel(Vector3.new(math.random(-6,6),8,math.random(-6,6)))
        root.AssemblyAngularVelocity = Vector3.new(math.random(-1200,1200),math.random(-1200,1200),math.random(-1200,1200))
    end
end

Commands["flingall"]  = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then flingCore(p, flingVel(Vector3.new(math.random(-8,8),5,math.random(-8,8)))) task.wait(0.07) end
        end
    end)
end
Commands["massfling"] = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then spinlaunchCore(p) task.wait(0.5) end
        end
    end)
end
Commands["flingbomb"] = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local root = getRoot(LP) local tRoot = getRoot(p)
                if root and tRoot then
                    root.CFrame = tRoot.CFrame
                    root.AssemblyLinearVelocity  = flingVel(Vector3.new(math.random(-8,8),4,math.random(-8,8)))
                    root.AssemblyAngularVelocity = Vector3.new(math.random(-1000,1000),math.random(-1000,1000),math.random(-1000,1000))
                    task.wait(0.12)
                end
            end
        end
    end)
end
Commands["nuke"]     = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then flingCore(p, flingVel(Vector3.new(math.random(-3,3),-10,math.random(-3,3)), MAX_FLING), 5) task.wait(0.07) end
        end
    end)
end
Commands["massacre"] = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then flingCore(p, flingVel(Vector3.new(math.random(-8,8),6,math.random(-8,8)), MAX_FLING), 10) task.wait(0.08) end
        end
    end)
end

-- ─── PROTECT / DEFEND ──────────────────────────────────────────────────────
Commands["protect"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local radius = tonumber(args[2]) or 15
    local cds = {}
    startCheckerLoop("protect", function()
        local tRoot = getRoot(target) if not tRoot then return end
        local now = tick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p ~= target and not isMaster(p) then
                local pRoot = getRoot(p)
                if pRoot then
                    local dist = (pRoot.Position-tRoot.Position).Magnitude
                    local last = cds[p.UserId] or 0
                    if dist < radius and (now-last) > 2.5 then
                        cds[p.UserId] = now
                        local dir = (pRoot.Position-tRoot.Position)
                        dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(1,0,0)
                        task.spawn(function() flingCore(p, flingVel(dir + Vector3.new(0,0.5,0)), 5) end)
                    end
                end
            end
        end
    end)
end
Commands["unprotect"] = function() stopLoop("protect") end

Commands["guardian"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local radius = tonumber(args[2]) or 12
    local cds = {} local offset = botFollowOffset()
    startLoop("guardian", function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * offset end
    end)
    startCheckerLoop("guardian_protect", function()
        if (loopId["guardian"] or 0) == 0 then stopLoop("guardian_protect") return end
        local tRoot = getRoot(target) if not tRoot then return end
        local now = tick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p ~= target and not isMaster(p) then
                local pRoot = getRoot(p)
                if pRoot then
                    local dist = (pRoot.Position-tRoot.Position).Magnitude
                    local last = cds[p.UserId] or 0
                    if dist < radius and (now-last) > 2.5 then
                        cds[p.UserId] = now
                        local dir = (pRoot.Position-tRoot.Position)
                        dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(1,0,0)
                        task.spawn(function() flingCore(p, flingVel(dir + Vector3.new(0,0.5,0)), 5) end)
                    end
                end
            end
        end
    end)
end
Commands["unguardian"] = function() stopLoop("guardian") stopLoop("guardian_protect") end

Commands["shield"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    startLoopWithPhysRep("shield", function() return getRoot(target) end, function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if not myRoot or not tRoot then return end
        local threat, threatDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p ~= target then
                local pRoot = getRoot(p)
                if pRoot then
                    local d = (pRoot.Position-tRoot.Position).Magnitude
                    if d < threatDist then threatDist=d threat=p end
                end
            end
        end
        if threat then
            local tR = getRoot(threat)
            if tR then myRoot.CFrame = CFrame.new((tRoot.Position+tR.Position)/2) end
        else
            myRoot.CFrame = tRoot.CFrame * CFrame.new(0,0,-3)
        end
    end)
end
Commands["unshield"] = function() stopLoop("shield") end

Commands["intercept"] = function(args)
    local attacker = findPlayer(args[1]) local victim = findPlayer(args[2])
    if not attacker or not victim then return end
    startLoopWithPhysRep("intercept", function() return getRoot(victim) end, function()
        local myRoot = getRoot(LP) local aRoot = getRoot(attacker) local vRoot = getRoot(victim)
        if myRoot and aRoot and vRoot then myRoot.CFrame = CFrame.new((aRoot.Position+vRoot.Position)/2) end
    end)
end
Commands["unintercept"] = function() stopLoop("intercept") end

Commands["no_move"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local tRoot = getRoot(target) if not tRoot then return end
    local lockPos = tRoot.Position local cd = 0
    startCheckerLoop("no_move", function()
        local now = tick() local tR = getRoot(target)
        if tR and (now-cd) > 1.5 then
            if (tR.Position-lockPos).Magnitude > 8 then
                cd = now
                local dir = lockPos - tR.Position
                task.spawn(function() flingCore(target, flingVel(dir, 10000), 4) end)
            end
        end
    end)
end
Commands["unno_move"] = function() stopLoop("no_move") end

Commands["mineguard"] = function(args)
    local radius = tonumber(args[1]) or 10 local cds = {}
    startCheckerLoop("mineguard", function()
        local myRoot = getRoot(LP) if not myRoot then return end
        local now = tick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and not isMaster(p) then
                local pRoot = getRoot(p)
                if pRoot then
                    local dist = (pRoot.Position-myRoot.Position).Magnitude
                    local last = cds[p.UserId] or 0
                    if dist < radius and (now-last) > 2.5 then
                        cds[p.UserId] = now
                        local dir = (pRoot.Position-myRoot.Position)
                        dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(1,0,0)
                        task.spawn(function() flingCore(p, flingVel(dir + Vector3.new(0,0.5,0)), 5) end)
                    end
                end
            end
        end
    end)
end
Commands["unmineguard"] = function() stopLoop("mineguard") end

Commands["lockdown"] = function(args)
    local radius = tonumber(args[1]) or 12 local cds = {}
    startCheckerLoop("lockdown", function()
        local now = tick()
        for _, masterName in ipairs(MASTER_NAMES) do
            local master = findPlayer(masterName) local mRoot = master and getRoot(master)
            if mRoot then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and not isMaster(p) then
                        local pRoot = getRoot(p)
                        if pRoot then
                            local dist = (pRoot.Position-mRoot.Position).Magnitude
                            local cdKey = masterName..tostring(p.UserId) local last = cds[cdKey] or 0
                            if dist < radius and (now-last) > 2.5 then
                                cds[cdKey] = now
                                local dir = (pRoot.Position-mRoot.Position)
                                dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(1,0,0)
                                task.spawn(function() flingCore(p, flingVel(dir + Vector3.new(0,0.5,0)), 5) end)
                            end
                        end
                    end
                end
            end
        end
    end)
end
Commands["unlockdown"] = function() stopLoop("lockdown") end

Commands["tether"] = function(args)
    local target = findPlayer(args[1]) local maxDist = tonumber(args[2]) or 20
    if not target then return end
    local cd = 0
    startCheckerLoop("tether", function()
        local now = tick() local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot and (now-cd) > 1.5 then
            if (myRoot.Position-tRoot.Position).Magnitude > maxDist then
                cd = now
                local dir = myRoot.Position - tRoot.Position
                task.spawn(function() flingCore(target, flingVel(dir + Vector3.new(0,2,0), 10000), 4) end)
            end
        end
    end)
end
Commands["untether"] = function() stopLoop("tether") end

Commands["barrier"] = function(args)
    local p1 = findPlayer(args[1]) local p2 = findPlayer(args[2])
    if not p1 or not p2 then return end
    startLoop("barrier", function()
        local myRoot = getRoot(LP) local r1 = getRoot(p1) local r2 = getRoot(p2)
        if myRoot and r1 and r2 then
            local mid = (r1.Position+r2.Position)/2
            local along = (r2.Position-r1.Position)
            local shift = along.Magnitude > 0 and (along.Unit * (BOT_INDEX-1) * 1.5) or Vector3.zero
            myRoot.CFrame = CFrame.new(mid + shift)
        end
    end)
end
Commands["unbarrier"] = function() stopLoop("barrier") end

-- ─── CHAOS / OFFENSIVE ─────────────────────────────────────────────────────
Commands["blackhole"] = function(args)
    local radius = tonumber(args[1]) or 20 local cds = {}
    startCheckerLoop("blackhole", function()
        local myRoot = getRoot(LP) if not myRoot then return end
        local now = tick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local pRoot = getRoot(p)
                if pRoot then
                    local dist = (pRoot.Position-myRoot.Position).Magnitude
                    local last = cds[p.UserId] or 0
                    if dist < radius and dist > 3 and (now-last) > 1.5 then
                        cds[p.UserId] = now
                        local dir = myRoot.Position - pRoot.Position
                        task.spawn(function() flingCore(p, flingVel(dir, 8000), 4) end)
                    end
                end
            end
        end
    end)
end
Commands["unblackhole"] = function() stopLoop("blackhole") end

Commands["shockwave"] = function(args)
    local radius = tonumber(args[1]) or 20 local myRoot = getRoot(LP) if not myRoot then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local pRoot = getRoot(p)
            if pRoot and (pRoot.Position-myRoot.Position).Magnitude < radius then
                local dir = pRoot.Position - myRoot.Position
                task.spawn(function() flingCore(p, flingVel(dir + Vector3.new(0,2,0)), 4) end)
            end
        end
    end
end

Commands["explosion"] = function(args)
    local radius = tonumber(args[1]) or 25 local myRoot = getRoot(LP) if not myRoot then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local pRoot = getRoot(p)
            if pRoot and (pRoot.Position-myRoot.Position).Magnitude < radius then
                local dir = pRoot.Position - myRoot.Position
                task.spawn(function() flingCore(p, flingVel(dir + Vector3.new(0,3,0), MAX_FLING), 6) end)
            end
        end
    end
end

Commands["tornado"] = function(args)
    local radius = tonumber(args[1]) or 15 local myRoot = getRoot(LP) if not myRoot then return end
    local targets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local pRoot = getRoot(p)
            if pRoot and (pRoot.Position-myRoot.Position).Magnitude < radius then table.insert(targets, p) end
        end
    end
    if #targets == 0 then return end
    local startT = tick()
    startLoop("tornado", function()
        local t = (tick()-startT)*3
        local ct = targets[(math.floor(t) % #targets) + 1]
        local tRoot = getRoot(ct) local root = getRoot(LP)
        if root and tRoot then
            local angle = t*8 + BOT_PHASE
            local offset = Vector3.new(math.cos(angle)*3,0,math.sin(angle)*3)
            root.CFrame = CFrame.new(tRoot.Position + offset)
            if math.random(1,25) == 1 then
                task.spawn(function() flingCore(ct, flingVel(offset + Vector3.new(0,3,0), 12000), 3) end)
            end
        end
    end)
end
Commands["untornado"] = function() stopLoop("tornado") end

Commands["mayhem"] = function()
    task.spawn(function()
        Commands["flingall"]() task.wait(0.4)
        Commands["shockwave"]({"30"}) task.wait(0.4)
        Commands["seizure"]({}) task.delay(5, function() stopLoop("seizure") end)
        queueChat("MAYHEM HAS BEGUN") queueChat("GOD HELP US ALL")
    end)
end

Commands["overload"] = function()
    task.spawn(function()
        Commands["flingbomb"]() task.wait(1)
        Commands["flingall"]() task.wait(0.5)
        Commands["explosion"]({"40"})
    end)
end

Commands["chaos"] = function()
    local id = (loopId["chaos"] or 0) + 1 loopId["chaos"] = id
    task.spawn(function()
        while loopId["chaos"] == id do
            local targets = {}
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(targets,p) end end
            if #targets > 0 then
                local t = targets[math.random(#targets)]
                local actions = {
                    function() flingCore(t, flingVel(Vector3.new(math.random(-8,8),6,math.random(-8,8)))) end,
                    function() spinlaunchCore(t) end,
                    function() flingCore(t, flingVel(Vector3.new(0,1,0), MAX_FLING), 5) end,
                    function() Commands["shockwave"]({"15"}) end,
                    function() queueChat(t.Name..", "..roasts[math.random(#roasts)]) end,
                    function() flingCore(t, flingVel(Vector3.new(math.random(-8,8),-6,math.random(-8,8)), MAX_FLING)) end,
                }
                actions[math.random(#actions)]()
            end
            task.wait(math.random(3,8))
        end
    end)
end
Commands["unchaos"] = function() stopLoop("chaos") end

Commands["bamboozle"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local offset = botFollowOffset()
    startLoop("follow", function()
        local myRoot = getRoot(LP) local tRoot = getRoot(target)
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * offset end
    end)
    task.delay(math.random(3,8), function()
        stopLoop("follow")
        flingCore(target, flingVel(Vector3.new(math.random(-8,8),6,math.random(-8,8)), MAX_FLING), 7)
        queueChat("bamboozled.")
    end)
end

Commands["duel"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    queueChat(target.Name..", I challenge you to a duel. Prepare yourself.")
    task.delay(1.5, function()
        Commands["orbit"]({target.Name, "5"})
        task.delay(5, function() stopLoop("orbit") spinlaunchCore(target) end)
    end)
end

Commands["tag"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    queueChat(target.Name.." is IT!! everyone run!!!")
    Commands["ghost"]({target.Name})
    task.delay(3, function() stopLoop("ghost") spinlaunchCore(target) end)
end

Commands["taunt"] = function(args)
    local target = findPlayer(args[1]) local name = target and target.Name or ""
    fireChat((name ~= "" and (name..", ") or "")..taunt_lines[math.random(#taunt_lines)])
end

Commands["grief"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    task.spawn(function()
        for i=1,25 do
            local root = getRoot(LP) local tRoot = getRoot(target)
            if root and tRoot then
                root.CFrame = tRoot.CFrame
                root.AssemblyLinearVelocity = flingVel(Vector3.new(math.random(-5,5),math.random(2,6),math.random(-5,5)))
            end
            task.wait(0.04)
        end
    end)
end

Commands["grief_all"] = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then task.spawn(function() Commands["grief"]({p.Name}) end) task.wait(0.1) end
        end
    end)
end

Commands["rush"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local hum = getHumanoid(LP) if hum then hum.WalkSpeed = 300 end
    startCheckerLoop("rush", function()
        local root2 = getRoot(LP) local tRoot = getRoot(target)
        if not root2 or not tRoot then stopLoop("rush") return end
        local dist = (root2.Position-tRoot.Position).Magnitude
        if dist < 4 then
            stopLoop("rush")
            root2.AssemblyLinearVelocity = flingVel(tRoot.Position-root2.Position + Vector3.new(0,2,0), 8000)
        else
            root2.CFrame = CFrame.lookAt(root2.Position, tRoot.Position)
            local h2 = getHumanoid(LP) if h2 then h2:MoveTo(tRoot.Position) end
        end
    end)
end
Commands["unrush"] = function()
    stopLoop("rush")
    local hum = getHumanoid(LP) if hum then hum.WalkSpeed = 16 end
end

Commands["murder"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    task.spawn(function() for i=1,5 do spinlaunchCore(target) task.wait(0.55) end end)
end

Commands["obliterate"] = function(args)
    local target = findPlayer(args[1])
    local hum = getHumanoid(LP) if hum then hum.Health = 0 end
    if target then
        LP.CharacterAdded:Wait() task.wait(0.6)
        local root = getRoot(LP) local tRoot = getRoot(target)
        if root and tRoot then root.CFrame = tRoot.CFrame * botFollowOffset() end
    end
end

Commands["scatter"] = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local root = getRoot(LP) local tRoot = getRoot(p)
                if root and tRoot then
                    root.CFrame = tRoot.CFrame
                    root.AssemblyLinearVelocity = flingVel(Vector3.new(math.random(-8,8),3,math.random(-8,8)))
                    task.wait(0.1)
                end
            end
        end
    end)
end

Commands["bringall"] = function()
    local master = getMaster() if not master then return end
    local mRoot = getRoot(master) if not mRoot then return end
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p ~= master then
                local root = getRoot(LP) local tRoot = getRoot(p)
                if root and tRoot then
                    root.CFrame = tRoot.CFrame
                    local dir = mRoot.Position - tRoot.Position
                    root.AssemblyLinearVelocity = flingVel(dir + Vector3.new(0,3,0), 6000)
                    task.wait(0.15)
                end
            end
        end
    end)
end

Commands["tpall"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local tRoot = getRoot(target) if not tRoot then return end
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local root = getRoot(LP) local pRoot = getRoot(p)
                if root and pRoot then
                    root.CFrame = pRoot.CFrame
                    root.AssemblyLinearVelocity = flingVel((tRoot.Position-pRoot.Position) + Vector3.new(0,2,0), 10000)
                    task.wait(0.12)
                end
            end
        end
    end)
end

Commands["drag"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local cd = 0
    startCheckerLoop("drag", function()
        local now = tick() local master = getMaster()
        local tRoot = getRoot(target) local mRoot = master and getRoot(master)
        if tRoot and mRoot and (now-cd) > 1.8 then
            if (mRoot.Position-tRoot.Position).Magnitude > 8 then
                cd = now
                local dir = mRoot.Position - tRoot.Position
                task.spawn(function() flingCore(target, flingVel(dir + Vector3.new(0,3,0)), 4) end)
            end
        end
    end)
end
Commands["undrag"] = function() stopLoop("drag") end

Commands["steal"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local cd = 0
    startCheckerLoop("steal", function()
        local now = tick() local master = getMaster()
        local tRoot = getRoot(target) local mRoot = master and getRoot(master)
        if tRoot and mRoot and (now-cd) > 0.8 then
            if (tRoot.Position-mRoot.Position).Magnitude > 5 then
                cd = now
                local dir = mRoot.Position - tRoot.Position
                task.spawn(function()
                    local root = getRoot(LP)
                    if root then
                        root.CFrame = tRoot.CFrame
                        root.AssemblyLinearVelocity = flingVel(dir + Vector3.new(0,2,0), 5000)
                    end
                end)
            end
        end
    end)
end
Commands["unsteal"] = function() stopLoop("steal") end

Commands["seizure"] = function(args)
    local target = findPlayer(args[1])
    startLoop("seizure", function()
        local root = getRoot(LP) if not root then return end
        if target then
            local tRoot = getRoot(target)
            if tRoot then root.CFrame = tRoot.CFrame * CFrame.new(math.random(-3,3),math.random(0,2),math.random(-3,3)) end
        else
            root.CFrame = root.CFrame * CFrame.new(math.random(-2,2),math.random(0,1),math.random(-2,2))
        end
    end)
end
Commands["unseizure"] = function() stopLoop("seizure") end

Commands["haunt"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local id = (loopId["haunt"] or 0) + 1 loopId["haunt"] = id
    task.spawn(function()
        while loopId["haunt"] == id do
            local root = getRoot(LP) local tRoot = getRoot(target)
            if root and tRoot then
                root.CFrame = tRoot.CFrame * CFrame.new(0,0,2) task.wait(0.7)
                root.CFrame = tRoot.CFrame * CFrame.new(math.random(-25,25),0,math.random(-25,25)) task.wait(1.3)
            else
                task.wait(1)
            end
        end
    end)
end
Commands["unhaunt"] = function() stopLoop("haunt") end

Commands["bump"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local frame = 0
    startLoop("block", function()
        frame = frame + 1 if frame % 3 ~= 0 then return end
        local root = getRoot(LP) local tRoot = getRoot(target)
        if root and tRoot then
            root.CFrame = tRoot.CFrame * CFrame.new(0,0,1)
            root.AssemblyLinearVelocity = Vector3.new(math.random(-80,80),30,math.random(-80,80))
        end
    end)
end
Commands["unbump"] = function() stopLoop("block") end

Commands["block"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    startLoopWithPhysRep("block", function() return getRoot(target) end, function()
        local root = getRoot(LP) local tRoot = getRoot(target)
        if root and tRoot then root.CFrame = CFrame.new(tRoot.Position + Vector3.new(0,3.5,0)) end
    end)
end
Commands["unblock"] = function() stopLoop("block") end

Commands["ragdoll"] = function(args)
    local n = tonumber(args[1]) or 3
    task.spawn(function()
        for i=1,n do
            local hum = getHumanoid(LP) if hum then hum.Health=0 end
            LP.CharacterAdded:Wait() task.wait(0.3)
        end
    end)
end

Commands["troll"] = function()
    local trolls = {
        function() Commands["flingme"]() end,
        function() Commands["seizure"]({}) task.delay(3, function() stopLoop("seizure") end) end,
        function() Commands["bounce"]() task.delay(3, function() stopLoop("bounce") end) end,
        function() Commands["spin"]({"25"}) task.delay(3, function() stopLoop("spin") end) end,
        function() local hum=getHumanoid(LP) if hum then hum.WalkSpeed=500 end task.delay(3, function() local h=getHumanoid(LP) if h then h.WalkSpeed=16 end end) end,
        function() Commands["rocket"]({"300"}) task.delay(4, function() stopLoop("rocket") end) end,
        function() Commands["dance2"]() task.delay(4, function() stopLoop("dance2") end) end,
    }
    trolls[math.random(#trolls)]()
end

-- ─── CHAT / ANNOY ──────────────────────────────────────────────────────────
Commands["say"]   = function(a) if #a > 0 then fireChat(table.concat(a," ")) end end
Commands["chat"]  = Commands["say"]
Commands["shout"] = function(a) if #a > 0 then fireChat(table.concat(a," "):upper()) end end

Commands["spam"] = function(args)
    local n = math.min(tonumber(args[1]) or 5, 20) local msg = table.concat(args," ",2)
    if msg=="" then msg="." end
    for i=1,n do queueChat(msg) end
end

Commands["announce"] = function(args)
    local msg = table.concat(args," ") if msg=="" then return end
    for i=1,3 do queueChat(">>> "..msg.." <<<") end
end

Commands["mock"] = function(args)
    local msg = table.concat(args," ") local out = ""
    for i=1,#msg do local c=msg:sub(i,i) out=out..(i%2==0 and c:upper() or c:lower()) end
    fireChat(out)
end

Commands["mockery"] = function(args)
    local target = findPlayer(args[1])
    stopLoop("mockery")
    local id = (loopId["mockery"] or 0) + 1 loopId["mockery"] = id
    local conn
    conn = target.Chatted:Connect(function(msg)
        if loopId["mockery"] ~= id then conn:Disconnect() conn = nil return end
        local out = ""
        for i=1,#msg do local c=msg:sub(i,i) out=out..(i%2==0 and c:upper() or c:lower()) end
        task.wait(0.3) queueChat(out)
    end)
end

Commands["uwu"] = function(args)
    local msg = table.concat(args," ")
    msg = msg:gsub("[rl]","w"):gsub("[RL]","W"):gsub("n([aeiou])","ny%1"):gsub("N([aeiou])","Ny%1")
    fireChat(msg.." uwu OwO")
end

Commands["rickroll"] = function()
    fireChat("Never gonna give you up, never gonna let you down, never gonna run around and desert you!")
end

Commands["copypasta"] = function(args)
    local key = args[1] and args[1]:lower() or nil
    local text = copypastas[key] or copypastas[math.random(1,#copypastas)]
    fireChat(bypassFilter(text))
end

Commands["listpastas"] = function()
    local keys = {}
    for k in pairs(copypastas) do table.insert(keys,k) end
    table.sort(keys)
    local page, pages = "", {}
    for _, k in ipairs(keys) do
        local add = #page>0 and (", "..k) or k
        if #page+#add > 185 then table.insert(pages,page) page=k
        else page=page..add end
    end
    if #page>0 then table.insert(pages,page) end
    task.spawn(function()
        for i,p in ipairs(pages) do queueChat(p) end
    end)
end

Commands["countdown"] = function(args)
    local n = math.min(tonumber(args[1]) or 5, 10)
    for i=n,1,-1 do queueChat(tostring(i).."...") end
    queueChat("GO!")
end

Commands["fake"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local msg = table.concat(args," ",2) if msg=="" then return end
    fakeLine(target.Name, msg)
end

Commands["warn"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local reason = table.concat(args," ",2)
    reason = reason~="" and reason or "being themselves"
    fakeLine("[SYSTEM]", target.Name.." has been warned. Reason: "..reason)
end

Commands["ban_msg"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local reason = table.concat(args," ",2)
    reason = reason~="" and reason or "violating community guidelines"
    fakeLine("[MODERATION]", target.Name.." has been banned. Reason: "..reason)
end

Commands["kick_msg"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local reason = table.concat(args," ",2)
    reason = reason~="" and reason or "suspicious behavior"
    fakeLine("[MODERATION]", target.Name.." has been kicked. Reason: "..reason)
end

Commands["reward"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local reason = table.concat(args," ",2)
    reason = reason~="" and reason or "being an outstanding community member"
    fakeLine("[REWARD]", target.Name.." has earned 1000 Robux! Reason: "..reason)
end

Commands["broadcast"] = function(args)
    local msg = table.concat(args," ") if msg=="" then return end
    fakeLine("[SERVER BROADCAST]", msg, "📢")
end

Commands["system_msg"] = function(args)
    local msg = table.concat(args," ") if msg=="" then return end
    fakeLine("[SYSTEM]", msg)
end

Commands["admin_msg"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local msg = table.concat(args," ",2) if msg=="" then return end
    fakeLine("[ADMIN → "..target.Name.."]", msg)
end

Commands["impersonate"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local msg = table.concat(args," ",2) if msg=="" then return end
    fakeLine(target.DisplayName.." ("..target.Name..")", msg)
end

Commands["roast"]      = function(args) local t=findPlayer(args[1]) local name=t and t.Name or "everyone" fireChat(name..", "..roasts[math.random(#roasts)]) end
Commands["insult"]     = Commands["roast"]
Commands["compliment"] = function(args) local t=findPlayer(args[1]) local name=t and t.Name or "everyone" fireChat(name..compliments[math.random(#compliments)]) end

Commands["haiku"] = function(args)
    local target = findPlayer(args[1]) local name = target and target.Name or "this server"
    local t = {
        string.format("%s walks alone / no one invited them here / server mourns the loss",name),
        string.format("there goes %s / tripping on flat terrain / classic moment there",name),
        string.format("%s has logged on / the entire server sighs / birds fly south early",name),
        string.format("why is %s / still here after all this time / god has abandoned us",name),
        string.format("legend of %s / arrived too late, flung too hard / respawning again",name),
    }
    fireChat(t[math.random(#t)])
end

Commands["rap"] = function(args)
    local target = findPlayer(args[1]) local name = target and target.Name or "everyone"
    local lines = {
        "yo it's "..name.." in the game /",
        "came in with a terrible username, what a shame /",
        "default spawn, no aim, still living in the tutorial zone /",
        "even the NPCs cringe when they see you on their phone.",
    }
    for _, l in ipairs(lines) do queueChat(l) end
end

Commands["trial"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local crime = table.concat(args," ",2)
    if crime=="" then crime = crimes[math.random(#crimes)] end
    queueChat("⚖ TRIAL BEGINS ⚖")
    queueChat("The accused: "..target.Name)
    queueChat("Crime: "..crime)
    queueChat("Defend yourself, "..target.Name..".")
    task.delay(10, function()
        queueChat("Times up! You are: "..(math.random(1,2) == 1 and "GUILTY!" or "NOT GUILTY!"))
    end)
end

Commands["sentence"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local punishment = table.concat(args," ",2)
    if punishment=="" then punishment = punishments[math.random(#punishments)] end
    fireChat(target.Name.." has been sentenced to: "..punishment)
    task.delay(1, function()
        flingCore(target, flingVel(Vector3.new(math.random(-6,6),8,math.random(-6,6))), 5)
    end)
end

Commands["expose"]     = function(args) local t=findPlayer(args[1]) local name=t and t.Name or "this person" fireChat("🚨 EXPOSE 🚨 "..name..exposes[math.random(#exposes)]) end
Commands["hype"]       = function(args) local t=findPlayer(args[1]) local name=t and t.Name or "everyone" fireChat(hypes[math.random(#hypes)]:format(name)) end
Commands["news"]       = function() fireChat("📰 "..news_headlines[math.random(#news_headlines)]) end
Commands["greet"]      = function(args) local t=findPlayer(args[1]) local name=t and t.Name or "everyone" fireChat(greetings[math.random(#greetings)]:format(name)) end

Commands["question"] = function(args)
    local target = findPlayer(args[1]) local name = target and target.Name or "you"
    local qs = {
        "hey, "..name.." are you even real?",name..", what is your life?",
        "does, "..name.."'s mom know they're doing this?",name..", do you need help?",
        "why is, "..name.." like this? genuinely asking.","someone explain, "..name.." to me.",
        name.." are you okay? be honest.",
    }
    for _, q in ipairs(qs) do queueChat(q) end
end

Commands["agree"] = function(args)
    local name = findPlayer(args[1]) and findPlayer(args[1]).Name or "that"
    for i=1,4 do queueChat("yes "..name.." yes yes yes yes YES") end
end

Commands["disagree"] = function(args)
    local name = findPlayer(args[1]) and findPlayer(args[1]).Name or "that"
    for i=1,4 do queueChat("no. no. NO. absolutely not "..name..". NO.") end
end

Commands["poll"] = function(args)
    local question = table.concat(args," ") if question=="" then return end
    queueChat("📊 POLL: "..question) queueChat("React with yes or no to vote.")
    local votesyes = 0
    local votesno = 0
    local timesup = false
    for _,p in pairs(Players:GetPlayers()) do
        local chatcon = nil
        chatcon = p.Chatted:Connect(function(msg)
            msg = msg:lower()
            if timesup == true then
                chatcon:Disconnect()
                chatcon = nil
                return
            end
            if msg == "yes" then
                votesyes += 1
                chatcon:Disconnect()
                chatcon = nil
            elseif msg == "no" then
                votesno += 1
                chatcon:Disconnect()
                chatcon = nil
            end
        end)
    end
    task.delay(10, function()
        timesup = true
        queueChat("Poll times up!")
        queueChat("Results: Yes = "..tostring(votesyes)..", No = "..tostring(votesno))
        queueChat("The winner is: "..(votesyes > votesno and "Yes" or "No"))
    end)
end

Commands["vote"] = function(args)
    local full = table.concat(args," ") local parts = full:split(",")
    local opt1 = parts[1] or "yes" local opt2 = parts[2] or "no"
    queueChat("🗳 VOTE: "..opt1.." vs "..opt2.." | Vote by saying: one or two")
    local votesone = 0
    local votestwo = 0
    local timesup = false
    for _,p in pairs(Players:GetPlayers()) do
        local chatcon = nil
        chatcon = p.Chatted:Connect(function(msg)
            msg = msg:lower()
            if timesup == true then
                chatcon:Disconnect()
                chatcon = nil
                return
            end
            if msg == "one" then
                votesone += 1
                chatcon:Disconnect()
                chatcon = nil
            elseif msg == "two" then
                votestwo += 1
                chatcon:Disconnect()
                chatcon = nil
            end
        end)
    end
    task.delay(10, function()
        timesup = true
        local v1,v2 = votesone,votestwo
        queueChat("Voting times up!")
        queueChat("Results: "..opt1..": "..v1.." | "..opt2..": "..v2.." | winner: "..(v1>v2 and opt1 or opt2))
    end)
end

Commands["mimic"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    stopLoop("mimic")
    local id = (loopId["mimic"] or 0) + 1 loopId["mimic"] = id
    local conn
    conn = target.Chatted:Connect(function(msg)
        if loopId["mimic"] ~= id then conn:Disconnect() conn = nil return end
        task.wait(0.3) queueChat(msg)
    end)
end
Commands["unmimic"] = function() stopLoop("mimic") end

Commands["echo"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    stopLoop("echo")
    local id = (loopId["echo"] or 0) + 1 loopId["echo"] = id
    local conn
    conn = target.Chatted:Connect(function(msg)
        if loopId["echo"] ~= id then conn:Disconnect() conn = nil return end
        task.wait(0.2) fakeLine(target.Name, msg, "echo:")
    end)
end
Commands["unecho"] = function() stopLoop("echo") end

Commands["echo_all"] = function()
    stopLoop("echo_all")
    local id = (loopId["echo_all"] or 0) + 1 loopId["echo_all"] = id
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local conn
            conn = p.Chatted:Connect(function(msg)
                if loopId["echo_all"] ~= id then conn:Disconnect() conn = nil return end
                task.wait(0.3) fakeLine(p.Name, msg, ">>")
            end)
        end
    end
end
Commands["unecho_all"] = function() stopLoop("echo_all") end

Commands["silence"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    stopLoop("silence")
    local id = (loopId["silence"] or 0) + 1 loopId["silence"] = id
    local conn
    conn = target.Chatted:Connect(function(msg)
        if loopId["silence"] ~= id then conn:Disconnect() conn = nil return end
        task.wait(0.1) fakeLine(target.Name, "[SILENCED]", "⛔")
    end)
end
Commands["unsilence"] = function() stopLoop("silence") end

-- stopmimic remains as a "kill all chat monitoring" shortcut
Commands["stopmimic"] = function()
    stopLoop("mimic") stopLoop("echo") stopLoop("echo_all") stopLoop("silence")
end

-- ─── INFO / SPY ────────────────────────────────────────────────────────────
Commands["pos"]       = function() local root=getRoot(LP) if root then local p=root.Position fireChat(string.format("pos: %.1f, %.1f, %.1f",p.X,p.Y,p.Z)) end end
Commands["coords"]    = Commands["pos"]
Commands["count"]     = function() fireChat("players: "..#Players:GetPlayers()) end
Commands["players"]   = function() local names={} for _,p in ipairs(Players:GetPlayers()) do table.insert(names,p.Name) end fireChat(table.concat(names,", ")) end

Commands["find"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local root = getRoot(target)
    if root then local p=root.Position fireChat(string.format("%s: %.1f, %.1f, %.1f",target.Name,p.X,p.Y,p.Z)) end
end

Commands["dist"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local root = getRoot(LP) local tRoot = getRoot(target)
    if root and tRoot then
        fireChat(string.format("dist to %s: %.1f studs",target.Name,(root.Position-tRoot.Position).Magnitude))
    end
end

Commands["info"] = function(args)
    local target = findPlayer(args[1]) or LP
    fireChat(string.format("%s | id: %d | age: %dd",target.Name,target.UserId,target.AccountAge))
end

Commands["serverinfo"] = function()
    fireChat(string.format("job: %s | place: %d | %d/%d",game.JobId:sub(1,8),game.PlaceId,#Players:GetPlayers(),Players.MaxPlayers))
end

Commands["time"] = function() fireChat("time: "..tostring(game:GetService("Lighting").TimeOfDay)) end
Commands["fps"]  = function() local dt=RunService.RenderStepped:Wait() fireChat(string.format("fps: %.1f",1/dt)) end

Commands["statecheck"] = function()
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local root = getRoot(p)
                if root then
                    local pos = root.Position
                    queueChat(string.format("%s: %.0f,%.0f,%.0f",p.Name,pos.X,pos.Y,pos.Z))
                end
            end
        end
    end)
end

Commands["spy"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local lastPos, timer = nil, 0
    local id = (loopId["spy"] or 0) + 1 loopId["spy"] = id
    task.spawn(function()
        while loopId["spy"] == id do
            timer = timer + RunService.Heartbeat:Wait()
            if timer >= 5 then
                timer = 0
                local tRoot = getRoot(target)
                if tRoot then
                    local p = tRoot.Position
                    local speed = lastPos and (p-lastPos).Magnitude/5 or 0
                    lastPos = p
                    queueChat(string.format("[spy:%s] %.0f,%.0f,%.0f spd:%.1f",target.Name,p.X,p.Y,p.Z,speed))
                end
            end
        end
    end)
end
Commands["unspy"] = function() stopLoop("spy") end

Commands["alert_on"] = function(args)
    local target = findPlayer(args[1]) local radius = tonumber(args[2]) or 10
    if not target then return end
    local alerted = {}
    startCheckerLoop("alert", function()
        local tRoot = getRoot(target) if not tRoot then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p ~= target then
                local pRoot = getRoot(p)
                if pRoot then
                    local dist = (pRoot.Position-tRoot.Position).Magnitude
                    local wasClose = alerted[p.UserId] or false
                    if dist < radius and not wasClose then
                        alerted[p.UserId] = true
                        fireChat(string.format("[ALERT] %s is near %s (%.0f studs)",target.Name,p.Name,dist))
                    elseif dist >= radius then
                        alerted[p.UserId] = false
                    end
                end
            end
        end
    end)
end
Commands["alert_off"] = function() stopLoop("alert") end

Commands["track"] = function(args)
    local target = findPlayer(args[1]) if not target then return end
    local t = 0 local id = (loopId["track"] or 0) + 1 loopId["track"] = id
    task.spawn(function()
        while loopId["track"] == id do
            t = t + RunService.Heartbeat:Wait()
            if t >= 3 then
                t = 0
                local root = getRoot(target)
                if root then local p=root.Position fireChat(string.format("[%s] %.1f %.1f %.1f",target.Name,p.X,p.Y,p.Z)) end
            end
        end
    end)
end
Commands["untrack"] = function() stopLoop("track") end

-- ─── COMBAT / HEALTH ───────────────────────────────────────────────────────
Commands["kill"]  = function() local hum=getHumanoid(LP) if hum then hum.Health=0 end end
Commands["heal"]  = function() local hum=getHumanoid(LP) if hum then hum.Health=hum.MaxHealth end end

Commands["godmode"] = function()
    startCheckerLoop("godmode", function()
        local hum = getHumanoid(LP)
        if hum and hum.Health < hum.MaxHealth then hum.Health=hum.MaxHealth end
    end)
end
Commands["ungodmode"] = function() stopLoop("godmode") end

-- ─── TOOLS ─────────────────────────────────────────────────────────────────
Commands["equip"] = function(args)
    local bp = LP:FindFirstChildOfClass("Backpack") if not bp then return end
    local slot = tonumber(args[1]) local tool
    if slot then tool = bp:GetChildren()[slot]
    else
        local query = args[1] and args[1]:lower() or ""
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(query,1,true) then tool=t break end
        end
    end
    if tool and tool:IsA("Tool") and LP.Character then LP.Character.Humanoid:EquipTool(tool) end
end

Commands["droptool"] = function()
    local char = LP.Character if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        tool.Parent = workspace
        local root = getRoot(LP)
        if root and tool.PrimaryPart then tool:SetPrimaryPartCFrame(CFrame.new(root.Position + Vector3.new(2,0,0))) end
    end
end

Commands["dropall"] = function()
    local char = LP.Character local bp = LP:FindFirstChildOfClass("Backpack")
    if char then for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then t.Parent=workspace end end end
    if bp   then for _,t in ipairs(bp:GetChildren())   do if t:IsA("Tool") then t.Parent=workspace end end end
end

Commands["usetool"] = function()
    local char = LP.Character if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

Commands["holster"] = function()
    local hum = getHumanoid(LP) if hum then hum:UnequipTools() end
end

-- ─── SERVER HOP ────────────────────────────────────────────────────────────
Commands["rejoin"] = function() TeleportService:Teleport(game.PlaceId, LP) end

Commands["hop"] = function()
    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=10"))
    end)
    if ok and result and result.data and #result.data > 0 then
        local pick = result.data[math.random(#result.data)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LP)
    else
        TeleportService:Teleport(game.PlaceId, LP)
    end
end

-- ─── AUTOMATION ────────────────────────────────────────────────────────────
Commands["delay"] = function(args)
    local secs = tonumber(args[1]) or 1 local cmdName = args[2] if not cmdName then return end
    local subArgs = {} for i=3,#args do subArgs[i-2]=args[i] end
    task.delay(secs, function()
        local handler = Commands[cmdName:lower()] if handler then pcall(handler, subArgs) end
    end)
end

Commands["repeat"] = function(args)
    local n = math.min(tonumber(args[1]) or 3, 50) local cmdName = args[2] if not cmdName then return end
    local subArgs = {} for i=3,#args do subArgs[i-2]=args[i] end
    task.spawn(function()
        for i=1,n do
            local handler = Commands[cmdName:lower()] if handler then pcall(handler, subArgs) end
            task.wait(0.4)
        end
    end)
end

Commands["loop"] = function(args)
    local interval = tonumber(args[1]) or 2 local cmdName = args[2] if not cmdName then return end
    local subArgs = {} for i=3,#args do subArgs[i-2]=args[i] end
    userLoopCount = userLoopCount + 1 local id = userLoopCount userLoopId[id] = true
    task.spawn(function()
        while userLoopId[id] do
            local handler = Commands[cmdName:lower()] if handler then pcall(handler, subArgs) end
            task.wait(interval)
        end
    end)
    fireChat("[loop #"..id.." started]")
end

Commands["stoploop"] = function(args)
    local id = tonumber(args[1])
    if id then userLoopId[id]=nil fireChat("[loop #"..id.." stopped]")
    else for k in pairs(userLoopId) do userLoopId[k]=nil end fireChat("[all user loops stopped]") end
end

Commands["macro"] = function(args)
    local full = table.concat(args," ") local parts = full:split("|")
    task.spawn(function()
        for _, part in ipairs(parts) do
            part = part:match("^%s*(.-)%s*$")
            if part ~= "" then
                local tokens = {} for tok in part:gmatch("%S+") do table.insert(tokens,tok) end
                if #tokens > 0 then
                    local cmd2 = tokens[1]:lower() local sArgs = {}
                    for i=2,#tokens do sArgs[i-1]=tokens[i] end
                    local h = Commands[cmd2] if h then pcall(h, sArgs) end
                end
            end
            task.wait(0.3)
        end
    end)
end

-- ─── STATE / MISC ──────────────────────────────────────────────────────────
Commands["status"] = function()
    local flags = {}
    local checkList = {
        "follow","stalk","ghost","orbit","circle","encircle","patrol","stare","spin",
        "bounce","seizure","haunt","block","rush","levitate","anchor","rocket","drag",
        "guardian","mineguard","barrier","distract","creep","protect","godmode","track",
        "mimic","echo","puppet","above","below","surrogate","mirror","shield","intercept",
        "no_move","autoreturn","blackhole","tornado","poltergeist","juggle","relentless",
        "volley","chaos","paranoia","lockdown","echo_all","tether","spy","alert","steal",
        "camo","pingpong","counterfling","face_all","dance2","mine","silence",
    }
    for _, n in ipairs(checkList) do
        if (loopId[n] or 0) > 0 then table.insert(flags, n) end
    end
    if next(userLoopId) then table.insert(flags, "user loops") end
    fireChat("[status] "..(#flags>0 and table.concat(flags," | ") or "idle"))
end

Commands["reset"] = function()
    stopAllMovement()
    for k in pairs(userLoopId) do userLoopId[k]=nil end
    chatQueue = {}
    Commands["unfreeze"]() stopLoop("godmode")
    fireChat("[reset] all clear")
end

Commands["stopall"] = function()
    stopAllMovement()
    for k in pairs(userLoopId) do userLoopId[k]=nil end
    chatQueue = {}
    fireChat("[stopall] everything halted")
end

Commands["version"] = function()
    local n = 0 for _ in pairs(Commands) do n=n+1 end
    fireChat(string.format("BotControl v9 | %d cmds | bot %d/%d | use !cmds", n, BOT_INDEX, MAX_BOTS))
end

-- ══════════════════════════════════════════
--  !cmds
-- ══════════════════════════════════════════
local CMD_SIGNATURES = {
    "setid [number]","setmax [number]","botinfo",
    "addmaster [plrname]","removemaster [plrname]","masters",
    "tp [plrname]","goto [x][y][z]","tptome",
    "follow [plrname]","unfollow","stalk [plrname]","unstalk",
    "ghost [plrname]","unghost","puppet","unpuppet",
    "orbit [plrname][radius]","unorbit","circle [plrname][radius]","uncircle",
    "encircle [plrname]","unencircle","patrol [plrname1][plrname2]","unpatrol",
    "stare [plrname]","unstare","spin [speed]","unspin",
    "bounce","unbounce","dance2","undance2",
    "face_all","unface_all","freeze","unfreeze",
    "ws [speed]","jh [height]","jump","sit","noclip","stop",
    "nearest","farthest",
    "above [plrname][height]","unabove","below [plrname][distance]","unbelow",
    "surrogate [plrname]","unsurrogate","mirror [plrname]","unmirror",
    "distract [plrname]","undistract","creep [plrname]","uncreep",
    "camo [plrname]","uncamo","poltergeist","unpoltergeist",
    "paranoia [plrname]","unparanoia",
    "anchor","unanchor","levitate [height]","unlevitate",
    "rocket [power]","unrocket","chill","unchill",
    "checkpoint","save_pos [name]","load_pos [name]",
    "autoreturn [distance]","unautoreturn",
    "mine [plrname?]","unmine",
    "fling [plrname]","skyfling [plrname]","voidfling [plrname]",
    "spinlaunch [plrname]","megafling [plrname]","snipe [plrname]","karma [plrname]",
    "catapult [plrname][direction]","chain [plrname]","combo [plrname]",
    "execute [plrname]","assassinate [plrname]","pummel [plrname]",
    "juggle [p]","unjuggle","relentless [plrname]","unrelentless",
    "volley [plrname]","unvolley","pingpong [plrname1][plrname2]","unpingpong",
    "counterfling [plrname]","uncounterfling",
    "orbital [plrname]","yeet [plrname]","flingme",
    "flingall","massfling","flingbomb","nuke","massacre",
    "protect [plrname][radius]","unprotect","guardian [plrname][radius]","unguardian",
    "shield [plrname]","unshield","intercept [attack][vic]","unintercept",
    "no_move [plrname]","unno_move","mineguard [radius]","unmineguard",
    "lockdown [radius]","unlockdown","tether [plrname][distance]","untether",
    "barrier [plrname1][plrname2]","unbarrier",
    "blackhole [radius]","unblackhole","shockwave [radius]","explosion [radius]",
    "tornado [radius]","untornado","mayhem","overload",
    "chaos","unchaos","bamboozle [plrname]","duel [plrname]","tag [plrname]",
    "taunt [plrname?]","grief [plrname]","grief_all",
    "rush [plrname]","unrush","murder [plrname]","obliterate [plrname]",
    "scatter","bringall","tpall [plrname]",
    "drag [plrname]","undrag","steal [plrname]","unsteal",
    "seizure [plrname?]","unseizure","haunt [plrname]","unhaunt",
    "bump [plrname]","unbump","block [plrname]","unblock",
    "ragdoll [number]","troll",
    "say [message]","shout [message]","spam [number][message]","announce [message]",
    "mock [message]","uwu [message]","rickroll",
    "copypasta [name]","listpastas","countdown [number]",
    "fake [plrname][message]","warn [plrname][reason]","ban_msg [plrname][reason]",
    "kick_msg [plrname][reason]","reward [plrname][reason]",
    "broadcast [message]","system_msg [message]",
    "admin_msg [plrname][message]","impersonate [plr][message]",
    "roast [plrname]","compliment [plrname]","haiku [plrname]","rap [plrname]",
    "trial [plrname][crime?]","sentence [plrname][punishment?]",
    "expose [plrname]","hype [plrname]","news","greet [plrname]",
    "question [plrname]","agree [plrname]","disagree [plrname]",
    "poll [question]","vote [option1,option2]",
    "mimic [plrname]","unmimic","mockery [plrname]","echo [plrname]","unecho",
    "echo_all","unecho_all","silence [plrname]","unsilence","stopmimic",
    "pos","coords","find [plrname]","dist [plrname]","count","players",
    "info [plrname?]","serverinfo","time","fps","statecheck",
    "spy [plrname]","unspy","alert_on [plrname][radius]","alert_off",
    "track [plrname]","untrack",
    "kill","heal","godmode","ungodmode",
    "equip [slot/name]","droptool","dropall","usetool","holster",
    "rejoin","hop",
    "delay [seconds][command]","repeat [number][command]","loop [seconds][command]","stoploop [id?]",
    "macro [command1|command2]",
    "status","reset","stopall","version","cmds",
}

Commands["cmds"] = function()
    local pages = {} local current = ""
    for _, sig in ipairs(CMD_SIGNATURES) do
        local add = #current>0 and ("  "..PREFIX..sig) or PREFIX..sig
        if #current + #add > 190 then table.insert(pages, current) current = PREFIX..sig
        else current = current .. (#current>0 and "  " or "") .. PREFIX..sig end
    end
    if #current > 0 then table.insert(pages, current) end
    queueChat(string.format("[cmds] %d commands, %d messages", #CMD_SIGNATURES, #pages))
    task.spawn(function()
        task.wait(1)
        for _, page in ipairs(pages) do queueChat(page) end
    end)
end

-- ══════════════════════════════════════════
--  PARSER
-- ══════════════════════════════════════════
local function parseAndExecute(message, sender)
    if message:sub(1,#PREFIX) ~= PREFIX then return end
    local body = message:sub(#PREFIX+1):match("^%s*(.-)%s*$")
    local tokens = {}
    for tok in body:gmatch("%S+") do table.insert(tokens,tok) end
    if #tokens == 0 then return end
    local cmd = tokens[1]:lower()
    local args = {} for i=2,#tokens do args[i-1]=tokens[i] end
    -- safety: bot cannot target itself
    for _, arg in ipairs(args) do
        local p = findPlayer(arg)
        if p and p == LP then return end
    end
    local handler = Commands[cmd]
    if handler then
        currentSender = sender
        local ok, err = pcall(handler, args)
        currentSender = nil
        if not ok then warn("[BotControl] !"..cmd.." error: "..tostring(err)) end
    end
end

-- ══════════════════════════════════════════
--  CHAT LISTENER
-- ══════════════════════════════════════════
function hookMaster(player)
    if isMaster(player) then
        player.Chatted:Connect(function(msg) parseAndExecute(msg, player) end)
    end
end

for _, p in ipairs(Players:GetPlayers()) do hookMaster(p) end
Players.PlayerAdded:Connect(hookMaster)

LP.CharacterAdded:Connect(function()
    for _, n in ipairs({"spin","bounce","seizure","anchor","levitate","rocket","block","rush","dance2","mine"}) do
        stopLoop(n)
    end
    checkpointCF = nil
end)

local cmdCount = 0
for _ in pairs(Commands) do cmdCount=cmdCount+1 end
fireChat(string.format("[BotControl v9] loaded | masters: '%s' | %d cmds | bot %d/%d | !cmds for list | (C) MIT License | By: E Fred/E God",
    table.concat(MASTER_NAMES,", "), cmdCount, BOT_INDEX, MAX_BOTS))
