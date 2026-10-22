--[[
	ABOUT THIS SCRIPT
	A LocalScript sword-fighting bot for Roblox. Per its author, it is used in games the author made, run in
	Roblox Studio with a plugin that implements the executor-style environment functions listed below.
	The plugin's functions are based on the Potassium documentation, which is the reference for their names,
	arguments and behaviour (the environment follows the UNC naming standard):
	  https://docs.potassium.pro/api-reference/introduction
	Each of those functions is checked for and skipped if it is missing, so the script also runs without them.
]]

--[[
	SWORD BOT  (LocalScript)
	Place in: StarterPlayer > StarterPlayerScripts
	Toggle:   K  (or click the switch in the UI)

	Movement is done only with Humanoid:Move() and Humanoid.Jump.
	No WalkSpeed / JumpPower changes, no teleporting, no velocity or physics objects.
	Fairness: reaction delays, limited turn rate, and imperfect dodging.
	Works with the Roblox toolbox "ClassicSword" (swings via Tool:Activate()).

	UI: three tabs - Bot (target, session and lifetime stats), Debug (live state + event log), Games (lifetime
	kills/assists per game). CONFIG.UIScale resizes the card; getgenv().SwordBot:SetScale(n) does it live.

	FILES (written through writefile into the CONFIG.ProfileFolder folder, "SwordBot" by default):
	  profiles.json   what the bot has learned about each player's fighting habits, keyed by UserId. The folder is
	                  shared by every game it runs in, so profiles carry over; saves merge with the file on disk.
	  games.json      lifetime kills and assists per game (keyed by game id), summed across all servers of that game.
	Per-server numbers (X.sess) start from 0 on every join; the lifetime numbers come from games.json.

	EXECUTOR-STYLE FUNCTIONS (provided by the author's Roblox Studio plugin; reference: the Potassium docs above):
	  gethui          UI is parked in a container hidden from game scripts
	  getgenv         re-running the script cleans up the old copy; control it via getgenv().SwordBot
	  readfile/writefile/isfile/isfolder/makefolder   profiles.json and games.json (see FILES)
	  Drawing         on-screen line + label to the current target
	  setclipboard    press CONFIG.CopyLogKey to copy the Debug log
	  rconsole*       optional external console mirror of the log
	  queueonteleport optional: re-run the bot after teleports
	  firetouchinterest optional hit-registration assist (on by default, see CONFIG.TouchAssist)
	  setfpscap       optional steadier frame rate
]]

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local X = { conns = {}, logBuf = {}, all = {}, saved = {}, saveTimer = 0 }
local CONFIG = {
	Keybind = Enum.KeyCode.K,
	StartEnabled = true,

	SwordName = "ClassicSword",
	SwordKeywords = { "sword", "blade", "katana", "saber" },

	SearchRange = 250,       -- how far it looks for players
	EquipRange = 30,         -- equips sword inside this distance
	UnequipRange = 45,       -- unequips beyond this distance
	EngageRange = 16,        -- switches from pathing to close combat
	AttackRange = 4.2,       -- studs (flat, root-to-root) within which it swings; raise if it still stands too far
	AttackAngle = 40,        -- degrees in front of us that counts as "facing"
	AttackCooldown = 0.45,

	ReactionMin = 0.03,      -- human-like delay before swinging
	ReactionMax = 0.09,
	MaxTurnRate = 480,       -- degrees per second (lower = calmer turning)
	BackOffRange = 8,        -- studs: while retreating / backing off, step away from any OTHER player this close too
	FaceRange = 20,          -- studs: inside this it turns to face the target (AutoRotate is off only then). 0 = never

	NoSwordAttackChance = 0.30, -- chance to attack someone with no sword (re-rolled periodically)
	NoSwordRerollTime = 20,

	FlankChance = 0.75,       -- jump over + backstab
	FlankCooldown = 4,

	Gank = true,             -- ganking: prefer / ambush players who are busy fighting someone else, hurt, weak, or have their back turned
	GankBusyRange = 12,      -- studs: another armed player this close to them = they're "busy"
	GankWeakBelow = 0.4,     -- health fraction under which a player counts as an easy kill
	GankBonus = { busy = 22, hurt = 12, weak = 18, turned = 6 }, -- how much each opening makes a player more attractive as a target (in studs of distance)
	GankLurk = true,         -- wait just outside their fight until one of them is hurt, then strike (false = strike straight away)
	GankLurkRange = 13,      -- studs: where it waits
	GankLurkMax = 6,         -- seconds it waits before striking anyway

	SkipUnkillable = true,   -- drop a target that just won't die (god mode / endless health / heals it all back / spawn protection) and pick someone else
	UnkillableFightTime = 12, -- seconds actually trading in melee range with them before judging
	UnkillableSwings = 10,   -- ...and at least this many of our swings in reach
	UnkillableMaxDrop = 0.08, -- ...and their health never fell more than this fraction of max below where it started
	UnkillableBanTime = 60,  -- seconds to leave that player alone afterwards
	DodgeChance = 0.9,       -- chance to sidestep when it sees you swing (raised by request: dodges more; learning still adjusts it per player)
	ComboLunge = false,      -- quick second click (classic sword lunge) on EVERY swing
	LungeBeyond = 3.4,       -- studs: swings from further than this get the lunge click for extra reach (nil = off)

	RetreatBelow = 0.40,     -- back off when own health fraction is below this (also: when ~1.6 average hits from death)
	RetreatUntil = 0.70,
	RetreatMax = 12,         -- seconds a retreat can last (health regenerates slowly)
	FeintChance = 0.5,       -- when in striking range, chance to try a feint (lure a whiff or a dodge); one try per ~0.8s
	ChatMessages = true,     -- post stat lines in chat (kills, deaths, streaks, K/D, ping, FPS). false = never chats
	ChatSessionSummary = true, -- post a session summary in chat when the bot is switched off
	ChatCooldown = 10,      -- seconds between chat lines. Lines that come in during the cooldown wait in a queue (up to 13) and go out in order        -- seconds between chat lines. Lines that are due wait in a short queue instead of being dropped
	ChatMilestones = { 1, 3, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100 }, -- kill / death counts that get a line (overall and per player)
	ChatStreaks = { 3, 5, 7, 10, 15 }, -- kill streaks (in a row) that get a line
	ChatKDFlips = true,      -- say when overall K/D crosses 1.0 (at most once a minute)
	ChatHighPing = 200,     -- ms: say so once when ping stays above this for ~3 seconds (re-arms after it drops well below)
	ChatLowFps = 30,        -- frames per second: say so once when it stays below this for ~3 seconds (re-arms after it recovers)
	ChatOnlyInFights = true, -- only mention ping / FPS while the bot is in a fight
	ChatMean = true,         -- playful teasing after kills and losses (about the game only, never the person)
	ChatTauntChance = 0.3,   -- chance that a kill or a loss gets a line
	ChatTauntCooldown = 25,  -- seconds between teasing lines
	ChatStyleLines = true,   -- say what style a player seems to have (once per style per player)
	ChatStats = true,        -- extra stat lines every ChatStatEvery kills, plus an uptime line
	ChatStatEvery = 8,       -- kills between stat lines
	ChatUptimeEvery = 300,   -- seconds between uptime lines
	ChatAdaptLines = true,   -- say when the bot changes how it fights a player (learned adaptations)
	ChatAdaptCooldown = 15,  -- seconds between adaptation lines
	ReachCheck = true,       -- watch for hits that land from further away than a sword can reach (reach exploits)
	ReachFarStuds = 7,       -- a hit from further than this many studs counts as "far" (sword reach is ~4.2, plus lag)
	ReachMinSamples = 6,     -- far-or-near hits needed before a player can be flagged
	ReachFarRatio = 0.6,     -- share of their hits that must be far before we flag them
	ReachChatLines = true,   -- say so in chat when a player is flagged, and every 10 far hits after that
	FootprintCheck = true,   -- clanker-style: a spot only counts as safe if the floor is under all four sides of the body too
	MinSwitchTime = 2.5,     -- keep a target at least this long before switching (unless it's gone or we're not fighting)
	OutnumberedBelow = 0.75, -- retreat when 2+ armed players are on top of us and health is under this

	WanderMinDist = 25,      -- wander goal distance range (studs) when nobody is in range
	WanderMaxDist = 70,
	WanderPause = { 1, 3.5 },-- idle pause (seconds) after reaching a wander spot

	AgentRadius = 1.0,       -- pathfinding clearance from edges/walls. Paths narrower than ~2x this can't be pathed by Roblox (1.0 = ~2 studs wide; was 1.5, which refused narrow paths)
	AgentHeight = 5,         -- studs: the body height Roblox plans routes for (lower = fits under lower gaps)
	WaypointSpacing = 3,     -- studs between route points: denser = tighter corners, a little more compute
	RouteRepathBlocked = true, -- re-route as soon as Roblox reports a waypoint on the route is blocked
	HitAndRun = true,        -- MOVE: after a swing, step straight back for a moment (they swing into air, you're out of reach)
	HitAndRunTime = 0.3,     -- seconds of step-back after each swing
	GuardHold = true,        -- MOVE: when they rush in at mid range while facing us, hold ground and let them walk into our swing
	PathRetryNarrow = true,  -- if no route at full AgentRadius, try once more with a narrower body
	PathNarrowRadius = 0.6,  -- studs: the narrower body used for that retry
	BodySweep = true,        -- sweep a body-width box along route legs and the chase line: re-route if a wall blocks the body
	PathGoalSnap = true,     -- if no route to the goal, raycast down to the real floor under it (and a ring of spots around it) and try those
	ChaseTurnRate = 420,     -- degrees/sec: max heading change while chasing/wandering (kills pathfinding twitch)
	ChaseSnapAngle = 70,     -- degrees: heading changes bigger than this (corners, U-turns after a re-path) happen instantly instead of being eased
	DebugLog = true,         -- log bot events (mode changes, paths, fake floors, dodges, jumps) into the Debug tab
	DebugPrint = false,      -- also print those events to the Output window
	DebugMaxLines = 250,     -- how many lines the Debug tab keeps

	AvoidFakeFloors = true,  -- won't step onto visible floor-like parts you can't actually stand on (CanCollide off / collision group)
	FakeFloorStrict = true,  -- true = ALSO avoid them when real ground is right underneath (so they're always flagged); false = only when there's nothing solid below
	AvoidUnstableFloors = true, -- also avoid floors that are fading out or toggling CanCollide (disappearing platforms), even while still solid
	EscapeUnstableFloors = true, -- if the floor UNDER us turns unstable, run/jump to the nearest stable ground first
	EscapeRadius = 15,       -- studs: how far it will look for stable ground to escape to
	UnstableHold = 3,        -- seconds a floor stays flagged after it last faded / toggled
	BlinkerHold = 10,        -- ...if it has changed 3+ times (a floor that keeps vanishing and returning)
	GhostMaxTransparency = 0.9, -- CanCollide-off parts MORE transparent than this are ignored (invisible trigger zones aren't floors)
	LedgeAvoidance = true,
	JumpClearance = 0.4,     -- studs shaved off max jump height when judging a jump shortcut (lower = tries higher ledges)
	MaxDrop = 30,            -- studs: drops up to this far are OK to walk/jump down; beyond it counts as a ledge/void
	CasualDrop = 9,          -- studs: drops up to this are taken freely. Deeper drops (up to MaxDrop) are only taken when they land near the player it's chasing, or the route goes there
	ShortcutLookahead = 30,  -- how many path waypoints ahead it scans for shortcuts (walk or jump)
	ShortcutMinSave = 1.5,   -- studs a shortcut must save to be taken (was 3: too strict for tight zig-zags)
	ShortcutHeavy = 14,      -- how many shortcut candidates get the full walk test per check (was 8)
	PathService = true,      -- Roblox PathfindingService plans every route
	PfDropCost = 1.8,        -- grid search: cost multiplier for drops deeper than CasualDrop (discourages needless drops)
	PfJumpCost = 2.2,        -- grid search: cost multiplier for jumps (up, or across a gap)
	JumpMaxCells = 3,        -- grid search: widest gap it will jump, in cells (3 cells = 9 studs, if the jump can reach it)
	LedgeRun = 4.5,          -- studs: start a ledge climb this far out (a run-up gets it up), instead of stopping at the foot of it
	RouteDrop = 30,          -- studs: drops on a route are taken up to this; whether the landing is real is checked on the floor itself (see X.legHasGap / X.supportedAt)
	CommitDrops = true,      -- at a ledge, drop straight off it (no side-steering) once the landing is checked for void
	SkipThinObstacles = true, -- rails / bars / lids above the floor (fence tops) are not ground: look through them
	CrackWidth = 2.5,        -- studs: a gap in the floor this narrow or less can be stepped across (floor on both sides, same height)
	WalkStep = 2,            -- studs between the floor checks along a walked leg (narrower = catches smaller gaps, costs more)
	UnreachableBanTime = 10, -- seconds to leave alone an elevated player we can't get up to (instead of walking under them)
	RouteCheckEvery = 0.5,   -- seconds between checks that the route is still over solid ground (void / vanished floor -> re-route)

	-- executor features
	HiddenUI = true,         -- gethui(): hide the card from game scripts
	AnimateUI = true,        -- smooth GUI animations (false = everything snaps instantly)
	UIScale = 0.65,          -- size of the whole card (1 = full size, 0.7 = smaller). Live: getgenv().SwordBot:SetScale(0.7)
	SaveProfiles = true,     -- readfile/writefile: remember how each player fights across sessions
	ProfileFolder = "SwordBot",
	AutosaveEvery = 30,      -- seconds between profile saves
	Overlay = true,          -- Drawing: line + label to the current target
	CopyLogKey = Enum.KeyCode.L, -- setclipboard: copies the Debug log (nil = off)
	ExecConsole = false,     -- rconsole: mirror the log into an external console window
	RequeueOnTeleport = true,  -- queueonteleport: needs the script saved as workspace/SwordBot/SwordBot.lua
	TouchAssist = true,      -- firetouchinterest to help near-miss swings register (still only swings inside AttackRange)
	TouchAssistChance = 0.6, -- fraction of swings that get assisted (assisting every swing looks robotic)
	TouchAssistDelay = { 0.08, 0.2 }, -- seconds after the swing starts, roughly when the blade would be mid-arc
	TouchAssistCooldown = 0.8, -- minimum seconds between assisted hits
	FpsCap = 144,            -- frames per second cap (nil = leave alone)
	Tryhard = true,          -- tougher play: faster reactions, commit harder when winning the trade, retreat earlier when losing it
	TryhardReactionScale = 0.7,
	Rest = true, RestBelow = 0.5, -- hurt and nobody armed nearby: stand still and regenerate instead of wandering into fights -- multiplies reaction time when Tryhard is on (lower = faster)

	-- flung recovery: if the character gets launched (by an exploiter or a fling part) the bot stops, waits to land,
	-- and if it can't get back it turns itself off. It never breaks joints or forces a respawn; a client can't do that.
	FlingRecovery = true,
	FlingDistance = 150,     -- studs: airborne and this far (flat) from the last safe spot = flung
	FlingSpeed = 60,         -- studs/sec: and moving at least this fast
	FlingVoidY = -150,       -- below this height = outside the map
	FlingMapBound = 2000,    -- studs from the origin = outside the map
	FlingMaxWait = 4,        -- seconds to land before the bot resets its character
}

-- SAVING: the Config tab's values are kept in SwordBot_config.json when the executor can read/write files.
-- Without file support (readfile/writefile missing) everything still works, it just isn't remembered.
do
	local HttpService = game:GetService("HttpService")
	local SAVE_FILE = "SwordBot_config.json"
	X.configDefaults = {}
	for k, v in pairs(CONFIG) do
		if type(v) == "boolean" or type(v) == "number" then X.configDefaults[k] = v end
	end
	if readfile and isfile then
		local ok, data = pcall(function()
			if isfile(SAVE_FILE) then return readfile(SAVE_FILE) end
		end)
		if ok and type(data) == "string" and data ~= "" then
			local ok2, t = pcall(function() return HttpService:JSONDecode(data) end)
			if ok2 and type(t) == "table" then
						for k, v in pairs(t) do
					if k == "UIScale" and t._v ~= 2 then
						-- saves from before the new default: ignore their UIScale so the current default applies
					elseif type(CONFIG[k]) == type(v) and (type(v) == "boolean" or type(v) == "number") then
						CONFIG[k] = v
					end
				end
			end
		end
	end
	-- returns true when the file was written
	function X.saveConfig(tbl)
		if not writefile then return false end
		local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
		if not ok then return false end
		return (pcall(writefile, SAVE_FILE, json))
	end
	X.saveSupported = writefile ~= nil
end

----------------------------------------------------------------------
-- SERVICES / HELPERS
----------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local UP = Vector3.yAxis


----------------------------------------------------------------------
-- EXECUTOR FEATURES (functions come from the plugin)
----------------------------------------------------------------------
-- checks: a feature is skipped (not an error) when the plugin doesn't provide its function
X.genv = getgenv and getgenv() or nil
X.hasFiles = (isfile and readfile and writefile and isfolder and makefolder) and true or false
X.fps = 60
-- ping in ms (Roblox's own network stat; shows "-" if it isn't available)
function X.ping()
	local ok, v = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and type(v) == "number" and math.floor(v + 0.5) or nil
end
function X.resetStats()
	X.stats = {
		activates = 0, assists = 0, assistSkips = 0, escapes = 0, saves = 0, lastSaveAt = nil,
		swings = 0, hits = 0, dealt = 0, taken = 0, dodges = 0, ganks = 0, jumps = 0, stuck = 0, twitches = 0, targets = 0,
		-- extra stats
		engages = 0, wins = 0, losses = 0, ttkSum = 0, ttkCount = 0,
		swSeen = 0, dodgedSw = 0, punishes = 0, wiggles = 0,
		combatTime = 0, distSum = 0, combatFrames = 0,
	}
end
X.resetStats()
-- session numbers for the Bot tab: NOT wiped by the Debug "Clear" button
X.sess = { up = 0, combat = 0, streak = 0, best = 0, kills = 0, assists = 0 }
X.fpsLow, X.fpsWinMin, X.fpsWinT = 60, 1e9, 0 -- lowest frame rate seen in the last 5s window
X.keys = {
	"speed", "idle", "retreat", "strafeBias", "flipInterval", "flips", "range", "rush",
	"theirSwings", "swingGap", "swingRange", "ourSwings", "dodgesOurs", "dodgeBias", "hitDist", "missDist", "hitN", "missN",
	"firstStrike", "engagements", "counterRate", "fleeHit", "hitsLanded", "dodgeBack", "dodgeHop",
	"lowHpRun", "lowSamples", "jumpSwing", "wins", "losses", "recW", "recL", "trade", "eLin", "eFlip", "lossRun",
	"approach", "heals", "ambush", "zig",
}

-- a second run replaces the first instead of stacking two bots
if X.genv and X.genv.SwordBot_Cleanup then pcall(X.genv.SwordBot_Cleanup) end

if CONFIG.FpsCap and setfpscap then setfpscap(CONFIG.FpsCap) end

if CONFIG.ExecConsole and rconsolecreate then
	rconsolecreate()
	if rconsolesettitle then rconsolesettitle("SwordBot") end
end

if CONFIG.RequeueOnTeleport and queueonteleport and X.hasFiles then
	local path = CONFIG.ProfileFolder .. "/SwordBot.lua"
	if isfile(path) then queueonteleport(readfile(path)) end
end

-- learned profiles saved to disk: plain numbers only, keyed by UserId
do
	local HttpService = game:GetService("HttpService")
	local file = CONFIG.ProfileFolder .. "/profiles.json"
	local function ensureFolder()
		if not isfolder(CONFIG.ProfileFolder) then makefolder(CONFIG.ProfileFolder) end
	end

	-- the file is shared by every game you run this in (and any other open Roblox window), so always read it fresh
	local function readSaved()
		if not (CONFIG.SaveProfiles and X.hasFiles) then return nil end
		ensureFolder()
		if not isfile(file) then return nil end
		local ok, data = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
		if ok and type(data) == "table" then return data end
		return nil
	end

	function X.loadProfiles()
		local data = readSaved()
		if data then X.saved = data end
		X.savedAt = time()
	end

	-- picks up players another game/window learned while this one has been running (at most every 5s)
	function X.refreshSaved()
		if time() - (X.savedAt or 0) < 5 then return end
		X.loadProfiles()
	end

	function X.saveProfiles()
		if not (CONFIG.SaveProfiles and X.hasFiles) then return end
		ensureFolder()
		local out = {}
		-- start from what is on disk NOW (other games/windows may have saved since we loaded), then overlay what we learned
		for k, v in pairs(readSaved() or X.saved) do out[k] = v end
		for userId, pr in pairs(X.all) do
			local row = {}
			for _, key in ipairs(X.keys) do
				if type(pr[key]) == "number" then row[key] = pr[key] end
			end
			out[tostring(userId)] = row
		end
		if pcall(function() writefile(file, HttpService:JSONEncode(out)) end) then
			X.saved, X.savedAt = out, time()
			X.stats.saves += 1
			X.stats.lastSaveAt = time()
		end
	end

	X.loadProfiles()
end

-- LIFETIME KILLS / ASSISTS PER GAME: every server of the same game adds to ONE total, saved in SwordBot/games.json
-- (the per-server numbers stay in X.sess and start from 0 on every join)
do
	local HttpService = game:GetService("HttpService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local file = CONFIG.ProfileFolder .. "/games.json"
	local GM = { data = {}, pending = { kills = 0, assists = 0 }, metaDirty = false, visitPending = false }
	X.games = GM
	GM.key = tostring(game.GameId ~= 0 and game.GameId or game.PlaceId) -- universe id: every place of one game shares it
	local canSave = (CONFIG.SaveProfiles and X.hasFiles) and true or false

	local function readDisk()
		if canSave and isfile(file) then
			local ok, data = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
			if ok and type(data) == "table" then return data end
		end
		return nil
	end
	local function ensureRow(data)
		local row = data[GM.key]
		if type(row) ~= "table" then row = {} data[GM.key] = row end
		row.kills, row.assists = tonumber(row.kills) or 0, tonumber(row.assists) or 0
		row.visits, row.last = tonumber(row.visits) or 0, tonumber(row.last) or 0
		row.name = type(row.name) == "string" and row.name or ""
		return row
	end

	function GM.totals() -- kills, assists, number of games
		local k, a, n = 0, 0, 0
		for _, row in pairs(GM.data) do
			if type(row) == "table" then
				k += tonumber(row.kills) or 0
				a += tonumber(row.assists) or 0
				n += 1
			end
		end
		return k, a, n
	end

	function GM.save()
		if not canSave then return end
		local p = GM.pending
		if p.kills == 0 and p.assists == 0 and not GM.metaDirty and not GM.visitPending then return end
		if not isfolder(CONFIG.ProfileFolder) then makefolder(CONFIG.ProfileFolder) end
		-- merge our new kills into whatever is on disk NOW (another Roblox window may have written since we loaded)
		local disk = readDisk()
		local merged = disk ~= nil
		if not merged then disk = GM.data end
		local row = ensureRow(disk)
		if merged then
			row.kills += p.kills
			row.assists += p.assists
			if GM.visitPending then row.visits += 1 end
		end
		if GM.cur.name ~= "" then row.name = GM.cur.name end
		row.last = os.time()
		if pcall(function() writefile(file, HttpService:JSONEncode(disk)) end) then
			p.kills, p.assists, GM.metaDirty, GM.visitPending = 0, 0, false, false
			GM.data, GM.cur = disk, row
		end
	end

	function GM.add(what) -- "kills" or "assists"
		GM.cur[what] += 1
		GM.pending[what] += 1
		GM.cur.last = os.time()
		GM.save()
		if X.ui and X.ui.gamesChanged then X.ui.gamesChanged(what) end
	end

	local disk = readDisk()
	if disk then GM.data = disk end
	GM.cur = ensureRow(GM.data)
	GM.cur.visits += 1 -- this join
	GM.cur.last = os.time()
	GM.visitPending = true
	GM.save()

	-- the game's name (async: GetProductInfo can yield or fail, e.g. in an unpublished place)
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
		local name = ok and type(info) == "table" and type(info.Name) == "string" and info.Name or ""
		if name == "" then name = (game.Name ~= "" and game.Name ~= "Game") and game.Name or "Unknown game" end
		if GM.cur.name ~= name then
			GM.cur.name = name
			GM.metaDirty = true
			GM.save()
			if X.ui and X.ui.gamesChanged then X.ui.gamesChanged("name") end
		end
	end)
end

-- Drawing overlay: line from the bottom of the screen to the target + a small label
do
	local line, label
	if CONFIG.Overlay and Drawing and Drawing.new then
		line = Drawing.new("Line")
		line.Thickness, line.Color, line.Transparency, line.Visible = 1.5, Color3.fromRGB(52, 211, 153), 1, false
		label = Drawing.new("Text")
		label.Size, label.Center, label.Outline, label.Color, label.Visible = 14, true, true, Color3.new(1, 1, 1), false
	end
	function X.overlay(isOn, tgt, root, modeName, d)
		if not line then return end
		local cam = Workspace.CurrentCamera
		if isOn and tgt and root and root.Parent and cam then
			local p, onScreen = cam:WorldToViewportPoint(root.Position)
			if onScreen and p.Z > 0 then
				line.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
				line.To = Vector2.new(p.X, p.Y)
				line.Visible = true
				label.Text = string.format("%s  [%s]  %.0f", tgt.Name, tostring(modeName), d)
				label.Position = Vector2.new(p.X, p.Y - 34)
				label.Visible = true
				return
			end
		end
		line.Visible = false
		label.Visible = false
	end
	function X.removeOverlay()
		if line then line:Remove() end
		if label then label:Remove() end
		line, label = nil, nil
	end
end


local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function unitOr(v, fallback) if v.Magnitude > 1e-3 then return v.Unit end return fallback end
local function rotY(v, rad)
	local c, s = math.cos(rad), math.sin(rad)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
local function ema(old, new, a) return old + (new - old) * a end
local function rand(a, b) return a + math.random() * (b - a) end
-- rotate heading `cur` toward `want` by at most maxTurn radians, keeping `want`'s speed.
-- Unlike a lerp it never passes through zero when the new heading is opposite (that stall is a classic twitch).
local function steerToward(cur, want, maxTurn)
	cur, want = flat(cur), flat(want)
	if cur.Magnitude < 0.05 or want.Magnitude < 0.01 then return want end
	local c, w = cur.Unit, want.Unit
	local ang = math.acos(math.clamp(c:Dot(w), -1, 1))
	if ang <= maxTurn then return want end
	-- A big change (path corner, U-turn after a re-path, waypoint behind us) is a real decision, not jitter:
	-- take it at once. Easing it made the bot sweep through every heading in between, walking across ground
	-- that isn't on the path (into walls and ledges) while it "slowly turned around".
	if ang > math.rad(CONFIG.ChaseSnapAngle) then return want end
	local rot = (c.Z * w.X - c.X * w.Z) >= 0 and maxTurn or -maxTurn
	return rotY(c, rot) * want.Magnitude
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
local enabled = false
local character, humanoid, hrp

local target, tChar, tHum, tHrp, profile
local diedConn
local history, tVel, lastSample = {}, Vector3.zero, 0
local targetArmed = false

local mode, modeUntil, swings = "Idle", 0, 0
local strafeSign, strafeFlipAt = 1, 0
local flankReadyAt = 0
local nextPickAt, nextArmedCheck, nextDirectCheck, nextEquipAt = 0, 0, 0, 0
local directOK, directFalseSince = false, nil
local inCombat = false
local smoothDir, stuckStrikes = Vector3.zero, 0
local nextAttackAt, attackArmedAt = 0, nil
local lastJump = 0
local dist = 0

local retreating, retreatStart, retreatBlockedUntil = false, 0, 0
local lastHurt, lastHealth = -100, 100

local dodgeStartAt, dodgeUntil, dodgeReadyAt, dodgeSign, dodgeJump = 0, 0, 0, 1, false
local nextSwingCheck, wasSwinging = 0, false

local wps, wpIdx, pathBusy, lastPath, pathGoal = nil, 1, false, 0, nil
local leap, noLedgeUntil = nil, 0 -- committed gap jump / temporary ledge-avoid bypass
local leapEndedAt = -100          -- when the last leap finished (used to drop waypoints we flew past)
local nextStuckCheck, lastStuckPos, sideStepUntil, sideStepSign = 0, Vector3.zero, 0, 1

local kos, deaths = 0, 0
local step_dodging = false
local predQueue = {}                        -- pending predictions, scored when their horizon has passed
local smoothPred, smoothLook = nil, nil -- low-passed target prediction / facing (stops steering jitter)
local facing = false                    -- hysteresis for AutoRotate on/off
local safeSide = 1                      -- remembered side for ledge sidestepping (stops left/right flip-flop)
local punishFrom, punishUntil = 0, 0    -- window right after THEY swing (whiff) where we rush in and hit
local watchEnd, watchRight, watchHealth, watchDist = 0, nil, 0, 0 -- grading how they reacted to our last swing
local watchLat0, watchAir0 = 0, false
local directTrueSince = nil           -- rising-edge hysteresis for directOK (stops chase mode flapping)
local lastWpDir = Vector3.zero         -- last heading toward a waypoint (held when we're right on top of it)
local nav = { vel = Vector3.zero, prev = nil, gpos = nil, gy = 0 } -- our measured flat speed (from position changes), last solid footing + its feet height

-- RespectCanCollide: parts with CanCollide OFF are invisible to every check using rayParams, so the bot
-- walks straight through them and never treats them as walls (or as ground).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

-- same filter but it DOES see CanCollide-off parts: used only to spot fake floors
local ghostParams = RaycastParams.new()
ghostParams.FilterType = Enum.RaycastFilterType.Exclude
ghostParams.RespectCanCollide = false

local function refreshFilter()
	local list = {}
	if character then table.insert(list, character) end
	if tChar then table.insert(list, tChar) end
	rayParams.FilterDescendantsInstances = list
	ghostParams.FilterDescendantsInstances = list
	-- rays obey OUR collision rules: a part that lets rays hit it but not us (collision group) must NOT count as floor
	if hrp then rayParams.CollisionGroup = hrp.CollisionGroup end
end

----------------------------------------------------------------------
-- PLAYER LEARNING PROFILES (per player, per session)
----------------------------------------------------------------------
local getProfile
do
local profiles = X.all
function getProfile(p)
	local pr = profiles[p.UserId]
	if not pr then
		pr = {
			samples = 0, observed = 0,
			speed = 0, idle = 0, retreat = 0.3,
			strafeBias = 0, lastSign = 0, lastFlip = 0, flipInterval = nil, flips = 0,
			jumpTimes = {}, jumpRate = 0, wasAir = false,
			range = 10, rush = 0.3,                    -- usual fighting distance / how often they walk INTO us
			theirSwings = 0, swingGap = nil, swingRange = nil, -- their swing habits (count, seconds between, studs away)
			ourSwings = 0, dodgesOurs = 0.4, dodgeBias = 0,   -- how they react to MY swings (+1 = dodge to my right)
			dodgeBack = 0.2, dodgeHop = 0.2,                  -- HOW they dodge: backstep / jump
			firstStrike = 0.4, engagements = 0,               -- do they swing first when a fight starts
			counterRate = 0.4, fleeHit = 0.3, hitsLanded = 0, -- right after I hit them: swing back / run
			lowHpRun = 0.3, lowSamples = 0,                   -- do they run when their health is low
			jumpSwing = 0.2,                                  -- do they swing while airborne
			wins = 0, losses = 0,                             -- how our fights against them have ended (wins/losses = totals for display)
			recW = 0, recL = 0, trade = 0, eLin = 0.5, eFlip = 0.5,                               -- decayed record: recent fights count more (see edgeOf)
			tact = {},                                        -- how well each of MY tactics lands on them: [mode] = { n, rate }
			orbit = 0, orbitSpin = 0,                         -- do they circle around me (0..1), and which way they spin (-1..1)
			approach = 0.3, heals = 0,                        -- do THEY close the gap to start fights (0..1), and do they heal up when away from us
			ambush = 0, zig = 0,                              -- do they stand still then strike as we near (0..1), and how often they zig-zag
			hitDist = nil, missDist = nil, hitN = 0, missN = 0, -- how far away my hits land vs my whiffs
		}
		X.refreshSaved() -- the player may have been learned in another of your games since this one started
		local saved = X.saved[tostring(p.UserId)]
		if saved then
			for k, v in pairs(saved) do if type(v) == "number" then pr[k] = v end end
			pr.observed = 5 -- we already know this player; skip the "still learning" warm-up
		end
		pr.name = p.Name
		profiles[p.UserId] = pr
	end
	return pr
end
end

-- RESULTS: one place that records a fight outcome. Totals stay as plain integers (shown in the UI);
-- recW / recL are decayed so old fights (and old bugs) stop deciding how we treat someone today.
local function recordResult(pr, won)
	if won then pr.wins += 1 else pr.losses += 1 end
	pr.lossRun = won and 0 or ((pr.lossRun or 0) + 1) -- losses in a row to this player
	pr.recW = pr.recW * 0.9 + (won and 1 or 0)
	pr.recL = pr.recL * 0.9 + (won and 0 or 1)
	X.stats[won and "wins" or "losses"] += 1
end
-- chance WE win a fight vs this player, smoothed toward 50% while we have little data
local function edgeOf(pr)
	return (pr.recW + 1) / (pr.recW + pr.recL + 2)
end
-- each dead humanoid is counted at most once (kills, assists, losses)
local credited = setmetatable({}, { __mode = "k" })
-- kill tracking that survives target switches: which humanoids have a death listener, and when we were last close to each
X.deathWatched = setmetatable({}, { __mode = "k" })
X.ourHitAt = setmetatable({}, { __mode = "k" }) -- humanoid -> when one of OUR hits last landed on it (for games without creator tags)
X.nearAt = setmetatable({}, { __mode = "k" })

-- per-fight bookkeeping (who swung first, did they answer a hit) - reset on every new target
local fight = { engagedAt = nil, decided = false, ourFirstSwingAt = nil, ourSwingAt = -100,
	lastHp = nil, hitAt = nil, countered = false, hitDist = 0,
	dealt = 0, taken = 0, lastMyHp = nil, lastHitAt = nil } -- damage ledger for the current fight
local function resetFight()
	fight.engagedAt, fight.decided, fight.ourFirstSwingAt = nil, false, nil
	fight.ourSwingAt, fight.lastHp, fight.hitAt, fight.countered = -100, nil, nil, false
	fight.dealt, fight.taken, fight.lastMyHp, fight.lastHitAt = 0, 0, nil, nil
end
----------------------------------------------------------------------
-- MATCHUP PLANS: per player, the bot picks a fighting plan, plays it for a few seconds, scores how it went
-- (damage dealt vs taken, kills, deaths), and remembers which plans work against which player.
-- Plans only change HOW the bot fights (how far it circles, how often it flanks, dodges, punishes, commits).
-- The scores are saved per player (pn_<plan> = decayed episode count, ps_<plan> = decayed score sum).
----------------------------------------------------------------------
X.plans = { cur = nil, name = "Patient", ep = nil, EPISODE = 12, DECAY = 0.93, feint = nil, feintReadyAt = 0, inst = Vector3.zero, trend = Vector3.zero,
	mirror = false, MIRROR_CHANCE = 0.3, theirSwingAt = -9 }
local PL = X.plans
PL.MODS = {
	Patient  = { circle = 1.5, flank = 0.6, dodge = 1.0, punish = 1.0, commitSwings = 2 }, -- stand off, punish their whiffs
	Pressure = { circle = 0.5, flank = 1.0, dodge = 0.7, punish = 1.0, commitSwings = 3 }, -- close in and keep swinging
	Flank    = { circle = 0.9, flank = 2.0, dodge = 0.9, punish = 1.2, commitSwings = 2 }, -- get behind them
	Bait     = { circle = 1.0, flank = 0.5, dodge = 0.4, punish = 1.6, commitSwings = 2 }, -- take their swing, punish hard
	Kite     = { circle = 1.8, flank = 0.4, dodge = 1.2, punish = 1.3, commitSwings = 1 }, -- one swing, then back off out of their reach
	Ambush   = { circle = 2.0, flank = 0.8, dodge = 0.8, punish = 2.2, commitSwings = 2 }, -- wait far off, pounce on any opening
	Brawl    = { circle = 0.3, flank = 0.8, dodge = 0.3, punish = 0.8, commitSwings = 4 }, -- stand toe to toe and trade blows
	Harass   = { circle = 1.0, flank = 1.5, dodge = 1.0, punish = 1.0, commitSwings = 1 }, -- quick in-and-out flanks
	Cover    = { circle = 2.0, flank = 0.2, dodge = 1.4, punish = 1.5, commitSwings = 1 }, -- keep distance, dodge a lot, counter their overreach
	Anchor   = { circle = 1.2, flank = 0.0, dodge = 1.1, punish = 1.8, commitSwings = 1 }, -- hold ground, punish every whiff
	Rush     = { circle = 0.2, flank = 0.5, dodge = 0.5, punish = 1.2, commitSwings = 3 }, -- close fast and keep pressing hurt players
	Slip     = { circle = 1.6, flank = 1.2, dodge = 1.3, punish = 1.0, commitSwings = 1 }, -- slip around them, then strike from behind
	Counter  = { circle = 1.2, flank = 0.6, dodge = 1.6, punish = 2.0, commitSwings = 1 }, -- dodge their swing, hit back the instant they overreach
}
PL.NAMES = { "Patient", "Pressure", "Flank", "Bait", "Kite", "Ambush", "Brawl", "Harass", "Cover", "Anchor", "Rush", "Slip", "Counter" }
for _, n in ipairs(PL.NAMES) do
	table.insert(X.keys, "pn_" .. n)
	table.insert(X.keys, "ps_" .. n)
	table.insert(X.keys, "pd_" .. n)
	table.insert(X.keys, "pk_" .. n)
end
for _, k in ipairs({ "fwN", "fwR", "fdN", "fdR", "turn" }) do table.insert(X.keys, k) end
PL.cur = PL.MODS.Patient

function PL.armN(pr, name) return pr["pn_" .. name] or 0 end
function PL.armMean(pr, name)
	local n = PL.armN(pr, name)
	if n < 1 then return nil end
	return (pr["ps_" .. name] or 0) / n
end

-- pick a plan: untried plans first, then mean score + an exploration bonus that shrinks with experience
function PL.choosePlan(pr)
    -- we're low and they're healthy: stop trading, back off and reset the spacing
    if tHum and humanoid and humanoid.Health / math.max(humanoid.MaxHealth, 1) < 0.4
        and tHum.Health / math.max(tHum.MaxHealth, 1) > 0.6 and math.random() < 0.6 then
        return math.random() < 0.5 and "Kite" or "Cover"
    end
    -- they've beaten us a few times in a row: stop trading blows, keep distance and counter instead
    if (pr.lossRun or 0) >= 2 and math.random() < 0.7 then
        return math.random() < 0.5 and "Cover" or "Anchor"
    end
    -- tryhard: they're nearly dead and we're healthy: press them
    if tHum and humanoid and tHum.Health / math.max(tHum.MaxHealth, 1) < 0.35
        and humanoid.Health / math.max(humanoid.MaxHealth, 1) > 0.6 and math.random() < 0.5 then
        return "Rush"
    end
	local total = 0
	for _, name in ipairs(PL.NAMES) do total += PL.armN(pr, name) end
	local eps = 0.03 + 0.12 * 20 / (20 + total) -- explore a lot early, settle down as we learn this player
	local function allowed(name)
		local n = PL.armN(pr, name)
		if name == "Brawl" and total >= 6 and (pr.trade or 0) < 0 then return false end -- don't trade blows with someone we keep losing to
		if n >= 4 and (PL.armMean(pr, name) or 0) < 0.3 then return false end -- drop plans that keep failing
		return true
	end
	if math.random() < eps then
		local pool = {}
		for _, name in ipairs(PL.NAMES) do if allowed(name) then pool[#pool + 1] = name end end
		if #pool > 0 then return pool[math.random(#pool)] end
	end
	local best, bestV = "Patient", -math.huge
	for _, name in ipairs(PL.NAMES) do
		if allowed(name) then
			local n = PL.armN(pr, name)
			local v
			if n < 1 then
				v = 1 + math.random() * 0.1 -- try it at least once
			else
				v = PL.armMean(pr, name) + 0.45 * math.sqrt(math.log(total + 2) / (n + 1))
					- 0.3 * ((pr["pd_" .. name] or 0) / (n + 2)) + 0.25 * ((pr["pk_" .. name] or 0) / (n + 1))
					+ (math.random() - 0.5) * 0.05
			end
			if v > bestV then best, bestV = name, v end
		end
	end
	return best
end

-- every plan choice goes through here:
--  * don't repeat the plan we last died on against this player for 90 seconds (that's how we keep losing the same way)
--  * when they're clearly winning the record against us, lean defensive for a share of the picks
function PL.pick(pr)
	local name = PL.choosePlan(pr)
	if pr.deathPlan and name == pr.deathPlan and time() - (pr.deathAt or 0) < 90 then
		local alts = {}
		for _, n in ipairs(PL.NAMES) do
			if n ~= pr.deathPlan then alts[#alts + 1] = n end
		end
		name = alts[math.random(#alts)]
	end
	if (pr.recW + pr.recL) >= 4 and edgeOf(pr) < 0.35 and math.random() < 0.3 then
		name = math.random() < 0.5 and "Cover" or "Counter"
	end
	return name
end

-- what we expect from this player: the best plan's average score (0.5 when nothing is known yet)
function PL.value(pr)
	local best = nil
	for _, name in ipairs(PL.NAMES) do
		if PL.armN(pr, name) >= 2 then
			local m = PL.armMean(pr, name)
			if not best or m > best then best = m end
		end
	end
	return best or 0.5
end

-- the plan that has worked best so far against this player (nil until we have enough episodes)
function PL.bestFor(pr)
	local best, bestM = nil, -math.huge
	for _, name in ipairs(PL.NAMES) do
		if PL.armN(pr, name) >= 2 then
			local m = PL.armMean(pr, name)
			if m > bestM then best, bestM = name, m end
		end
	end
	return best
end

function PL.start(name, pr, now)
	PL.name, PL.cur = name, PL.MODS[name]
	-- sometimes copy them: swing right after they swing, and turn on their strafe rhythm (only with enough of their habits seen)
	PL.mirror = pr.theirSwings >= 5 and (pr.flips or 0) >= 4 and math.random() < PL.MIRROR_CHANCE
	if PL.mirror and X.log then X.log("copying " .. (target and target.Name or "?") .. "'s rhythm this episode") end
	PL.ep = {
		name = name, pr = pr, t0 = now,
		dealt0 = fight.dealt, taken0 = fight.taken,
		tMax = math.max(tHum and tHum.MaxHealth or 100, 1),
		myMax = math.max(humanoid and humanoid.MaxHealth or 100, 1),
	}
end

-- score the episode that just ended and fold it into this player's record
-- reason: "time" (normal end), "kill" (we got the kill), "died" (we died), anything else is discarded
function PL.close(reason)
	local ep = PL.ep
	PL.ep = nil
	if not ep then return end
	local elapsed = time() - ep.t0
	if reason ~= "kill" and reason ~= "died" and elapsed < 2 then return end
	local dealt = (fight.dealt - ep.dealt0) / ep.tMax   -- fraction of their max health we took
	local taken = (fight.taken - ep.taken0) / ep.myMax  -- fraction of our max health they took
	-- neutral trade = 0.5; winning the damage race lifts it, losing it lowers it. Kills and deaths move it hard
	-- (a death used to set the score to 0 and throw away how the trade actually went)
	local r = math.clamp(0.5 + 0.5 * (dealt - taken), 0, 1)
	if reason == "kill" then r = math.min(1, r + 0.3) end
	local pr, name, d = ep.pr, ep.name, PL.DECAY
	if reason == "died" then
		r = math.max(0, r - 0.35)
		pr.deathPlan, pr.deathAt = name, time()
	end
	pr.trade = ema(pr.trade or 0, math.clamp(dealt - taken, -1, 1), 0.2) -- who wins the damage trade vs this player
	pr["pn_" .. name] = PL.armN(pr, name) * d + 1
	pr["ps_" .. name] = (pr["ps_" .. name] or 0) * d + r
	pr["pd_" .. name] = (pr["pd_" .. name] or 0) * d + (reason == "died" and 1 or 0)
	pr["pk_" .. name] = (pr["pk_" .. name] or 0) * d + (reason == "kill" and 1 or 0)
	if X.log then
		X.log(string.format("plan %s vs %s: score %.2f (dealt %d%%, taken %d%%, %s)",
			name, (target and target.Name or "?"), r, math.floor(dealt * 100), math.floor(taken * 100), reason))
	end
end

-- how long this plan gets: longer while it's winning the trade, longer when the target is low (so we finish them)
function PL.episodeLength(ep)
	local len = PL.EPISODE
	local lead = (fight.dealt - ep.dealt0) / ep.tMax - (fight.taken - ep.taken0) / ep.myMax
	if lead > 0.2 then len *= 1.5 end
	if tHum and tHum.Health / math.max(tHum.MaxHealth, 1) < 0.25 then len *= 1.3 end
	return len
end

-- called every frame in melee: starts a plan, and re-plans when the current one has run its course
function PL.tick(now, pr)
	if not pr then return end
	local ep = PL.ep
	if not ep or ep.pr ~= pr then
		PL.start(PL.pick(pr), pr, now)
	elseif now - ep.t0 > PL.episodeLength(ep) then
		PL.close("time")
		PL.start(PL.pick(pr), pr, now)
	elseif now - ep.t0 > 3 then
		-- losing the damage race badly on this plan: switch now instead of riding it out
		local dealt = (fight.dealt - ep.dealt0) / ep.tMax
		local taken = (fight.taken - ep.taken0) / ep.myMax
		if taken - dealt > 0.35 then
			PL.close("bail")
			PL.start(PL.pick(pr), pr, now)
		end
	end
end

-- which feint to try: "fw" = step back so their swing whiffs, "fd" = step in so they sidestep. Try both first, then go with what works.
function PL.pickFeint(pr)
	local wn, dn = pr.fwN or 0, pr.fdN or 0
	if wn < 2 and dn < 2 then return math.random() < 0.5 and "fw" or "fd" end
	if math.random() < 0.2 then return math.random() < 0.5 and "fw" or "fd" end
	return (pr.fwR or 0.35) >= (pr.fdR or 0.35) and "fw" or "fd"
end
-- CHAT: stat lines only. Each line reports a number the bot already tracks (kills, deaths, streaks, K/D, ping, FPS)
-- and goes out when a milestone is reached, never on every kill or death.
X.chat = { queue = {}, pumping = false, lastMsg = nil, lastAt = -100, kdSide = nil, kdAt = -100,
	pingN = 0, pingHigh = false, fpsN = 0, fpsLow = false, tickAt = 0 }

-- one line at a time, at least ChatCooldown apart. Up to 13 lines wait in the queue (the oldest is dropped beyond that)
function X.chat.send(msg)
	if not CONFIG.ChatMessages or not msg or msg == "" then return end
	local q = X.chat.queue
	if msg == X.chat.lastMsg or q[#q] == msg then return end
	q[#q + 1] = msg
	while #q > 13 do table.remove(q, 1) end
	if X.chat.pumping then return end
	X.chat.pumping = true
	task.spawn(function()
		while #X.chat.queue > 0 do
			local wait = CONFIG.ChatCooldown - (time() - X.chat.lastAt)
			if wait > 0 then task.wait(wait) end
			local m = table.remove(X.chat.queue, 1)
			if m then
				task.wait(rand(0.8, 2)) -- like a person typing
				X.chat.lastMsg, X.chat.lastAt = m, time()
				local sent = pcall(function()
					game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(m)
				end)
				if not sent then
					pcall(function()
						game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest"):FireServer(m, "All")
					end)
				end
				if X.log then X.log("chat: " .. m) end
			end
		end
		X.chat.pumping = false
	end)
end

-- a count reached one of the milestones (counts only go up by one, so an exact match is enough)
function X.chat.isMilestone(n, list)
	for _, m in ipairs(list or CONFIG.ChatMilestones) do
		if n == m then return true end
	end
	return false
end

function X.chat.kdText(k, d)
	if d == 0 then return k == 0 and "0.00" or "no deaths yet" end
	return string.format("%.2f", k / d)
end

-- overall K/D crossing 1.0 (either way), at most once a minute
function X.chat.checkKD()
	local k, d = X.sess.kills, deaths
	if k + d == 0 then return end
	local side = k >= d
	if X.chat.kdSide ~= nil and side ~= X.chat.kdSide and time() - X.chat.kdAt > 60 and CONFIG.ChatKDFlips then
		X.chat.kdAt = time()
		X.chat.send(string.format(X.chat.pick("kdflip", X.chat.pools.kdflip), X.chat.kdText(k, d), k, d))
	end
	X.chat.kdSide = side
end

-- we got a KO (only real kills are counted here, not assists)
function X.chat.onKill(p, pr)
	local name = p and p.Name or "them"
	if X.chat.isMilestone(pr.wins) then
		X.chat.send(string.format(X.chat.pick("killMile", X.chat.pools.killMile), pr.wins, name, pr.wins, pr.losses))
	end
	if X.chat.isMilestone(X.sess.kills) then
		X.chat.send(string.format(X.chat.pick("killSess", X.chat.pools.killSess), X.sess.kills, X.chat.kdText(X.sess.kills, deaths)))
	end
	if X.chat.isMilestone(X.sess.streak, CONFIG.ChatStreaks) then
		X.chat.send(string.format(X.chat.pick("streak", X.chat.pools.streak), X.sess.streak))
	end
	X.chat.checkKD()
	X.chat.afterKill(p, pr)
end

-- we died (any death, overall)
function X.chat.onDeath()
	if X.chat.isMilestone(deaths) then
		X.chat.send(string.format(X.chat.pick("death", X.chat.pools.death), deaths, X.chat.kdText(X.sess.kills, deaths)))
	end
	X.chat.checkKD()
end

-- we died to this player (their blow was the last one)
function X.chat.onLoss(pr, name)
	if X.chat.isMilestone(pr.losses) then
		X.chat.send(string.format(X.chat.pick("lossTo", X.chat.pools.lossTo), pr.losses, name or "them", pr.wins, pr.losses))
	end
	X.chat.afterLoss(pr, name)
end

-- ping and FPS: each reported once when it stays bad for a few seconds, then re-arms after it recovers
function X.chat.tick(now)
	if now - X.chat.tickAt < 1 then return end
	X.chat.tickAt = now
	if enabled then X.chat.adaptTick(now) X.chat.statTick(now) end
	if not enabled then return end
	if CONFIG.ChatOnlyInFights and not (target and inCombat) then
		X.chat.pingN, X.chat.fpsN = 0, 0
		return
	end
	local ping = X.ping()
	if ping then
		if ping > CONFIG.ChatHighPing then X.chat.pingN += 1 else X.chat.pingN = 0 end
		if X.chat.pingN >= 3 and not X.chat.pingHigh then
			X.chat.pingHigh = true
			X.chat.send(string.format(X.chat.pick("ping", X.chat.pools.ping), ping))
		elseif ping < CONFIG.ChatHighPing * 0.8 then
			X.chat.pingHigh = false
		end
	end
	local fps = math.floor(X.fps + 0.5)
	if fps < CONFIG.ChatLowFps then X.chat.fpsN += 1 else X.chat.fpsN = 0 end
	if X.chat.fpsN >= 3 and not X.chat.fpsLow then
		X.chat.fpsLow = true
		X.chat.send(string.format(X.chat.pick("fps", X.chat.pools.fps), fps))
	elseif fps > CONFIG.ChatLowFps * 1.2 then
		X.chat.fpsLow = false
	end
end

-- ============================================================================
-- CHAT LINES: teasing after kills/losses, style call-outs, extra stats, learned adaptations.
-- Teasing stays about the game (mild, never about the person's life, family, looks or identity).
-- Every line is picked at random without repeating the last one from its group, and goes through X.chat.send
-- (so the cooldown and the queue still apply).
-- ============================================================================
-- grow a list of lines: every line in base gets each prefix in mods (keeps %s/%d placeholders intact)
local function grow(base, mods)
	local out, seen = {}, {}
	for _, m in ipairs(mods) do
		for _, b in ipairs(base) do
			local line = m .. b
			if not seen[line] then seen[line] = true out[#out + 1] = line end
		end
	end
	return out
end
local CHAT_MODS = { "", "honestly, ", "ha, ", "heh, " }

X.chat.pools = {
	mean = {
		"that was too easy, try harder",
		"you swing like you're waiting for a bus",
		"nice try, but that's not how you dodge",
		"that's the best you've got?",
		"aww, you almost had me",
		"too slow, buddy",
		"you dodged that? lucky",
		"keep practicing, you'll get there",
		"not bad, but not good either",
		"you're fun to fight, I'll give you that",
		"I'll go easy on you... not really",
		"that's a lot of running for one kill",
		"my sword's getting bored",
		"slow reflexes detected",
		"back to the training grounds, rookie",
		"that one was free",
		"you really thought that would work?",
		"you're not even trying, are you",
		"your timing needs work",
		"so close, that was almost a fight",
		"come back when you've got some combos",
		"sit down, I'm just warming up",
		"you're doing great... for a warm-up",
		"my grandma swings faster, no offense",
		"you need more practice, I can wait",
			"tough luck, that one was on you",
			"you walked right into that",
			"I was expecting more from you",
			"you're getting closer to a kill, just not on me",
			"I'm not even breaking a sweat",
			"that dodge was a bit late",
			"try swinging when the blade is up, maybe",
			"you look lost, need directions to the fight?",
			"I can see you thinking about dodging, too late",
			"that's a nice try, but the sword wins",
			"my turn, I think",
			"keep your head up, or I'll take it",
			"that was almost a good attack",
			"you're improving, slowly",
			"I've been waiting for you to get it right",
			"that's one for the scoreboard",
			"your streak is looking a bit short",
			"hold still, it'll be quicker",
			"you're going to have to move faster than that",
			"I'll give you a hint: dodging helps",
	},
	loss = {
		"nice hit, you got me that time",
		"lucky one, rematch?",
		"okay, that was good. don't get used to it",
		"you got me, I'll be back",
		"good game, that was a clean one",
		"alright, you earned that one",
		"I'll remember that, next time is mine",
		"nice timing, I didn't see that coming",
		"you win this one, I'm not done",
		"good fight, let's go again",
			"okay, you got me, I'll be more careful",
			"fair hit, nice work",
			"that was a great hit, I'm impressed",
			"you timed that well, good job",
			"that was lucky, but I'll take the loss",
			"your comeback was clean, respect",
			"that one's yours, go get another",
			"well played, I'll be back",
			"that was smooth, I'll step it up",
			"nice combo, I should have dodged earlier",
	},
	style = {
		["kiter"] = {
			"%s, stop backing away and fight me",
			"%s, every time I close in you run, classic kiting",
			"%s, running again? I can wait",
		},
		["aggressive"] = {
			"%s, you come at me hard, I like it",
			"%s, charge all you want, I'm dodging",
			"%s, you're really pushing, let's see if it works",
		},
		["passive"] = {
			"%s, you're just standing there, come on",
			"%s, waiting for me to come to you? I'm coming",
			"%s, you're so still it's almost too easy",
		},
		["heals up and runs"] = {
			"%s, I see you healing and running, nice try",
			"%s, running to heal again? I'll be waiting",
			"%s, you heal and bounce, I'm onto you",
		},
		["jumper"] = {
			"%s, all those jumps won't save you",
			"%s, you hop a lot, I'll wait for you to land",
			"%s, bunny hopping won't stop my sword",
		},
		["orbiter"] = {
			"%s, you're circling me, I can see the pattern",
			"%s, round and round we go",
			"%s, orbiting doesn't help you",
		},
		["waiter"] = {
			"%s, you wait for me to strike first, smart",
			"%s, I see you waiting, so I'll wait too",
			"%s, you like to strike first, I'll remember that",
		},
		["counter-puncher"] = {
			"%s, you hit back right after I hit, I noticed",
			"%s, I'll stop hitting you so you can't counter",
			"%s, counters are cute, I'll dodge them",
		},
		["sniper"] = {
			"%s, you fight from far away, not for long",
			"%s, long range? I'm closing the gap",
			"%s, stop poking from over there",
		},
		["brawler"] = {
			"%s, you're up close, let's go",
			"%s, you want close range? fine",
			"%s, tight quarters suit me too",
		},
		["hit-and-run"] = {
			"%s, tag and leave, I see it",
			"%s, hit and run won't work twice",
			"%s, I'm chasing you down after that tag",
		},
		["turtle"] = {
			"%s, you're turtling, come out",
			"%s, stay in your shell, I'll get you anyway",
			"%s, turtle mode is cute, but I'm coming in",
		},
		["ambusher"] = {
			"%s, you wait in ambush, I'm not walking into it",
			"%s, that ambush spot is obvious",
			"%s, nice ambush, I'll bait you out",
		},
		["hop-dodger"] = {
			"%s, you dodge by hopping back, I'll wait for the landing",
			"%s, hopping away again?",
			"%s, I'm waiting for you to land",
		},
		["zigzagger"] = {
			"%s, zigzagging won't save you",
			"%s, you change direction a lot, I'm predicting you anyway",
			"%s, all that zigzagging is making me dizzy",
		},
	},
	reach = {
		"%s, I got hit from %.1f studs away, that's way past sword range",
		"%s, that reach looks longer than a sword should be",
		"%s, I'm measuring %.1f studs on your hits, something's off with your reach",
		"%s, your hits land from far away, that's more reach than normal",
		"%s, I'm getting hit from %.1f studs, check your sword's reach",
			"%s, your hits keep landing from farther than a sword allows",
			"%s, I measure those hits at %.1f studs, that's too far",
			"%s, that's a long reach for a sword",
			"%s, something's wrong with your reach, check it",
			"%s, I keep getting hit from %.1f studs away",
	},
	reachCount = {
		"%s, that's %d hits from out of sword range now, I'm keeping count",
		"%s, %d far hits so far, your reach is definitely off",
			"%s, %d far hits and counting",
			"%s, that's %d hits from out of range, I'm writing it down",
			"%s, another far hit, that's %d so far",
			"%s, %d hits from way out there, your reach is off",
			"%s, I've lost count... no wait, it's %d",
	},
	adapt = {
		aggressive = {
			"%s, I'm pushing harder now, your standoffs are too long",
			"%s, I'm going in faster on you now",
			"%s, waiting around isn't working, so I'm attacking more",
			"%s, I'm not waiting around anymore, time to push",
			"%s, I'll close the distance faster from now on",
		},
		patient = {
			"%s, I'm being more patient now, my swings keep whiffing",
			"%s, I'll wait for your mistake before I swing",
			"%s, I'm slowing down, you punish rushing",
			"%s, I'm playing it safer now, no rushing in",
			"%s, I'll keep my distance and watch your timing",
		},
		reach = {
			"%s, I'm only swinging from %.1f studs now, the far ones keep missing",
			"%s, I'm closing in to %.1f studs before I swing, far swings whiff",
			"%s, my far swings keep missing, so I'm staying close",
			"%s, I'll only attack when I'm in close range",
		},
		flank = {
			"%s, my back attacks land on you, so I'm going behind you more",
			"%s, you don't see me coming from behind, I'm using that more",
			"%s, I'm circling behind you more, it lands better",
			"%s, your front is safe, I'm going for your back",
		},
		tactic = {
			"%s, %s works best on you, so I'm doing it more",
			"%s, I've figured you out, %s lands the most on you",
			"%s, I'm sticking with %s since it works on you",
			"%s, %s is my go-to against you now",
		},
	},
}

-- extra lines (the grow step below multiplies each by CHAT_MODS, so 25 base lines give ~100 per pool)
local EXTRA_LOSS = {
	"that one got me, but the rematch is on",
	"fair trade, I'll remember that opening",
	"you read my swing well that time",
	"I walked into that one, my mistake",
	"good hit, I'll try a different angle next time",
}
local EXTRA_REACH = {
	"%s, I got tagged from %.1f studs out, that's far for a sword",
	"%s, that hit landed from %.1f studs, check the reach",
	"%s, %.1f studs is way too far for a normal sword hit",
	"%s, your hit reached me from %.1f studs, that's odd",
	"%s, I measured a hit at %.1f studs, something isn't normal",
	"%s, that landed from %.1f studs away, is that your normal reach?",
	"%s, another hit from %.1f studs, your reach looks boosted",
	"%s, %.1f studs for a sword hit is a lot, just saying",
	"%s, my health dropped from %.1f studs out, that's not a sword",
	"%s, your swing hit me from %.1f studs, can you check that?",
	"%s, from %.1f studs away, that's more reach than the blade has",
	"%s, I'm logging a hit at %.1f studs, your reach is high",
	"%s, hits from %.1f studs don't match a sword, just a heads up",
	"%s, got hit from %.1f studs out, check your weapon's reach",
	"%s, I've been tagged from %.1f studs away, that's suspicious",
}
local EXTRA_REACHCOUNT = {
	"%s, %d far hits logged so far, your reach looks off",
	"%s, that's far hit number %d, check your reach",
	"%s, I've counted %d hits from out of range",
	"%s, %d hits from way out there, just noting it",
	"%s, far hits so far: %d, that's not normal",
	"%s, %d out-of-range hits and I'm still counting",
	"%s, that's %d from out of range now",
	"%s, number %d from out of range, check the reach",
	"%s, %d far hits, my log is getting long",
	"%s, I've got %d far hits written down",
	"%s, %d hits landed from outside sword range",
	"%s, the far hit count is %d, your reach is suspicious",
	"%s, %d so far from out of range, just a heads up",
	"%s, another one from far away, that makes %d",
	"%s, %d far hits now, I'd look at your reach",
	"%s, I'm keeping a tally: %d far hits",
	"%s, that's %d hits from out of range, noted",
	"%s, %d far hits recorded, check that reach",
}
local EXTRA_ADAPT = {
	aggressive = "%s, I'm going all in on you now, no more waiting",
	patient = "%s, I'm playing a waiting game against you now",
	reach = "%s, I'll only swing from %.1f studs, further ones miss",
	flank = "%s, I'm sneaking behind you more, it works better",
	tactic = "%s, %s is working best on you, I'm sticking with it",
}
for _, l in ipairs(EXTRA_LOSS) do table.insert(X.chat.pools.loss, l) end
for _, l in ipairs(EXTRA_REACH) do table.insert(X.chat.pools.reach, l) end
for _, l in ipairs(EXTRA_REACHCOUNT) do table.insert(X.chat.pools.reachCount, l) end
for k, l in pairs(EXTRA_ADAPT) do table.insert(X.chat.pools.adapt[k], l) end

X.chat.pools.mean = grow(X.chat.pools.mean, CHAT_MODS)
X.chat.pools.loss = grow(X.chat.pools.loss, CHAT_MODS)
X.chat.pools.reach = grow(X.chat.pools.reach, CHAT_MODS)
X.chat.pools.reachCount = grow(X.chat.pools.reachCount, CHAT_MODS)
for k, lines in pairs(X.chat.pools.style) do X.chat.pools.style[k] = grow(lines, CHAT_MODS) end
for k, lines in pairs(X.chat.pools.adapt) do X.chat.pools.adapt[k] = grow(lines, CHAT_MODS) end

-- templated stat lines (their numbers are filled in at send time), with several wordings each
X.chat.pools.kdflip = {
	"kill/death ratio is now %s (%d kills, %d deaths), good game!", "kill/death ratio flipped to %s (%d kills, %d deaths), nice!",
	"we're at %s now (%d kills, %d deaths), good games!", "kill/death ratio shifts to %s with %d kills and %d deaths, good game!",
}
X.chat.pools.killMile = {
	"%d kills on %s, record %d-%d, good game!", "I've got %d on %s now (record %d-%d), good fights!",
	"%d on %s so far, record %d-%d, nice matches!", "%d kills on %s, the score is %d-%d, good game, friend!",
	"%d kills on %s, record %d-%d, what a rivalry!", "%d on %s now, record %d-%d, keep them coming!",
	"that's %d kills on %s, record %d-%d, nice work!",
}
X.chat.pools.killSess = {
	"%d kills this session, kill/death ratio %s, good game!", "%d kills so far today, kill/death ratio %s, nice!",
	"session kills: %d, kill/death ratio %s, good games!", "%d kills in this session, kill/death ratio %s, keep going!",
	"that's %d kills this session (kill/death ratio %s), good game!", "%d kills and counting, kill/death ratio %s",
	"%d kills this run, kill/death ratio %s, nice fights!",
}
X.chat.pools.streak = {
	"%d kills in a row, nice!", "%d in a row, on a roll!", "streak at %d, good game!",
	"%d kills straight, keep it going!", "that's %d in a row, nice run!", "%d kills without a loss, nice!",
	"%d in a row now, hot streak!",
}
X.chat.pools.death = {
	"%d deaths this session, kill/death ratio %s", "%d deaths so far, kill/death ratio %s, I'll bounce back",
	"session deaths: %d, kill/death ratio %s", "%d deaths now, kill/death ratio %s, rematch soon",
	"that's %d deaths this session (kill/death ratio %s)", "%d deaths in this session, kill/death ratio %s, good game",
}
X.chat.pools.lossTo = {
	"%d deaths to %s so far (record %d-%d), good game", "%d losses to %s now (record %d-%d), good fights",
	"%d times %s got me (record %d-%d), good game", "%d deaths to %s, record %d-%d, rematch?",
	"%d losses against %s, record %d-%d, good games",
}
X.chat.pools.ping = {
	"my ping is high right now (%d milliseconds), sorry if I lag", "lag spike: ping at %d milliseconds, sorry about that",
	"my connection is spiky (%d milliseconds), bear with me", "ping jumped to %d milliseconds, sorry if I'm slow",
	"my ping is up to %d milliseconds, I'll try to keep up",
}
X.chat.pools.fps = {
	"my frame rate is low right now (%d), sorry if my moves look off", "frame rate dipped to %d, my swings may look weird",
	"my frame rate dropped to %d, sorry about the jerky moves", "running at %d frames per second right now, bear with me",
	"low frame rate (%d), sorry if I look laggy",
}
X.chat.pools.void = {
	"saved myself from the void %d times now", "that's %d near-falls I avoided",
	"%d times I pulled back from a bad jump", "%d jump saves so far, careful landings!",
	"another jump saved, that's %d so far",
}

-- more wordings for the templated lines (their numbers are filled in at send time)
X.chat.pools.uptime = X.chat.pools.uptime or {}
local function extendPool(name, lines)
	for _, l in ipairs(lines) do table.insert(X.chat.pools[name], l) end
	X.chat.pools[name] = grow(X.chat.pools[name], CHAT_MODS)
end
extendPool("killMile", {
	"%d kills on %s and still counting, record %d-%d",
	"%d on %s so far, that's a %d-%d record",
	"%d kills on %s, score %d-%d, good fights",
	"%d kills on %s, record %d-%d, what a match",
	"%d kills on %s, record %d-%d, rematch anytime",
	"%d on %s now, record %d-%d, still fun",
	"%d kills against %s, record %d-%d, good game",
	"%d kills on %s, our record is %d-%d, nice",
	"%d on %s, %d-%d on the books, good game",
	"%d kills on %s, record %d-%d, keep it fun",
	"%d kills on %s, I'm at %d-%d, good games",
	"%d on %s, record %d-%d, great rivalry",
	"%d kills on %s, record %d-%d, very good",
	"%d kills on %s so far, %d-%d overall, good game",
	"%d on %s, the record stands at %d-%d",
	"%d kills on %s, the head to head is %d-%d",
	"%d on %s, record %d-%d, let's keep going",
	"%d kills on %s, record %d-%d, nice duels",
	"%d kills on %s, %d-%d overall, thanks for the games",
	"%d on %s, record %d-%d, see you next round",
})
extendPool("killSess", {
	"%d kills this session, kill/death ratio %s, keep it up",
	"%d kills in this session, kill/death ratio %s, nice play",
	"session total: %d kills, kill/death ratio %s, good game",
	"%d kills today, kill/death ratio %s, good session",
	"%d kills so far, kill/death ratio %s, feeling good",
	"%d kills this session (kill/death ratio %s), thanks for the games",
	"%d kills in this run, kill/death ratio %s, good games all",
	"%d kills and counting, kill/death ratio %s, nice",
	"so far this session: %d kills, kill/death ratio %s",
	"%d kills here, kill/death ratio %s, enjoying this",
	"%d kills this session, kill/death ratio %s, good times",
	"%d kills in total, kill/death ratio %s, nice fights",
	"%d kills now, kill/death ratio %s, keep playing",
	"%d kills this session, running at kill/death ratio %s",
	"%d kills total, kill/death ratio %s, good games everyone",
	"%d kills this session, kill/death ratio %s, nice matches",
	"%d kills, kill/death ratio %s, what a session",
	"%d kills so far this session, kill/death ratio %s, cheers",
	"%d kills this session at kill/death ratio %s, good game",
	"%d kills this session, kill/death ratio %s, see you around",
})
extendPool("streak", {
	"%d kills in a row, nice run!",
	"%d in a row, keep the streak alive!",
	"streak: %d, good game!",
	"%d straight kills, on a roll!",
	"that's %d in a row, excellent!",
	"%d kills without dying, nice!",
	"%d in a row, hot streak!",
	"%d kills in a row, can't stop now!",
	"%d straight, that's a good run",
	"streak of %d, good games everyone",
	"%d kills in a row, feeling sharp",
	"%d in a row, I'm locked in",
	"%d kills in a row, what a run",
	"%d straight without a loss, nice",
	"%d in a row, great rhythm",
	"%d kills in a row, the streak is real",
	"%d in a row, keep your guard up",
	"that's %d in a row, very good",
	"%d kills in a row, the swords are singing",
	"%d straight now, enjoy the run",
})
extendPool("death", {
	"%d deaths this session, kill/death ratio %s, I'll be back",
	"%d deaths so far, kill/death ratio %s, rematch soon",
	"session deaths: %d, kill/death ratio %s, good game",
	"%d deaths now, kill/death ratio %s, nice fights",
	"%d deaths this session (kill/death ratio %s), good games",
	"%d deaths in this session, kill/death ratio %s, see you soon",
	"%d deaths, kill/death ratio %s, I'm not out yet",
	"%d deaths so far, kill/death ratio %s, respect",
	"%d deaths this session, running kill/death ratio %s",
	"%d deaths in total, kill/death ratio %s, good game",
	"session tally: %d deaths, kill/death ratio %s",
	"%d deaths, kill/death ratio %s, next one's mine",
	"%d deaths so far, kill/death ratio %s, keep it friendly",
	"%d deaths this session, kill/death ratio %s, well fought",
	"%d deaths, kill/death ratio %s, I'll study your moves",
	"%d deaths so far, kill/death ratio %s, nice play",
	"%d deaths this session (kill/death ratio %s), let's go again",
	"%d deaths, kill/death ratio %s, good match",
	"%d deaths in this session, kill/death ratio %s, respect",
	"%d deaths, kill/death ratio %s, good game, see you",
})
extendPool("lossTo", {
	"%d losses to %s, record %d-%d, good game",
	"%d times %s beat me (record %d-%d), nice",
	"%d deaths to %s, record %d-%d, rematch?",
	"%d losses against %s, record %d-%d, good games",
	"%d times %s got me, record %d-%d, respect",
	"%d deaths to %s so far, record %d-%d, nice fights",
	"%d losses to %s, the record is %d-%d",
	"%d times %s won, record %d-%d, good game",
	"%d against %s now, record %d-%d, well played",
	"%d losses to %s, record %d-%d, I'll get one back",
	"%d deaths to %s, record %d-%d, good duel",
	"%d times %s came out on top, record %d-%d",
	"%d losses to %s, record %d-%d, keep at it",
	"%d deaths to %s, record %d-%d, good game, friend",
	"%d times %s got the better of me, record %d-%d",
	"%d losses to %s, %d-%d overall, nice work",
	"%d deaths to %s, record %d-%d, see you next time",
	"%d times %s beat me, record %d-%d, fair",
	"%d losses to %s, record %d-%d, good fights",
	"%d deaths to %s, record %d-%d, rematch soon",
})
extendPool("kdflip", {
	"kill/death ratio is now %s (%d kills, %d deaths), nice!",
	"kill/death ratio flipped to %s (%d kills, %d deaths), good game",
	"we're at %s now (%d kills, %d deaths), good games",
	"kill/death ratio shifts to %s with %d kills and %d deaths, nice",
	"kill/death ratio's at %s now (%d kills, %d deaths), keep going",
	"kill/death ratio moved to %s (%d kills, %d deaths), good games all",
	"new kill/death ratio: %s (%d kills, %d deaths), nice fights",
	"kill/death ratio is %s now, %d kills and %d deaths, good game",
	"kill/death ratio hit %s (%d kills, %d deaths), good stuff",
	"kill/death ratio changed to %s (%d kills, %d deaths), well played",
	"kill/death ratio now %s with %d kills and %d deaths, nice",
	"we just crossed over, kill/death ratio %s (%d kills, %d deaths)",
	"kill/death ratio swings to %s (%d kills, %d deaths), good game",
	"kill/death ratio reads %s now (%d kills, %d deaths), cheers",
	"kill/death ratio at %s (%d kills, %d deaths), feeling good",
	"kill/death ratio is %s (%d kills, %d deaths), nice session",
	"kill/death ratio now sits at %s (%d kills, %d deaths), good game",
	"kill/death ratio moved to %s, %d kills against %d deaths, good games",
	"kill/death ratio flipped: %s (%d kills, %d deaths), nice",
	"kill/death ratio is at %s now (%d kills, %d deaths), keep it up",
})
extendPool("ping", {
	"my ping is high right now (%d milliseconds), sorry if I lag",
	"lag spike: ping at %d milliseconds, sorry about that",
	"my connection is spiky (%d milliseconds), bear with me",
	"ping jumped to %d milliseconds, sorry if I'm slow",
	"my ping is up to %d milliseconds, I'll try to keep up",
	"ping is %d milliseconds right now, sorry for the lag",
	"my ping spiked to %d milliseconds, bear with me",
	"connection's rough, ping at %d milliseconds, sorry",
	"high ping right now (%d milliseconds), apologies",
	"my ping is %d milliseconds, sorry if the hits feel late",
	"lagging a bit, ping at %d milliseconds, sorry",
	"ping's at %d milliseconds, my swings may be late",
	"sorry, ping is %d milliseconds, I'm trying to keep up",
	"my ping is %d milliseconds, the fights may feel off",
	"ping jumped to %d milliseconds, sorry about the delay",
	"my connection is at %d milliseconds, bear with me a sec",
	"high ping (%d milliseconds), sorry for any lag",
	"my ping went up to %d milliseconds, sorry",
	"lag from my side, ping %d milliseconds, sorry",
	"ping %d milliseconds right now, my moves may lag",
})
extendPool("fps", {
	"my frame rate is low right now (%d), sorry if my moves look off",
	"frame rate dipped to %d, my swings may look weird",
	"my frame rate dropped to %d, sorry about the jerky moves",
	"running at %d frames per second right now, bear with me",
	"low frame rate (%d), sorry if I look laggy",
	"frame rate is down to %d, sorry for the choppy moves",
	"my frame rate is %d right now, bear with me",
	"only %d frames per second here, sorry about the stutter",
	"frame rate at %d, my moves might look stuttery",
	"my game is running at %d frames per second, sorry",
	"%d frames per second right now, my fights may look rough",
	"frame rate fell to %d, apologies for the jitter",
	"my frame rate is %d, sorry if I'm slow to react",
	"low frame rate (%d), sorry if I stutter",
	"frame rate dipped to %d, my swings may look off",
	"my frame rate sits at %d right now, sorry",
	"%d frames per second, apologies for the choppiness",
	"my game is at %d frames per second, sorry for the lag",
	"frame rate down to %d, bear with my moves",
	"running at %d frames per second, sorry it looks rough",
})
extendPool("void", {
	"saved myself from the void %d times now",
	"that's %d near-falls I avoided",
	"%d times I pulled back from a bad jump",
	"%d jump saves so far, careful landings!",
	"another jump saved, that's %d so far",
	"%d bad jumps called off so far",
	"%d near-falls avoided, nice footwork",
	"that's %d jumps I didn't take into the void",
	"%d times I stopped a bad jump, phew",
	"%d jump saves, the void keeps missing",
	"%d near-void moments avoided so far",
	"%d jumps I called off, careful landing",
	"%d saves from the void, not bad",
	"%d times I backed out of a bad leap",
	"%d jump saves so far, keep it safe",
	"that's %d bad landings avoided",
	"%d near-falls, I'm getting careful",
	"%d jumps called off before they hurt",
	"%d void saves, I'm watching my landings",
	"%d jump saves logged, safe and sound",
})
extendPool("uptime", {
	"%d minutes in: %d kills, %d deaths, kill/death ratio %s",
	"%d minutes in, %d kills and %d deaths, kill/death ratio %s",
	"%d minutes so far: %d kills, %d deaths (kill/death ratio %s)",
	"%d minutes played: %d kills, %d deaths, kill/death ratio %s",
	"%d minutes in with %d kills, %d deaths, kill/death ratio %s",
	"time check: %d minutes, %d kills, %d deaths, kill/death ratio %s",
	"%d minutes on the clock: %d kills, %d deaths, kill/death ratio %s",
	"%d minutes of play: %d kills, %d deaths, kill/death ratio %s",
	"session clock: %d minutes, %d kills, %d deaths, kill/death ratio %s",
	"%d minutes in, %d kills, %d deaths, kill/death ratio %s, still going",
	"%d minutes: %d kills, %d deaths, kill/death ratio %s",
	"%d minutes in and at %d kills, %d deaths, kill/death ratio %s",
	"uptime %d minutes: %d kills, %d deaths, kill/death ratio %s",
	"%d minutes running: %d kills, %d deaths, kill/death ratio %s",
	"%d minutes so far, %d kills, %d deaths, kill/death ratio %s",
	"%d minutes in, %d kills, %d deaths, kill/death ratio %s, nice",
	"%d minutes played: %d kills, %d deaths, kill/death ratio %s, good game",
	"%d minutes, %d kills, %d deaths, kill/death ratio %s, enjoying it",
	"%d minutes in: %d kills, %d deaths, kill/death ratio %s, keep it fun",
	"%d minutes so far, %d kills, %d deaths, kill/death ratio %s, nice",
	"%d minutes in: %d kills, %d deaths, kill/death ratio %s, good games all",
	"%d minutes, %d kills, %d deaths, kill/death ratio %s, keep going",
	"%d minutes in: %d kills, %d deaths, kill/death ratio %s, cheers",
	"%d minutes in, %d kills, %d deaths, kill/death ratio %s, nice session",
})
extendPool("kdflip", { "kill/death ratio lands on %s (%d kills, %d deaths), good game" })
X.chat.pools.summary = X.chat.pools.summary or {}
extendPool("summary", {
	"session over: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"that's a wrap: %d minutes played, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"session summary: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak of %d",
	"%d minutes in total: %d kills and %d deaths, kill/death ratio %s, longest streak %d",
	"signing off after %d minutes: %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"thanks for the games! %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"final tally: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"%d minutes, %d kills, %d deaths, kill/death ratio %s, best run of %d in a row",
	"wrapping up: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"session stats: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"good session: %d minutes, %d kills, %d deaths, kill/death ratio %s, longest streak %d",
	"that's all for now: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"%d minutes played, %d kills, %d deaths, kill/death ratio %s, best streak of %d, good games",
	"done for now: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"logging off after %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"thanks everyone, %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"session recap: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"%d minutes in: %d kills, %d deaths, kill/death ratio %s, best streak %d, see you next time",
	"session closed: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"signing out: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"total time %d minutes: %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"that's the session: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"%d minutes of play, %d kills, %d deaths, kill/death ratio %s, best streak %d, thanks",
	"final numbers: %d minutes, %d kills, %d deaths, kill/death ratio %s, best streak %d",
	"session ended after %d minutes: %d kills, %d deaths, kill/death ratio %s, best streak %d",
})
extendPool("uptime", { "%d minutes in, %d kills, %d deaths, kill/death ratio %s, see you later" })
-- the tactic names the bot learns, as they read in chat
X.chat.tacticLabels = { Committing = "charging in", Circling = "circling", Backstab = "sneaking behind", Punish = "punishing your whiffs" }

-- extra stat lines: each returns a sentence, or nil while it doesn't have enough data yet
X.chat.statLines = {
	function() if X.stats.ttkCount < 1 then return nil end return string.format("%d kills so far, an average kill takes me %.1fs", X.sess.kills, X.stats.ttkSum / X.stats.ttkCount) end,
	function() if X.stats.combatTime < 5 then return nil end return string.format("I'm doing %.1f damage per second in fights", X.stats.dealt / X.stats.combatTime) end,
	function() if X.stats.swSeen < 5 then return nil end return string.format("I dodge %d%% of your swings", math.floor(X.stats.dodgedSw / X.stats.swSeen * 100 + 0.5)) end,
	function() if X.sess.up < 30 then return nil end return string.format("I've spent %d%% of my time in fights", math.floor(X.sess.combat / X.sess.up * 100 + 0.5)) end,
	function() if X.stats.combatFrames < 60 then return nil end return string.format("our fights happen about %.0f studs apart on average", X.stats.distSum / X.stats.combatFrames) end,
	function() if not profile or profile.wins + profile.losses < 2 then return nil end return string.format("my record against %s: %d-%d", target and target.Name or "them", profile.wins, profile.losses) end,
	function() if X.sess.up < 60 then return nil end return string.format("%.1f kills per minute right now", X.sess.kills / (X.sess.up / 60)) end,
	function() if X.sess.best < 2 then return nil end return string.format("best streak this session: %d in a row", X.sess.best) end,
	function() return string.format("%d assists so far (kills someone else finished)", X.sess.assists) end,
	function() return string.format("my frame rate is at %d right now", math.floor(X.fps + 0.5)) end,
	function() if X.stats.engages < 2 then return nil end return string.format("%d fights started so far", X.stats.engages) end,
	function() return string.format("my kill/death ratio is %s right now", X.chat.kdText(X.sess.kills, deaths)) end,
}

X.chat.picks = {}
X.chat.tauntAt, X.chat.adaptAt, X.chat.statKills = -100, -100, 0
-- random pick from a list, never the same entry twice in a row for the same group
function X.chat.pick(key, list)
	local n = #list
	if n == 0 then return nil end
	local i = math.random(n)
	if n > 1 and i == X.chat.picks[key] then i = i % n + 1 end
	X.chat.picks[key] = i
	return list[i]
end

-- teasing after a kill / a loss: sometimes, and not too often
function X.chat.afterKill(p, pr)
	if not CONFIG.ChatMean or math.random() > CONFIG.ChatTauntChance then return end
	if time() - X.chat.tauntAt < CONFIG.ChatTauntCooldown then return end
	X.chat.tauntAt = time()
	X.chat.send(X.chat.pick("mean", X.chat.pools.mean))
end
function X.chat.afterLoss(pr, name)
	if not CONFIG.ChatMean or math.random() > CONFIG.ChatTauntChance then return end
	if time() - X.chat.tauntAt < CONFIG.ChatTauntCooldown then return end
	X.chat.tauntAt = time()
	X.chat.send(X.chat.pick("loss", X.chat.pools.loss))
end

-- the style check just settled on a style for this player: say so once per style per player
function X.chat.onStyle(pr, style)
	if not CONFIG.ChatStyleLines or not pr or style == "balanced" then return end
	local lines = X.chat.pools.style[style]
	if not lines then return end
	pr.chatStyles = pr.chatStyles or {}
	if pr.chatStyles[style] then return end
	pr.chatStyles[style] = true
	local who = pr.name or (target and target.Name) or "you"
	X.chat.send(string.format(X.chat.pick("style:" .. style, lines), who))
end

-- every few kills: one stat line; every few minutes: an uptime line
function X.chat.statTick(now)
	if not CONFIG.ChatStats then return end
	if X.sess.kills >= X.chat.statKills + CONFIG.ChatStatEvery then
		X.chat.statKills = X.sess.kills
		for _ = 1, 4 do -- a line may not have enough data yet: try another
			local f = X.chat.pick("stat", X.chat.statLines)
			local ok, text = pcall(f)
			if ok and text then X.chat.send(text) break end
		end
	end
	if not X.chat.statAt then X.chat.statAt = now end
	if now - X.chat.statAt >= CONFIG.ChatUptimeEvery and X.sess.up > 60 then
		X.chat.statAt = now
		X.chat.send(string.format(X.chat.pick("uptime", X.chat.pools.uptime), math.floor(X.sess.up / 60), X.sess.kills, deaths, X.chat.kdText(X.sess.kills, deaths)))
	end
end

-- learned adaptations about the current target: aggression, reach, flanking, and which tactic works best
function X.chat.adaptTick(now)
	local pr = profile
	if not pr or not target or not CONFIG.ChatAdaptLines then return end
	local who = target.Name
	-- one adaptation line per ChatAdaptCooldown; a change that couldn't be said yet is said later
	local function say(pool, ...)
		if now - X.chat.adaptAt < CONFIG.ChatAdaptCooldown then return false end
		X.chat.adaptAt = now
		X.chat.send(string.format(X.chat.pick("adapt:" .. pool, X.chat.pools.adapt[pool]), ...))
		return true
	end
	-- 1. aggression: the learning note (more aggressive / more patient)
	if pr.adaptNote ~= pr.chatNote then
		if pr.adaptNote == nil or say(pr.adaptNote == "more aggressive" and "aggressive" or "patient", who) then
			pr.chatNote = pr.adaptNote
		end
	end
	-- 2. reach: the bot has pulled its swing range in (or back out)
	local r = X.reach(pr)
	if pr.chatReach == nil then pr.chatReach = r end
	if math.abs(r - pr.chatReach) > 0.4 and r < CONFIG.AttackRange then
		if say("reach", who, r) then pr.chatReach = r end
	end
	-- 3. flanking: back attacks have started landing on this player
	local e = X.tacticEdge(pr, "Backstab")
	local flankOn = e ~= nil and e > 0.12
	if flankOn and not pr.chatFlank then
		if say("flank", who) then pr.chatFlank = true end
	elseif not flankOn then
		pr.chatFlank = false
	end
	-- 4. the tactic that lands best on this player
	local bestName, bestRate
	for k, v in pairs(pr.tact) do
		if v.n >= 6 and (not bestRate or v.rate > bestRate) then bestName, bestRate = k, v.rate end
	end
	if bestName and bestName ~= pr.chatBest then
		if say("tactic", who, X.chat.tacticLabels[bestName] or string.lower(bestName)) then pr.chatBest = bestName end
	end
end

-- learning speed: a plain running average while we have few observations (first ones count a lot), settling at `floor`
local function rate(n, floor) return math.max(floor, 1 / (n + 2)) end

-- WHO GOT THE KILL? Roblox swords tag the victim's Humanoid with a "creator" ObjectValue on every hit, so the tag at the
-- moment of death says who dealt the last blow. No tag, or a stale one -> NOT counted as a kill (no guessing).
-- who gets the kill. A creator tag (Roblox's record of the last hitter) wins when the game sets one.
-- Games without one: if we hit them shortly before they died, it's ours.
function X.killer(th, ourLastHit, lastHitBy)
	local tag = th:FindFirstChild("creator")
	local v = tag and tag.Value
	if v == player then return true, "creator tag" end
	if typeof(v) == "Instance" and v:IsA("Player") then return false, "killed by " .. v.Name end
	-- no creator tag: whose sword touched them last (any player's tool counts)
	if lastHitBy and time() - lastHitBy.t < 4 then
		if lastHitBy.p == player then return true, "my sword hit last" end
		return false, "sword hit last by " .. lastHitBy.p.Name
	end
	if ourLastHit and time() - ourLastHit < 4 then return true, "my hit landed just before" end
	return false, "no killer tag and no recent sword hit (not counted as a kill)"
end

-- who last touched each humanoid with a sword: any tool that touches a player's body is recorded against its owner
X.lastHitBy = setmetatable({}, { __mode = "k" })
local function onBodyTouched(char, other)
	local tool = other:FindFirstAncestorOfClass("Tool")
	if not tool or not tool.Parent then return end
	local owner = Players:GetPlayerFromCharacter(tool.Parent)
	if not owner then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then X.lastHitBy[hum] = { p = owner, t = time() } end
end
local function watchBody(char)
	local function hook(part)
		if part:IsA("BasePart") then
			table.insert(X.conns, part.Touched:Connect(function(other) onBodyTouched(char, other) end))
		end
	end
	for _, d in ipairs(char:GetDescendants()) do hook(d) end
	table.insert(X.conns, char.DescendantAdded:Connect(hook))
end
local function watchPlayerBodies(p)
	if p.Character then watchBody(p.Character) end
	table.insert(X.conns, p.CharacterAdded:Connect(watchBody))
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayerBodies(p) end
table.insert(X.conns, Players.PlayerAdded:Connect(watchPlayerBodies))

-- OUTCOME LEARNING: how much better (+) or worse (-) has tactic `name` landed on this player than my other swings?
-- nil = not enough swings yet to say.
function X.tacticEdge(pr, name)
	local t = pr.tact[name]
	if not t or t.n < 4 then return nil end
	local sum, n = 0, 0
	for k, v in pairs(pr.tact) do
		if k ~= name then sum += v.rate * v.n n += v.n end
	end
	if n < 4 then return nil end
	return t.rate - sum / n
end

-- how far out I'm willing to swing at this player: if my hits land close in and my far swings keep whiffing, tighten up
function X.reach(pr)
	local r = CONFIG.AttackRange
	if pr.hitN >= 4 and pr.missN >= 4 and pr.hitDist and pr.missDist and pr.missDist > pr.hitDist + 0.4 then
		r = math.max(pr.hitDist + 0.7, CONFIG.AttackRange - 0.3)
	end
	return math.min(r, CONFIG.AttackRange)
end

local function learn(now, dt)
	local pr = profile
	local toThem = flat(tHrp.Position - hrp.Position)
	local d = toThem.Magnitude
	if d < 0.5 or d > 45 then return end
	local fwd = toThem.Unit
	local right = fwd:Cross(UP)
	local speed = tVel.Magnitude
	-- the per-frame smoothing rates below were tuned for 60 FPS; rescale them by frame time so the bot learns a
	-- player at the same pace at 30 FPS and at 144 FPS
	local f = math.clamp(dt * 60, 0.2, 6)
	local function a(base) return 1 - (1 - base) ^ f end

	pr.samples += 1
	pr.observed += dt
	pr.speed = ema(pr.speed, speed, a(0.03))
	pr.idle = ema(pr.idle, speed < 1 and 1 or 0, a(0.02))
	if d < 20 then pr.range = ema(pr.range, d, a(0.02)) end
	-- do THEY start the fights? (closing in on us over about a second, from further out)
	if not pr.lastD or now - (pr.lastDAt or 0) > 0.8 then
		if pr.lastD then pr.approach = ema(pr.approach or 0.3, (d < pr.lastD - 1.5) and 1 or 0, a(0.08)) end
		pr.lastD, pr.lastDAt = d, now
	end
	-- AMBUSH: they stand still, then charge the moment we get close
	if speed < 1 then
		pr.stillSince = pr.stillSince or now
	else
		if pr.stillSince and now - pr.stillSince > 1.5 and d < 9 and tVel:Dot(fwd) > 3 then
			pr.ambush = ema(pr.ambush or 0, 1, a(0.1))
		end
		pr.stillSince = nil
	end
	-- ZIG-ZAG: quick, repeated changes of direction (a fast sign flip counts)
	if speed > 3 then
		pr.zig = ema(pr.zig or 0, (pr.flipInterval and pr.flips >= 4 and pr.flipInterval < 1.2) and 1 or 0, a(0.03))
	end
	-- do they heal up while away from us? (only compare against the same humanoid)
	if pr.hum == tHum and d > 12 and tHum.Health > (pr.lastHp or 0) + 0.5 then
		pr.heals = ema(pr.heals or 0, 1, a(0.1))
	end
	pr.hum, pr.lastHp = tHum, tHum.Health
	-- ORBIT: their velocity relative to US (our own movement taken out), sideways to us and steady in one direction
	do
		local rel = tVel - nav.vel
		local tang, radial = rel:Dot(right), rel:Dot(fwd)
		local strong = d > 2.5 and d < 12 and math.abs(tang) > 2.5 and math.abs(radial) < 0.5 * math.abs(tang)
		pr.orbit = ema(pr.orbit or 0, strong and 1 or 0, a(0.04))
		pr.orbitSpin = ema(pr.orbitSpin or 0, strong and (tang > 0 and 1 or -1) or 0, a(0.05))
	end
	-- how much their heading swings around (circling / wandering) vs running straight
	if speed > 3 and PL.inst.Magnitude > 1 and PL.trend.Magnitude > 1 then
		pr.turn = ema(pr.turn or 0, 1 - PL.inst.Unit:Dot(PL.trend.Unit), a(0.02))
	end

	if speed > 3 then
		local share = tVel:Dot(right) / speed
		pr.strafeBias = ema(pr.strafeBias, share, a(0.015))
		local sign = share > 0.4 and 1 or (share < -0.4 and -1 or 0)
		if sign ~= 0 then
			if pr.lastSign == 0 then
				pr.lastFlip = now
			elseif sign ~= pr.lastSign then
				local interval = now - pr.lastFlip
				if interval > 0.2 and interval < 4 then
					pr.flipInterval = pr.flipInterval and ema(pr.flipInterval, interval, 0.3) or interval
					pr.flips += 1
				end
				pr.lastFlip = now
			end
			pr.lastSign = sign
		end
		if d < 18 then
			pr.retreat = ema(pr.retreat, (tVel:Dot(fwd) > 1.5) and 1 or 0, a(0.02))
			pr.rush = ema(pr.rush, (tVel:Dot(fwd) < -1.5) and 1 or 0, a(0.02))
		end
	end

	-- do they run away once their own health is low?
	if d < 18 and tHum.Health / math.max(tHum.MaxHealth, 1) < 0.4 then
		pr.lowHpRun = ema(pr.lowHpRun, (tVel:Dot(fwd) > 1.5) and 1 or 0, a(0.05))
		pr.lowSamples += 1
	end

	local air = tHum.FloorMaterial == Enum.Material.Air
	if air and not pr.wasAir then table.insert(pr.jumpTimes, now) end
	pr.wasAir = air
	while #pr.jumpTimes > 0 and now - pr.jumpTimes[1] > 20 do table.remove(pr.jumpTimes, 1) end
	pr.jumpRate = #pr.jumpTimes / math.clamp(pr.observed, 5, 20)
end

local function sampleTarget(now)
	if now - lastSample < 0.05 then return end
	local dt = math.min(now - lastSample, 0.2)
	lastSample = now
	table.insert(history, { t = now, p = tHrp.Position })
	while #history > 2 and now - history[1].t > 1.6 do table.remove(history, 1) end

	local oldest
	for i = 1, #history do
		if now - history[i].t <= 0.35 then oldest = history[i] break end
	end
	local newest = history[#history]
	if oldest and newest ~= oldest and newest.t - oldest.t > 0.1 then
		tVel = tVel:Lerp(flat(newest.p - oldest.p) / (newest.t - oldest.t), 0.6)
	end
	-- prediction inputs: the last step alone, and a longer trend (~1.4s)
	if #history >= 2 then
		local a2, b2 = history[#history - 1], history[#history]
		if b2.t - a2.t > 0.01 then PL.inst = flat(b2.p - a2.p) / (b2.t - a2.t) end
	end
	for i = 1, #history do
		if now - history[i].t <= 1.4 then
			if newest.t - history[i].t > 0.5 then PL.trend = flat(newest.p - history[i].p) / (newest.t - history[i].t) end
			break
		end
	end
	-- turn rate (right-hand, rad/s) and acceleration from the last two velocity estimates (feeds predictedPosition)
	local dtS = now - (PL.lastInstT or now)
	if PL.lastInst and dtS > 0.01 and dtS < 0.3 then
		local a1, a2 = PL.lastInst, PL.inst
		if a1.Magnitude > 2 and a2.Magnitude > 2 then
			local ang = math.atan2(a1.X * a2.Z - a1.Z * a2.X, a1:Dot(a2))
			PL.omega = (PL.omega or 0) + (-ang / dtS - (PL.omega or 0)) * 0.25
		else
			PL.omega = (PL.omega or 0) * 0.8
		end
		PL.accel = (PL.accel or Vector3.zero):Lerp((a2 - a1) / dtS, 0.25)
	end
	PL.lastInst, PL.lastInstT = PL.inst, now
	learn(now, dt)
end

-- how far to trust each velocity estimate, given how this player moves (weights adapt to their pattern)
function PL.predictWeights(pr)
	local wI, wS, wT = 0.2, 0.5, 0.3
	if (pr.turn or 0) > 0.35 then wI, wS, wT = wI * 0.5, wS * 0.7, wT * 0.3 end -- circling/wandering: straight-line guesses are unreliable
	if pr.flips >= 3 and pr.flipInterval and pr.flipInterval < 1.5 then wS, wT = wS + 0.2, wT - 0.1 end -- quick strafing: trust the smoothed speed
	if pr.rush > 0.5 then wI, wT = wI + 0.2, wT - 0.1 end -- charging or retreating: trust the latest step
	wT = math.max(wT, 0.05)
	local tot = wI + wS + wT
	return wI / tot, wS / tot, wT / tot
end
-- Movement prediction: weighted blend of velocity estimates, plus the player's learned direction-flip rhythm.
local function predictedPosition(now, lead)
	local pr = profile
	local pos = tHrp.Position
	local wI, wS, wT = PL.predictWeights(pr)
	local v = PL.inst * wI + tVel * wS + PL.trend * wT
	local disp = v * lead
	-- turning: keep bending the velocity at the rate they've been turning (a curve, not a straight line)
	local w = PL.omega or 0
	if math.abs(w) > 0.25 and v.Magnitude > 3 then
		local h, cur, sum = lead / 4, v, Vector3.zero
		for _ = 1, 4 do
			sum += cur * h
			cur = CFrame.fromAxisAngle(Vector3.yAxis, w * h) * cur
		end
		disp = sum
	end
	-- acceleration: someone speeding up or braking lands further or shorter than their current speed says
	local acc = PL.accel or Vector3.zero
	if acc.Magnitude > 25 then acc = acc.Unit * 25 end
	disp += acc * (lead * lead * 0.25)
	if pr.flipInterval and pr.flips >= 3 and v.Magnitude > 3 and flat(pos - hrp.Position).Magnitude < 14 then
		local fwd = unitOr(flat(pos - hrp.Position), Vector3.zAxis)
		local right = fwd:Cross(UP)
		local lat = right * v:Dot(right)
		local rest = v - lat
		local untilFlip = pr.lastFlip + pr.flipInterval - now
		if untilFlip > -0.15 and untilFlip < lead then
			local t1 = math.max(untilFlip, 0)
			disp = rest * lead + lat * t1 - lat * (lead - t1)
		end
	end
	if disp.Magnitude > 14 then disp = disp.Unit * 14 end
	return pos + disp
end

----------------------------------------------------------------------
-- TARGET SELECTION
----------------------------------------------------------------------
-- Matches the tool's own name AND the names of things inside it, so a renamed
-- ClassicSword is still found (its inner "SwordScript" keeps the keyword).
-- Used for both the bot's own sword and other players' swords.
local function isSwordTool(tool)
	if tool.Name == CONFIG.SwordName then return true end
	local n = tool.Name:lower()
	for _, k in ipairs(CONFIG.SwordKeywords) do
		if n:find(k) then return true end
	end
	for _, child in ipairs(tool:GetChildren()) do
		local cn = child.Name:lower()
		for _, k in ipairs(CONFIG.SwordKeywords) do
			if cn:find(k) then return true end
		end
	end
	return false
end

local hasSword
do
local swordSeen = {}
function hasSword(p)
	local char = p.Character
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Tool") and isSwordTool(c) then
				swordSeen[p.UserId] = time()
				return true
			end
		end
	end
	local t = swordSeen[p.UserId]
	return t ~= nil and time() - t < 3 -- short grace so tool swaps don't drop the target
end

-- ============================================================================
-- REACH CHECK: a sword reaches about 4 studs. If an armed player keeps hurting us from much further away than that,
-- their reach is longer than the sword allows. Each time we lose health we measure how far away the armed player
-- is. Only counted when exactly ONE armed player is within 20 studs, so the hit can't be blamed on the wrong person.
-- ============================================================================
X.reachStats = {} -- [UserId] = { n, far, farHits, flagged, maxD }
function X.reachHit(dmg)
	if not CONFIG.ReachCheck or dmg <= 0 or not hrp then return end
	local nearest, nd, armed = nil, math.huge, 0
	for _, q in ipairs(Players:GetPlayers()) do
		if q ~= player and q.Character then
			local qr = q.Character:FindFirstChild("HumanoidRootPart")
			local qh = q.Character:FindFirstChildOfClass("Humanoid")
			if qr and qh and qh.Health > 0 and hasSword(q) then
				local d = (qr.Position - hrp.Position).Magnitude
				if d < 20 then
					armed += 1
					if d < nd then nearest, nd = q, d end
				end
			end
		end
	end
	if not nearest or armed ~= 1 then return end -- no clear culprit: don't guess
	local r = X.reachStats[nearest.UserId]
	if not r then r = { n = 0, far = 0, farHits = 0, flagged = false, maxD = 0 } X.reachStats[nearest.UserId] = r end
	r.n += 1
	r.maxD = math.max(r.maxD, nd)
	if nd > CONFIG.ReachFarStuds then
		r.far += 1
		r.farHits += 1
	end
	if r.n >= CONFIG.ReachMinSamples and r.far / r.n >= CONFIG.ReachFarRatio and not r.flagged then
		r.flagged = true
		dlog(string.format("reach check: %s hits from far away (%d of %d hits, up to %.1f studs)", nearest.Name, r.far, r.n, r.maxD))
		if CONFIG.ReachChatLines then
			X.chat.send(string.format(X.chat.pick("reach", X.chat.pools.reach), nearest.Name, nd))
		end
	elseif r.flagged and r.farHits > 0 and r.farHits % 10 == 0 and CONFIG.ReachChatLines then
		X.chat.send(string.format(X.chat.pick("reachCount", X.chat.pools.reachCount), nearest.Name, r.farHits))
	end
end

end

local rollsHostile
do
local rolls = {}
function rollsHostile(p)
	local r = rolls[p.UserId]
	if not r or time() > r.expires then
		r = { hostile = math.random() < CONFIG.NoSwordAttackChance, expires = time() + CONFIG.NoSwordRerollTime }
		rolls[p.UserId] = r
	end
	return r.hostile
end
end

local function passesFilters(p, char)
	if char:FindFirstChildOfClass("ForceField") then return false end -- spawn protection
	return true
end

----------------------------------------------------------------------
-- GANKING: spot players who are busy fighting someone else, hurt, weak or exposed
----------------------------------------------------------------------
local G = {
	hp = setmetatable({}, { __mode = "k" }), -- per-player health history (who is taking damage right now)
	on = false, engaged = false, hurt = false, weak = false, turned = false,
	busy = nil, why = nil, loggedWhy = nil, whyAt = 0,
	nextRead = 0, lurkReadyAt = 0, strikeReadyAt = 0,
}
function G.reset()
	G.on, G.engaged, G.hurt, G.weak, G.turned, G.busy, G.why, G.loggedWhy = false, false, false, false, false, nil, nil, nil
	G.nextRead, G.lurkReadyAt, G.strikeReadyAt = 0, 0, 0
end
-- returns: who they're busy with (or nil), taking damage from someone else, low health, we're behind them
function G.read(p, th, tr)
	local now = time()
	local rec = G.hp[p]
	local hpNow = th.Health
	if not rec then
		rec = { hp = hpNow, dropAt = -100 }
		G.hp[p] = rec
	end
	if hpNow < rec.hp - 0.5 then rec.dropAt = now end
	rec.hp = hpNow
	local busy
	for _, q in ipairs(Players:GetPlayers()) do
		if q ~= p and q ~= player then
			local qc = q.Character
			local qr = qc and qc:FindFirstChild("HumanoidRootPart")
			local qh = qc and qc:FindFirstChildOfClass("Humanoid")
			if qr and qh and qh.Health > 0 and flat(qr.Position - tr.Position).Magnitude < CONFIG.GankBusyRange and hasSword(q) then
				busy = q
				break
			end
		end
	end
	local hurt = now - rec.dropAt < 3 and flat(tr.Position - hrp.Position).Magnitude > 7 -- they're losing health and it isn't us
	local weak = hpNow / math.max(th.MaxHealth, 1) < CONFIG.GankWeakBelow
	local toUs = flat(hrp.Position - tr.Position)
	local look = flat(tr.CFrame.LookVector)
	local turned = toUs.Magnitude > 0.5 and look.Magnitude > 0.1 and look.Unit:Dot(toUs.Unit) < -0.2
	return busy, hurt, weak, turned
end
-- how much more attractive a player is as a target because of the openings they're giving
function G.bonus(p, th, tr, d)
	if not CONFIG.Gank or d > 80 then return 0 end
	local busy, hurt, weak, turned = G.read(p, th, tr)
	local b, v = CONFIG.GankBonus, 0
	if busy then v += b.busy end
	if hurt then v += b.hurt end
	if weak then v += b.weak end
	if turned and d < 40 then v += b.turned end
	return v
end

local function pickTarget()
	local best, bestScore
	local hurtRecently = time() - lastHurt < 3
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local char = p.Character
			local th = char and char:FindFirstChildOfClass("Humanoid")
			local tr = char and char:FindFirstChild("HumanoidRootPart")
			if th and tr and th.Health > 0 then
				local d = (tr.Position - hrp.Position).Magnitude
				if d <= CONFIG.SearchRange and passesFilters(p, char) and not X.immune.banned(p) then
					local armed = hasSword(p)
					if armed or rollsHostile(p) then
						local score = d
						if armed then score -= 25 end
						if hurtRecently and armed and d < 18 then score -= 40 end -- fight back
						score -= G.bonus(p, th, tr, d) -- ganking: prefer players who are busy / hurt / exposed
						local prof = X.all[p.UserId]
						if prof and prof.recW + prof.recL >= 1 then score += (0.5 - (edgeOf(prof) + PL.value(prof)) / 2) * 60 end -- losing matchup: avoid; winning: go after them
						local crowd = 0 -- other armed players near them: fighting into a group is how we die
						for _, q in ipairs(Players:GetPlayers()) do
							if q ~= p and q ~= player and q.Character then
								local qr = q.Character:FindFirstChild("HumanoidRootPart")
								local qh = q.Character:FindFirstChildOfClass("Humanoid")
								if qr and qh and qh.Health > 0 and flat(qr.Position - tr.Position).Magnitude < 12 and hasSword(q) then crowd += 1 end
							end
						end
						score += crowd * 25
						-- hurt: don't start fights with someone healthier than us
						local myFrac = humanoid.Health / math.max(humanoid.MaxHealth, 1)
						local theirFrac = th.Health / math.max(th.MaxHealth, 1)
						if myFrac < 0.5 and theirFrac > myFrac + 0.2 then score += (0.5 - myFrac) * 100 end
						if p == target then score -= 10 end -- stickiness
						if not bestScore or score < bestScore then best, bestScore = p, score end
					end
				end
			end
		end
	end
	return best
end

local card, dbg, overLog, setLive, dlog, gui, mainPage, paintSwitch, showTarget, switch, trackMode, updateUI  -- UI names used by the game logic below (kept at top level on purpose)
do
----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
-- UI work must never stop the bot. A UI call that fails (e.g. "cannot access 'Instance' (lacking capability Plugin)")
-- is logged once and skipped, so the combat loop keeps running.
function X.uiCall(f, ...)
	local ok, err = pcall(f, ...)
	if not ok and not X.uiErrShown then
		X.uiErrShown = true
		if X.log then X.log("UI error (bot keeps running): " .. tostring(err)) end
	end
end
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local BG = Color3.fromRGB(14, 16, 24)
local PANEL = Color3.fromRGB(26, 29, 42)
local ACCENT = Color3.fromRGB(124, 140, 255)
local TEXT = Color3.fromRGB(240, 242, 250)
local SUB = Color3.fromRGB(150, 156, 180)
local ON = Color3.fromRGB(52, 211, 153)
local OFF = Color3.fromRGB(64, 68, 88)
local MUTED = Color3.fromRGB(95, 100, 122)
local WARN = Color3.fromRGB(251, 191, 36)
local BAD = Color3.fromRGB(248, 113, 113)

----------------------------------------------------------------------
-- GUI ANIMATION HELPERS (they live on X so they don't use up top-level locals)
----------------------------------------------------------------------
X.ui = {}
do
	local ui = X.ui
	local running = setmetatable({}, { __mode = "k" }) -- object -> { [property list] = tween }
	local STROKE = Color3.fromRGB(60, 64, 84)

	-- tween(obj, seconds, props, style, direction, delay)
	-- A new tween of the same properties on the same object cancels the old one, so quick changes never fight.
	-- CONFIG.AnimateUI = false makes everything instant.
	function ui.tween(obj, t, props, style, dir, delay)
		if CONFIG.AnimateUI == false then
			for k, v in pairs(props) do obj[k] = v end
			return nil
		end
		local reg = running[obj]
		if not reg then reg = {} running[obj] = reg end
		local names = {}
		for k in pairs(props) do names[#names + 1] = k end
		table.sort(names)
		local key = table.concat(names, ",")
		if reg[key] then reg[key]:Cancel() end
		local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
		reg[key] = tw
		tw:Play()
		return tw
	end

	-- press feedback: the button squeezes toward its centre and springs back (touch works too)
	function ui.pressable(btn, hoverColor, baseColor)
		local size, pos = btn.Size, btn.Position
		local dx, dy = size.X.Offset * 0.05, size.Y.Offset * 0.07
		local function set(down)
			ui.tween(btn, down and 0.07 or 0.24, {
				Size = down and UDim2.new(size.X.Scale, size.X.Offset - dx * 2, size.Y.Scale, size.Y.Offset - dy * 2) or size,
				Position = down and UDim2.new(pos.X.Scale, pos.X.Offset + dx, pos.Y.Scale, pos.Y.Offset + dy) or pos,
			}, down and Enum.EasingStyle.Quad or Enum.EasingStyle.Back)
		end
		btn.MouseButton1Down:Connect(function() set(true) end)
		btn.MouseButton1Up:Connect(function() set(false) end)
		btn.MouseLeave:Connect(function()
			set(false)
			if hoverColor then ui.tween(btn, 0.15, { BackgroundColor3 = baseColor }) end
		end)
		if hoverColor then
			btn.MouseEnter:Connect(function() ui.tween(btn, 0.15, { BackgroundColor3 = hoverColor }) end)
		end
	end

	-- on/off: status dot + radar ping, card border colour and a slow "breathing" glow while the bot runs
	function ui.setRunning(on)
		local animate = CONFIG.AnimateUI ~= false
		if ui.dot then ui.tween(ui.dot, 0.25, { BackgroundColor3 = on and ON or OFF }) end
		if ui.stroke then
			ui.tween(ui.stroke, 0.4, { Color = on and STROKE:Lerp(ON, 0.55) or STROKE })
			if ui.breathe then ui.breathe:Cancel() ui.breathe = nil end
			if on and animate then
				ui.breathe = TweenService:Create(ui.stroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 })
				ui.breathe:Play()
			else
				ui.tween(ui.stroke, 0.3, { Transparency = 0.2 })
			end
		end
		if ui.ring then
			if ui.pulse then ui.pulse:Cancel() ui.pulse = nil end
			ui.ring.Size, ui.ring.BackgroundTransparency = UDim2.fromOffset(8, 8), 1
			if on and animate then
				ui.ring.BackgroundTransparency = 0.45
				ui.pulse = TweenService:Create(ui.ring, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
					{ Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1 })
				ui.pulse:Play()
			end
		end
	end

	ui.modeColor = {
		Idle = SUB, Wandering = SUB, Chasing = Color3.fromRGB(129, 140, 248), Circling = Color3.fromRGB(34, 211, 238),
		Committing = BAD, Flanking = Color3.fromRGB(251, 146, 60), Backstab = Color3.fromRGB(251, 146, 60),
		Retreating = WARN, Escaping = WARN, Dodging = WARN, Lurking = Color3.fromRGB(192, 132, 252), Hopping = Color3.fromRGB(244, 114, 182), Lunging = Color3.fromRGB(250, 204, 21), Stalking = Color3.fromRGB(148, 163, 184), Backhopping = Color3.fromRGB(56, 189, 248), Baiting = Color3.fromRGB(163, 230, 53),
		Feinting = Color3.fromRGB(250, 204, 21),
	}
	local AGGRO = { Committing = true, Flanking = true, Backstab = true }

	-- state text slides up when the mode changes; the avatar ring takes the mode's colour (and throbs when attacking)
	function ui.setState(key, text, accent)
		local lbl = ui.stateLabel
		lbl.Text = text
		if ui.stateKey == key then return end
		ui.stateKey = key
		lbl.Position = UDim2.fromOffset(72, 38)
		lbl.TextTransparency = 0.8
		ui.tween(lbl, 0.25, { TextTransparency = 0, Position = UDim2.fromOffset(72, 31) })
		ui.tween(ui.aring, 0.3, { Color = accent or SUB })
		if ui.ringPulse then ui.ringPulse:Cancel() ui.ringPulse = nil end
		if AGGRO[key] and CONFIG.AnimateUI ~= false then
			ui.ringPulse = TweenService:Create(ui.aring, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.9 })
			ui.ringPulse:Play()
		else
			ui.tween(ui.aring, 0.2, { Transparency = 0.4 })
		end
	end

	-- health bar: the fill drops fast, a pale "ghost" bar trails behind it so you can see how big the hit was
	function ui.setHp(frac, col)
		if ui.hpFrac == frac then return end
		local size = UDim2.fromScale(frac, 1)
		if col then ui.tween(ui.hpFill, 0.25, { BackgroundColor3 = col }) end
		if ui.hpFrac and frac < ui.hpFrac then
			ui.tween(ui.hpFill, 0.12, { Size = size })
			ui.tween(ui.hpTrail, 0.5, { Size = size }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.25)
		else
			ui.tween(ui.hpFill, 0.3, { Size = size })
			ui.tween(ui.hpTrail, 0.3, { Size = size })
		end
		ui.hpFrac = frac
	end
	function ui.hpReset()
		ui.hpFrac = 0
		ui.hpFill.Size = UDim2.fromScale(0, 1)
		ui.hpTrail.Size = UDim2.fromScale(0, 1)
	end

	function ui.setAvatar(img)
		local a = ui.avatar
		a.Image = img
		if img == "" then a.ImageTransparency = 0 return end
		a.ImageTransparency = 1
		ui.tween(a, 0.4, { ImageTransparency = 0 })
	end

	-- a new target: avatar pops in, name slides in, the learned-info text fades up
	function ui.targetIn(has)
		if ui.ringPulse then ui.ringPulse:Cancel() ui.ringPulse = nil end
		ui.stateKey = nil
		local n = ui.nameLabel
		n.TextTransparency = 1
		n.Position = UDim2.fromOffset(has and 82 or 76, 12)
		ui.tween(n, 0.35, { TextTransparency = 0, Position = UDim2.fromOffset(72, 12) })
		if has then
			ui.ascale.Scale = 0.5
			ui.tween(ui.ascale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
			ui.aring.Transparency = 1
			ui.tween(ui.aring, 0.4, { Transparency = 0.4 })
			ui.insight.TextTransparency = 1
			ui.tween(ui.insight, 0.5, { TextTransparency = 0 })
		end
	end

	-- a number changed: it pops bigger, flashes a colour and settles back
	function ui.bump(lbl, col)
		ui.tween(lbl, 0.1, { TextSize = 17, TextColor3 = col })
		task.delay(0.1, function()
			ui.tween(lbl, 0.4, { TextSize = 12, TextColor3 = TEXT }, Enum.EasingStyle.Back)
		end)
	end

	-- "+1" that floats up from a tile and fades
	function ui.float(lbl, text, col)
		if CONFIG.AnimateUI == false then return end
		local f = lbl.Parent
		local fl = make("TextLabel", {
			Size = UDim2.fromOffset(f.Size.X.Offset, 16), Position = UDim2.new(f.Position.X.Scale, f.Position.X.Offset, f.Position.Y.Scale, f.Position.Y.Offset - 4),
			BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = col, ZIndex = 5,
		}, f.Parent)
		ui.tween(fl, 0.9, { Position = fl.Position - UDim2.fromOffset(0, 26), TextTransparency = 1 })
		task.delay(1, function() fl:Destroy() end)
	end

	-- brief highlight on a debug tile
	function ui.flash(frame)
		frame.BackgroundColor3 = Color3.fromRGB(62, 66, 92)
		ui.tween(frame, 0.6, { BackgroundColor3 = PANEL })
	end

	-- short notice that drops in from the top of the screen and leaves again
	function ui.toast(text, col)
		local g = ui.gui
		if not g then return end
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -44), Size = UDim2.fromOffset(240, 30),
			BackgroundColor3 = PANEL, BorderSizePixel = 0, ZIndex = 20,
		}, g)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, f)
		make("UIStroke", { Color = col or ACCENT, Thickness = 1, Transparency = 0.4 }, f)
		local bar = make("Frame", {
			Size = UDim2.new(0, 4, 1, -10), Position = UDim2.fromOffset(6, 5), BackgroundColor3 = col or ACCENT,
			BorderSizePixel = 0, ZIndex = 21,
		}, f)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
		make("TextLabel", {
			Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(18, 0), BackgroundTransparency = 1, Text = text,
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
		}, f)
		ui.tween(f, 0.45, { Position = UDim2.new(0.5, 0, 0, 14) }, Enum.EasingStyle.Back)
		task.delay(1.8, function()
			ui.tween(f, 0.35, { Position = UDim2.new(0.5, 0, 0, -44) }, Enum.EasingStyle.Quint)
			task.delay(0.4, function() f:Destroy() end)
		end)
	end

	-- while dragging the card "lifts": thicker border, slightly see-through
	function ui.dragFx(on)
		ui.tween(ui.stroke, 0.15, { Thickness = on and 2 or 1 })
		ui.tween(ui.card, 0.15, { BackgroundTransparency = on and 0.14 or 0.04 })
	end
end

-- TOOLTIPS: hover any label whose text is cut off with "..." to see the full text next to the cursor
do
	local TextService = game:GetService("TextService")
	local tipFrame, tipLabel, tipConn, tipFor
	local function plain(lbl)
		local t = lbl.Text
		if lbl.RichText then t = t:gsub("<[^>]+>", "") end
		return t
	end
	local function isCut(lbl)
		local t = plain(lbl)
		if t == "" then return false end
		local sc = X.ui.scale and X.ui.scale.Scale or 1 -- AbsoluteSize is scaled by the card's UIScale, text metrics aren't
		return TextService:GetTextSize(t, lbl.TextSize, lbl.Font, Vector2.new(1e5, 1e5)).X > lbl.AbsoluteSize.X / sc + 1
	end
	local function hide()
		if tipFrame then tipFrame.Visible = false end
		if tipConn then tipConn:Disconnect() tipConn = nil end
		tipFor = nil
	end
	local function build()
		tipFrame = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 100 }, X.ui.gui)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, tipFrame)
		make("UIStroke", { Color = Color3.fromRGB(60, 64, 84), Thickness = 1 }, tipFrame)
		tipLabel = make("TextLabel", {
			Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), BackgroundTransparency = 1,
			Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TEXT, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101,
		}, tipFrame)
	end
	local function show(lbl)
		if not tipFrame then build() end
		tipFor = lbl
		local shown, w, h
		tipFrame.Visible = true
		if tipConn then tipConn:Disconnect() end
		tipConn = RunService.RenderStepped:Connect(function()
			-- hide when the label's page/card got hidden or removed
			local o = lbl
			while o and o ~= X.ui.gui do
				if o:IsA("GuiObject") and not o.Visible then hide() return end
				o = o.Parent
			end
			if not o then hide() return end
			local text = plain(lbl) -- follow live changes while hovering
			if text ~= shown then
				shown = text
				local size = TextService:GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(220, 1000))
				w, h = size.X + 12, size.Y + 8
				tipLabel.Text = text
				tipFrame.Size = UDim2.fromOffset(w, h)
			end
			local m = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			local vp = X.ui.gui.AbsoluteSize
			tipFrame.Position = UDim2.fromOffset(math.max(math.min(m.X + 14, vp.X - w - 4), 4), math.max(math.min(m.Y + 16, vp.Y - h - 4), 4))
		end)
	end
	function X.ui.tip(lbl)
		lbl.MouseEnter:Connect(function() if isCut(lbl) then show(lbl) end end)
		lbl.MouseLeave:Connect(function() if tipFor == lbl then hide() end end)
	end
end

-- a small stat tile: tiny label on top, bold value below. Returns the value label.
local function makeTile(parent, label, size, pos, order)
	local f = make("Frame", {
		Size = size, Position = pos or UDim2.new(), BackgroundColor3 = PANEL, BorderSizePixel = 0, LayoutOrder = order or 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	local glow = make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1 }, f)
	f.MouseEnter:Connect(function() X.ui.tween(glow, 0.2, { Transparency = 0.45 }) end)
	f.MouseLeave:Connect(function() X.ui.tween(glow, 0.3, { Transparency = 1 }) end)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 11), Position = UDim2.fromOffset(0, 3), BackgroundTransparency = 1, Text = label,
		Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = MUTED,
	}, f)
	local value = make("TextLabel", {
		Size = UDim2.new(1, -6, 0, 15), Position = UDim2.fromOffset(3, 13), BackgroundTransparency = 1, Text = "-",
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TEXT, TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
	X.ui.tip(value)
	return value
end

gui = make("ScreenGui", {
	Name = "SwordBotUI", ResetOnSpawn = false, DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil) -- parented at the end of the UI build (see below), once everything exists
X.ui.gui = gui

card = make("Frame", {
	Size = UDim2.fromOffset(540, 402), Position = UDim2.new(0, 16, 0.5, -160),
	BackgroundColor3 = BG, BackgroundTransparency = 0.04, BorderSizePixel = 0,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
X.ui.stroke = make("UIStroke", { Color = Color3.fromRGB(70, 78, 130), Thickness = 1, Transparency = 0.2 }, card)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(BG, Color3.fromRGB(24, 27, 40)) }, card)
X.ui.card = card
X.ui.scale = make("UIScale", { Scale = CONFIG.UIScale or 1 }, card) -- shrinks the whole card (and everything on it)
local topLine = make("Frame", {
	Size = UDim2.new(1, -44, 0, 2), Position = UDim2.fromOffset(22, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0, ZIndex = 3,
}, card)
make("UIGradient", { Color = ColorSequence.new(ACCENT, Color3.fromRGB(56, 218, 240)) }, topLine)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, topLine)
card.MouseEnter:Connect(function() X.ui.tween(X.ui.stroke, 0.2, { Thickness = 1.6 }) end)
card.MouseLeave:Connect(function() X.ui.tween(X.ui.stroke, 0.3, { Thickness = 1 }) end)

do
local header = make("Frame", {
	Size = UDim2.fromOffset(170, 28), Position = UDim2.fromOffset(14, 12),
	BackgroundTransparency = 1, Active = true,
}, card)
local title = make("TextLabel", {
	Size = UDim2.fromOffset(90, 28), BackgroundTransparency = 1, Text = "Sword Bot",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(240, 242, 250), Color3.fromRGB(150, 220, 255)), Rotation = 0 }, title)
local chip = make("Frame", {
	Size = UDim2.fromOffset(22, 20), Position = UDim2.fromOffset(94, 4), BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, header)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
make("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = CONFIG.Keybind.Name,
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = SUB,
}, chip)
-- status dot (grey = off, green + radar ping = running)
X.ui.ring = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(132, 14), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = ON, BackgroundTransparency = 1, BorderSizePixel = 0,
}, header)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, X.ui.ring)
X.ui.dot = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(132, 14), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = OFF, BorderSizePixel = 0,
}, header)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, X.ui.dot)
end

switch = make("TextButton", {
	Size = UDim2.fromOffset(46, 26), Position = UDim2.new(1, -60, 0, 13),
	BackgroundColor3 = OFF, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
}, card)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, switch)
X.ui.switchStroke = make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.7 }, switch)
local knob = make("Frame", {
	Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
}, switch)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
X.ui.pressable(switch)

-- tabs: "Bot" (the usual card), "Debug" (live state + event log) and "Games" (lifetime kills/assists per game)
mainPage = make("CanvasGroup", {
	Size = UDim2.fromOffset(540, 364), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1,
}, card)
local debugPage = make("CanvasGroup", {
	Size = UDim2.fromOffset(540, 390), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1,
}, card)
X.ui.gamesPage = make("CanvasGroup", {
	Size = UDim2.fromOffset(540, 340), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1,
}, card)

-- CONFIG TAB: every true/false and number setting from CONFIG, editable live. Values are read from CONFIG
-- when the bot runs, so a change applies immediately (HiddenUI and StartEnabled are only read at load).
X.ui.configPage = make("CanvasGroup", {
	Size = UDim2.fromOffset(540, 340), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1,
	Visible = false, GroupTransparency = 1,
}, card)
do
	local page = X.ui.configPage
	X.configSync = {}
	local keys = {}
	for k, v in pairs(CONFIG) do
		if type(v) == "boolean" or type(v) == "number" then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	local PENDING, dirty = {}, false -- edits wait here until Apply
	for _, k in ipairs(keys) do PENDING[k] = CONFIG[k] end
	local RESTART_ONLY = { HiddenUI = true, StartEnabled = true }

	local scroll = make("ScrollingFrame", {
		Size = UDim2.fromOffset(512, 224), Position = UDim2.fromOffset(14, 46), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, page)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	local order = 0
	local function row(key)
		order += 1
		local f = make("Frame", {
			Size = UDim2.new(1, -6, 0, 24), BackgroundColor3 = PANEL, BorderSizePixel = 0, LayoutOrder = order,
		}, scroll)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, f)
		make("TextLabel", {
			Size = UDim2.new(1, -96, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
			Text = key .. (RESTART_ONLY[key] and "  (next run)" or ""), Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, f)

		if type(CONFIG[key]) == "boolean" then
			local b = make("TextButton", {
				Size = UDim2.fromOffset(44, 18), Position = UDim2.new(1, -52, 0, 3), BackgroundColor3 = CONFIG[key] and ON or OFF,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0,
			}, f)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
			local knob = make("Frame", {
				Size = UDim2.fromOffset(14, 14), Position = CONFIG[key] and UDim2.fromOffset(27, 2) or UDim2.fromOffset(3, 2),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			}, b)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
			local function show(animate)
				local on = PENDING[key] == true
				local pos = on and UDim2.fromOffset(27, 2) or UDim2.fromOffset(3, 2)
				if animate then
					X.ui.tween(b, 0.2, { BackgroundColor3 = on and ON or OFF })
					X.ui.tween(knob, 0.25, { Position = pos }, Enum.EasingStyle.Back)
				else
					b.BackgroundColor3, knob.Position = on and ON or OFF, pos
				end
			end
			b.Activated:Connect(function()
				PENDING[key] = not PENDING[key]
				dirty = true
				show(true)
			end)
			X.configSync[key] = function() show(false) end
		else
			local box = make("TextBox", {
				Size = UDim2.fromOffset(64, 18), Position = UDim2.new(1, -72, 0, 3),
				BackgroundColor3 = Color3.fromRGB(44, 47, 62), TextColor3 = TEXT, Font = Enum.Font.GothamBold,
				TextSize = 11, Text = tostring(PENDING[key]), ClearTextOnFocus = false, BorderSizePixel = 0,
			}, f)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, box)
			box.FocusLost:Connect(function()
				local n = tonumber(box.Text)
				if n and n == n and math.abs(n) < math.huge then
					if PENDING[key] ~= n then dirty = true end
					PENDING[key] = n
				end
				box.Text = tostring(PENDING[key]) -- bad input snaps back to the staged value
			end)
			X.configSync[key] = function() box.Text = tostring(PENDING[key]) end
		end
	end
	-- a header row whenever the name's first word changes (ChatCooldown, ChatMessages... sit under "Chat")
	local function header(text)
		order += 1
		make("TextLabel", {
			Size = UDim2.new(1, -6, 0, 16), BackgroundTransparency = 1, LayoutOrder = order,
			Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = ACCENT,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, scroll)
	end
	local lastGroup
	for _, k in ipairs(keys) do
		local g = string.match(k, "^%u%l+") or k
		if g ~= lastGroup then
			lastGroup = g
			header(g)
		end
		row(k)
	end

	order += 1
	local reset = make("TextButton", {
		Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = OFF, BorderSizePixel = 0, AutoButtonColor = false,
		Text = "Reset all to defaults", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TEXT, LayoutOrder = order,
	}, scroll)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, reset)
	X.ui.pressable(reset)

	local apply = make("TextButton", {
		Size = UDim2.fromOffset(512, 28), Position = UDim2.fromOffset(14, 280), BackgroundColor3 = ON, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "Apply changes", Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.fromRGB(16, 18, 24),
	}, page)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, apply)
	X.ui.pressable(apply)

	local function setDirty(on)
		dirty = on
		apply.Text = on and "Apply changes  (not applied yet)" or "Apply changes"
	end
	local function syncAll()
		for _, sync in pairs(X.configSync) do sync() end
	end

	reset.Activated:Connect(function()
		for k, v in pairs(X.configDefaults) do
			if PENDING[k] ~= nil then PENDING[k] = v end
		end
		syncAll()
		setDirty(true)
	end)

	apply.Activated:Connect(function()
		for k, v in pairs(PENDING) do CONFIG[k] = v end
		local snapshot = { _v = 2 }
		for _, k in ipairs(keys) do snapshot[k] = CONFIG[k] end
		local saved = X.saveConfig(snapshot)
		setDirty(false)
		apply.Text = saved and "Applied and saved" or (X.saveSupported and "Applied (save failed)" or "Applied (this executor can't save files)")
		task.delay(2, function() if not dirty then apply.Text = "Apply changes" end end)
	end)

	make("TextLabel", {
		Size = UDim2.fromOffset(512, 30), Position = UDim2.fromOffset(14, 318), BackgroundTransparency = 1,
		Text = "Edit values, then press Apply changes. Saved to SwordBot_config.json when the executor allows files.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
end

local debugOpen, setTab = false, nil
do
	local tabs = make("Frame", {
		Size = UDim2.fromOffset(508, 26), Position = UDim2.fromOffset(14, 46),
		BackgroundColor3 = PANEL, BorderSizePixel = 0,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, tabs)
	local TAB_ON = Color3.fromRGB(44, 47, 62)
	-- the highlight pill slides between the tabs
	local pill = make("Frame", {
		Size = UDim2.fromOffset(120, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = TAB_ON, BorderSizePixel = 0,
	}, tabs)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, pill)
	local function makeTab(text, x)
		return make("TextButton", {
			Size = UDim2.fromOffset(120, 20), Position = UDim2.fromOffset(x, 3),
			BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
			Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = SUB,
		}, tabs)
	end
	local ORDER = { "bot", "debug", "games", "config" }
	local TABS = {
		bot = { page = mainPage, x = 3, h = 402, btn = makeTab("Bot", 3) },
		debug = { page = debugPage, x = 126, h = 420, btn = makeTab("Debug", 126) },
		games = { page = X.ui.gamesPage, x = 249, h = 372, btn = makeTab("Games", 249) },
		config = { page = X.ui.configPage, x = 372, h = 372, btn = makeTab("Config", 372) },
	}
	local token, current = 0, "bot"
	setTab = function(name, instant)
		local ui = X.ui
		local prev = current
		current = name
		debugOpen = name == "debug"
		ui.tab = name
		token += 1
		local my = token
		local t = TABS[name]
		local size = UDim2.fromOffset(540, t.h)
		local pillPos = UDim2.fromOffset(t.x, 3)
		if instant then
			card.Size, pill.Position = size, pillPos
			for key, def in pairs(TABS) do
				local on = key == name
				def.page.Visible = on
				def.page.GroupTransparency = on and 0 or 1
				def.btn.TextColor3 = on and TEXT or SUB
			end
			t.page.Position = UDim2.fromOffset(0, 30)
			return
		end
		ui.tween(card, 0.3, { Size = size }, Enum.EasingStyle.Quint)
		ui.tween(pill, 0.3, { Position = pillPos }, Enum.EasingStyle.Back)
		-- old page fades out; the new one slides in from the side its tab is on
		local from = (table.find(ORDER, name) > table.find(ORDER, prev)) and 14 or -14
		for key, def in pairs(TABS) do
			ui.tween(def.btn, 0.2, { TextColor3 = key == name and TEXT or SUB })
			if key ~= name and def.page.Visible then
				local pg = def.page
				ui.tween(pg, 0.15, { GroupTransparency = 1 })
				task.delay(0.16, function() if token == my then pg.Visible = false end end)
			end
		end
		t.page.Visible = true
		t.page.GroupTransparency = 1
		t.page.Position = UDim2.fromOffset(from, 30)
		ui.tween(t.page, 0.3, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 30) }, Enum.EasingStyle.Quint, nil, 0.08)
		if name == "games" and ui.gamesIn then ui.gamesIn() end
	end
	for _, name in ipairs(ORDER) do
		local def = TABS[name]
		def.btn.Activated:Connect(function() if current ~= name then setTab(name) end end)
		X.ui.pressable(def.btn)
	end
	setTab("bot", true)
end

local avatar, nameLabel, stateLabel, hpFill
-- hero card: avatar, name, state and health of the current target
do
local panel = make("Frame", {
	Size = UDim2.fromOffset(236, 74), Position = UDim2.fromOffset(14, 46),
	BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, mainPage)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.85 }, panel)

avatar = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(36, 37),
	BackgroundColor3 = Color3.fromRGB(44, 47, 62), BorderSizePixel = 0, Image = "",
}, panel)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
X.ui.avatar = avatar
X.ui.ascale = make("UIScale", { Scale = 1 }, avatar)
X.ui.aring = make("UIStroke", { Color = SUB, Thickness = 2, Transparency = 0.4 }, avatar) -- mode-coloured ring

nameLabel = make("TextLabel", {
	Size = UDim2.fromOffset(158, 18), Position = UDim2.fromOffset(72, 12), BackgroundTransparency = 1,
	Text = "No target", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, panel)
stateLabel = make("TextLabel", {
	Size = UDim2.fromOffset(158, 16), Position = UDim2.fromOffset(72, 31), BackgroundTransparency = 1,
	Text = "Off", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
local hpTrack = make("Frame", {
	Size = UDim2.fromOffset(158, 6), Position = UDim2.fromOffset(72, 56),
	BackgroundColor3 = Color3.fromRGB(48, 51, 68), BorderSizePixel = 0,
}, panel)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, hpTrack)
X.ui.hpTrail = make("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, BorderSizePixel = 0,
}, hpTrack)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, X.ui.hpTrail)
hpFill = make("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = ON, BorderSizePixel = 0,
}, hpTrack)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, hpFill)
X.ui.nameLabel, X.ui.stateLabel, X.ui.hpFill = nameLabel, stateLabel, hpFill
X.ui.tip(nameLabel)
X.ui.tip(stateLabel)
end

-- stat grid: three columns of tiles, five rows (same tiles as before, regrouped)
local TW, TH = 74, 34
local COL = { 14, 95, 176 }
local ROW = { 128, 168, 208, 248 }
-- row 1: KOs / deaths / K-D ratio
local statKO = makeTile(mainPage, "ALL KOS", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[1], ROW[1]))
local statDeaths = makeTile(mainPage, "DEATHS", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[2], ROW[1]))
local statKD = makeTile(mainPage, "K/D", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[3], ROW[1]))
-- row 2: current/best kill streak, KOs per minute, time running
X.ui.tStreak = makeTile(mainPage, "STREAK / BEST", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[1], ROW[2]))
X.ui.tRate = makeTile(mainPage, "KILLS / MIN", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[2], ROW[2]))
X.ui.tUp = makeTile(mainPage, "UPTIME", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[3], ROW[2]))
-- row 3: REAL kills (you dealt the last blow) vs assists (someone else finished them)
X.ui.tKills = makeTile(mainPage, "SRV KILLS", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[1], ROW[3]))
X.ui.tAssists = makeTile(mainPage, "SRV ASSISTS", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[2], ROW[3]))
X.ui.tShare = makeTile(mainPage, "KILL SHARE", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[3], ROW[3]))
-- row 4: lifetime totals for THIS GAME + how many games are tracked
X.ui.tGameKills = makeTile(mainPage, "GAME KILLS", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[1], ROW[4]))
X.ui.tGameAssists = makeTile(mainPage, "GAME ASSISTS", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[2], ROW[4]))
X.ui.tGames = makeTile(mainPage, "GAMES", UDim2.fromOffset(TW, TH), UDim2.fromOffset(COL[3], ROW[4]))
-- row 5: ALL-TIME kills and assists across every game (two wide tiles)
X.ui.tAllK = makeTile(mainPage, "ALL-TIME KILLS", UDim2.fromOffset(116, TH), UDim2.fromOffset(14, 288))
X.ui.tAllA = makeTile(mainPage, "ALL-TIME ASSISTS", UDim2.fromOffset(116, TH), UDim2.fromOffset(134, 288))

-- learned info about the current player (scrolls when long)
local insightBox = make("ScrollingFrame", {
	Size = UDim2.fromOffset(236, 290), Position = UDim2.fromOffset(290, 46), BackgroundColor3 = PANEL, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = SUB, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, mainPage)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, insightBox)
make("UIPadding", {
	PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, insightBox)
local insight = make("TextLabel", {
	Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	Text = "Waiting for a target...", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = SUB, RichText = true,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, insightBox)
X.ui.insight = insight
make("TextLabel", {
	Name = "DragHint", Size = UDim2.fromOffset(236, 14), Position = UDim2.fromOffset(290, 344), BackgroundTransparency = 1,
	Text = "Drag anywhere to move  |  " .. CONFIG.Keybind.Name .. " = on/off", Font = Enum.Font.Gotham, TextSize = 10,
	TextColor3 = MUTED, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center,
}, mainPage)
X.ui.dragHint = mainPage:FindFirstChild("DragHint")

----------------------------------------------------------------------
-- GAMES TAB: lifetime kills / assists for every game the bot has played (saved in SwordBot/games.json)
----------------------------------------------------------------------
do
	local ui = X.ui
	local gKills = makeTile(X.ui.gamesPage, "TOTAL KILLS", UDim2.fromOffset(74, 34), UDim2.fromOffset(14, 46))
	local gAssists = makeTile(X.ui.gamesPage, "TOTAL ASSISTS", UDim2.fromOffset(74, 34), UDim2.fromOffset(95, 46))
	local gCount = makeTile(X.ui.gamesPage, "GAMES", UDim2.fromOffset(74, 34), UDim2.fromOffset(176, 46))
	local list = make("ScrollingFrame", {
		Size = UDim2.fromOffset(236, 290), Position = UDim2.fromOffset(290, 46), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = SUB, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, X.ui.gamesPage)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, list)
	make("UIPadding", { PaddingRight = UDim.new(0, 6) }, list)
	make("TextLabel", {
		Size = UDim2.fromOffset(236, 28), Position = UDim2.fromOffset(14, 92), BackgroundTransparency = 1, TextWrapped = true,
		Text = "Lifetime totals per game (all servers)", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = MUTED,
	}, X.ui.gamesPage)
	ui.gamesList = list

	local rows = {} -- game key -> { frame, scale, bar, name, sub, kills, assists, k, a }

	-- numbers can count up; setNum cancels a running count before setting text directly
	local function setNum(lbl, n, suffix)
		lbl:SetAttribute("cu", (lbl:GetAttribute("cu") or 0) + 1)
		lbl.Text = tostring(n) .. (suffix or "")
	end
	function ui.countUp(lbl, to, suffix)
		suffix = suffix or ""
		if CONFIG.AnimateUI == false or to <= 0 then setNum(lbl, to, suffix) return end
		local token = (lbl:GetAttribute("cu") or 0) + 1
		lbl:SetAttribute("cu", token)
		task.spawn(function()
			local t0, dur = time(), 0.6
			while time() - t0 < dur do
				if lbl:GetAttribute("cu") ~= token or not lbl.Parent then return end
				local a = 1 - (1 - (time() - t0) / dur) ^ 3
				lbl.Text = tostring(math.floor(to * a + 0.5)) .. suffix
				task.wait()
			end
			if lbl:GetAttribute("cu") == token then lbl.Text = tostring(to) .. suffix end
		end)
	end

	local function ago(ts)
		if type(ts) ~= "number" or ts <= 0 then return "never" end
		local sec = os.time() - ts
		if sec < 90 then return "just now" end
		if sec < 3600 then return math.floor(sec / 60) .. "m ago" end
		if sec < 86400 then return math.floor(sec / 3600) .. "h ago" end
		return math.floor(sec / 86400) .. "d ago"
	end

	local function makeRow(key)
		local frame = make("CanvasGroup", {
			Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = PANEL, BorderSizePixel = 0,
		}, list)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
		local scale = make("UIScale", { Scale = 1 }, frame)
		local bar = make("Frame", {
			Size = UDim2.fromOffset(3, 22), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = OFF, BorderSizePixel = 0,
		}, frame)
		local name = make("TextLabel", {
			Size = UDim2.fromOffset(134, 16), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1, Text = "",
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, frame)
		local sub = make("TextLabel", {
			Size = UDim2.fromOffset(134, 12), Position = UDim2.fromOffset(10, 22), BackgroundTransparency = 1, Text = "",
			Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, frame)
		local kills = make("TextLabel", {
			Size = UDim2.fromOffset(78, 16), Position = UDim2.fromOffset(146, 4), BackgroundTransparency = 1, Text = "0 kills",
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = ON, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, frame)
		local assists = make("TextLabel", {
			Size = UDim2.fromOffset(78, 12), Position = UDim2.fromOffset(146, 22), BackgroundTransparency = 1, Text = "0 assists",
			Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, frame)
		ui.tip(name)
		ui.tip(sub)
		local r = { frame = frame, scale = scale, bar = bar, name = name, sub = sub, kills = kills, assists = assists, k = -1, a = -1 }
		rows[key] = r
		return r
	end

	-- rebuilds/updates every row (current game first, then by kills) and the three totals
	function ui.gamesRefresh()
		local GM = X.games
		local keys = {}
		for k, row in pairs(GM.data) do
			if type(row) == "table" then keys[#keys + 1] = k end
		end
		table.sort(keys, function(x, y)
			if x == y then return false end
			if x == GM.key then return true end
			if y == GM.key then return false end
			local rx, ry = GM.data[x], GM.data[y]
			local kx, ky = tonumber(rx.kills) or 0, tonumber(ry.kills) or 0
			if kx ~= ky then return kx > ky end
			return (tonumber(rx.last) or 0) > (tonumber(ry.last) or 0)
		end)
		local visible = X.ui.gamesPage.Visible
		for i, k in ipairs(keys) do
			local row = GM.data[k]
			local r = rows[k] or makeRow(k)
			local isNow = k == GM.key
			local kills, assists = tonumber(row.kills) or 0, tonumber(row.assists) or 0
			local visits = tonumber(row.visits) or 0
			r.frame.LayoutOrder = i
			r.name.Text = (row.name and row.name ~= "") and row.name or ("Game " .. k)
			r.sub.Text = (isNow and "Playing now" or ("Played " .. ago(tonumber(row.last)))) .. " | " .. visits .. (visits == 1 and " join" or " joins")
			r.sub.TextColor3 = isNow and ON or MUTED
			ui.tween(r.bar, 0.3, { BackgroundColor3 = isNow and ON or OFF })
			if r.k ~= kills then
				if r.k >= 0 and visible then
					ui.tween(r.kills, 0.1, { TextSize = 17 })
					task.delay(0.1, function() ui.tween(r.kills, 0.4, { TextSize = 12 }, Enum.EasingStyle.Back) end)
					ui.flash(r.frame)
				end
				setNum(r.kills, kills, kills == 1 and " kill" or " kills")
				r.k = kills
			end
			if r.a ~= assists then
				if r.a >= 0 and visible then
					ui.tween(r.assists, 0.1, { TextColor3 = TEXT })
					task.delay(0.1, function() ui.tween(r.assists, 0.5, { TextColor3 = SUB }) end)
				end
				setNum(r.assists, assists, assists == 1 and " assist" or " assists")
				r.a = assists
			end
		end
		local tk, ta, n = GM.totals()
		for _, def in ipairs({ { gKills, tk, ON }, { gAssists, ta, SUB }, { gCount, n, TEXT } }) do
			local lbl, val = def[1], def[2]
			if lbl.Text ~= tostring(val) then
				if lbl.Text ~= "-" and visible then ui.bump(lbl, def[3]) end
				setNum(lbl, val)
			end
		end
	end

	-- opening the tab: totals count up and the rows pop in one after another
	function ui.gamesIn()
		ui.gamesRefresh()
		local GM = X.games
		local ordered = {}
		for k, r in pairs(rows) do ordered[#ordered + 1] = { k = k, r = r } end
		table.sort(ordered, function(x, y) return x.r.frame.LayoutOrder < y.r.frame.LayoutOrder end)
		for i, e in ipairs(ordered) do
			local d = 0.08 + math.min(i, 10) * 0.05
			e.r.frame.GroupTransparency = 1
			e.r.scale.Scale = 0.9
			ui.tween(e.r.frame, 0.3, { GroupTransparency = 0 }, nil, nil, d)
			ui.tween(e.r.scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, nil, d)
			local row = GM.data[e.k]
			local kills = tonumber(row.kills) or 0
			ui.countUp(e.r.kills, kills, kills == 1 and " kill" or " kills")
		end
		local tk, ta, n = GM.totals()
		ui.countUp(gKills, tk)
		ui.countUp(gAssists, ta)
		ui.countUp(gCount, n)
	end

	-- called by X.games whenever a kill/assist is added or the game's name arrives
	function ui.gamesChanged(what)
		ui.gamesRefresh()
	end

	ui.gamesRefresh()
end

----------------------------------------------------------------------
-- DEBUG TAB: live state + event log (so you don't have to open the console)
----------------------------------------------------------------------
dbg = { paths = 0, switches = 0, ghosts = 0, ghostHits = 0, shortcuts = 0, unstable = 0, checks = 0, rays = 0 }
do
	-- live stats as a tile grid (4 per row) instead of rows of text
	local grid = make("Frame", {
		Size = UDim2.fromOffset(236, 324), Position = UDim2.fromOffset(14, 46), BackgroundTransparency = 1,
	}, debugPage)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(56, 32), CellPadding = UDim2.fromOffset(4, 4),
		SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 4,
	}, grid)
	local liveTiles = {}
	for i, def in ipairs({
		{ "mode", "MODE" }, { "route", "ROUTE" }, { "tgt", "TARGET" }, { "dist", "DIST" },
		{ "thp", "TGT HP" }, { "myhp", "MY HP" }, { "fps", "FPS" }, { "ping", "PING" },
		{ "swings", "SWINGS" }, { "act", "ACT" }, { "assist", "ASSIST" }, { "state", "STATE" },
		{ "paths", "PATHS" }, { "switch", "SWITCH" }, { "short", "SHORT" }, { "esc", "ESC" },
		{ "fake", "FAKE" }, { "unstable", "UNSTBL" }, { "blocked", "BLOCKED" }, { "acc", "HIT %" }, { "dmg", "DMG" }, { "dodges", "DODGES" },
		{ "ganks", "GANKS" }, { "jumps", "JUMPS" }, { "stuck", "STUCK" }, { "twitch", "TWITCH" }, { "targets", "TARGETS" }, { "saved", "SAVED" },
		{ "engage", "ENGAGES" }, { "wl", "W-L" }, { "ttk", "AVG TTK" }, { "dps", "DPS" },
		{ "combat", "COMBAT %" }, { "react", "REACT %" }, { "fightd", "FIGHT D" }, { "fpslow", "FPS LOW" },
	}) do
		liveTiles[def[1]] = makeTile(grid, def[2], UDim2.fromOffset(56, 32), nil, i)
	end

	local logPanel = make("Frame", {
		Size = UDim2.fromOffset(236, 262), Position = UDim2.fromOffset(290, 46),
		BackgroundColor3 = PANEL, BorderSizePixel = 0,
	}, debugPage)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, logPanel)
	make("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.8 }, logPanel)
	local logScroll = make("ScrollingFrame", {
		Size = UDim2.fromOffset(222, 250), Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = SUB, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, logPanel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, logScroll)
	local function newLabel(text, order)
		local lbl = make("TextLabel", {
			Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Text = text, RichText = true, LayoutOrder = order,
			Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TEXT, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		}, logScroll)
		lbl.TextTransparency = 1
		X.ui.tween(lbl, 0.35, { TextTransparency = 0 })
		return lbl
	end
	local emptyLabel = newLabel('<font color="#5f647a">Nothing logged yet...</font>', 0)
	local logRows, rowOrder = {}, 0
	-- pause: freezes the list so you can read it; new lines queue up and appear on resume
	local pauseBtn = make("TextButton", {
		Size = UDim2.fromOffset(80, 18), Position = UDim2.fromOffset(290, 320), BackgroundColor3 = PANEL, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "Pause log", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = SUB,
	}, debugPage)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, pauseBtn)
	X.ui.pressable(pauseBtn, Color3.fromRGB(44, 47, 62), PANEL)
	X.logPaused, X.logPending = false, nil
	local function refreshPause()
		local n = X.logPending and #X.logPending or 0
		pauseBtn.Text = X.logPaused and (n > 0 and ("Resume (" .. n .. ")") or "Resume") or "Pause log"
		pauseBtn.TextColor3 = X.logPaused and WARN or SUB
	end
	X.ui.refreshPause = refreshPause
	local function setPaused(on)
		X.logPaused = on
		if not on and X.logPending then
			local q = X.logPending
			X.logPending = nil
			refreshPause()
			for _, m in ipairs(q) do X.logBase(m) end
		end
		refreshPause()
	end
	pauseBtn.MouseButton1Click:Connect(function() setPaused(not X.logPaused) end)

	-- sticky line under the list: the last flip/twitch and how many there were. It doesn't scroll away.
	local flipLabel = make("TextLabel", {
		Size = UDim2.fromOffset(236, 14), Position = UDim2.fromOffset(290, 344), BackgroundTransparency = 1,
		Text = "No flips yet", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = MUTED, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, debugPage)
	X.ui.setFlip = function(text)
		flipLabel.Text = '<font color="#fbbf24">' .. text .. "</font>"
	end
	local clearBtn = make("TextButton", {
		Size = UDim2.fromOffset(52, 18), Position = UDim2.fromOffset(472, 320), BackgroundColor3 = PANEL, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "Clear", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = SUB,
	}, debugPage)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, clearBtn)
	X.ui.pressable(clearBtn, Color3.fromRGB(44, 47, 62), PANEL)

	-- copy the whole log to the clipboard; the button shows the keybind that does the same thing
	local copyLabel = "Copy log" .. (CONFIG.CopyLogKey and (" [" .. CONFIG.CopyLogKey.Name .. "]") or "")
	local copyBtn = make("TextButton", {
		Size = UDim2.fromOffset(88, 18), Position = UDim2.fromOffset(376, 320), BackgroundColor3 = PANEL, BorderSizePixel = 0,
		AutoButtonColor = false, Text = copyLabel, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(160, 170, 255),
	}, debugPage)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, copyBtn)
	X.ui.pressable(copyBtn, Color3.fromRGB(44, 47, 62), PANEL)
	copyBtn.MouseButton1Click:Connect(function()
		local ok = X.copyLog()
		copyBtn.Text = ok and "Copied!" or "No clipboard"
		copyBtn.TextColor3 = ok and ON or BAD
		task.delay(1.4, function()
			copyBtn.Text, copyBtn.TextColor3 = copyLabel, SUB
		end)
	end)

	-- event log: one row per event, timestamped; identical repeats collapse into "xN" so flip-flopping shows as a growing count
	local lastMsg, lastLogAt, repeats = nil, 0, 1
	local function escapeRich(t)
		t = t:gsub("&", "&")
		t = t:gsub("<", "<")
		t = t:gsub(">", ">")
		return t
	end
	local function stamp()
		local t = math.floor(time())
		return string.format("%d:%02d", math.floor(t / 60), t % 60)
	end
	local function rowText(msg, count)
		local t = string.format('<font color="#8c92a8">%s</font> %s', stamp(), escapeRich(msg))
		if count > 1 then t = t .. string.format(' <font color="#f87171">x%d</font>', count) end
		return t
	end
	dlog = function(msg)
		if CONFIG.DebugPrint then print("[SwordBot] " .. msg) end
		if not CONFIG.DebugLog then return end
		if X.logPaused then -- paused: keep the line for when you resume (the copy/clipboard buffer still gets everything)
			X.logPending = X.logPending or {}
			if #X.logPending < 300 then table.insert(X.logPending, msg) end
			if X.ui and X.ui.refreshPause then X.ui.refreshPause() end
			return
		end
		local now = time()
		local atBottom = logScroll.CanvasPosition.Y >= logScroll.AbsoluteCanvasSize.Y - logScroll.AbsoluteSize.Y - 8
		if msg == lastMsg and now - lastLogAt < 3 and #logRows > 0 then
			repeats += 1
			lastLogAt = now
			logRows[#logRows].Text = rowText(msg, repeats)
			logRows[#logRows].TextColor3 = WARN -- repeated event: flashes
			X.ui.tween(logRows[#logRows], 0.5, { TextColor3 = TEXT })
		else
			lastMsg, repeats, lastLogAt = msg, 1, now
			rowOrder += 1
			table.insert(logRows, newLabel(rowText(msg, 1), rowOrder))
			emptyLabel.Visible = false
			while #logRows > CONFIG.DebugMaxLines do
				logRows[1]:Destroy()
				table.remove(logRows, 1)
			end
		end
		if atBottom then
			task.defer(function() logScroll.CanvasPosition = Vector2.new(0, 1e6) end)
		end
	end
	clearBtn.Activated:Connect(function()
		for _, r in ipairs(logRows) do r:Destroy() end
		logRows, lastMsg, repeats = {}, nil, 1
		dbg.paths, dbg.switches, dbg.ghosts, dbg.ghostHits, dbg.shortcuts, dbg.unstable, dbg.checks, dbg.rays = 0, 0, 0, 0, 0, 0, 0, 0
		X.resetStats()
		emptyLabel.Visible = true
	end)

	-- don't drag the card when the finger/mouse is on the log (it needs to scroll)
	overLog = function(pos)
		local box = X.ui.tab == "games" and X.ui.gamesList or (debugOpen and logScroll or insightBox)
		local p = box.AbsolutePosition - gui.AbsolutePosition
		local sz = box.AbsoluteSize
		return pos.X >= p.X and pos.X <= p.X + sz.X and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
	end
	-- data[key] = { text, optional color }
	local FLASH = { mode = true, state = true, tgt = true, wl = true, engage = true }
	setLive = function(data)
		for key, lbl in pairs(liveTiles) do
			local d = data[key]
			if d then
				if FLASH[key] and lbl.Text ~= d[1] and lbl.Text ~= "-" then X.ui.flash(lbl.Parent) end
				lbl.Text = d[1]
				lbl.TextColor3 = d[2] or TEXT
			end
		end
	end
end

-- dragging: grab the card anywhere (the switch still works as a button), stays on screen
do
	card.Active = true
	local dragging, dragStart, startOffset
	card.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and not overLog(input.Position) then
			dragging = true
			X.ui.dragFx(true)
			dragStart = input.Position
			startOffset = card.AbsolutePosition - gui.AbsolutePosition
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false X.ui.dragFx(false) end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local maxX = gui.AbsoluteSize.X - card.AbsoluteSize.X
			local maxY = gui.AbsoluteSize.Y - card.AbsoluteSize.Y
			local x = math.clamp(startOffset.X + delta.X, 0, math.max(maxX, 0))
			local y = math.clamp(startOffset.Y + delta.Y, 0, math.max(maxY, 0))
			card.Position = UDim2.fromOffset(x, y)
		end
	end)
end

do
local thumbs, shownUserId = {}, nil
function showTarget(p)
	local ui = X.ui
	if not p then
		shownUserId = nil
		ui.setAvatar("")
		nameLabel.Text = "No target"
		ui.targetIn(false)
		ui.setHp(0)
		return
	end
	shownUserId = p.UserId
	nameLabel.Text = p.DisplayName
	ui.targetIn(true)
	ui.hpReset()
	if thumbs[p.UserId] then
		ui.setAvatar(thumbs[p.UserId])
	else
		ui.setAvatar("")
		local uid = p.UserId
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok then
				thumbs[uid] = content
				if shownUserId == uid then ui.setAvatar(content) end
			end
		end)
	end
end
end

function paintSwitch()
	local ui = X.ui
	ui.tween(switch, 0.25, { BackgroundColor3 = enabled and ON or OFF })
	ui.tween(knob, 0.34, { Position = enabled and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Back)
	-- squash & stretch while it slides
	ui.tween(knob, 0.09, { Size = UDim2.fromOffset(25, 20) })
	task.delay(0.09, function() ui.tween(knob, 0.22, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Back) end)
	ui.setRunning(enabled)
end

local modeLabels = {
	Idle = "Scanning...", Wandering = "Wandering", Chasing = "Chasing", Circling = "Circling", Committing = "Attacking",
	Flanking = "Jumping over", Backstab = "Backstabbing", Retreating = "Retreating", Escaping = "Escaping floor", Lurking = "Lurking", Feinting = "Feinting", Hopping = "Hopping", Lunging = "Lunging", Stalking = "Stalking", Backhopping = "Backhop", Baiting = "Baiting",
}
local function routeText()
	if not target then return "no target" end
	if directOK then return "straight line" end
	if wps then return string.format("path %d/%d", math.min(wpIdx, #wps), #wps) end
	return "no path yet"
end
local SHORT_MODE = {
	Idle = "Idle", Wandering = "Wander", Chasing = "Chase", Circling = "Circle", Committing = "Attack",
	Flanking = "Flank", Backstab = "Stab", Retreating = "Retreat", Escaping = "Escape", Lurking = "Lurk", Feinting = "Feint",
}
local function hpColor(frac) return BAD:Lerp(ON, frac) end
local function refreshLive(dodging)
	local t = time()
	local st = X.stats
	local state, stateCol = "-", TEXT
	if dodging then state, stateCol = "dodge", WARN
	elseif t >= punishFrom and t < punishUntil then state, stateCol = "punish", ON
	elseif leap then state, stateCol = "leap", WARN
	elseif CONFIG.Gank and G.on then state, stateCol = "gank", Color3.fromRGB(251, 146, 60) end
	local route = "-"
	if target then
		if directOK then route = "direct"
		elseif wps then route = string.format("%d/%d", math.min(wpIdx, #wps), #wps)
		else route = "none" end
	end
	local hasT = target and tHum and tHum.Parent
	local tfrac = hasT and math.clamp(tHum.Health / math.max(tHum.MaxHealth, 1), 0, 1) or 0
	local mfrac = humanoid and math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1) or 0
	local ping = X.ping()
	setLive({
		mode = { SHORT_MODE[mode] or tostring(mode) },
		route = { route },
		tgt = { hasT and target.Name or "-" },
		dist = { hasT and string.format("%.1f", dist) or "-" },
		thp = hasT and { math.floor(tfrac * 100) .. "%", hpColor(tfrac) } or { "-" },
		myhp = { math.floor(mfrac * 100) .. "%", hpColor(mfrac) },
		fps = { tostring(math.floor(X.fps + 0.5)), X.fps < 30 and BAD or TEXT },
		ping = { ping and (ping .. "ms") or "-", (ping and ping > 200) and BAD or TEXT },
		swings = { tostring(swings) },
		act = { tostring(st.activates) },
		assist = { tostring(st.assists) },
		state = { state, stateCol },
		paths = { tostring(dbg.paths) },
		switch = { tostring(dbg.switches) },
		short = { tostring(dbg.shortcuts) },
		esc = { tostring(st.escapes) },
		fake = { tostring(dbg.ghosts), dbg.ghosts > 0 and WARN or TEXT },
		unstable = { tostring(dbg.unstable) },
		blocked = { tostring(dbg.ghostHits) },
		acc = { st.swings > 0 and (math.floor(st.hits / st.swings * 100 + 0.5) .. "%") or "-" },
		dmg = { string.format("%d/%d", math.floor(st.dealt + 0.5), math.floor(st.taken + 0.5)), st.taken > st.dealt and BAD or (st.dealt > 0 and ON or TEXT) },
		dodges = { tostring(st.dodges) },
		ganks = { tostring(st.ganks) },
		jumps = { tostring(st.jumps) },
		stuck = { tostring(st.stuck), st.stuck > 0 and WARN or TEXT },
		twitch = { tostring(st.twitches), st.twitches > 0 and WARN or TEXT },
		targets = { tostring(st.targets) },
		saved = { st.lastSaveAt and (math.floor(t - st.lastSaveAt) .. "s") or "never" },
		engage = { tostring(st.engages) },
		wl = { string.format("%d-%d", st.wins, st.losses), st.wins > st.losses and ON or (st.losses > st.wins and BAD or TEXT) },
		ttk = { st.ttkCount > 0 and string.format("%.1fs", st.ttkSum / st.ttkCount) or "-" },
		dps = { st.combatTime > 1 and string.format("%.1f", st.dealt / st.combatTime) or "-" },
		combat = { X.sess.up > 5 and (math.floor(X.sess.combat / X.sess.up * 100 + 0.5) .. "%") or "-" },
		react = { st.swSeen > 0 and (math.floor(st.dodgedSw / st.swSeen * 100 + 0.5) .. "%") or "-" },
		fightd = { st.combatFrames > 0 and string.format("%.1f", st.distSum / st.combatFrames) or "-" },
		fpslow = { tostring(math.floor(X.fpsLow + 0.5)), X.fpsLow < 20 and BAD or (X.fpsLow < 40 and WARN or TEXT) },
	})
end
do
local lastLoggedMode = nil
function trackMode()
	if enabled and CONFIG.AvoidFakeFloors and time() - (X.lastCheckLog or 0) > 30 then
		X.lastCheckLog = time()
		dlog(string.format("fake-floor check: %d ground checks, %d floor rays, %d fake floors found, %d steps refused",
			dbg.checks, dbg.rays, dbg.ghosts, dbg.ghostHits))
	end
	if enabled and PL.name ~= X.lastLoggedPlan and inCombat then
		dlog("plan: " .. tostring(PL.name) .. (target and (" vs " .. target.Name) or ""))
		X.lastLoggedPlan = PL.name
	end
	if enabled and mode ~= lastLoggedMode then
		dlog(string.format("mode: %s -> %s", tostring(lastLoggedMode or "-"), tostring(mode)))
		lastLoggedMode = mode
	end
end
end

-- how each style changes what we do (multipliers on the existing choices; missing = 1 = unchanged)
X.STYLE_TACTICS = { -- on X: this table used to be a local inside trackMode(), so step() saw nil and failed on every style lookup
	["kiter"]            = { lead = 1.3, feint = 0.6, circle = 0.6, lunge = 1.6 },   -- they back off: cut them off, lunge when they flee, don't wait for them
	["aggressive"]       = { feint = 1.3, circle = 1.2, lunge = 0.8 },                -- they come to us: bait their swings, keep our distance a bit longer
	["passive"]          = { stalk = 1.8, feint = 1.2, circle = 0.7 },                -- they wait: go to them, don't circle forever
	["heals up and runs"] = { lead = 1.4, feint = 0.7, circle = 0.5, lunge = 1.6 },   -- finish them before they recover and run
	["jumper"]           = { juke = 1.4, lunge = 0.6, feint = 0.8 },                  -- they hop a lot: sidestep more, don't lunge into the hop
	["orbiter"]          = { lead = 1.2, circle = 0.6 },                              -- they circle us: cut across the circle instead of orbiting
	["waiter"]           = { circle = 1.4, lead = 0.8 },                              -- they strike first: wait them out, punish the whiff
	["counter-puncher"]  = { feint = 0.5, juke = 1.2 },                               -- they hit back right after being hit: don't bait them, keep moving
	["sniper"]           = { lead = 1.2, lunge = 1.4, circle = 0.6 },                -- they fight from far off: close the distance fast
	["brawler"]          = { circle = 0.5, feint = 1.3 },                             -- they fight up close: circling is pointless, bait them
	["hit-and-run"]      = { lunge = 1.8, lead = 1.3, circle = 0.8 },                 -- they tag and leave: chase the leave, punish it
	["turtle"]           = { stalk = 1.5, feint = 1.3, lead = 0.9 },                  -- they stay put and dodge: go in and make them move
	["ambusher"]         = { stalk = 0.4, feint = 1.5, circle = 1.3 },                -- they wait and strike: don't walk into it, bait it out
	["hop-dodger"]       = { feint = 0.7, juke = 1.3 },                               -- they dodge by hopping back: wait for the landing, sidestep more
	["zigzagger"]        = { lunge = 0.5, juke = 0.6, circle = 0.8 },                 -- they change direction constantly: don't predict, don't lunge
	["balanced"]         = {},
}

-- one label for how this player fights, from the signals we've measured (nil until we know them well enough)
function X.styleOf(pr)
	if not pr or pr.samples < 80 then return nil end
	if pr.heals > 0.5 and pr.retreat > 0.4 then return "heals up and runs" end
	if pr.retreat > 0.5 and pr.rush < 0.3 then return "kiter" end
	if pr.jumpRate > 0.4 and (pr.observed or 0) > 10 then return "jumper" end
	if pr.orbit > 0.5 then return "orbiter" end
	if pr.range > 9 and pr.rush < 0.3 then return "sniper" end
	if pr.range < 4.5 and pr.rush > 0.4 then return "brawler" end
	if pr.fleeHit > 0.6 and pr.approach < 0.4 and pr.hitsLanded >= 3 then return "hit-and-run" end
	if pr.ambush > 0.4 and pr.idle > 0.4 then return "ambusher" end
	if pr.idle > 0.5 and pr.dodgesOurs > 0.6 then return "turtle" end
	if pr.ourSwings >= 3 and pr.dodgeHop > 0.5 then return "hop-dodger" end
	if pr.zig > 0.5 then return "zigzagger" end
	if pr.engagements >= 3 and pr.firstStrike > 0.65 then return "waiter" end
	if pr.hitsLanded >= 3 and pr.counterRate > 0.6 then return "counter-puncher" end
	if pr.approach > 0.55 and pr.rush > 0.25 then return "aggressive" end
	if pr.idle > 0.5 then return "passive" end
	return "balanced"
end

-- the player's style, re-checked once a minute: between checks it stays as it was (no flip-flopping each frame)
local STYLE_RECHECK = 60
function X.currentStyle(pr)
	if not pr then return nil end
	local now = time()
	if not pr.styleAt or now - pr.styleAt >= STYLE_RECHECK then
		pr.styleAt = now
		local fresh = X.styleOf(pr)
		if fresh ~= pr.styleNow then
			if pr.styleNow ~= nil or fresh ~= nil then
				dlog("style check: " .. tostring(pr.styleNow or "unknown") .. " -> " .. tostring(fresh or "unknown"))
			end
			pr.styleNow = fresh
			if fresh then X.chat.onStyle(pr, fresh) end
		end
	end
	return pr.styleNow
end

local function insightText()
	if not profile then return "Waiting for a target..." end
	local gankLine = (CONFIG.Gank and G.on and G.why) and ('<font color="#fb923c">•</font> gank: ' .. G.why) or nil
	if profile.samples < 80 then
		return string.format("Learning their movement... (%d/80)", profile.samples) .. (gankLine and ("\n" .. gankLine) or "")
	end
	local parts = {}
	local style = X.currentStyle(profile)
	if style then table.insert(parts, "style: " .. style) end
	local b = profile.strafeBias
	table.insert(parts, b > 0.15 and "dodges right" or (b < -0.15 and "dodges left" or "no side bias"))
	if profile.flipInterval and profile.flips >= 3 then
		table.insert(parts, string.format("flips ~%.1fs", profile.flipInterval))
	end
	table.insert(parts, string.format("jumps %.1f/s", profile.jumpRate))
	if profile.retreat > 0.6 then table.insert(parts, "runs away")
	elseif profile.rush > 0.6 then table.insert(parts, "rushes in")
	elseif profile.idle > 0.5 then table.insert(parts, "stands still") end
	table.insert(parts, string.format("fights at ~%.0f studs", profile.range))
	if profile.theirSwings >= 3 and profile.swingGap and profile.swingRange then
		table.insert(parts, string.format("swings every %.1fs from %.1f studs", profile.swingGap, profile.swingRange))
	end
	if PL.bestFor(profile) then table.insert(parts, "best plan: " .. PL.bestFor(profile)) end
	if profile.wins + profile.losses > 0 then
		table.insert(parts, string.format("record vs them %d-%d", profile.wins, profile.losses))
	end
	if profile.orbit > 0.5 and math.abs(profile.orbitSpin) > 0.5 then
		table.insert(parts, "circles me (" .. (profile.orbitSpin > 0 and "clockwise" or "counter-clockwise") .. ")")
	end
	if profile.engagements >= 3 then
		if profile.firstStrike > 0.6 then table.insert(parts, "strikes first")
		elseif profile.firstStrike < 0.3 then table.insert(parts, "waits for me to swing") end
	end
	if profile.hitsLanded >= 3 then
		if profile.counterRate > 0.6 then table.insert(parts, "hits back when hit") end
		if profile.fleeHit > 0.6 then table.insert(parts, "runs when hit") end
	end
	if profile.lowSamples >= 20 and profile.lowHpRun > 0.6 then table.insert(parts, "runs at low hp") end
	if profile.theirSwings >= 5 and profile.jumpSwing > 0.5 then table.insert(parts, "swings from the air") end
	if profile.ourSwings >= 3 and profile.dodgeBack > 0.5 then table.insert(parts, "backsteps") end
	if profile.ourSwings >= 3 and profile.dodgeHop > 0.5 then table.insert(parts, "hop-dodges") end
	if profile.ourSwings >= 3 then
		table.insert(parts, string.format("dodges %d%% of my swings", math.floor(profile.dodgesOurs * 100 + 0.5)))
	end
	-- more checks, each shown only when it's actually measured
	if profile.speed > 11 then table.insert(parts, "moves fast")
	elseif profile.speed < 4 and profile.samples > 200 then table.insert(parts, "moves slowly") end
	if profile.approach > 0.55 then table.insert(parts, "closes in on me")
	elseif profile.approach < 0.2 and profile.samples > 200 then table.insert(parts, "waits for me to come in") end
	if profile.heals > 0.3 then table.insert(parts, "heals when away from me") end
	if profile.ourSwings >= 5 then
		if profile.dodgesOurs > 0.7 then table.insert(parts, "dodges most of my swings")
		elseif profile.dodgesOurs < 0.2 then table.insert(parts, "rarely dodges my swings") end
	end
	if profile.hitN >= 4 and profile.hitDist then
		table.insert(parts, string.format("I hit them from ~%.1f studs", profile.hitDist))
	end
	if profile.missN >= 4 and profile.missDist and profile.missDist > 0 then
		table.insert(parts, string.format("my misses are ~%.1f studs out", profile.missDist))
	end
	if profile.wins + profile.losses >= 3 then
		local r = profile.wins / math.max(profile.wins + profile.losses, 1)
		table.insert(parts, string.format("I win %d%% of our fights", math.floor(r * 100 + 0.5)))
	end
	if profile.trade > 0.6 then table.insert(parts, "trades blows evenly") end
	do
		local bestName, bestRate, bestN
		for k, v in pairs(profile.tact) do
			if v.n >= 4 and (not bestRate or v.rate > bestRate) then bestName, bestRate, bestN = k, v.rate, v.n end
		end
		if bestName then
			table.insert(parts, string.format("my best vs them: %s (%d%% of %d swings)", bestName, math.floor(bestRate * 100 + 0.5), bestN))
		end
		if X.reach(profile) < CONFIG.AttackRange then
			table.insert(parts, string.format("only swinging inside %.1f studs (far swings whiff)", X.reach(profile)))
		end
	end
	local lines = {}
	if gankLine then table.insert(lines, gankLine) end
	for _, part in ipairs(parts) do
		table.insert(lines, '<font color="#34d399">•</font> ' .. part)
	end
	return table.concat(lines, "\n")
end

function updateUI(dodging)
	local ui = X.ui
	if debugOpen then refreshLive(dodging) end
	if X.ui.dragHint then
		if X.stepErr then
			X.ui.dragHint.Text = "ERROR: " .. X.stepErr:sub(1, 160)
			X.ui.dragHint.TextColor3 = BAD
		else
			X.ui.dragHint.Text = "Drag anywhere to move  |  " .. CONFIG.Keybind.Name .. " = on/off"
			X.ui.dragHint.TextColor3 = MUTED
		end
	end
	-- session tiles (kept up to date even while the bot is off)
	do
		local sess = X.sess
		local streakText = string.format("%d / %d", sess.streak, sess.best)
		if ui.tStreak.Text ~= streakText then
			-- pop + floating "+1" when the streak grows (not when it resets to 0 on a death)
			if sess.streak > (X.lastStreak or 0) and ui.tStreak.Text ~= "-" then
				ui.bump(ui.tStreak, ON)
				ui.float(ui.tStreak, "+1", ON)
			end
			X.lastStreak = sess.streak
			ui.tStreak.Text = streakText
		end
		ui.tStreak.TextColor3 = sess.streak >= 3 and ON or TEXT
		local kt, at = tostring(sess.kills), tostring(sess.assists)
		if ui.tKills.Text ~= kt then
			if ui.tKills.Text ~= "-" then ui.bump(ui.tKills, ON) ui.float(ui.tKills, "+1", ON) end
			ui.tKills.Text = kt
		end
		ui.tKills.TextColor3 = sess.kills > 0 and ON or TEXT
		if ui.tAssists.Text ~= at then
			if ui.tAssists.Text ~= "-" then ui.bump(ui.tAssists, SUB) end
			ui.tAssists.Text = at
		end
		do -- lifetime totals for this game / all games (bump + floating +1 when they grow)
			local GM = X.games
			local totalK, totalA, nGames = GM.totals()
			for _, def in ipairs({
				{ ui.tGameKills, GM.cur.kills, ON, true }, { ui.tGameAssists, GM.cur.assists, SUB, false }, { ui.tGames, nGames, TEXT, false },
				{ ui.tAllK, totalK, ON, true }, { ui.tAllA, totalA, SUB, false },
			}) do
				local lbl, val = def[1], tostring(def[2])
				if lbl.Text ~= val then
					if lbl.Text ~= "-" then
						ui.bump(lbl, def[3])
						if def[4] then ui.float(lbl, "+1", def[3]) end
					end
					lbl.Text = val
				end
			end
		end
		ui.tShare.Text = kos > 0 and (math.floor(sess.kills / kos * 100 + 0.5) .. "%") or "-"
		ui.tRate.Text = sess.up > 20 and string.format("%.1f", sess.kills / (sess.up / 60)) or "-"
		local sec = math.floor(sess.up)
		ui.tUp.Text = sec >= 3600 and string.format("%d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
			or string.format("%d:%02d", math.floor(sec / 60), sec % 60)
	end
	if not enabled then
		ui.setState("off", "Off", SUB)
		ui.setHp(0)
		insight.Text = "Press " .. CONFIG.Keybind.Name .. " to enable"
		return
	end
	if target and tHum then
		local key = dodging and "Dodging" or mode
		local label = dodging and "Dodging" or (modeLabels[mode] or mode)
		if CONFIG.Gank and G.on and not dodging and (mode == "Backstab" or mode == "Committing") then label = "Ganking" end
		-- the fighting plan this player is being handled with (Kite, Ambush, ...), shown while we're in a fight
		if inCombat and not dodging and mode ~= "Idle" and mode ~= "Wandering" and PL.name then label = label .. " / " .. PL.name end
		ui.setState(key, string.format("%s | %.0f studs", label, dist), ui.modeColor[key] or SUB)
		local frac = math.clamp(tHum.Health / math.max(tHum.MaxHealth, 1), 0, 1)
		ui.setHp(frac, hpColor(frac))
	else
		local why = X.stepErr and ("frame error: " .. X.stepErr:sub(1, 60)) or X.frameWhy or X.wanderWhy or "no one in range"
		ui.setState("wander", "Wandering | " .. why, SUB)
		ui.setHp(0)
	end
	insight.Text = insightText()
	-- KO / death counters pop and float a "+1" when they change
	local ko, de = tostring(kos), tostring(deaths)
	if statKO.Text ~= ko then
		if statKO.Text ~= "-" then ui.bump(statKO, ON) ui.float(statKO, "+1", ON) end
		statKO.Text = ko
	end
	if statDeaths.Text ~= de then
		if statDeaths.Text ~= "-" then ui.bump(statDeaths, BAD) ui.float(statDeaths, "+1", BAD) end
		statDeaths.Text = de
	end
	local realKills = X.sess.kills
	local kd = deaths > 0 and realKills / deaths or realKills -- K/D counts only kills you actually got
	statKD.Text = string.format("%.2f", kd)
	statKD.TextColor3 = (realKills + deaths == 0) and TEXT or (kd >= 1 and ON or BAD)
end


-- every visible piece fades and slides in once on load, staggered, even the ones that never change
function X.introAnimate()
	if CONFIG.AnimateUI == false then return end
	local i = 0
	for _, o in ipairs(gui:GetDescendants()) do
		local ok = o:IsA("GuiObject") or o:IsA("UIStroke")
		if ok then
			i += 1
			local delay = math.min(i * 0.012, 0.8)
			X.uiCall(function()
				if o:IsA("UIStroke") then
					local t = o.Transparency
					o.Transparency = 1
					X.ui.tween(o, 0.4, { Transparency = t }, nil, nil, delay)
				elseif o:IsA("TextLabel") or o:IsA("TextButton") then
					local bg, tt = o.BackgroundTransparency, o.TextTransparency
					o.BackgroundTransparency, o.TextTransparency = 1, 1
					X.ui.tween(o, 0.4, { BackgroundTransparency = bg, TextTransparency = tt }, nil, nil, delay)
				elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
					local bg, it = o.BackgroundTransparency, o.ImageTransparency
					o.BackgroundTransparency, o.ImageTransparency = 1, 1
					X.ui.tween(o, 0.4, { BackgroundTransparency = bg, ImageTransparency = it }, nil, nil, delay)
				elseif o:IsA("CanvasGroup") then
					local g = o.GroupTransparency
					o.GroupTransparency = 1
					X.ui.tween(o, 0.4, { GroupTransparency = g }, nil, nil, delay)
				else
					local bg = o.BackgroundTransparency
					o.BackgroundTransparency = 1
					X.ui.tween(o, 0.4, { BackgroundTransparency = bg }, nil, nil, delay)
				end
			end)
		end
	end
end
-- parent the whole UI last, after every piece is built: gethui() when HiddenUI is on,
-- falling back to PlayerGui if the executor refuses that container
do
	X.uiCall(X.introAnimate)
	local parented = false
	if CONFIG.HiddenUI and gethui then parented = pcall(function() gui.Parent = gethui() end) and gui.Parent ~= nil end
	if not parented then gui.Parent = player:WaitForChild("PlayerGui") end
end
end

----------------------------------------------------------------------
-- SWORD / PATH / MOVEMENT HELPERS
----------------------------------------------------------------------
local function getSword()
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Tool") and isSwordTool(c) then return c, true end
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		for _, c in ipairs(bp:GetChildren()) do
			if c:IsA("Tool") and isSwordTool(c) then return c, false end
		end
	end
	return nil, false
end

-- equips when near, unequips when far. returns the equipped tool (if any)
local function manageSword(d, now)
	local tool, isEq = getSword()
	if not tool then return nil end
	local want = false
	if d then
		want = (isEq and d <= CONFIG.UnequipRange) or (not isEq and d <= CONFIG.EquipRange)
	end
	if want ~= isEq and now >= nextEquipAt then
		nextEquipAt = now + 0.6
		if want then humanoid:EquipTool(tool) else humanoid:UnequipTools() end
	end
	return isEq and tool or nil
end

local groundAt
do
local seenGhost = setmetatable({}, { __mode = "k" })

-- a visible, floor-sized part you can't actually stand on (CanCollide off, or a collision group that lets us through)
local seenIgnored = setmetatable({}, { __mode = "k" })
local function isFakeFloor(part)
	if not part or not part:IsA("BasePart") or part:IsA("Terrain") then return false end
	if part.Transparency > CONFIG.GhostMaxTransparency then -- invisible trigger zones aren't floors
		return false, string.format("too transparent (%.2f > GhostMaxTransparency %.2f)", part.Transparency, CONFIG.GhostMaxTransparency)
	end
	local sz = part.Size
	if math.max(sz.X, sz.Y, sz.Z) < 3 then -- too small to mistake for a floor
		return false, string.format("too small (largest side %.1f studs, needs 3)", math.max(sz.X, sz.Y, sz.Z))
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then return false, "part of a character" end -- somebody's hat/accessory
	return true
end

-- looking down from `origin`, the first fake floor where a floor would be (skips invisible zones / small decor).
-- `solidHit` is what the normal (CanCollide-respecting) ray found, if anything.
local function fakeFloorBelow(origin, p, solidHit)
	local solidY = solidHit and solidHit.Position.Y
	if solidY and solidY >= p.Y - 7 and not CONFIG.FakeFloorStrict then return nil end
	local o, remaining = origin, CONFIG.MaxDrop + 4
	for _ = 1, 4 do
		dbg.rays += 1
		local g = Workspace:Raycast(o, Vector3.new(0, -remaining, 0), ghostParams)
		if not g then return nil end
		local y = g.Position.Y
		if y < p.Y - 7 then return nil end -- too far below to be where we'd step
		if solidHit and g.Instance == solidHit.Instance then return nil end -- that's the real floor
		if solidY and y <= solidY + 0.3 then return nil end -- at/below the real floor
		local isFake, why = isFakeFloor(g.Instance)
		if isFake then return g.Instance end
		if why and not g.Instance.CanCollide and not seenIgnored[g.Instance] then
			seenIgnored[g.Instance] = true
			dlog(string.format("ignored non-solid part: %s - %s", g.Instance.Name, why))
		end
		remaining = remaining - (o.Y - y) - 0.05 -- something irrelevant: keep looking below it
		o = Vector3.new(o.X, y - 0.05, o.Z)
		if remaining <= 0.1 then return nil end
	end
	return nil
end

-- Disappearing floors: a part we've looked at as ground is watched for fading (Transparency rising) and
-- CanCollide toggling. While it's "unstable" we treat it like a fake floor, even though it's still solid right now.
X.floorWatch = setmetatable({}, { __mode = "k" })
-- parts that legitimately change (bodies, limbs, accessories, tools, spawn points) are never "unstable floor"
local function neverFloor(part)
	if part:IsA("SpawnLocation") then return true end
	if part:FindFirstAncestorOfClass("Accessory") or part:FindFirstAncestorOfClass("Tool") then return true end
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return true end
		m = m.Parent and m.Parent:IsA("Model") and m.Parent or nil
	end
	return false
end
local NO_WATCH = { tr = 0, changes = 0, untilT = 0, why = "" }
local watchedCount = 0
function X.watchFloor(part)
	local w = X.floorWatch[part]
	if w then return w end
	-- not watched: characters/spawns/tools, or too many parts already (each one costs two signal connections)
	if neverFloor(part) or watchedCount >= 400 then
		X.floorWatch[part] = NO_WATCH
		return NO_WATCH
	end
	watchedCount += 1
	w = { tr = part.Transparency, changes = 0, untilT = 0, why = "" }
	X.floorWatch[part] = w
	local function flag(why)
		w.changes += 1
		w.why = why
		w.untilT = time() + (w.changes >= 3 and CONFIG.BlinkerHold or CONFIG.UnstableHold)
		if not w.logged then
			w.logged = true
			dbg.unstable += 1
			dlog(string.format("unstable floor: %s (%s)", part.Name, why))
			wps, lastPath = nil, 0 -- a route over it may now be wrong: re-path
		end
	end
	part:GetPropertyChangedSignal("Transparency"):Connect(function()
		local n = part.Transparency
		if n > w.tr + 0.01 then flag("fading out") end
		w.tr = n
	end)
	part:GetPropertyChangedSignal("CanCollide"):Connect(function() flag("CanCollide toggled") end)
	return w
end

-- is there something solid to land on below p? (looks MaxDrop studs down)
-- 2nd result = the fake floor, if that's why not. 3rd = the solid hit (if any).
function groundAt(p)
	dbg.checks += 1
	local origin = p + Vector3.new(0, 1, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -(CONFIG.MaxDrop + 4), 0), rayParams)
	-- a thin bar, rail or lid ABOVE the floor we stand on (fence top) is not ground: it used to be read as a floor,
	-- so the path ran along a fence and the bot hit it instead of going down. Look through it to what's under.
	if CONFIG.SkipThinObstacles then
		local feetY = p.Y - 3
		for _ = 1, 3 do
			if not (hit and hit.Instance:IsA("BasePart") and hit.Normal.Y > 0.5 and hit.Position.Y > feetY + 1.5
				and hit.Instance.Size.Y < 1.2) then break end
			origin = hit.Position - Vector3.new(0, hit.Instance.Size.Y + 0.2, 0) -- start below the bar, not inside it
			hit = Workspace:Raycast(origin, Vector3.new(0, -(CONFIG.MaxDrop + 4), 0), rayParams)
		end
	end
	if CONFIG.AvoidFakeFloors then
		local fake = fakeFloorBelow(origin, p, hit)
		if fake then
			dbg.ghostHits += 1
			if not seenGhost[fake] then
				seenGhost[fake] = true
				dbg.ghosts += 1
				dlog(string.format("fake floor: %s (%s)", fake.Name, fake.CanCollide and "collision group" or "CanCollide off"))
			end
			return false, fake, hit
		end
	end
	if CONFIG.AvoidFakeFloors and CONFIG.AvoidUnstableFloors and hit and hit.Instance:IsA("BasePart") then
		local w = X.watchFloor(hit.Instance)
		-- only refuse it as somewhere to step: while we're already on it we must be free to run off
		if (time() < w.untilT or hit.Instance.Transparency > 0.5) and hrp and flat(p - hrp.Position).Magnitude > 3 then
			dbg.ghostHits += 1
			return false, hit.Instance, hit
		end
	end
	return hit ~= nil, nil, hit
end
end

-- Is dropping onto `hit` a good idea? Small drops are free. Deep ones (that used to count as "ground" because
-- something exists 30 studs down) only when they land near the player we're chasing.
-- a narrow gap in the floor (a crack, a seam): the centre finds nothing at the floor's height, but there is floor
-- at the same height just before and just after it, so the body can step across
function X.crackAt(p, dir, floorY)
	for _, s2 in ipairs({ -CONFIG.CrackWidth * 0.65, CONFIG.CrackWidth * 0.65 }) do
		local solid, fake, h = groundAt(p + dir * s2)
		if fake or not solid or math.abs(h.Position.Y - floorY) > 1.5 then return false end
	end
	return true
end

local function dropIsFine(hit, refFeetY, onRoute)
	if hit.Normal.Y < 0.3 then return false end -- landing on a wall face / steep thing
	local drop = refFeetY - hit.Position.Y
	if drop <= CONFIG.CasualDrop then return true end
	if onRoute and drop <= CONFIG.RouteDrop then return true end -- on the route Roblox gave us: the drop is part of it
	if target and tHrp and tHrp.Parent then
		local t = tHrp.Position
		if flat(hit.Position - t).Magnitude < 18 and math.abs(hit.Position.Y - (t.Y - 3)) < 6 then return true end
	end
	return false
end

-- solid, real floor at pt that is OK to step/drop onto. refFeetY = the height we'd be dropping from (default: pt's feet)
-- Checks from clanker.lua: IsSafe rejects NaN / absurd positions, and the footprint check (CheckGround) also requires
-- floor under the body's edges, so a spot whose centre is on a ledge but whose foot hangs over the void is refused.
local function stepOK(pt, refFeetY, onRoute)
	if pt.X ~= pt.X or pt.Y ~= pt.Y or pt.Z ~= pt.Z or pt.Magnitude > 65536 then return false end
	local ref = refFeetY or (pt.Y - 3)
	local solid, fake, hit = groundAt(pt)
	if fake or not solid then return false end
	if not dropIsFine(hit, ref, onRoute) then return false end
	if CONFIG.FootprintCheck then
		for _, o in ipairs({ { 0.6, 0 }, { -0.6, 0 }, { 0, 0.6 }, { 0, -0.6 } }) do
			local s2, f2, h2 = groundAt(pt + Vector3.new(o[1], 0, o[2]))
			-- the corner must be on the centre's floor (within a small step). A corner over the lip used to pass
			-- when the route flag was set, because the floor it found was far below: that's the landing into the void
			if f2 or not s2 or math.abs(h2.Position.Y - hit.Position.Y) > 2 or not dropIsFine(h2, ref, false) then return false end
		end
	end
	return true
end

-- a normal (non-route) jump must land on something sensible, or we don't jump
local function landingSafe(dir)
	if not CONFIG.LedgeAvoidance or leap or time() < noLedgeUntil then return true end
	local pos = hrp.Position
	local ref = pos.Y - 3
	local d = dir and flat(dir)
	if not d or d.Magnitude < 0.2 then return stepOK(pos, ref) end
	d = d.Unit
	return stepOK(pos + d * 4, ref) and stepOK(pos + d * 7, ref)
end

local function tryJump(now, dir)
	if now - lastJump > 0.55 then
		if dir and not landingSafe(dir) then return end
		lastJump = now
		humanoid.Jump = true
	end
end

local function groundPoint(p)
	local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position or p
end

-- counts ground up to CONFIG.MaxDrop studs below our feet (so drop-downs are allowed)
local function hasSafeGround(p)
	return stepOK(p)
end

-- Is p (flat) within ~2.4 studs of the route we're following (bot -> next 3 waypoints) AND are we heading along it?
-- Pathfinding already guarantees that route is walkable, so ledge-avoidance shouldn't second-guess it.
-- (Heading check: strafing or dodging off the route isn't covered by that guarantee.)
local function nearPath(p, v)
	if not wps then return false end
	local tol = math.min(2.4, CONFIG.AgentRadius + 0.4)
	local prev = hrp.Position
	for i = wpIdx, math.min(#wps, wpIdx + 2) do
		local w = wps[i].Position
		if math.abs((p.Y - 3) - w.Y) < 5 then
			local ab, ap = flat(w - prev), flat(p - prev)
			local l2 = ab:Dot(ab)
			local t = l2 > 0 and math.clamp(ap:Dot(ab) / l2, 0, 1) or 0
			if (ap - ab * t).Magnitude <= tol then
				if not v or l2 < 0.01 or flat(v):Dot(ab.Unit) > 0.5 then return true end
			end
		end
		prev = w
	end
	return false
end

-- does the route we're following actually go down to a floor at height y? (only then is a deep drop "on the route")
function X.routeLands(y)
	if not wps then return false end
	for i = wpIdx, math.min(#wps, wpIdx + 3) do
		if math.abs(wps[i].Position.Y - y) < 4 then return true end
	end
	return false
end

local safeDir
do
local SAFE_ANGLES = { 0, 35, 70, 110, 150, 180 }
local safeSt = { ang = 0, hold = 0 } -- ledge-avoidance memory: the offset we're steering at, and until when

-- first heading (nearest to d, keeping to the side we picked last time) where clear(v) holds.
-- returns the heading and the offset angle used. peek = just look, don't remember the side.
local function pickClear(d, mag, clear, peek, maxBase)
	for _, base in ipairs(SAFE_ANGLES) do
		if maxBase and base > maxBase then break end
		if base == 0 then
			if clear(d) then return d * mag, 0 end
		else
			for k = 1, 2 do
				local s = (k == 1) and safeSide or -safeSide
				local rad = math.rad(base * s)
				local r = rotY(d, rad)
				if clear(r) then
					if not peek then safeSide = s end
					return r * mag, rad
				end
			end
		end
	end
	return nil, 0
end

local function fakeAhead(pos, d)
	local _, a = groundAt(pos + d * 2.5)
	if a then return true end
	local _, b = groundAt(pos + d * 5.5)
	return b ~= nil
end

function safeDir(dir, peek)
	if dir.Magnitude < 0.01 or not CONFIG.LedgeAvoidance then return dir end
	if X.drop and time() < X.drop.untilT then return dir end -- committed drop: straight off the edge, the void check was done
	local d = flat(dir)
	if d.Magnitude < 0.01 then return dir end
	d = d.Unit
	local pos = hrp.Position
	local mag = math.min(dir.Magnitude, 1)
	local now = time()

	-- In the air: a committed leap keeps its heading, but any other jump or fall must still land on solid ground.
	-- (This used to be skipped while airborne, so any hop near an edge - obstacle hop, dodge jump, flank jump - carried the bot off it.)
	if humanoid.FloorMaterial == Enum.Material.Air then
		if leap or now < noLedgeUntil or not nav.gpos then return dir end
		local sp = flat(nav.vel)
		if sp.Magnitude < 3 then return dir end
		-- a step up (stairs) is still floor: only turn back when there really is nothing solid ahead
		-- (before, a riser failed the full step test, so the bot steered back, landed, and climbed again)
		local function floorAhead(pt)
			local solid, fake, hit = groundAt(pt)
			return solid and not fake and hit ~= nil and hit.Position.Y > (nav.gy or (pos.Y - 3)) - CONFIG.MaxDrop
		end
		if floorAhead(pos + sp * 0.25) and floorAhead(pos + sp * 0.5) then return dir end
		return unitOr(flat(nav.gpos - pos), Vector3.zero) * mag -- just Move() input back toward where we took off (normal air control, like holding a key)
	end

	-- a route jump is close ahead: walk up to the lip (the jump code takes it from there) instead of backing off from the gap
	local jumpAhead = wps and wps[wpIdx] and wps[wpIdx].Action == Enum.PathWaypointAction.Jump
		and flat(wps[wpIdx].Position - pos).Magnitude < 6
	if jumpAhead and humanoid.FloorMaterial ~= Enum.Material.Air and not (CONFIG.AvoidFakeFloors and fakeAhead(pos, d)) then
		return dir
	end

	-- a wall right in front of us that the route didn't expect: don't walk into it; plan a new route around it
	if wps and not peek and not jumpAhead and now >= (X.wallReplanAt or 0) then
		local wall = Workspace:Raycast(pos + Vector3.new(0, 0.5, 0), d * 2.2, rayParams)
		if wall and wall.Normal.Y < 0.5 then
			X.wallReplanAt = now + 1.5
			wps, lastPath = nil, 0
			dlog("wall on the route: re-routing")
			return Vector3.zero
		end
	end

	if now < noLedgeUntil then
		-- parkour: we WANT to reach the edge, so edges are fine - but never aim at a fake floor
		if not CONFIG.AvoidFakeFloors or not fakeAhead(pos, d) then return dir end
		return (pickClear(d, mag, function(v) return not fakeAhead(pos, v) end, peek)) or dir
	end
	-- look 2.4 and 4.2 studs ahead; each must be real floor with a sane drop, or on the route we're following
	local function ok(pt, v)
		local solid, fake, hit = groundAt(pt)
		-- fake floors are never steered onto
		if fake then return false end
		local refY = pos.Y - 3
		-- nothing under the probe: a narrow crack is fine if the floor carries on past it at our height, otherwise it's the void
		if not solid then return X.crackAt(pt, v, refY) end
		local onRoute = nearPath(pt, v)
		if not onRoute and wps then
			-- the probe can land just off the route line (narrow passages) while a route point sits right there, at that floor
			for i = wpIdx, math.min(#wps, wpIdx + 3) do
				local w = wps[i]
				if w.Action ~= Enum.PathWaypointAction.Jump and flat(w.Position - pt).Magnitude < 8
					and math.abs(w.Position.Y - hit.Position.Y) < 4 then
					onRoute = true
					break
				end
			end
		end
		-- a deep drop only counts as "on the route" if the route itself goes down to that floor
		if onRoute and (refY - hit.Position.Y) > CONFIG.CasualDrop then onRoute = X.routeLands(hit.Position.Y) end
		if dropIsFine(hit, refY, onRoute) then return true end
		-- a deep floor under a crack (the basement seen through it): step across if the floor continues at our height
		if (refY - hit.Position.Y) > CONFIG.CasualDrop then return X.crackAt(pt, v, refY) end
		return false
	end
	local function clear(v)
		return ok(pos + v * 2.4, v) and ok(pos + v * 4.2, v)
	end
	-- Already steering around something? Keep that offset for a moment while it stays safe. Without this the bot
	-- snaps back to the blocked heading every frame, and that dithering at the edge looks exactly like twitching.
	if safeSt.ang ~= 0 and now < safeSt.hold then
		local r = rotY(d, safeSt.ang)
		if clear(r) then return r * mag end
	end
	-- while following a route, only sidestep up to 70 degrees. Past that we'd be walking BACKWARDS, the route
	-- pulls us forward again, and that is the back-and-forth in narrow passages. Ask for a new route instead.
	local r, ang = pickClear(d, mag, clear, peek, (not peek and wps) and 70 or nil)
	if not r then
		-- nothing safe ahead: back away from the edge instead of standing at it (the hold below keeps it going that way)
		local nxt = (not peek and wps) and wps[wpIdx + 1] or nil
		local toNext = nxt and nxt.Action ~= Enum.PathWaypointAction.Jump and flat(nxt.Position - pos) or nil
		local back = rotY(d, math.pi)
		if toNext and toNext.Magnitude > 0.5 and clear(toNext.Unit) then
			-- the corner ahead is solid if we look past it along the route: take the turn instead of backing out
			r, ang = toNext.Unit * mag, 0
		elseif clear(back) then
			r, ang = back * mag, math.pi
		else
			r, ang = pickClear(d, mag, clear, peek) -- last resort: any side that's safe
		end
		if not r then return Vector3.zero end
		-- the route led us here: plan a new one (grid search, avoids edges). At most once every 1.5s: dropping the
		-- route on every failed check stopped wandering and left the bot standing still (then the stuck check jumped it)
		if not peek and wps and not X.drop and now >= (X.edgeReplanAt or 0) then
			X.edgeReplanAt = now + 1.5
			wps, lastPath = nil, 0
		end
	end
	if not peek then
		if ang ~= 0 then
			safeSt.ang, safeSt.hold = ang, now + 0.6
		else
			safeSt.ang = 0
		end
	end
	return r
end
end

-- NARROW FLOOR: true when there is no floor a body-width away on either side (a path, a plank, a seam).
-- On these, hopping forward or over a step throws us off the side, so the bot walks or re-routes instead.
function X.narrowAt(p, dir)
	local d = flat(dir)
	if d.Magnitude < 0.1 then return false end
	d = d.Unit
	local side = Vector3.new(-d.Z, 0, d.X) * 2.2
	local function floorBeside(s)
		return Workspace:Raycast(p + s + Vector3.new(0, 1, 0), Vector3.new(0, -5, 0), rayParams) ~= nil
	end
	return not floorBeside(side) and not floorBeside(-side)
end

-- which way has the most floor? used to pull off a narrow strip while retreating
function X.openGroundDir()
	local best, bestN = nil, 0
	for i = 0, 7 do
		local a = i * math.pi / 4
		local v = Vector3.new(math.cos(a), 0, math.sin(a))
		local n = 0
		for _, r in ipairs({ 3, 6 }) do
			local p = hrp.Position + v * r
			if Workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), rayParams) then n += 1 end
		end
		if n > bestN then best, bestN = v, n end
	end
	return best
end

local function obstacleAhead(dir, reach)
	local d = flat(dir)
	if d.Magnitude < 0.01 then return false end
	d = d.Unit * (reach or 1.9)
	if X.narrowAt(hrp.Position, d) then return false end -- narrow floor: a low step isn't a wall, hopping forward drops us off the side
	local low = Workspace:Raycast(hrp.Position - Vector3.new(0, 2, 0), d, rayParams)
	if not low or low.Normal.Y > 0.7 then return false end -- nothing there, or just a walkable slope
	local high = Workspace:Raycast(hrp.Position + Vector3.new(0, 3.5, 0), d, rayParams)
	return high == nil
end

-- Body-width check: sweep a box the width of the character from a to b (in the air above the step height).
-- True only when it hits a WALL (a steep face). Floors, slopes and steps are ignored, so this won't fire on normal ground.
-- Thin rays slip past corners that the body can't; this catches those.
function X.bodyBlocked(a, b)
	if not CONFIG.BodySweep then return false end
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if dir.Magnitude < 0.5 then return false end
	local center = CFrame.new(a.X, a.Y + 1.1, a.Z)
	local ok, hit = pcall(function()
		return Workspace:Blockcast(center, Vector3.new(2.2, 3.2, 2.2), dir, rayParams)
	end)
	if not ok then return false end -- Blockcast unavailable here: fall back to the normal checks
	return hit ~= nil and hit.Normal.Y < 0.5
end

local function computeDirectOK()
	local origin = hrp.Position
	local diff = tHrp.Position - origin
	if diff.Y > 5 or diff.Y < -CONFIG.MaxDrop then return false end -- can drop down to targets below us
	if Workspace:Raycast(origin, diff, rayParams) then return false end
	if X.bodyBlocked(origin, tHrp.Position) then return false end
	local steps = math.clamp(math.floor(diff.Magnitude / 5), 0, 14)
	for i = 1, steps do
		if not stepOK(origin + diff * (i / (steps + 1))) then return false end
	end
	return true
end

-- can we get from fromPos up to goalPos in one jump? false = the goal is above our reach from there
function X.tooHighFor(goalPos, fromPos)
	local g = Workspace.Gravity
	local v = humanoid.UseJumpPower and humanoid.JumpPower or math.sqrt(2 * g * humanoid.JumpHeight)
	local maxUp = v * v / (2 * g)
	return goalPos.Y - fromPos.Y > maxUp - CONFIG.JumpClearance
end

-- raycast tricks for bad goals: a goal can sit inside a wall, float in the air or hang over an edge.
-- Returns up to 5 spots that are real floor: the floor straight under the goal, then four spots 3 studs around it.
function X.goalCandidates(goal)
	local out = {}
	local function floorAt(xz)
		local h = Workspace:Raycast(xz + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), rayParams)
		if h and h.Normal.Y > 0.6 then return h.Position + Vector3.new(0, 0.2, 0) end
		return nil
	end
	local function add(p)
		if not p then return end
		for _, q in ipairs(out) do
			if (q - p).Magnitude < 1.5 then return end -- already have (nearly) this spot
		end
		out[#out + 1] = p
	end
	add(floorAt(goal))
	for _, ang in ipairs({ 0, 1.5708, 3.1416, 4.7124 }) do
		add(floorAt(goal + Vector3.new(math.cos(ang) * 3, 0, math.sin(ang) * 3)))
	end
	return out
end

-- Roblox sometimes succeeds by routing to the nearest reachable spot under an elevated goal. Detect that.
function X.routeStopsUnder(path, goal)
	local ws = path:GetWaypoints()
	local last = ws[#ws] and ws[#ws].Position
	return last ~= nil and X.tooHighFor(goal, last) and flat(last - goal).Magnitude > 4
end

-- forward declaration: markUnreachable (below) calls setTarget, which is defined further down the file
local setTarget

-- nobody can reach this player from here: leave them alone for a while and go after someone else
function X.markUnreachable(p)
	if not p then return end
	X.reachBan[p] = time() + CONFIG.UnreachableBanTime
	dlog("can't get up to " .. p.Name .. " (above our jump) - going after someone else")
	if p == target then setTarget(nil) end
end

-- which waypoint to head for on a route we're standing somewhere along: the closest point on the route's next
-- few legs (not just the nearest corner, which can aim us back at one we've already passed)
local function routeStartIndex(list, here)
	local lastCheck = #list
	for i = 2, #list do
		if list[i].Action == Enum.PathWaypointAction.Jump then lastCheck = i - 1 break end
	end
	local startIdx, bestD = 2, math.huge
	for j = 1, math.min(lastCheck, 5) - 1 do
		local a, b = list[j].Position, list[j + 1].Position
		local ab, ap = flat(b - a), flat(here - a)
		local l2 = ab:Dot(ab)
		local t = l2 > 0.01 and math.clamp(ap:Dot(ab) / l2, 0, 1) or 0
		local dd = (ap - ab * t).Magnitude
		if dd < bestD - 0.25 then -- ties keep the earlier leg
			bestD = dd
			startIdx = j + (t > 0.9 and 2 or 1)
		end
	end
	return math.min(math.max(startIdx, 2), math.max(#list, 1))
end

local function requestPath(goal, now)
	if pathBusy then return end
	pathBusy = true
	lastPath = now
	local who = target -- who this route is for (the target may change before it finishes computing)
	task.spawn(function()
		-- if anything in here errors, the busy flag must still clear: otherwise wandering waits forever for a route
		-- that never comes back, and the bot stands still
		local okRun, errRun = pcall(function()
		-- one planning attempt with a given body width; returns the path object, or nil if the call itself errored
		local function planWith(radius, to)
			local p = PathfindingService:CreatePath({
				AgentRadius = radius, AgentHeight = CONFIG.AgentHeight, AgentCanJump = true,
				WaypointSpacing = CONFIG.WaypointSpacing,
			})
			local good = pcall(function() p:ComputeAsync(hrp.Position, to) end)
			return good and p or nil
		end
		local function routeOK(p) return p ~= nil and p.Status == Enum.PathStatus.Success end
		local path = planWith(CONFIG.AgentRadius, goal)
		local usable = routeOK(path)
		-- no route at full width: some gaps only fit a narrower body. Try once more before giving up on the route.
		if not usable and CONFIG.PathRetryNarrow then
			local narrow = planWith(math.min(CONFIG.AgentRadius, CONFIG.PathNarrowRadius), goal)
			if routeOK(narrow) then
				path, usable = narrow, true
				dlog("route found with a narrower body")
			end
		end
		-- raycast tricks: the goal itself may be inside a wall or floating. Route to the real floor under it, or next to it.
		if not usable and CONFIG.PathGoalSnap then
			for _, cand in ipairs(X.goalCandidates(goal)) do
				local alt = planWith(CONFIG.AgentRadius, cand)
				if routeOK(alt) then
					path, usable, goal = alt, true, cand
					dlog("route to the floor next to the goal")
					break
				end
			end
		end
		if usable and not X.routeStopsUnder(path, goal) then
			local list = {}
			for i, w in ipairs(path:GetWaypoints()) do
				list[i] = { Position = w.Position, Action = w.Action }
			end
			wps = list
			-- Roblox tells us when a waypoint ahead becomes blocked (a door closes, a part appears): re-route at once
			-- instead of walking into it and waiting for the stuck check
			if CONFIG.RouteRepathBlocked then
				if X.pathBlockConn then X.pathBlockConn:Disconnect() X.pathBlockConn = nil end
				pcall(function()
					X.pathBlockConn = path.Blocked:Connect(function(idx)
						if wps == list and idx >= wpIdx then
							wps, lastPath = nil, 0
							dlog("route blocked ahead: re-routing")
						end
					end)
				end)
			end
			-- we kept moving while the path was computing: start at the first waypoint that's still ahead,
			-- otherwise the bot turns around for a waypoint it already passed (classic pathfinding twitch)
			local here = (hrp and hrp.Parent) and hrp.Position or (list[1] and list[1].Position) or Vector3.zero
			wpIdx = routeStartIndex(list, here)
			pathGoal = goal
			dbg.paths += 1
			dlog(string.format("new path: %d waypoints, start #%d", #list, wpIdx))
		else
			-- Roblox found no route
			wps = nil
			dlog("no path found")
			if X.tooHighFor(goal, hrp.Position) then X.markUnreachable(who) end
		end
		end)
		pathBusy = false
		if not okRun then
			dlog("route error (recovered): " .. tostring(errRun))
		end
	end)
end

-- SHORTCUTS: skip ahead on the path when we can walk straight, or jump, to a later waypoint
local nextShortcut = 0

local function jumpStats()
	local g = Workspace.Gravity
	local v = humanoid.UseJumpPower and humanoid.JumpPower or math.sqrt(2 * g * humanoid.JumpHeight)
	local maxH = v * v / (2 * g)          -- how high a jump can lift us
	local reach = humanoid.WalkSpeed * (2 * v / g) -- how far a jump carries us
	return maxH, reach
end

local function groundContinuous(a, b)
	local diff = b - a
	local steps = math.clamp(math.floor(diff.Magnitude / 4), 1, 10)
	for i = 1, steps do
		if not stepOK(a + diff * (i / (steps + 1)), nil, true) then return false end
	end
	return true
end

-- returns a candidate {p, i, wp, len, saved}, isJump  (or nil)
-- Candidates are spots every ~2.5 studs along the route ahead (not just the waypoints), up to a real jump.
-- ===== helpers used by the jump / route / drop code (these were called but never defined) =====
-- floor under a point: the floor's top surface (nil = no floor within reach). p is feet+3, the same as grid nodes.
function X.landingSpot(p)
	local hit = Workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, -7, 0), rayParams)
	if not hit or hit.Normal.Y < 0.5 then return nil end
	return hit.Position, hit.Instance
end

-- is there solid, not-fading floor under a point?
function X.supportedAt(p)
	local floor, inst = X.landingSpot(p)
	if not floor then return false end
	local w = inst and X.floorWatch[inst]
	if w and time() < w.untilT then return false end -- a floor that's fading / toggling is not somewhere to land
	return true
end

-- a walk leg crosses a gap when it's not a clean line of floor (anything the centre-line void check refuses)
function X.legHasGap(a, b)
	return not X.dropClear(a, b)
end

-- can we get up to a height change dy with speed spd? returns the horizontal distance and the time in the air
function X.jumpReach(dy, spd)
	local g = math.max(Workspace.Gravity, 1)
	local v = math.sqrt(2 * g * math.max(humanoid.JumpHeight, 0.1)) -- take-off speed for the character's jump height
	local peak = v * v / (2 * g)
	if dy > peak then return 0, 0 end
	local tAir = (v + math.sqrt(math.max(v * v - 2 * g * dy, 0))) / g -- time until we are dy above the start (falling back)
	return math.max(spd, 0) * tAir, tAir
end

-- the void check for a committed drop (see followPath): floor along the centre line from the lip down to the landing
function X.dropClear(from, to)
	local ref, lo = from.Y - 3, to.Y - 3
	if ref - lo > CONFIG.RouteDrop then return false end
	local d = flat(to - from)
	local len = d.Magnitude
	if len < 0.1 then return true end
	local dir = d.Unit
	local n = math.max(2, math.floor(len / 1.5 + 0.5))
	-- ramps: the floor sits on the straight line between the two ends, so accept that height too (this used to refuse
	-- every ramp, which made the route re-plan over and over: the jitter)
	local function level(y, t) return math.abs(y - ref) <= 1.5 or math.abs(y - lo) <= 1.5 or math.abs(y - (ref + (lo - ref) * t)) <= 1.5 end
	for i = 1, n - 1 do
		local p = from:Lerp(to, i / n)
		local solid, fake, h = groundAt(p)
		if fake then return false end
		if solid then
			if not level(h.Position.Y, i / n) then return false end
		elseif not X.crackAt(p, dir, ref + (lo - ref) * (i / n)) then
			return false
		end
	end
	return true
end

-- at most 3 gap / wall re-routes in 4 seconds: a route that keeps getting thrown away walks itself in circles
X.rerouteTimes = {}
function X.canReroute(now)
	local t = X.rerouteTimes
	for i = #t, 1, -1 do if now - t[i] > 4 then table.remove(t, i) end end
	if #t >= 3 then return false end
	table.insert(t, now)
	return true
end

local function findShortcut(pos)
	local JUMP = Enum.PathWaypointAction.Jump
	local maxH, reach = jumpStats()
	local feetY = pos.Y - 3
	local first = wps[wpIdx]
	if not first or first.Action == JUMP then return nil end
	local fwdFirst = flat(first.Position - pos)

	local cands, acc, prev = {}, 0, pos
	for i = wpIdx, math.min(#wps, wpIdx + CONFIG.ShortcutLookahead) do
		local w = wps[i]
		if w.Action == JUMP then break end -- never skip past a real jump
		local seg = (w.Position - prev).Magnitude
		local n = math.max(1, math.floor(seg / 2.5 + 0.5))
		for k = 1, n do
			local t = k / n
			table.insert(cands, { p = prev:Lerp(w.Position, t), i = i, wp = (k == n), len = acc + seg * t })
		end
		acc += seg
		prev = w.Position
		if acc > 150 then break end
	end

	local heavy = 0
	for c = #cands, 1, -1 do -- farthest first = biggest saving
		local cd = cands[c]
		local wpos = cd.p
		local straight = (wpos - pos).Magnitude
		local saved = cd.len - straight
		local behind = fwdFirst.Magnitude > 0.5 and flat(wpos - pos):Dot(fwdFirst.Unit) < 0
		if not behind and saved > CONFIG.ShortcutMinSave and cd.len > straight * 1.08 then
			local dy = wpos.Y - feetY
			local hd = flat(wpos - pos).Magnitude
			-- A) plain walking shortcut (cuts corners / zig-zags)
			if heavy < CONFIG.ShortcutHeavy and math.abs(dy) < 2.2 and hd < 40 then
				heavy += 1
				local k0, k1 = pos + Vector3.new(0, -1.2, 0), wpos + Vector3.new(0, 1.8, 0) -- knee height
				local h0, h1 = pos + Vector3.new(0, 1.5, 0), wpos + Vector3.new(0, 4.5, 0)  -- head height
				if not Workspace:Raycast(k0, k1 - k0, rayParams) and not Workspace:Raycast(h0, h1 - h0, rayParams)
					and groundContinuous(pos, wpos + Vector3.new(0, 3, 0)) then
					cd.saved = saved
					return cd, false
				end
			end
			-- B) jump shortcut (hop up onto something / across a gap / off a ledge)
			-- same judgement as the jump itself: our current speed (at least a walk), so a shortcut is never planned and then aborted
			local hMax = X.jumpReach(dy, math.max(flat(nav.vel).Magnitude, 0.6 * humanoid.WalkSpeed))
			if hMax and hd <= hMax * 0.9 and dy <= maxH - CONFIG.JumpClearance and dy >= -CONFIG.MaxDrop then
				local j0, j1 = pos + Vector3.new(0, 2, 0), wpos + Vector3.new(0, 4, 0)
				if not Workspace:Raycast(j0, j1 - j0, rayParams) then
					cd.saved = saved
					return cd, true
				end
			end
		end
	end
	return nil
end

local routeCheckAt = 0
-- a jump we can't make: say why, plan around it with our grid search for a bit, and re-route from here
local function jumpAbort(now, why)
	dlog(why)
	X.stats.jumpSaves = (X.stats.jumpSaves or 0) + 1
	if X.chat.isMilestone(X.stats.jumpSaves, { 1, 5, 10, 25, 50 }) then
		X.chat.send(string.format(X.chat.pick("void", X.chat.pools.void), X.stats.jumpSaves))
	end
	wps, lastPath = nil, 0
	if pathGoal then requestPath(pathGoal, now) end
	return Vector3.zero, false
end

local function followPath(now)
	local pos = hrp.Position

	-- Mid-leap: commit to the landing spot so we don't drift or walk off the gap
	if leap then
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		if now > leap.untilT or (grounded and now - leap.start > 0.35) then
			X.landedDir = leap.dir
			leap = nil
			leapEndedAt = now
		else
			noLedgeUntil = now + 0.2
			if leap.part and leap.part.Parent and leap.off then
				-- moving platform: its landing spot moves with it (and keeps moving for the rest of the flight)
				local left = math.max(0, leap.start + leap.flightT - now)
				local pv = leap.part.AssemblyLinearVelocity
				leap.pos = leap.part.CFrame:PointToWorldSpace(leap.off) + Vector3.new(pv.X, 0, pv.Z) * left
			end
			local toL = flat(leap.pos - pos)
			-- close to / already past the landing spot: keep our heading instead of flipping back toward it mid-air
			if toL.Magnitude > 1.5 and (not leap.dir or toL:Dot(leap.dir) > 0) then leap.dir = toL.Unit end
			return (leap.dir or unitOr(toL, Vector3.zero)) * math.clamp(toL.Magnitude / 3, 0.25, 1), false -- ease off near the landing
		end
	end

	-- just landed: keep the jump's heading for a moment, instead of turning toward the next point at once (the twitch)
	if X.landedDir and now - leapEndedAt < 0.35 and humanoid.FloorMaterial ~= Enum.Material.Air then
		if X.narrowAt(hrp.Position, X.landedDir) then return Vector3.zero, false end -- narrow floor: stop, don't carry on off the far side
		return X.landedDir, false
	end

	if not wps then return nil, false end

	-- Route sanity: if the next walking point has no solid floor under it (the route was put above a void, or the
	-- floor it was built on is gone), throw the route away and re-route from here instead of walking into the void.
	if now - routeCheckAt >= CONFIG.RouteCheckEvery and wps[wpIdx] then
		routeCheckAt = now
		for k = wpIdx, math.min(#wps, wpIdx + 2) do
			local fromP = (k == wpIdx) and pos or wps[k - 1].Position
			local legGap = wps[k].Action ~= Enum.PathWaypointAction.Jump and X.legHasGap(fromP, wps[k].Position)
			local wallLeg = wps[k].Action ~= Enum.PathWaypointAction.Jump and X.bodyBlocked(fromP, wps[k].Position)
			if not X.supportedAt(wps[k].Position) or ((legGap or wallLeg) and X.canReroute(now)) then
				dlog(legGap and "route crosses a gap (no floor between two points): re-routing" or wallLeg and "wall in the way of the route (body too wide): re-routing" or "route no longer on solid floor (void or vanished platform): re-routing")
				wps, lastPath = nil, 0
				if pathGoal then requestPath(pathGoal, now) end
				return Vector3.zero, false
			end
		end
	end

	-- skip normal waypoints we've reached (Jump waypoints are handled below, never skipped)
	local wp = wps[wpIdx]
	local justLanded = now - leapEndedAt < 1.0
	while wp and wp.Action ~= Enum.PathWaypointAction.Jump do
		local reached = flat(wp.Position - pos).Magnitude < 2.8
		if not reached and flat(wp.Position - pos).Magnitude < 4.5 then
			-- pushed a little past it (edge avoidance, a sidestep): if we're already ahead of it along the route, don't turn back for it
			local nxt = wps[wpIdx + 1]
			if nxt and nxt.Action ~= Enum.PathWaypointAction.Jump then
				local seg = flat(nxt.Position - wp.Position)
				if seg.Magnitude > 0.1 and flat(pos - wp.Position):Dot(seg.Unit) > 0 then reached = true end
			end
		end
		local behind = false
		if justLanded and not reached then
			local nxt = wps[wpIdx + 1]
			if nxt then -- we landed beyond this waypoint: going back for it is the 'turn around after the jump' bug
				local seg = flat(nxt.Position - wp.Position)
				local rel = flat(pos - wp.Position)
				behind = seg.Magnitude > 0.1 and rel:Dot(seg.Unit) > 0 and rel.Magnitude < 8
			end
		end
		if not (reached or behind) then break end
		wpIdx += 1
		wp = wps[wpIdx]
	end
	if not wp then wps = nil return nil, false end

	-- parkour: a jump is coming up, so switch ledge-avoidance off early. Otherwise the bot veers away from
	-- the very edge it needs to jump from (the 'turns back before the jump' bug)
	for k = 0, 2 do
		local w = wps[wpIdx + k]
		if w and w.Action == Enum.PathWaypointAction.Jump and flat(w.Position - pos).Magnitude < 5 then
			noLedgeUntil = now + 0.25
			break
		end
	end

	if now >= nextShortcut and not wp.Shortcut and wp.Action ~= Enum.PathWaypointAction.Jump
		and humanoid.FloorMaterial ~= Enum.Material.Air then
		nextShortcut = now + 0.2
		local cd, isJump = findShortcut(pos)
		if cd then
			local JUMP, WALK = Enum.PathWaypointAction.Jump, Enum.PathWaypointAction.Walk
			if cd.wp then
				if isJump then
					wps[cd.i] = { Position = wps[cd.i].Position, Action = JUMP, Shortcut = true }
				end
			else -- a spot between waypoints: add it as a waypoint of its own
				table.insert(wps, cd.i, { Position = cd.p, Action = isJump and JUMP or WALK, Shortcut = isJump or nil })
			end
			wpIdx = cd.i
			wp = wps[wpIdx]
			dbg.shortcuts += 1
			dlog(string.format("shortcut: %s, saves ~%.0f studs", isJump and "jump" or "walk", cd.saved or 0))
		end
	end

	local diff = flat(wp.Position - pos)
	local fd = diff.Magnitude
	local dir
	if fd > 0.6 then dir = diff.Unit lastWpDir = dir else dir = lastWpDir end

	-- COMMITTED DROP: the next route point is a floor lower down, and we're at the lip. Steer straight off it
	-- (side-steering would turn us back along the edge) - but only after the void check passes.
	if X.drop then
		if now > X.drop.untilT or (humanoid.FloorMaterial ~= Enum.Material.Air and now - X.drop.start > 0.2) then
			X.drop = nil
		else
			return X.drop.dir, false
		end
	end
	if CONFIG.CommitDrops and wp.Action ~= Enum.PathWaypointAction.Jump and humanoid.FloorMaterial ~= Enum.Material.Air and fd < 4 then
		local lp = X.landingSpot(wp.Position)
		local dropBy = lp and ((pos.Y - 3) - lp.Y) or 0 -- no floor below the waypoint: no committed drop
		if dropBy > 2 and dropBy <= CONFIG.RouteDrop then
			-- at the lip: nothing solid at our feet level just ahead
			local lip = not Workspace:Raycast(pos + dir * 1.2 + Vector3.new(0, 1, 0), Vector3.new(0, -3.5, 0), rayParams)
			if lip then
				local landing = lp + Vector3.new(0, 3, 0)
				-- the body must fit on the landing: floor past it in the drop direction and on both sides. The centre-line
				-- check alone let it commit to a narrow or partial landing and fall off the side.
				local side = Vector3.new(-dir.Z, 0, dir.X)
				local fits = X.landingSpot(lp + dir * 1.8) and X.landingSpot(lp + side * 1.0) and X.landingSpot(lp - side * 1.0)
				if fits and X.dropClear(pos, landing) and stepOK(landing, nil, false) then
					X.drop = { dir = dir, start = now, untilT = now + 1.4 }
					dlog(string.format("drop: committed, %.0f studs down (void check passed)", dropBy))
					return dir, false
				end
			end
		end
	end

	if wp.Action == Enum.PathWaypointAction.Jump then
		-- Walk straight up to the edge/obstacle and jump right there, not early.
		noLedgeUntil = now + 0.25
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		-- if there is solid floor all the way to the landing, walk it: a jump onto a narrow path it can simply
		-- walk onto is how it fell in the void (it jumped early and fell short)
		local nextW = wps[wpIdx + 1] or wp
		local walkTo = not wp.Shortcut and X.landingSpot(nextW.Position)
		if walkTo and X.dropClear(pos, walkTo + Vector3.new(0, 3, 0)) then
			wp.Action = Enum.PathWaypointAction.Walk
			return dir, false
		end
		if grounded and dir.Magnitude > 0 then
			local edge = not Workspace:Raycast(pos + dir * 1.2 + Vector3.new(0, 1, 0), Vector3.new(0, -5.5, 0), rayParams)
			local wall = obstacleAhead(dir)
			if wp.Shortcut and fd < 2 then
				-- got here without needing the jump: treat as a normal waypoint
				wp.Action, wp.Shortcut = Enum.PathWaypointAction.Walk, nil
				return dir, false
			end
			-- take off when the landing is inside our reach (with margin), not only once we're on the very edge:
			-- waiting for the edge made the jump too late for narrow landings
			local landing = wp.Shortcut and wp or (wps[wpIdx + 1] or wp)
			local lpEarly = X.landingSpot(landing.Position)
			local hEarly = lpEarly and select(1, X.jumpReach(lpEarly.Y - (pos.Y - 3), math.max(flat(nav.vel).Magnitude, 0.9 * humanoid.WalkSpeed))) or 0
			local inWindow = lpEarly ~= nil and hEarly > 0 and flat(lpEarly - pos).Magnitude <= hEarly * 0.85
			if edge or wall or (fd < 1.1 and not wp.Shortcut) or inWindow then
				if not X.supportedAt(landing.Position) then -- the platform we'd land on is gone or fading: don't jump
					dlog("jump landing is gone or fading: re-routing")
						wps, lastPath = nil, 0
					if pathGoal then requestPath(pathGoal, now) end
					return Vector3.zero, false
				end
				-- can we make it? judge from our current speed (at least a walk), and the landing height
				local lp0, lpart = X.landingSpot(landing.Position)
				if not lp0 then return jumpAbort(now, "jump: no floor under the landing (the void): re-routing") end
				-- the landing has to be a whole floor under the body, not the edge of a platform
				if not stepOK(lp0 + Vector3.new(0, 3, 0), nil, false) then return jumpAbort(now, "jump: landing is the edge of a platform: re-routing") end
				if Workspace:Raycast(pos, Vector3.new(0, humanoid.JumpHeight + 1, 0), rayParams) then return jumpAbort(now, "jump: something overhead: re-routing") end
				local spd = math.max(flat(nav.vel).Magnitude, 0.9 * humanoid.WalkSpeed) -- we run up to a jump: judge it at near walk speed
				local hMax, tAir = X.jumpReach(lp0.Y - (pos.Y - 3), spd)
				if not hMax then return jumpAbort(now, "jump: landing is too high to reach: re-routing") end
				local off = lpart and lpart.CFrame:PointToObjectSpace(lp0) or nil
				local vel = lpart and lpart.AssemblyLinearVelocity or Vector3.zero
				local down = lp0.Y < (pos.Y - 3) - 2
				if down then
					-- a jump down onto a narrow floor overshoots into the void: there must be floor past the landing too
					if not X.landingSpot(lp0 + dir * 2.2) then return jumpAbort(now, "jump: narrow landing, void past it: re-routing") end
				end
				local aim = lp0 + Vector3.new(vel.X, 0, vel.Z) * tAir -- where a moving platform will be when we land
				if down then aim -= dir * 0.6 end -- aim a little short: overshooting is the fall, undershooting is just a hop
				if flat(aim - pos).Magnitude > hMax * 0.9 then
					if edge then return jumpAbort(now, "jump: landing is too far to reach: re-routing") end
					return dir, false -- not at the edge yet: keep walking up to it
				end
				leap = { pos = aim, start = now, untilT = now + 1.3, part = lpart, off = off, flightT = tAir or 0.5 }
				dlog(string.format("jump: %s, %.0f studs to landing", edge and "edge" or (wall and "wall" or "waypoint"), flat(landing.Position - pos).Magnitude))
				X.stats.jumps += 1
				wpIdx += 1
				humanoid.Jump = true
				lastJump = now
				return unitOr(flat(landing.Position - pos), dir), false
			end
		end
		return dir, false
	end

	local jump = false
	local rise = wp.Position.Y - (pos.Y - 3)
	local maxH = jumpStats()
	if rise > 2.2 and rise <= maxH - CONFIG.JumpClearance and fd < (rise > 4 and CONFIG.LedgeRun or 2.8)
		and humanoid.FloorMaterial ~= Enum.Material.Air and now - lastJump > 0.6 and not X.narrowAt(pos, dir) then
		jump = true -- a step or ledge we can clear: jump at a run-up, not from standing
	end
	return dir, jump
end

local function chaseDir(now, goal)
	local pos = hrp.Position
	if directOK then
		if wps and pathGoal then X.savedRoute = { wps = wps, goal = pathGoal, at = now } end -- keep the A* route for when the straight line breaks
		wps, leap = nil, nil
		local v = flat(goal - pos)
		if v.Magnitude < 1.2 then return Vector3.zero, false end -- right on top of it: overshooting would flip our heading every frame
		return v.Unit, false
	end
	local gp = groundPoint(goal)
	-- straight line just ended: reuse the route we were on (same goal, not too old) instead of computing it again
	local sr = X.savedRoute
	if not wps and sr and now - sr.at < 4 and (sr.goal - gp).Magnitude < 12 and #sr.wps > 1 then
		wps, pathGoal, lastPath = sr.wps, sr.goal, now
		wpIdx = routeStartIndex(wps, pos)
		X.savedRoute = nil
	end
	local moved = pathGoal and (gp - pathGoal).Magnitude or 0
	local needNew = (not wps and now - lastPath > 0.35)
		or (wps ~= nil and now - lastPath > 3.0)
		or (wps ~= nil and moved > math.max(10, flat(goal - pos).Magnitude * 0.25) and now - lastPath > 0.9)
	if needNew then requestPath(gp, now) end
	local dir, jump = followPath(now)
	if dir then return dir, jump end
	local fv = flat(goal - pos)
	if fv.Magnitude < 1.2 then return Vector3.zero, false end
	-- path still loading and they're above our jump: a straight run just takes us under them
	if X.tooHighFor(goal, pos) then return Vector3.zero, false end
	-- path still loading: holding a moment beats driving straight into whatever is in between
	-- (that straight run, then the path's own heading, was the back-and-forth on the way to a target)
	-- route still being computed: keep going the way we were already going instead of stopping dead
	-- (if we were standing still, the last waypoint heading is used; edge checks still apply to this move)
	if pathBusy and now - lastPath < 1.5 then
		local mv = flat(nav.vel)
		local keep = mv.Magnitude > 2 and mv.Unit or lastWpDir
		if keep.Magnitude > 0.5 then return keep, false end
		return Vector3.zero, false
	end
	return fv.Unit, false -- fallback (path never came back)
end

-- while retreating / backing off: the way away from every other player close to us (not just the target)
function X.awayFrom(pos)
	local sum = Vector3.zero
	for _, q in ipairs(Players:GetPlayers()) do
		if q ~= player and q ~= target and q.Character then
			local qr = q.Character:FindFirstChild("HumanoidRootPart")
			local qh = q.Character:FindFirstChildOfClass("Humanoid")
			if qr and qh and qh.Health > 0 then
				local v = flat(pos - qr.Position)
				local m = v.Magnitude
				if m > 0.1 and m < CONFIG.BackOffRange then sum += v.Unit * (1 - m / CONFIG.BackOffRange) end
			end
		end
	end
	if sum.Magnitude < 0.05 then return nil end
	return sum.Unit
end

-- turn the character toward a point by writing its CFrame (eased, capped by CONFIG.MaxTurnRate). This is what lets the
-- bot face its target so its swings land in front of it.
local function turnToward(point, dt)
	local cf = hrp.CFrame
	local want = flat(point - cf.Position)
	if want.Magnitude < 0.9 then return end -- right on top of them the heading flips wildly: just hold it
	local look = flat(cf.LookVector)
	local curYaw = math.atan2(-look.X, -look.Z)
	local wantYaw = math.atan2(-want.X, -want.Z)
	local diff = (wantYaw - curYaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) < math.rad(3) then return end -- deadzone: no micro-corrections
	local maxStep = math.rad(CONFIG.MaxTurnRate) * dt
	local stepYaw = math.clamp(diff * (1 - math.exp(-dt * 12)), -maxStep, maxStep) -- eases in, so it can't overshoot and wobble
	hrp.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, curYaw + stepYaw, 0)
end

-- Swing detection for the Roblox ClassicSword (no Animation instances).
-- When someone swings, the sword script adds a "toolanim" StringValue to the tool
-- and changes the tool's grip. Both replicate, so we just listen for them.
local lastTargetSwing = -100
local watchTargetSwings, targetSwinging
do
local swingConns = {}
local lastCountedSwing = -100

-- learn their swing habits (distance they swing from, time between swings)
local function recordTargetSwing(t)
	local gap = t - lastCountedSwing
	if gap < 0.3 then return end -- one swing fires several grip changes
	local pr = profile
	if pr and tHrp and hrp and hrp.Parent then
		local sd = flat(tHrp.Position - hrp.Position).Magnitude
		if sd < 10 then
			pr.theirSwings += 1
			PL.theirSwingAt = t
			pr.swingRange = pr.swingRange and ema(pr.swingRange, sd, 0.25) or sd
			if gap < 3 then pr.swingGap = pr.swingGap and ema(pr.swingGap, gap, 0.3) or gap end
			-- airborne swings (jump-attackers)
			pr.jumpSwing = ema(pr.jumpSwing, (tHum and tHum.FloorMaterial == Enum.Material.Air) and 1 or 0, 0.25)
			-- whoever swings first in a fight decides "firstStrike"
			if fight.engagedAt and not fight.decided then
				fight.decided = true
				pr.engagements += 1
				pr.firstStrike = ema(pr.firstStrike, fight.ourFirstSwingAt and 0 or 1, 0.3)
			end
			-- they swung back within a second of being hit
			if fight.hitAt and not fight.countered and t - fight.hitAt < 0.9 then
				fight.countered = true
				pr.counterRate = ema(pr.counterRate, 1, 0.3)
			end
			lastCountedSwing = t
		end
	end
end

local function clearSwingWatch()
	for _, c in ipairs(swingConns) do c:Disconnect() end
	table.clear(swingConns)
end

local function watchTool(tool)
	if not tool:IsA("Tool") then return end
	local equippedAt = time()
	local function mark()
		if time() - equippedAt > 0.4 then -- ignore equip-time grip changes
			local t = time()
			recordTargetSwing(t)
			lastTargetSwing = t
		end
	end
	table.insert(swingConns, tool.ChildAdded:Connect(function(child)
		if child.Name == "toolanim" then mark() end
	end))
	table.insert(swingConns, tool:GetPropertyChangedSignal("GripForward"):Connect(mark))
	table.insert(swingConns, tool:GetPropertyChangedSignal("GripUp"):Connect(mark))
end

function watchTargetSwings(char)
	clearSwingWatch()
	lastTargetSwing = -100
	lastCountedSwing = -100
	if not char then return end
	for _, c in ipairs(char:GetChildren()) do watchTool(c) end
	table.insert(swingConns, char.ChildAdded:Connect(watchTool))
end

function targetSwinging()
	return time() - lastTargetSwing < 0.15
end
end

local function updateStrafe(now)
	local rs = X.rearSign or 1
	-- they dodge a known way, and we just watched them dodge one of our swings: cut off that side
	if profile and X.dodgeSeenAt and now - X.dodgeSeenAt < 2 and profile.dodgesOurs > 0.5 and math.abs(profile.dodgeBias) > 0.25
		and X.dodgeSeenAt ~= X.dodgeUsedAt then
		X.dodgeUsedAt = X.dodgeSeenAt
		strafeSign = profile.dodgeBias > 0 and 1 or -1
		strafeFlipAt = now + rand(1.0, 2.2)
	elseif PL.mirror and profile and profile.flipInterval and profile.flips >= 4 and now >= strafeFlipAt then
		-- copying: change direction on their beat, not on our own random timer
		if math.abs(profile.dodgeBias or 0) > 0.25 and math.random() < 0.6 then
			strafeSign = profile.dodgeBias > 0 and 1 or -1 -- cut off the side they dodge toward
		else
			strafeSign = -strafeSign
		end
		strafeFlipAt = now + math.clamp(profile.flipInterval, 0.4, 2.5)
	elseif now >= strafeFlipAt then
		-- mostly circle toward THEIR back (so flanks and backstabs arrive from behind); sometimes the other side,
		-- so the bot isn't predictable
		if math.random() < 0.8 then strafeSign = rs else strafeSign = math.random() < 0.5 and 1 or -1 end
		strafeFlipAt = now + rand(1.0, 2.2)
	elseif rs ~= X.lastRs then
		-- they turned around: follow their back to the new side right away instead of waiting for the timer
		strafeSign = rs
	end
	X.lastRs = rs
end

-- Wandering (no target in range): pathfind to random nearby spots, pause, repeat
local resetWander, wander
do
local wanderGoal, wanderWaitUntil, wanderStartedAt = nil, 0, 0
local wanderLastPos, wanderNextCheck = Vector3.zero, 0

function resetWander()
	wanderGoal = nil
end

function wander(now)
	local pos = hrp.Position
	if wanderGoal and flat(wanderGoal - pos).Magnitude < 4 then
		wanderGoal, wps = nil, nil
		wanderWaitUntil = now + rand(CONFIG.WanderPause[1], CONFIG.WanderPause[2])
	end
	if now < wanderWaitUntil then X.wanderWhy = "pausing" return Vector3.zero, false end

	if not wanderGoal then
		if pathBusy and now - lastPath > 5 then pathBusy = false end -- safety net: a route request should never take this long
		if pathBusy or now - lastPath < 0.5 then X.wanderWhy = "waiting for a route" return Vector3.zero, false end
		local ang = math.random() * math.pi * 2
		local r = rand(CONFIG.WanderMinDist, CONFIG.WanderMaxDist)
		local g = groundPoint(pos + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r))
		wanderGoal, wanderStartedAt, wps = g, now, nil
		wanderLastPos, wanderNextCheck = pos, now + 1
		requestPath(g, now)
		return Vector3.zero, false
	end

	local dir, jump = followPath(now)
	if dir then
		X.wanderMoveAt = now -- we're getting somewhere along a route
		X.wanderWhy = wps and string.format("walking %d/%d", math.min(wpIdx, #wps), #wps) or "walking"
		-- give up on spots we can't make progress toward
		if now >= wanderNextCheck then
			if (pos - wanderLastPos).Magnitude < 1 then
				wanderGoal, wps = nil, nil
				wanderWaitUntil = now + 0.3
				-- no progress: pick a new spot. (This used to also request a jump, so the bot hopped in place
				-- every second or so while wandering.)
				return Vector3.zero, false
			end
			wanderLastPos, wanderNextCheck = pos, now + 1
		end
		if now - wanderStartedAt > 25 then wanderGoal, wps = nil, nil end
		return dir, jump
	end
	-- no route has worked for a while (every request failed): don't stand still, walk straight at the spot instead.
	-- safeDir still stops it at ledges, and the route search gets another try as soon as it can.
	if wanderGoal and now - (X.wanderMoveAt or 0) > 4 then
		local v = flat(wanderGoal - hrp.Position)
		if v.Magnitude > 3 then
			X.wanderWhy = "no route: walking straight"
			return v.Unit, false
		end
	end
	if not pathBusy then -- path failed or finished early: pick a new spot
		X.wanderWhy = "no route, picking another spot"
		wanderGoal, wps = nil, nil
		wanderWaitUntil = now + 0.3
	end
	return Vector3.zero, false
end
end

----------------------------------------------------------------------
----------------------------------------------------------------------
-- TARGET / CONTROL LIFECYCLE
----------------------------------------------------------------------
local function validTarget()
	return target and target.Parent == Players and tChar and tChar.Parent and tHum and tHum.Health > 0
		and tHrp and tHrp.Parent
end

function setTarget(p) -- assigns the forward-declared local above
	target, history, tVel, lastSample = p, {}, Vector3.zero, 0
	PL.inst, PL.trend, PL.feint = Vector3.zero, Vector3.zero, nil
	PL.omega, PL.accel, PL.lastInst = 0, Vector3.zero, nil
	X.chargeUntil = nil
	smoothPred, smoothLook, facing = nil, nil, false
	predQueue = {}
	if X.hop then X.hop.active = false end
	punishFrom, punishUntil, watchEnd = 0, 0, 0
	resetFight()
	G.reset()
	X.immune.reset()
	PL.ep = nil
	if p then X.stats.targets += 1 end
	wps, mode, attackArmedAt = nil, "Chasing", nil
	inCombat = false
	leap = nil
	if p then
		tChar = p.Character
		tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
		tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
		profile = getProfile(p)
		local pr = profile
		if tHum and not X.deathWatched[tHum] then
			-- one listener per humanoid, kept across target switches (switching targets mid-fight used to lose the kill)
			local victim = tHum
			X.deathWatched[victim] = true
			victim.Died:Connect(function()
				local now2 = time()
				if enabled and not X.selfReset and hrp and now2 - (X.nearAt[victim] or -100) < 6 then
					if credited[victim] then return end
					credited[victim] = true
					kos += 1 -- every KO we were near (kills + assists)
					local mine, why = X.killer(victim, X.ourHitAt[victim], X.lastHitBy[victim])
					if mine then -- an ACTUAL kill: we dealt the last blow
						X.sess.kills += 1
						X.games.add("kills")
						PL.close("kill")
						recordResult(pr, true)
						X.sess.streak += 1
						X.sess.best = math.max(X.sess.best, X.sess.streak)
						X.chat.onKill(p, pr)
						if fight.engagedAt then
							X.stats.ttkSum += time() - fight.engagedAt
							X.stats.ttkCount += 1
						end
						dlog("KILL: " .. p.Name .. " (" .. why .. ")")
					else -- someone else finished them
						X.sess.assists += 1
						X.games.add("assists")
						dlog("assist (not my kill): " .. p.Name .. " - " .. why)
					end
				end
			end)
		end
	else
		tChar, tHum, tHrp, profile = nil, nil, nil, nil
	end
	watchTargetSwings(tChar)
	refreshFilter()
	X.uiCall(showTarget, p)
end

----------------------------------------------------------------------
-- UNKILLABLE DETECTION: someone we keep fighting who never loses health (god mode, endless health, heals it all back,
-- spawn protection) is a waste of time - leave them alone for a while and go after someone else
----------------------------------------------------------------------
X.immune = { ban = setmetatable({}, { __mode = "k" }) } -- player -> time() until which we ignore them
function X.immune.reset()
	local im = X.immune
	im.melee, im.swings, im.startFrac, im.lowFrac, im.ffSince = 0, 0, nil, 1, nil
end
X.immune.reset()
X.reachBan = setmetatable({}, { __mode = "k" }) -- player -> time() until which we ignore them (they're above our reach)
function X.immune.banned(p)
	local u = X.immune.ban[p]
	if u ~= nil and time() < u then return true end
	local r = X.reachBan[p]
	return r ~= nil and time() < r
end
function X.immune.drop(why)
	local p = target
	X.immune.ban[p] = time() + CONFIG.UnkillableBanTime
	dlog("unkillable: " .. p.Name .. " (" .. why .. ") - leaving them alone for " .. CONFIG.UnkillableBanTime .. "s")
	setTarget(nil)
	return true
end
-- called every frame while we have a target; returns true if it just dropped them (the caller must stop using the old target)
function X.immune.check(now, dt, d)
	if not CONFIG.SkipUnkillable then return false end
	local im = X.immune
	-- spawn protection that is up while we fight: our hits can't land at all
	if tChar and tChar:FindFirstChildOfClass("ForceField") then
		im.ffSince = im.ffSince or now
		if d < 15 and now - im.ffSince > 2 then return im.drop("has a ForceField") end
	else
		im.ffSince = nil
	end
	-- progress only counts while we're actually trading blows in melee range
	if inCombat and d <= CONFIG.AttackRange + 2 then
		local frac = tHum.Health / math.max(tHum.MaxHealth, 1)
		if frac ~= frac or frac == math.huge then frac = 1 end -- NaN / infinite health
		im.melee += dt
		if not im.startFrac then im.startFrac = frac end
		im.lowFrac = math.min(im.lowFrac, frac)
		local T, S = CONFIG.UnkillableFightTime, CONFIG.UnkillableSwings
		if im.melee >= T and im.swings >= S and im.startFrac - im.lowFrac < CONFIG.UnkillableMaxDrop then
			return im.drop(string.format("never lost health: %d swings in %.0fs", im.swings, im.melee))
		end
		-- they do lose health but heal it all back: no net progress after a much longer fight
		if im.melee >= T * 2 and im.swings >= S * 2 and frac >= im.startFrac - 0.02 then
			return im.drop(string.format("heals it all back: %d swings in %.0fs", im.swings, im.melee))
		end
	end
	return false
end

local function setControls(on)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controls = module:GetControls()
		if on then controls:Enable() else controls:Disable() end
	end)
end

local function setEnabled(v)
	if enabled and not v and CONFIG.ChatSessionSummary and (X.sess.kills + deaths) > 0 then
		X.chat.send(string.format(X.chat.pick("summary", X.chat.pools.summary),
			math.floor(X.sess.up / 60), X.sess.kills, deaths, X.chat.kdText(X.sess.kills, deaths), X.sess.best))
	end
	if v ~= enabled then X.uiCall(function() X.ui.toast(v and "Sword Bot is on" or "Sword Bot is off", v and ON or OFF) end) end
	enabled = v
	if v then
		setControls(false)
	else
		setControls(true)
		if humanoid then
			humanoid:Move(Vector3.zero, false)
			humanoid.AutoRotate = true
		end
		setTarget(nil)
		mode = "Idle"
		X.saveProfiles()
		X.games.save()
	end
	X.uiCall(paintSwitch)
	X.uiCall(updateUI, false)
end

local function bindCharacter(char)
	character = char
	X.selfReset = false
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
	nav.prev, nav.gpos, nav.vel = nil, nil, Vector3.zero
	lastHealth = humanoid.Health
	humanoid.Died:Connect(function()
		if X.selfReset then return end -- our own flung reset: not a death in a fight
		do -- death report: what the last seconds looked like (for tuning)
			local trace = {}
			for _, e in ipairs(X.hpTrace or {}) do table.insert(trace, string.format("%.0f", e.h)) end
			local armedNear = 0
			if hrp then
				for _, q in ipairs(Players:GetPlayers()) do
					local qr = q ~= player and q.Character and q.Character:FindFirstChild("HumanoidRootPart")
					if qr and hasSword(q) and (qr.Position - hrp.Position).Magnitude < 15 then armedNear += 1 end
				end
			end
			dlog(string.format("DEATH: plan %s, mode %s, target %s, armed nearby %d, hp trace [%s]",
				tostring(PL.name), tostring(mode), target and target.Name or "none", armedNear, table.concat(trace, " ")))
		end
		deaths += 1
		X.sess.streak = 0
		X.chat.onDeath()
		-- count it as a loss against whoever we were fighting up close
		-- a loss only if THIS player's blow killed us (creator tag), not a fall or someone else
		local tag = humanoid:FindFirstChild("creator")
		if profile and target and tag and tag.Value == target then
			PL.close("died")
			recordResult(profile, false)
			X.chat.onLoss(profile, target.Name)
			dlog("died to " .. target.Name)
		end
	end)
	humanoid.HealthChanged:Connect(function(h)
		if h < lastHealth then lastHurt = time() end
		X.hpTrace = X.hpTrace or {}
		table.insert(X.hpTrace, { t = time(), h = h })
		while #X.hpTrace > 0 and time() - X.hpTrace[1].t > 3 do table.remove(X.hpTrace, 1) end
		lastHealth = h
	end)
	retreating = false
	setTarget(nil)
	refreshFilter()
	if enabled then setControls(false) end
end

----------------------------------------------------------------------
-- MAIN STEP
----------------------------------------------------------------------
local function angleBetween(a, b)
	a, b = flat(a), flat(b)
	if a.Magnitude < 0.01 or b.Magnitude < 0.01 then return 0 end
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- Twitch detector: counts big heading jumps per second and blames a cause; reports into the Debug tab.
local trackTwitch
do
local tw = { last = nil, n = 0, t0 = 0, causes = {} }
function trackTwitch(now, dir, cause)
	local h = flat(dir)
	if h.Magnitude > 0.2 then
		if tw.last and angleBetween(tw.last, h) > 35 then
			tw.n += 1
			tw.causes[cause] = (tw.causes[cause] or 0) + 1
		end
		tw.last = h.Unit
	end
	if now - tw.t0 >= 1 then
		if tw.n >= 4 then
			local best, bc = "?", 0
			for c, n in pairs(tw.causes) do
				if n > bc then best, bc = c, n end
			end
			dlog(string.format("twitch: %d heading jumps in 1s, mostly %s (%s)", tw.n, best, tostring(mode)))
			if X.ui and X.ui.setFlip then
				X.ui.setFlip(string.format("%s: %d turns in 1s (%s) | flips: %d", best, tw.n, tostring(mode), X.stats.twitches + 1))
			end
			X.stats.twitches += 1
		end
		tw.n, tw.t0, tw.causes = 0, now, {}
	end
end
end

-- which way to side-step when stuck: the side with more room (random only if it's a tie)
local function freeSide(dir)
	local d = flat(dir)
	if d.Magnitude < 0.01 then return math.random() < 0.5 and 1 or -1 end
	d = d.Unit
	local function room(sign)
		local hit = Workspace:Raycast(hrp.Position, rotY(d, math.rad(90) * sign) * 5, rayParams)
		return hit and (hit.Position - hrp.Position).Magnitude or 5
	end
	local a, b = room(1), room(-1)
	if math.abs(a - b) < 0.5 then return math.random() < 0.5 and 1 or -1 end
	return a > b and 1 or -1
end

-- Spin detector: total body rotation per second; logs when it's excessive so the cause shows up in the Debug tab
local trackSpin
do
local spin = { last = nil, acc = 0, t0 = 0 }
function trackSpin(now)
	local look = flat(hrp.CFrame.LookVector)
	if look.Magnitude > 0.1 then
		local yaw = math.atan2(-look.X, -look.Z)
		if spin.last then
			spin.acc += math.abs((yaw - spin.last + math.pi) % (2 * math.pi) - math.pi)
		end
		spin.last = yaw
	end
	if now - spin.t0 >= 1 then
		local deg = math.deg(spin.acc) / (now - spin.t0)
		if deg > 540 then
			dlog(string.format("spin: %.0f deg/s (%s, %s)", deg, tostring(mode), facing and "locked on target" or "auto-rotate"))
		end
		spin.acc, spin.t0 = 0, now
	end
end
end

-- ESCAPE: if the floor we're standing on is flagged unstable (fading / toggling CanCollide), run (and hop) to the nearest
-- stable ground before doing anything else. If no safe ground is in reach it does nothing special.
function X.findSafeGround(pos, curPart)
	local feetY = pos.Y - 3
	local toT = (target and tHrp and tHrp.Parent) and unitOr(flat(tHrp.Position - pos), nil) or nil
	for _, r in ipairs({ 4, 6, 8, 10, 12, CONFIG.EscapeRadius }) do
		local best, bestScore
		for i = 0, 15 do
			local a = i * math.pi / 8
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local pt = pos + dir * r
			if stepOK(pt, feetY) then -- real, stable ground with a sane drop
				if not Workspace:Raycast(pos, dir * r, rayParams) then -- no wall in the way
					local mid = pos + dir * (r / 2)
					local mh = Workspace:Raycast(mid + UP, Vector3.new(0, -(CONFIG.MaxDrop + 4), 0), rayParams)
					-- the middle must be ground too (the unstable floor itself is fine to cross, we're running off it)
					if mh and ((curPart and mh.Instance == curPart) or stepOK(mid, feetY)) then
						local score = r - (toT and dir:Dot(toT) * 2 or 0) -- tie-break: lean toward our target
						if not bestScore or score < bestScore then best, bestScore = pt, score end
					end
				end
			end
		end
		if best then return best end -- nearest ring that has somewhere safe
	end
	return nil
end

-- FLING RECOVERY: pause while launched, resume once back on solid ground; reset the character (health to 0, it respawns) if stuck outside the map
X.fling = { safe = nil, active = false, since = 0 }
function X.resetCharacter(why, now)
	X.fling.active, X.fling.safe = false, nil
	X.stats.resets = (X.stats.resets or 0) + 1
	X.selfReset = true -- so the death that follows isn't counted as a kill, assist or loss
	dlog("resetting character: " .. why)
	setTarget(nil)
	pcall(function() humanoid.Health = 0 end)
	return true
end

function X.fling.check(now)
	if not CONFIG.FlingRecovery then return false end
	local f = X.fling
	local pos = hrp.Position
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local outOfMap = pos.Y < CONFIG.FlingVoidY or pos.Magnitude > CONFIG.FlingMapBound
	local launched = f.safe ~= nil and not grounded and flat(pos - f.safe).Magnitude > CONFIG.FlingDistance
		and nav.vel.Magnitude > CONFIG.FlingSpeed
	if not f.active then
		if outOfMap then
			return X.resetCharacter("flung outside the map", now)
		elseif launched then
			f.active, f.since = true, now
			leap = nil
			humanoid:Move(Vector3.zero, false)
			dlog("flung: pausing until I land on solid ground")
		elseif grounded then
			f.safe = pos -- last place we stood safely
		end
		return f.active
	end
	if grounded and not outOfMap then
		f.active, f.safe = false, pos
		dlog("landed: back to normal")
		return false
	end
	humanoid:Move(Vector3.zero, false)
	if outOfMap then return X.resetCharacter("flung outside the map", now) end
	if now - f.since > CONFIG.FlingMaxWait then return X.resetCharacter("couldn't land in time", now) end
	return true
end

function X.escape(now)
	if not (CONFIG.AvoidFakeFloors and CONFIG.AvoidUnstableFloors and CONFIG.EscapeUnstableFloors) or leap then return false end
	local pos = hrp.Position
	local below = Workspace:Raycast(pos, Vector3.new(0, -7, 0), rayParams)
	local curPart = below and below.Instance
	local onBad = curPart ~= nil and curPart:IsA("BasePart") and now < X.watchFloor(curPart).untilT
	if onBad and X.escIgnorePart == curPart and now < (X.escIgnoreUntil or 0) then onBad = false end -- we already gave up on this one
	local esc = X.esc
	if onBad then
		if not esc then esc = { holdUntil = 0, nextSearch = 0 } X.esc = esc end
		esc.holdUntil, esc.part = now + 0.6, curPart
	elseif not esc or now > esc.holdUntil then
		X.esc = nil
		return false
	end
	if not esc.pt or now >= esc.nextSearch then
		esc.nextSearch = now + 0.35
		local pt = X.findSafeGround(pos, esc.part)
		if not pt then
			if not esc.warned then esc.warned = true dlog("unstable floor under us, but no safe ground within reach") end
			if not onBad then X.esc = nil end
			return false
		end
		if not esc.pt then
			X.stats.escapes += 1
			dlog(string.format("escaping unstable floor -> %.0f studs away", flat(pt - pos).Magnitude))
		end
		esc.pt = pt
	end
	local to = flat(esc.pt - pos)
	if to.Magnitude < 1.5 then
		-- we're at the best spot we can find and the floor here is still flagged: stop escaping and ignore this floor for a bit.
		-- (before, this held the bot still forever: no movement, and nothing else ran - it sat on "no one in range")
		X.esc = nil
		X.escIgnorePart, X.escIgnoreUntil = curPart, now + 8
		dlog("unstable floor: no safer spot than this, carrying on")
		return false
	end
	local dir = to.Magnitude > 0.1 and to.Unit or Vector3.zero
	mode = "Escaping"
	humanoid.AutoRotate = true
	if humanoid.FloorMaterial ~= Enum.Material.Air and now - lastJump > 0.55
		and (to.Magnitude > 6 or esc.pt.Y - (pos.Y - 3) > 1.2) then
		lastJump = now
		humanoid.Jump = true
	end
	smoothDir = dir
	humanoid:Move(dir, false)
	step_dodging = false
	return true
end

-- read-out for the CURRENT target, 5x a second; logs when the opening changes
function G.update(now)
	if not CONFIG.Gank then
		G.on = false
		return
	end
	if now < G.nextRead then return end
	G.nextRead = now + 0.2
	G.busy, G.hurt, G.weak, G.turned = G.read(target, tHum, tHrp)
	G.engaged = G.busy ~= nil
	G.on = G.engaged or G.hurt or G.weak or G.turned
	local parts = {}
	if G.engaged then table.insert(parts, "busy with " .. G.busy.Name) end
	if G.hurt then table.insert(parts, "taking damage") end
	if G.weak then table.insert(parts, "low hp") end
	if G.turned then table.insert(parts, "back turned") end
	G.why = #parts > 0 and table.concat(parts, ", ") or nil
	if G.why and G.why ~= G.loggedWhy and now - G.whyAt > 1.5 then
		G.loggedWhy, G.whyAt = G.why, now
		dlog(string.format("gank: %s - %s", target.Name, G.why))
	elseif not G.why and G.loggedWhy then
		G.loggedWhy = nil
		dlog("gank: opening gone")
	end
end

-- where to run while chasing a gank target: a point BEHIND them (not their face), easing back onto them as we close in
function G.goal(pred, tLook, d)
	if not (CONFIG.Gank and G.on) or d < 7 then return pred end
	local spot = pred - tLook * 5 * math.clamp((d - 7) / 10, 0, 1)
	if hasSafeGround(spot) then return spot end
	return pred
end

-- scores the predictions made 0.25s ago against where the target actually is now (learns linear vs flip-rhythm accuracy)
	X.hop = { active = false, untilT = 0, jumped = false, jumpAt = 0, readyAt = 0 } -- hop-in move state
	X.mv = { name = nil, untilT = 0, jumped = false, lunged = false, ready = {} } -- scripted moves state
-- nothing solid between us and them (so the swing can actually land instead of hitting a wall)
local function clearShot(from, to)
	local origin = from + Vector3.yAxis
	return Workspace:Raycast(origin, to - origin, rayParams) == nil
end

local function scorePredictions(now)
	local q = predQueue
	while q[1] and now >= q[1].due do
		local e = table.remove(q, 1)
		if profile and tHrp and tHrp.Parent then
			local actual = tHrp.Position
			profile.eLin = ema(profile.eLin, flat(actual - e.lin).Magnitude, 0.05)
			profile.eFlip = ema(profile.eFlip, flat(actual - e.flip).Magnitude, 0.05)
		end
	end
	while #q > 60 do table.remove(q, 1) end
end

local function step(dt)
	if not enabled then return end
	if not (humanoid and humanoid.Health > 0 and hrp and hrp.Parent) then return end
	local now = time()
	if leap and now > leap.untilT then leap = nil end

	-- measure our own speed from position changes (read-only, no physics properties) + remember last solid footing for the airborne ledge guard
	do
		local p0 = hrp.Position
		if hrp.CollisionGroup ~= rayParams.CollisionGroup then rayParams.CollisionGroup = hrp.CollisionGroup end
		if nav.prev and dt > 0 and (p0 - nav.prev).Magnitude < 10 then
			nav.vel = nav.vel:Lerp(flat(p0 - nav.prev) / dt, 0.5)
		else
			nav.vel = Vector3.zero
		end
		nav.prev = p0
		if humanoid.FloorMaterial ~= Enum.Material.Air and not leap then
			nav.gpos, nav.gy = p0, p0.Y - 3
		end
	end

	X.frameWhy = nil
	if X.fling.check(now) then X.frameWhy = "recovering from a fling" return end
	if X.escape(now) then X.frameWhy = "escaping floor" return end

	if target and not validTarget() then setTarget(nil) end
	if not target or now >= nextPickAt then
		nextPickAt = now + 0.5
		local best = pickTarget()
		if best ~= target and (not target or not inCombat or now - (X.lastSwitchAt or -100) >= CONFIG.MinSwitchTime) then
			X.lastSwitchAt = now
			setTarget(best)
		end
	end

	if not target then
		inCombat = false -- no target means no fight (a stale "in combat" flag can make the next frame use a nil profile)
		if mode ~= "Wandering" then resetWander() wps = nil end
		mode, dist = "Wandering", 0
		manageSword(nil, now)
		if CONFIG.Rest and humanoid.Health / math.max(humanoid.MaxHealth, 1) < CONFIG.RestBelow then
			X.wanderWhy = string.format("resting (hp %d%%)", math.floor(humanoid.Health / math.max(humanoid.MaxHealth, 1) * 100))
			humanoid:Move(Vector3.zero, false)
			return
		end
		local dir, jump = wander(now)
		if dir.Magnitude < 0.01 or leap then
			smoothDir = dir
		else
			smoothDir = steerToward(smoothDir, dir, math.rad(CONFIG.ChaseTurnRate) * dt)
			dir = smoothDir
		end
		local preSafe = dir
		dir = safeDir(dir)
		local altered = preSafe.Magnitude > 0.05 and (dir.Magnitude < 0.05 or angleBetween(preSafe, dir) > 20)
		trackTwitch(now, dir, altered and "ledge/fake-floor avoidance" or "wander path")
		if not leap and dir.Magnitude > 0.2 and obstacleAhead(dir) then jump = true end
		humanoid.AutoRotate = true
		humanoid:Move(dir, false)
		if jump then tryJump(now, dir) end
		return
	end

	sampleTarget(now)
	scorePredictions(now)
	-- clanker's arena read (every 0.5s): count floor around THEM. On a narrow strip, circling and flanking walk us off the edge
	if inCombat and now >= (PL.arenaCheckAt or 0) then
		PL.arenaCheckAt = now + 0.5
		local open = 0
		for _, o in ipairs({ { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 2.2, 2.2 }, { -2.2, 2.2 }, { -2.2, -2.2 }, { 2.2, -2.2 } }) do
			if groundAt(tHrp.Position + Vector3.new(o[1], 0, o[2])) then open += 1 end
		end
		PL.arena = open > 5 and "open" or "narrow"
	end
	if now >= nextArmedCheck then
		nextArmedCheck = now + 0.25
		targetArmed = hasSword(target)
	end

	local pos, tPos = hrp.Position, tHrp.Position
	if now >= (X.lagAt or 0) then -- latency: ping is round-trip, so one way is half. Smoothed, read twice a second
		X.lagAt = now + 0.5
		local pingMs = X.ping()
		if pingMs then X.lagS = ema(X.lagS or 0.05, math.clamp(pingMs / 2000, 0, 1.0), 0.3) end
	end
	local lag = X.lagS or 0.05
	-- the target's data can be cleared partway through a frame (profile/humanoid go nil): drop it and pick again next frame
	if not (profile and tHum and tHrp) then setTarget(nil) return end
	local d = flat(tPos - pos).Magnitude
	dist = (tPos - pos).Magnitude
	if d < 25 and tHum then X.nearAt[tHum] = now end -- for kill credit: we were in the fight with them

	if X.immune.check(now, dt, d) then return end -- they won't die: dropped, pick someone else next frame

	local tool = manageSword(dist, now)

	if now >= nextDirectCheck then
		nextDirectCheck = now + 0.15
		local wasDirect = directOK
		local raw = computeDirectOK()
		if raw then
			directTrueSince = directTrueSince or now
			if directOK then directFalseSince = nil
			elseif now - directTrueSince > 0.25 then directOK, directFalseSince = true, nil end
		elseif directOK then
			directTrueSince = nil
			directFalseSince = directFalseSince or now
			if now - directFalseSince > 0.35 then directOK = false end -- don't flip modes on a blip
		else
			directTrueSince = nil
		end
		if wasDirect ~= directOK then
			dbg.switches += 1
			dlog("chase: " .. (directOK and "straight line" or "pathfinding"))
		end
	end

	if inCombat then PL.tick(now, profile) end
	-- prediction
	local lead = math.clamp(d / math.max(humanoid.WalkSpeed, 8), 0.05, 0.55)
	-- close in, aim at where they are (a long lead at melee range whiffs); then add half our ping, since our swing lands late
	lead *= math.clamp((d - 4) / 6, 0.25, 1)
	local okPing, ownPing = pcall(function() return player:GetNetworkPing() end)
	if not okPing or type(ownPing) ~= "number" then ownPing = 0 end
	lead += math.min(ownPing * 0.5, 0.15)
	-- learned: how this fight is going. Losing the damage race (or losing to this player before) -> fight smarter, not harder
	local cautious = profile.theirSwings >= 3 and (fight.taken > fight.dealt + 20 or edgeOf(profile) < 0.35)
	if cautious ~= X.wasCautious then
		X.wasCautious = cautious
		dlog(cautious and "style: cautious (losing to this player)" or "style: normal")
	end
	-- learned: this player runs when their health is low, and they're low now -> finish them, don't circle
	local finisher = ((profile.lowSamples >= 20 and profile.lowHpRun > 0.6) or edgeOf(profile) > 0.6)
		and tHum.Health / math.max(tHum.MaxHealth, 1) < 0.4
	local styleNow = X.currentStyle(profile)
	local sm = (styleNow and X.STYLE_TACTICS[styleNow]) or {} -- this player's style (empty until we know them)
	if profile.retreat > 0.6 or finisher then lead *= 1.3 end -- runners get cut off
	lead *= sm.lead or 1
	local predRaw = predictedPosition(now, lead)
	do -- learned: which predictor has been more accurate on this player? blend toward it
		local H = 0.25
		predQueue[#predQueue + 1] = { due = now + H, lin = tPos + tVel * H, flip = predictedPosition(now, H) }
		local linLead = tPos + tVel * lead
		local wFlip = profile.eLin / (profile.eLin + profile.eFlip + 1e-3) -- high = flip-rhythm predictor has been better
		predRaw = linLead:Lerp(predRaw, math.clamp(wFlip, 0, 1))
	end
	-- don't predict them onto a ledge or into the void: pull the prediction back halfway if the spot isn't safe
	if not hasSafeGround(predRaw) then predRaw = tPos + (predRaw - tPos) * 0.5 end
	-- the raw prediction jumps around when the target strafes (velocity + flip-rhythm guess),
	-- which swings fwd/right and makes the bot dart sideways. Low-pass it.
	smoothPred = smoothPred and smoothPred:Lerp(predRaw, math.clamp(dt * (inCombat and 8 or 3), 0, 1)) or predRaw
	local pred = smoothPred

	-- up close aim at where they ARE (leading them makes us orbit/overshoot); far away use the lead
	local aim = tPos:Lerp(pred, math.clamp((d - 4) / 5, 0, 1))
	local fwd = unitOr(flat(aim - pos), flat(hrp.CFrame.LookVector))
	local right = fwd:Cross(UP)
	local rawLook = unitOr(flat(tHrp.CFrame.LookVector), fwd)
	smoothLook = smoothLook and unitOr(smoothLook:Lerp(rawLook, math.clamp(dt * 8, 0, 1)), rawLook) or rawLook
	local tLook = smoothLook
	local facingUs = tLook:Dot(-fwd) -- >0: they are looking at us, <0: we're behind them
	do -- which way to move along the circle to reach their back: +1 / -1 along `right` (kept steady when we're dead ahead)
		local rd = right:Dot(-tLook)
		if math.abs(rd) > 0.15 then X.rearSign = rd >= 0 and 1 or -1 end
		X.rearSign = X.rearSign or 1
	end
	G.update(now)

	-- low health retreat
	local hpFrac = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	-- extra reasons to back off: the next hit or two could kill us, or we're being ganged up on
	local lethal = X.avgHit ~= nil and humanoid.Health <= X.avgHit * 1.6
	local outnumbered = false
	if hpFrac < CONFIG.OutnumberedBelow then
		local armedNear = 0
		for _, q in ipairs(Players:GetPlayers()) do
			if q ~= player then
				local qr = q.Character and q.Character:FindFirstChild("HumanoidRootPart")
				local qh = q.Character and q.Character:FindFirstChildOfClass("Humanoid")
				if qr and qh and qh.Health > 0 and (qr.Position - pos).Magnitude < 12 and hasSword(q) then armedNear += 1 end
			end
		end
		outnumbered = armedNear >= 2
	end
	if not retreating and targetArmed and now > retreatBlockedUntil
		and (hpFrac < CONFIG.RetreatBelow + (cautious and 0.1 or 0) or lethal or outnumbered
		or (CONFIG.Tryhard and (profile.trade or 0) < -0.2 and hpFrac < 0.55)) then
		retreating, retreatStart = true, now
		dlog(string.format("retreat: hp %d%%%s%s", math.floor(hpFrac * 100), lethal and " (next hit could kill)" or "", outnumbered and " (outnumbered)" or ""))
	elseif retreating and (hpFrac > CONFIG.RetreatUntil or now - retreatStart > CONFIG.RetreatMax) then
		retreating = false
		-- only pause retreating when we're actually recovered; if still low, we may retreat again almost at once
		retreatBlockedUntil = now + (hpFrac > CONFIG.RetreatBelow + 0.1 and 5 or 1)
	end

	-- did one of our swings just land? (their health drops right after we swing) -> learn how they answer a hit
	local tHp = tHum.Health
	-- damage ledger: what we dealt vs what they dealt to us in this fight
	local myHp = humanoid.Health
	if fight.lastMyHp and myHp < fight.lastMyHp - 0.5 and now - lastTargetSwing < 0.8 and d < 9 then
		fight.taken += fight.lastMyHp - myHp
		X.stats.taken += fight.lastMyHp - myHp
		X.reachHit(fight.lastMyHp - myHp)
		X.avgHit = X.avgHit and ema(X.avgHit, fight.lastMyHp - myHp, 0.3) or (fight.lastMyHp - myHp) -- typical size of a hit on us
	end
	fight.lastMyHp = myHp
	if fight.lastHp and tHp < fight.lastHp - 0.5 and now - fight.ourSwingAt < 0.7 + lag * 2 then
		fight.dealt += fight.lastHp - tHp
		X.stats.dealt += fight.lastHp - tHp
		X.stats.hits += 1
		fight.lastHitAt = now
		X.ourHitAt[tHum] = now
		profile.hitsLanded += 1
		fight.hitAt, fight.countered, fight.hitDist = now, false, flat(tPos - pos).Magnitude
		if inCombat and profile.hitsLanded >= 3 then
			if profile.counterRate > 0.5 and now >= dodgeReadyAt and not (now >= dodgeStartAt and now < dodgeUntil) then
				-- they always hit back right after being hit: take the hit and step out of their answer
				dodgeStartAt, dodgeUntil, dodgeReadyAt = now + 0.05, now + 0.4, now + 0.9
				dodgeSign, dodgeJump = math.random() < 0.5 and 1 or -1, false
				dlog("hit, then dodge (they hit back)")
				X.stats.dodges += 1
			elseif profile.fleeHit > 0.6 and mode ~= "Flanking" and mode ~= "Backstab" then
				mode, modeUntil, swings = "Committing", now + 1.2, 0 -- they run after a hit: keep the pressure on
				dlog("hit, they run: keep pressure")
			end
		end
	end
	fight.lastHp = tHp
	if fight.hitAt and now - fight.hitAt >= 0.9 then
		if not fight.countered then profile.counterRate = ema(profile.counterRate, 0, 0.3) end
		local fled = flat(tPos - pos).Magnitude - fight.hitDist > 2.5
		profile.fleeHit = ema(profile.fleeHit, fled and 1 or 0, 0.3)
		fight.hitAt = nil
	end

	-- dodge reaction to their swing (delayed + only sometimes = human-like)
	if now >= nextSwingCheck then
		nextSwingCheck = now + 0.08
		local sw = targetSwinging()
		if sw and not wasSwinging and d < 11 then
			X.stats.swSeen += 1
			-- learned: players who strike first, or swing from the air, get dodged more often
			local dodgeChance = CONFIG.DodgeChance
			if profile.engagements >= 3 and profile.firstStrike > 0.6 then dodgeChance += 0.2 end
			if profile.theirSwings >= 5 and profile.jumpSwing > 0.5 and tHum.FloorMaterial == Enum.Material.Air then dodgeChance += 0.2 end
			if cautious then dodgeChance += 0.1 end
			if edgeOf(profile) > 0.6 then dodgeChance -= 0.15 end -- winning this matchup: trade blows instead of dancing
			if X.currentStyle(profile) == "aggressive" then dodgeChance += 0.05 end -- they come at us: expect more swings
			dodgeChance *= PL.cur.dodge -- plan
			if now >= dodgeReadyAt and math.random() < math.min(dodgeChance, 0.95) then
				dodgeStartAt = now + (cautious and rand(0.04, 0.10) or rand(0.08, 0.18))
				dodgeUntil = dodgeStartAt + 0.35
				dodgeReadyAt = now + 0.6 -- was 0.9: can dodge again sooner
				-- clanker's idea: their sword arm sweeps from one side, so step away from that side (70% of the time)
				local handSide = unitOr(flat(tHrp.CFrame:VectorToWorldSpace(Vector3.new(1.5, 0, -1.2))), right):Dot(right)
				local away = handSide > 0 and -1 or 1
				dodgeSign = math.random() < 0.7 and away or -away
				dodgeJump = math.random() < 0.3
				dlog(string.format("dodge %s%s", dodgeSign > 0 and "right" or "left", dodgeJump and " + jump" or ""))
				X.stats.dodges += 1
				X.stats.dodgedSw += 1
				-- keep strafing the way we dodged afterwards (no instant reversal)
				strafeSign = dodgeSign
				strafeFlipAt = math.max(strafeFlipAt, dodgeUntil + 0.8)
			end
			-- they just swung: once we're clear of it, rush in while they recover
			local gap = (profile.swingGap and profile.theirSwings >= 3) and profile.swingGap or 0.6
			punishFrom = dodgeUntil > now and dodgeUntil or now + 0.05
			punishUntil = punishFrom + math.clamp(gap * 0.8, 0.4, 0.9) * PL.cur.punish
			X.stats.punishes += 1
		end
		wasSwinging = sw
	end
	local dodging = now >= dodgeStartAt and now < dodgeUntil
	local punishing = now >= punishFrom and now < punishUntil and not dodging

	local moveDir, faceTarget, wantJump = Vector3.zero, false, false

	-- enter close combat at EngageRange, only leave at +4 studs (stops mode flicker)
	if inCombat then
		if d > CONFIG.EngageRange + 4 or not directOK then inCombat = false end
	elseif d <= CONFIG.EngageRange and directOK then
		inCombat = true
		fight.engagedAt, fight.decided, fight.ourFirstSwingAt = now, false, nil -- a new fight starts
		X.stats.engages += 1
	end

	-- FEINT: a short fake that baits a reaction. "fw" backs out of reach so a swing from them whiffs; "fd" steps in so they
	-- sidestep. If the bait works, we punish right away while they're recovering.
	if not PL.feint and inCombat and targetArmed and not dodging and not punishing and not retreating
		and d > 2.5 and d < CONFIG.AttackRange + 1.5 and now >= PL.feintReadyAt and now - lastHurt > 1 then
		local mul = (PL.name == "Ambush" or PL.name == "Bait" or PL.name == "Kite") and 1.5 or 1 -- these plans feint more
		mul *= sm.feint or 1
		if (profile.turn or 0) < 0.12 and profile.flips < 3 then mul *= 0.5 end -- predictable movers: skip most feints
		if math.random() < CONFIG.FeintChance * mul then
			PL.feint = { kind = PL.pickFeint(profile), t0 = now, untilT = now + 0.3, won = false,
				lat0 = tVel:Dot(right), air0 = tHum.FloorMaterial == Enum.Material.Air }
			PL.feintReadyAt = now + 2.5
		else
			PL.feintReadyAt = now + 0.8
		end
	end
	local feintDir = Vector3.zero
	if PL.feint and now >= PL.feint.untilT then
		local k = PL.feint.kind
		profile[k .. "N"] = (profile[k .. "N"] or 0) + 1
		profile[k .. "R"] = ema(profile[k .. "R"] or 0.35, PL.feint.won and 1 or 0, rate(profile[k .. "N"], 0.2))
		if PL.feint.won then punishFrom, punishUntil = now, now + 0.5 end
		dlog(string.format("feint %s: %s", k == "fw" and "lure whiff" or "lure dodge", PL.feint.won and "it worked, punishing" or "no reaction"))
		PL.feint = nil
	end
	local feintOn = PL.feint ~= nil
	if feintOn then
		if PL.feint.kind == "fw" and targetSwinging() and now >= PL.feint.t0 then PL.feint.won = true end
		if PL.feint.kind == "fd" and (math.abs(tVel:Dot(right) - PL.feint.lat0) > 7 or (tHum.FloorMaterial == Enum.Material.Air and not PL.feint.air0)) then PL.feint.won = true end
		if now - lastHurt < 0.1 then PL.feint, feintOn = nil, false end -- they hit us: drop it, don't score it
		if feintOn then feintDir = PL.feint.kind == "fw" and -fwd or (fwd + right * strafeSign * 0.3) end
	end

	-- BACK OFF WHILE THEY'RE UNARMED: a player walking at us with no sword out is backed away from, facing them.
	-- The moment they draw a sword (targetArmed) we fight. Capped at 6s so we can't be pushed around forever.
	-- back-off is a state that holds: it starts when they close in while unarmed, and stops only when they're out of
	-- range, draw a sword, or we've been at it 6s (then a 4s rest). Before, the trigger was re-checked every frame, so
	-- backing off pushed them past the trigger, the bot chased, closed in again, and flipped back and forth.
	local backNow = (not targetArmed) and d < 14 and not leap
	local closingIn = tVel:Dot(fwd) > 1.5 or d < 6
	if X.backing then
		if not backNow then
			X.backing = false
		elseif now - (X.backoffSince or now) >= 6 then
			X.backing = false
			X.backoffCoolUntil = now + 4
		end
	elseif backNow and closingIn and now >= (X.backoffCoolUntil or 0) then
		X.backing, X.backoffSince = true, now
	end
	local wantBack = X.backing == true

	if feintOn then
		mode, faceTarget = "Feinting", true
		moveDir = feintDir
	elseif wantBack then
		mode, faceTarget = "Backing off", true
		moveDir = -fwd * 0.9 + right * strafeSign * 0.2 -- away from them, a little sideways so we're not a straight line
		local away = X.awayFrom(hrp.Position) -- and away from anyone else close by
		if away then moveDir += away * 0.9 end
		if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end
	elseif retreating then
		mode, faceTarget = "Retreating", true
		if d < 28 then
			updateStrafe(now)
			moveDir = -fwd + right * strafeSign * 0.4
			local away = X.awayFrom(hrp.Position) -- and away from anyone else close by
			if away then moveDir += away * 0.9 end
			if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end
			if X.narrowAt(hrp.Position, moveDir) then -- narrow strip while retreating: head for the open floor instead
				local open = X.openGroundDir()
				if open then moveDir = open * 0.9 end
			end
		else
			-- far enough: hold and regenerate. Before, this fell through to chasing, so the bot flipped
			-- between chasing and retreating every time it crossed 28 studs.
			moveDir = Vector3.zero
		end
	elseif not inCombat then
		mode = "Chasing"
		moveDir, wantJump = chaseDir(now, G.goal(pred, tLook, d))
	else
		faceTarget = true
		updateStrafe(now)

		-- GANKING: they're busy with someone else / hurt / weak / have their back to us
		if CONFIG.Gank and G.on and mode ~= "Committing" and mode ~= "Flanking" and mode ~= "Backstab" and mode ~= "Lurking" then
			if CONFIG.GankLurk and G.engaged and not (G.hurt or G.weak) and now >= G.lurkReadyAt and d > 7 then
				-- they're busy but healthy: wait outside the fight and let the other player soften them up
				mode, modeUntil = "Lurking", now + CONFIG.GankLurkMax
				G.lurkReadyAt = now + CONFIG.GankLurkMax + 5 -- no endless lurking around one fight
				dlog("gank: lurking, waiting for an opening")
			elseif (G.hurt or G.weak or G.turned or not CONFIG.GankLurk) and now >= G.strikeReadyAt and d < 12 then
				mode, modeUntil, swings = "Backstab", now + 1.8, 0
				G.strikeReadyAt = now + 2.5 -- between strikes we circle, then go again while they stay exposed
				dlog("gank: strike")
				X.stats.ganks += 1
			end
		end

		-- state machine
		if mode ~= "Flanking" and mode ~= "Backstab" and mode ~= "Lurking" then
			local flankChance = CONFIG.FlankChance + (profile.idle > 0.5 and 0.25 or 0)
			do -- learned: do back-attacks actually land on THEM? lean into it or drop it
				local e = X.tacticEdge(profile, "Backstab")
				if e then flankChance = math.clamp(flankChance * (e > 0.12 and 1.6 or (e < -0.12 and 0.4 or 1)), 0, 0.9) end
			end
			flankChance = math.clamp(flankChance * PL.cur.flank, 0, 0.9) -- plan
			if PL.arena == "narrow" then flankChance *= 0.3 end -- narrow strip: few flanks, they run us off the edge
			if now >= flankReadyAt and d > 3.5 and d < 8.5 and facingUs > 0.35
				and hasSafeGround(pred - tLook * 5) and hasSafeGround(pred - tLook * 2.6) then
				flankReadyAt = now + CONFIG.FlankCooldown + math.random() * 3
				if math.random() < flankChance then
					mode, modeUntil = "Flanking", now + 1.4
				end
			elseif facingUs < -0.3 and mode ~= "Committing" then
				mode, modeUntil, swings = "Committing", now + 1.8, 0 -- they turned their back: strike
			end
		end

		if punishing and mode ~= "Committing" and not (mode == "Flanking" and d > CONFIG.AttackRange + 0.5) then
			mode, modeUntil, swings = "Committing", punishUntil + 0.3, 0
		end

		local circleScale = ((profile.retreat > 0.6 or finisher) and 0.6 or 1) * (sm.circle or 1)
		if cautious then circleScale *= 1.6 end -- longer standoffs: wait for their swing to whiff, then punish
		circleScale *= PL.cur.circle -- plan
		if PL.arena == "narrow" then circleScale *= 0.4 end -- narrow strip: hold our ground, don't circle off the edge
		do -- learned: if committing lands better than my circling swings, stand off less; if worse, be more patient
			local agg = (X.tacticEdge(profile, "Committing") or 0) - (X.tacticEdge(profile, "Circling") or 0)
			local note = agg > 0.12 and "more aggressive" or (agg < -0.12 and "more patient" or nil)
			if note then circleScale *= (agg > 0 and 0.7 or 1.4) end
			if note ~= profile.adaptNote then
				profile.adaptNote = note
				if note then dlog(string.format("adapt: %s vs %s (what lands on them changed)", note, target.Name)) end
			end
		end
		if mode == "Flanking" then
			local airborne = humanoid.FloorMaterial == Enum.Material.Air
			if facingUs > 0.4 and d < 5 and not airborne then
				-- they turned to face us before we got around: don't stand there, fight head-on
				mode, modeUntil, swings = "Committing", now + 1.5, 0
				dlog("flank: they turned, fighting head-on")
			elseif (facingUs < -0.1 and d < 6.5) or (now > modeUntil and not airborne) then
				mode, modeUntil, swings = "Backstab", now + 1.6, 0
			elseif now > modeUntil + 1.2 then
				mode, modeUntil = "Circling", now + 1.0 -- the flank has gone on far too long: give it up
				dlog("flank: gave up")
			end
		elseif mode == "Backstab" then
			if now > modeUntil or swings >= 2 then
				mode, modeUntil = "Circling", now + rand(1.0, 2.0) * circleScale
			elseif facingUs > 0.5 and d < 6 then
				-- they turned to face us: chasing their back just orbits them (that's the "spinning"), so fight head-on
				mode, modeUntil, swings = "Committing", now + 1.5, 0
			end
		elseif mode == "Lurking" then
			if not G.on or not G.engaged or G.hurt or G.weak or now > modeUntil or d < 6 then
				mode, modeUntil, swings = "Backstab", now + 1.8, 0
				G.strikeReadyAt = now + 2.5
				dlog("gank: lurk over, striking")
				X.stats.ganks += 1
			end
		elseif mode == "Committing" then
			if now > modeUntil or swings >= (cautious and 1 or PL.cur.commitSwings) then -- cautious: one clean hit, then back out
				mode, modeUntil = "Circling", now + rand(1.0, 2.0) * circleScale
			end
		elseif mode == "Circling" then
			-- clanker's charge rules: they run away from us -> chase them; they come straight at us -> counter-charge,
			-- stepping off the side their sword arm swings from
			local spd = tVel.Magnitude
			local fleeing = d < 10 and spd > 4 and tVel:Dot(fwd) > 0.55 * spd
			local coming = d < 8 and spd > 4 and -tVel:Dot(fwd) > 0.7 * spd
			if coming then
				local armSide = flat(tHrp.CFrame:VectorToWorldSpace(Vector3.new(1.5, 0, -1.2))):Dot(right)
				X.counterSide = armSide > 0 and -1 or 1
				X.counterUntil = now + 0.6
			end
			-- clanker's "non-moving target": if they're standing still, stop orbiting and go in
			if spd < 1 then X.stillSince = X.stillSince or now else X.stillSince = nil end
			local standing = X.stillSince ~= nil and now - X.stillSince > 0.6 and d < 12
			-- ORBIT: they're circling us, so circling back just keeps the standoff going. Cut in after a short while.
			local orbiting = profile.orbit > 0.5 and math.abs(profile.orbitSpin) > 0.5
			if orbiting then
				modeUntil = math.min(modeUntil, now + 0.8)
				if not profile.orbitLogged then
					profile.orbitLogged = true
					dlog("orbit: " .. target.Name .. " is circling me - cutting in")
				end
			end
			if now > modeUntil or finisher or fleeing or coming or standing or (CONFIG.Tryhard and (profile.trade or 0) > 0.15 and profile.recW > profile.recL and d < 6) then mode, modeUntil, swings = "Committing", now + 1.8, 0 end
		else
			mode, modeUntil = "Circling", now + rand(0.6, 1.2) * circleScale
		end

		-- CLOSE-RANGE CHARGE (clanker's idea): short timed bursts that close the last few studs. It never covers a dodge,
		-- a punish, a feint or a retreat: those run after this and override the movement, and any of them ends the burst.
		if X.chargeUntil and (now >= X.chargeUntil or dodging or punishing or targetSwinging() or d > 10 or not targetArmed
			or tHum.FloorMaterial == Enum.Material.Air or retreating or feintOn) then
			X.chargeUntil = nil
			X.chargeReadyAt = now + rand(4, 7) -- next burst comes a few seconds later, never back to back
		end
		if not X.chargeUntil and now >= (X.chargeReadyAt or 0) and inCombat and not dodging and not punishing and not retreating
			and not feintOn and not cautious and d > CONFIG.AttackRange and d <= 10 and facingUs > -0.2
			and tHum.FloorMaterial ~= Enum.Material.Air and tHum.Health > 0 and humanoid.Health / math.max(humanoid.MaxHealth, 1) > 0.5 then
			X.chargeUntil = now + 0.9
			dlog("close-range charge")
		end
		if X.chargeUntil and mode ~= "Flanking" and mode ~= "Backstab" and mode ~= "Lurking" then
			mode, modeUntil = "Committing", math.max(modeUntil, X.chargeUntil)
		end
		if mode == "Flanking" then
			-- run at a spot just behind them, and jump once that spot is about one jump-length away, lined up on it.
			-- (The old rule jumped at a fixed distance to THEM, so a sidestep mid-run landed the bot in front.)
			local toLand = flat((pred - tLook * 2.8) - pos)
			moveDir = unitOr(toLand, fwd)
			local _, reach = jumpStats()
			local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
			local lined = toLand.Magnitude > 0.5 and angleBetween(hrp.CFrame.LookVector, toLand) < 35
			if onGround and lined and toLand.Magnitude <= reach * 0.85 and toLand.Magnitude >= reach * 0.45 then
				wantJump = true
			end
		elseif mode == "Backstab" then
			local spot = pred - tLook * 2.6
			if not hasSafeGround(spot) then spot = pred end
			local v = flat(spot - pos)
			moveDir = v.Magnitude > 1 and v.Unit or fwd * 0.2
		elseif mode == "Lurking" then
			-- hover just outside their fight, circling slowly and watching
			local fc = math.clamp((d - CONFIG.GankLurkRange) * 0.6, -0.5, 0.8)
			moveDir = fwd * fc + right * strafeSign * 0.35
		elseif mode == "Committing" then
			local fc = math.clamp((d - 2.4) * 1.5, -0.3, 1) -- close in tight before/while swinging (continuous, no threshold jitter)
			if punishing then fc = math.max(fc, 0.6) end -- rush in while they recover from their swing
			if profile.ourSwings >= 3 and profile.dodgeBack > 0.5 then fc = math.max(fc, 0.5) end -- they backstep: follow through
			local cut = 0
			if profile.ourSwings >= 3 and profile.dodgesOurs > 0.55 and math.abs(profile.dodgeBias) > 0.25 then
				cut = profile.dodgeBias > 0 and 1 or -1 -- step toward the side they like to dodge to
			end
			if now < (X.counterUntil or 0) then cut = X.counterSide or cut end -- counter-charge: step off their sword side
			moveDir = fwd * fc + right * (cut ~= 0 and cut * 0.5 or strafeSign * 0.35)
		else -- Circling
			-- hover just outside THEIR swing reach but inside ours
			local maxRing = math.max(CONFIG.AttackRange - 0.3, 3.0)
			local ringR = 3.4
			if profile.theirSwings >= 3 and profile.swingRange then ringR = profile.swingRange + 0.7 end
			ringR = math.clamp(ringR + (cautious and 0.4 or 0), 3.0, maxRing)
			local fc = math.clamp((d - ringR) * 1.2, -0.4, 0.9)
			if profile.rush > 0.6 then fc = math.min(fc, 0.1) end -- they walk into us: hold ground and hit first
			-- orbiting at speed drifts outward (the old orbit sat ~5 studs out, beyond sword reach):
			-- the further outside the ring we are, the less we strafe and the more we close in
			local side = 0.9 * (1 - math.clamp(fc, 0, 0.8))
			moveDir = fwd * fc + right * strafeSign * side
		end

		if dodging then
			moveDir = right * dodgeSign + (-fwd) * 0.3
			if dodgeJump then wantJump = true dodgeJump = false end
		end
	end

	-- grade how they reacted to our last swing (feeds their profile: dodge %, dodge side)
	if watchEnd > 0 and now >= watchEnd and watchRight then
		watchEnd = 0
		local pr = profile
		local lat = tVel:Dot(watchRight)
		local airNow = tHum.FloorMaterial == Enum.Material.Air
		local grew = flat(tPos - pos).Magnitude - watchDist
		local hit = tHum.Health < watchHealth - 0.5
		local change = lat - watchLat0 -- change in sideways speed = a reaction, not just their usual strafing
		local dodgedIt = (not hit) and (math.abs(change) > 8 or (airNow and not watchAir0) or (grew > 2.5 and pr.retreat < 0.6))
		pr.ourSwings += 1
		-- outcome learning: did this tactic land, and from how far out?
		do
			local name = X.wTactic or "?"
			local t = pr.tact[name]
			if not t then t = { n = 0, rate = 0.35 } pr.tact[name] = t end
			t.n += 1
			t.rate = ema(t.rate, hit and 1 or 0, rate(t.n, 0.15))
			local wfd = X.wFd or watchDist
			if hit then
				pr.hitN += 1
				pr.hitDist = pr.hitDist and ema(pr.hitDist, wfd, rate(pr.hitN, 0.2)) or wfd
			else
				pr.missN += 1
				pr.missDist = pr.missDist and ema(pr.missDist, wfd, rate(pr.missN, 0.2)) or wfd
			end
		end
		local lr = rate(pr.ourSwings, 0.2)
		pr.dodgesOurs = ema(pr.dodgesOurs, dodgedIt and 1 or 0, lr)
		pr.dodgeBack = ema(pr.dodgeBack, (not hit and grew > 2.5) and 1 or 0, lr)
		pr.dodgeHop = ema(pr.dodgeHop, (not hit and airNow and not watchAir0) and 1 or 0, lr)
		if dodgedIt and math.abs(change) > 8 then
			pr.dodgeBias = ema(pr.dodgeBias, change > 0 and 1 or -1, 0.3)
			X.dodgeSeenAt = now -- they really dodged a swing just now (this is what the dodge-side bias keys off)
		end
	end

	-- SCRIPTED MOVES: short manoeuvres started only in the right situation (lunge a fleeing player, stalk an idle one,
	-- hop back out of an incoming swing, bait a swing). Each one overrides movement while it runs.
	do
		local mv = X.mv
		local hop = X.hop
		if mv.name and now > mv.untilT then mv.name = nil end
		if not mv.name and not hop.active and not dodging and not punishing and not retreating and not leap then
			local function start(name, dur, cool)
				if now < (mv.ready[name] or 0) then return end
				mv.name, mv.untilT, mv.jumped, mv.lunged = name, now + dur, false, false
				mv.ready[name] = now + cool
				dlog("move: " .. name)
			end
			local fleeing = tVel:Dot(fwd) < -3
			if not inCombat and tool and fleeing and d > 5.5 and d < 10 and math.random() < 0.5 * (sm.lunge or 1) then
				start("Lunge", 0.8, 3)
			elseif not inCombat and profile.idle > 0.5 and d > 6 and d < 16 and math.random() < 0.2 * (sm.stalk or 1) then
				start("Stalk", 2.5, 4)
			elseif inCombat and targetSwinging() and d > 2 and d < CONFIG.AttackRange + 1.5 and not dodging
				and math.random() < CONFIG.DodgeChance * 0.65 then
				start("Backhop", 0.45, 1.5)
			elseif inCombat and not dodging and d > 2 and d < 3.5 and tVel:Dot(fwd) > 4 and math.random() < 0.25 then
				-- they're charging into us from close range: hop back out before they can swing
				start("Backhop", 0.45, 1.1)
			elseif inCombat and not targetSwinging() and not dodging and d > 3 and d < CONFIG.AttackRange + 1
				and math.random() < 0.12 * (sm.juke or 1) then
				-- sudden direction change: a quick sidestep the opposite way to whatever we were doing
				start("Juke", 0.3, 0.9)
				X.mv.jukeSign = -strafeSign
			elseif inCombat and mode == "Circling" and d > 3 and d < 5 and math.random() < 0.08 then
				start("Bait", 0.35, 2.5)
			end
		end
		if mv.name then
			local name = mv.name
			faceTarget = true
			if name == "Lunge" then
				moveDir = fwd
				if d <= 5.5 and not mv.lunged and tool then
					mv.lunged = true
					X.lunge(tool)
				end
				mode = "Lunging"
			elseif name == "Stalk" then
				moveDir = fwd * 0.5
				if d <= 6 then mv.untilT = now end -- close enough: stop stalking
				mode = "Stalking"
			elseif name == "Backhop" then
				moveDir = -fwd
				if not mv.jumped then
					wantJump, mv.jumped = true, true
				end
				mode = "Backhopping"
			elseif name == "Bait" then
				moveDir = Vector3.zero
				mode = "Baiting"
			elseif name == "Juke" then
				moveDir = right * (mv.jukeSign or 1) + fwd * 0.2
				mode = "Juking"
			end
		end
	end

	-- HOP-IN MOVE: from mid range, jump at them and strike on the way down (overrides movement while it runs)
	do
		local hop = X.hop
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		if not hop.active then
			local hopChance = CONFIG.Tryhard and 0.25 or 0.12
			if inCombat and not dodging and not punishing and grounded and mode == "Circling"
				and d > 4.5 and d < 7.5 and now >= hop.readyAt and math.random() < hopChance and hasSafeGround(pred) then
				hop.active, hop.untilT, hop.jumped, hop.jumpAt = true, now + 1.2, false, 0
				hop.readyAt = now + 3.5
				dlog("hop: jumping in")
			end
		end
		if hop.active then
			if not hop.jumped and d <= 5.5 then
				wantJump, hop.jumped, hop.jumpAt = true, true, now
			end
			moveDir = unitOr(flat(pred - pos), fwd)
			faceTarget = true
			mode = "Hopping"
			local landed = hop.jumped and grounded and now - hop.jumpAt > 0.15
			if now > hop.untilT or d < 2.2 or landed then
				hop.active = false
				if d < CONFIG.AttackRange + 1 then
					mode, modeUntil, swings = "Committing", now + 1.0, 0 -- follow the hop with a strike
				end
			end
		end
	end

	-- attack
	if tool and tHum then
		-- latency: what we see is old and our swing lands late, so judge the hit at where they'll be (about one round trip on)
		local delta = (tPos + flat(tVel) * math.min(lag * 2, 1.2)) - pos
		local fd = flat(delta).Magnitude
		local ang = math.deg(math.acos(math.clamp(flat(hrp.CFrame.LookVector).Unit:Dot(unitOr(flat(delta), fwd)), -1, 1)))
		local tAir = tHum.FloorMaterial == Enum.Material.Air
		local jumper = profile.jumpRate > 0.35
		-- learned: bunny-hoppers only get hit on the low part of their arc
		local maxDy = (jumper and tAir) and 2.5 or 4.5
		-- reach stretches while they close on us: our swing lands about one round trip late, so they'll be a little nearer by then
		local closeNow = -flat(tVel):Dot(unitOr(flat(delta), fwd))
		local pingReach = closeNow > 0 and math.min(closeNow * lag, 1.5) or 0
		local canHit = fd <= X.reach(profile) + pingReach and math.abs(delta.Y) <= maxDy and (ang <= CONFIG.AttackAngle or fd <= CONFIG.AttackRange - 0.6) and clearShot(pos, tPos)
		-- learned: they hop to dodge, so don't swing at them while they're up in the air - hit them on the landing
		if profile.ourSwings >= 3 and profile.dodgeHop > 0.5 and tAir and delta.Y > 1.5 then canHit = false end
		-- once a swing is lined up, don't lose it the instant they step a little out of range/angle
		-- latency-aware: if they're closing fast and will be in reach by the time our swing lands, start it now
		local closing = -flat(tVel):Dot(unitOr(flat(delta), fwd))
		local soon = closing > 2 and ang <= CONFIG.AttackAngle + 20 and math.abs(delta.Y) <= maxDy
			and fd - closing * (ownPing + 0.1) <= X.reach(profile)
		local almost = attackArmedAt ~= nil and fd <= CONFIG.AttackRange + 1
			and math.abs(delta.Y) <= maxDy + 1 and ang <= CONFIG.AttackAngle + 20
		-- copying: they just swung and whiffed or landed; we answer immediately while they recover
		if PL.mirror and canHit and now - PL.theirSwingAt < 0.5 and not attackArmedAt then attackArmedAt = now end
		if (canHit or almost or soon) and not dodging then
			if not attackArmedAt then
				local reactScale = (profile.ourSwings >= 3 and profile.dodgesOurs < 0.3) and 0.5 or 1 -- they never dodge: don't hesitate
				if CONFIG.Tryhard then reactScale *= CONFIG.TryhardReactionScale end
				attackArmedAt = now + ((punishing or (CONFIG.Gank and G.on and facingUs < 0.3) or (jumper and not tAir)) and 0 or rand(CONFIG.ReactionMin, CONFIG.ReactionMax) * reactScale)
			end
			if now >= attackArmedAt and now >= nextAttackAt and (canHit or soon) and not feintOn then -- the grace zone only keeps the timer alive; we swing in reach, or just before it
				X.swing(tool)
				X.wiggleStart, X.wiggleUntil = now, now + 0.4 -- sway side to side for the swing, so a small aim error still connects
				if CONFIG.HitAndRun and not feintOn then X.hitRunUntil = now + CONFIG.HitAndRunTime end
				X.stats.swings += 1
				X.touchAssist(tool, tChar)
				if CONFIG.ComboLunge or (CONFIG.LungeBeyond and fd > CONFIG.LungeBeyond) then task.delay(0.15, function() if tool.Parent == character then X.lunge(tool) end end) end
				nextAttackAt = now + CONFIG.AttackCooldown + math.random() * 0.12
				swings += 1
				fight.ourSwingAt = now
				X.immune.swings += 1
				if not fight.ourFirstSwingAt then fight.ourFirstSwingAt = now end
				if fight.engagedAt and not fight.decided then -- we swung first this fight
					fight.decided = true
					profile.engagements += 1
					profile.firstStrike = ema(profile.firstStrike, 0, 0.3)
				end
				watchEnd, watchRight, watchHealth, watchDist = now + 0.45, right, tHum.Health, fd
				X.wTactic, X.wFd = punishing and "Punish" or mode, fd -- which tactic this swing came from
				watchLat0, watchAir0 = tVel:Dot(right), tAir
			end
		else
			attackArmedAt = nil
		end
	end

	-- anti-stuck (judged by the edge-safe direction, so standing at a ledge isn't "stuck")
	local safeNow = safeDir(moveDir, true)
	if now >= nextStuckCheck then
		nextStuckCheck = now + 0.6
		local holding = mode == "Lurking" or ((mode == "Committing" or mode == "Backstab" or mode == "Flanking") and d < CONFIG.AttackRange * 1.1)
		if safeNow.Magnitude > 0.3 and not holding and (pos - lastStuckPos).Magnitude < 0.8
			and humanoid.FloorMaterial ~= Enum.Material.Air then
			stuckStrikes += 1
			if stuckStrikes >= 2 then
				stuckStrikes = 0
				if not X.narrowAt(hrp.Position, safeNow) then tryJump(now, safeNow) end -- on a narrow floor a hop drops us off: re-route
				local hadRoute = wps ~= nil -- the route we were following (checked before it's thrown away)
				wps, lastPath = nil, 0
				if hadRoute or mode == "Chasing" then
					-- while pathfinding: just re-path + hop. The random 90-degree side-step made the bot twist around in place
					dlog("stuck: re-pathing")
				else
					sideStepUntil, sideStepSign = now + 0.5, freeSide(moveDir)
					dlog("stuck: side-step " .. (sideStepSign > 0 and "right" or "left"))
					X.stats.stuck += 1
				end
			end
		else
			stuckStrikes = 0
		end
		lastStuckPos = pos
	end
	if now < sideStepUntil and moveDir.Magnitude > 0.01 then
		moveDir = rotY(moveDir, math.rad(90) * sideStepSign)
	end

	-- MOVES (only when not dodging, leaping or feinting)
	if not dodging and not leap and not feintOn then
		if CONFIG.HitAndRun and X.hitRunUntil and now < X.hitRunUntil and d < CONFIG.AttackRange + 2.5 then
			moveDir = -fwd * 0.9 -- poke and step out: their swing finds air
		elseif CONFIG.GuardHold and mode == "Circling" and d > 3.5 and d < 6.5
			and -flat(tVel):Dot(fwd) > 2.5 and facingUs > 0.3 then
			moveDir = Vector3.zero -- they're rushing in and facing us: stand still, our swing is ready when they arrive
		end
	end

	-- apply (steering is eased so it doesn't twitch; dodges and leaps stay instant)
	if moveDir.Magnitude < 0.01 or dodging or leap then
		smoothDir = moveDir
	else
		if mode == "Chasing" then
			smoothDir = steerToward(smoothDir, moveDir, math.rad(CONFIG.ChaseTurnRate) * dt)
		else
			smoothDir = smoothDir:Lerp(moveDir, math.clamp(dt * 10, 0, 1))
		end
		moveDir = smoothDir
	end
	local wiggling = now < (X.wiggleUntil or 0) and not dodging and not leap and not feintOn
	local preSafe = moveDir
	moveDir = safeDir(moveDir)
	local altered = preSafe.Magnitude > 0.05 and (moveDir.Magnitude < 0.05 or angleBetween(preSafe, moveDir) > 20)
	local cause = dodging and "dodge" or (now < sideStepUntil and "stuck side-step")
		or (altered and "ledge/fake-floor avoidance") or (mode == "Chasing" and (directOK and "straight chase" or "path following")) or tostring(mode)
	-- swing wiggle: while a swing is out, step side to side and a little forward (so a small aim error still connects).
	-- Applied after the edge check; if a ledge blocks it, the bot says so in the Debug log instead of silently not moving.
	if wiggling then
		local sgn = (math.floor((now - (X.wiggleStart or now)) / 0.15) % 2 == 0) and 1 or -1
		local w = safeDir(right * sgn * 0.9 + fwd * 0.35)
		if w.Magnitude > 0.2 then
			moveDir = w
			X.stats.wiggles += 1
		elseif now - (X.wiggleBlockedLog or 0) > 1.5 then
			X.wiggleBlockedLog = now
			dlog("wiggle blocked by an edge")
		end
	end
	trackTwitch(now, moveDir, cause)
	if not leap and moveDir.Magnitude > 0.2 and obstacleAhead(moveDir) then wantJump = true end

	if faceTarget then
		if d <= CONFIG.FaceRange then facing = true
		elseif d > CONFIG.FaceRange + 4 then facing = false end
	else
		facing = false
	end

	if facing then
		humanoid.AutoRotate = false
		-- don't whip around while hopping over the target: hold our heading until we've landed behind them
		local passing = (mode == "Flanking" and humanoid.FloorMaterial == Enum.Material.Air)
		if not passing then turnToward(tPos, dt) end
	else
		humanoid.AutoRotate = true
	end

	trackSpin(now)
	humanoid:Move(moveDir, false)
	if wantJump then tryJump(now, moveDir) end

	step_dodging = dodging
end

----------------------------------------------------------------------
-- WIRING
----------------------------------------------------------------------
-- ===== swings =====
-- (the old mouse1click fallback was removed: it crashed the game)

-- Lunge (the quick second click)
function X.lunge(tool)
	tool:Activate()
end

function X.swing(tool)
	tool:Activate()
	X.stats.activates += 1
end

X.lastAssist, X.assisting, X.assistErrors = 0, false, 0
function X.touchAssist(tool, tChar)
	if not (CONFIG.TouchAssist and firetouchinterest and tool and tChar) then return end
	if X.assisting then return end -- one assist at a time: never stack touches
	if math.random() > CONFIG.TouchAssistChance then return end
	if time() - X.lastAssist < CONFIG.TouchAssistCooldown then return end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end

	-- lock + cooldown start NOW (before the delay), and everything the delayed part needs is captured here,
	-- so a target change / respawn mid-delay can't make it touch the wrong thing
	X.assisting, X.lastAssist = true, time()
	local myHrp, theirHrp, theirHum = hrp, tHrp, tHum

	task.delay(rand(CONFIG.TouchAssistDelay[1], CONFIG.TouchAssistDelay[2]), function()
		local ok = pcall(function()
			-- only if the swing still plausibly connects: sword still held, target alive, still in reach
			if tool.Parent ~= character or not (tChar.Parent and theirHum and theirHum.Health > 0 and theirHrp and theirHrp.Parent and myHrp and myHrp.Parent) then
				X.stats.assistSkips += 1 X.assisting = false return
			end
			if flat(theirHrp.Position - myHrp.Position).Magnitude > CONFIG.AttackRange + 0.5 then
				X.stats.assistSkips += 1 X.assisting = false return
			end
			if not handle:IsDescendantOf(Workspace) then X.stats.assistSkips += 1 X.assisting = false return end
			-- touch the body part closest to the blade, like a real hit would, not always the root part
			local part, best = nil, math.huge
			for _, p in ipairs(tChar:GetChildren()) do
				if p:IsA("BasePart") and p.CanTouch then
					local pd = (p.Position - handle.Position).Magnitude
					if pd < best then part, best = p, pd end
				end
			end
			if not part or best > CONFIG.AttackRange + 1 then X.stats.assistSkips += 1 X.assisting = false return end

			X.stats.assists += 1
			firetouchinterest(handle, part, 0)
			-- the matching "touch ended" ALWAYS runs, even if something changed meanwhile, so no touch is left open
			task.delay(rand(0.04, 0.09), function()
				pcall(firetouchinterest, handle, part, 1)
				X.assisting = false
			end)
		end)
		if not ok then
			X.assisting = false
			X.assistErrors += 1
			dlog("touch assist error (" .. X.assistErrors .. "/3)")
			if X.assistErrors >= 3 then
				CONFIG.TouchAssist = false
				dlog("touch assist disabled after repeated errors")
			end
		end
	end)
end

-- Debug log also feeds a plain-text buffer (for setclipboard) and the optional external console
do
	local baseLog = dlog
	X.logBase = baseLog -- the list-only logger (resume uses it so the clipboard buffer doesn't get each line twice)
	dlog = function(msg)
		table.insert(X.logBuf, string.format("[%.1f] %s", time(), msg))
		while #X.logBuf > CONFIG.DebugMaxLines do table.remove(X.logBuf, 1) end
		if CONFIG.ExecConsole and rconsoleprint then rconsoleprint("[SwordBot] " .. msg .. "\n") end
		X.uiCall(baseLog, msg)
	end
end
dlog("executor: " .. tostring(identifyexecutor and identifyexecutor() or "unknown")
	.. " | files=" .. tostring(X.hasFiles) .. " | drawing=" .. tostring(Drawing ~= nil) .. " | gethui=" .. tostring(gethui ~= nil))

X.log = dlog
local uiTimer = 0
X.saveTimer = 0
table.insert(X.conns, RunService.Heartbeat:Connect(function(dt)
	if dt > 0 then
		local f = 1 / dt
		X.fps = X.fps + (f - X.fps) * 0.1
		if f < X.fpsWinMin then X.fpsWinMin = f end
		X.fpsWinT += dt
		if X.fpsWinT >= 5 then X.fpsLow, X.fpsWinMin, X.fpsWinT = X.fpsWinMin, 1e9, 0 end
	end
	if enabled then
		X.sess.up += dt
		if inCombat then
			X.sess.combat += dt
			X.stats.combatTime += dt
			X.stats.distSum += dist
			X.stats.combatFrames += 1
		end
	end
	local okStep, errStep = pcall(step, dt)
	if okStep and time() - (X.stepErrAt or 0) > 5 then X.stepErr = nil end
	if not okStep then
		X.stepErr = tostring(errStep)
		X.stepErrAt = time()
		if not X.stepErrLogged then
			X.stepErrLogged = true
			dlog("frame error: " .. X.stepErr)
		end
	end
	X.uiCall(trackMode)
	X.uiCall(X.chat.tick, time())
	X.overlay(enabled, target, tHrp, mode, dist)
	X.saveTimer += dt
	if X.saveTimer >= CONFIG.AutosaveEvery then
		X.saveTimer = 0
		X.saveProfiles()
		X.games.save()
	end
	uiTimer += dt
	if uiTimer >= 0.1 then
		uiTimer = 0
		X.uiCall(updateUI, step_dodging)
	end
end))

switch.MouseButton1Click:Connect(function() setEnabled(not enabled) end)

-- copies the whole Debug log (used by both the Copy button and its keybind)
function X.copyLog()
	if not setclipboard then
		dlog("copy log: setclipboard isn't available in this executor")
		return false
	end
	setclipboard(table.concat(X.logBuf, "\n"))
	dlog("log copied to clipboard (" .. #X.logBuf .. " lines)")
	return true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CONFIG.Keybind then setEnabled(not enabled) end
	if CONFIG.CopyLogKey and input.KeyCode == CONFIG.CopyLogKey then X.copyLog() end
end)

table.insert(X.conns, player.CharacterAdded:Connect(bindCharacter))
if player.Character then task.spawn(bindCharacter, player.Character) end

task.defer(function()
	local base = card.Position
	card.Position = UDim2.new(base.X.Scale, base.X.Offset - 300, base.Y.Scale, base.Y.Offset)
	X.ui.tween(card, 0.65, { Position = base }, Enum.EasingStyle.Back)
	mainPage.GroupTransparency = 1
	X.ui.tween(mainPage, 0.5, { GroupTransparency = 0 }, nil, nil, 0.15)
	local n = 0
	for _, c in ipairs(mainPage:GetChildren()) do
		if c:IsA("GuiObject") then
			n += 1
			local p = c.Position
			c.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + 10)
			X.ui.tween(c, 0.45, { Position = p }, Enum.EasingStyle.Quint, nil, 0.05 + n * 0.025)
		end
	end
	X.uiCall(paintSwitch)
	X.uiCall(updateUI, false)
	if CONFIG.StartEnabled then setEnabled(true) end
end)

-- re-run cleanup + remote control (getgenv().SwordBot:Toggle(), :SetEnabled(true), .Config.AttackRange = 5 ...)
function X.cleanup()
	for _, c in ipairs(X.conns) do pcall(function() c:Disconnect() end) end
	X.conns = {}
	pcall(function() setEnabled(false) end)
	pcall(function() X.games.save() end)
	X.removeOverlay()
	pcall(function() gui:Destroy() end)
end

if X.genv then
	X.genv.SwordBot_Cleanup = X.cleanup
	X.genv.SwordBot = {
		Config = CONFIG,
		Toggle = function() setEnabled(not enabled) end,
		SetEnabled = function(_, v) setEnabled(v and true or false) end,
		IsEnabled = function() return enabled end,
		SaveProfiles = X.saveProfiles,
		SetScale = function(_, v) -- shrink / grow the whole card live
			v = math.clamp(tonumber(v) or 1, 0.4, 1.5)
			CONFIG.UIScale = v
			X.ui.tween(X.ui.scale, 0.25, { Scale = v }, Enum.EasingStyle.Quint)
		end,
		Destroy = X.cleanup,
	}
end
