-- Сервер: будує карту, рахує гроші, вибухи, продаж, покупки, збереження.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Landmarks = require(script:WaitForChild("Landmarks"))

local B = Config.BLOCK
local SIZE = Config.ZONE_SIZE
local ROAD = Config.ROAD_HALF
local COLUMNS = math.ceil(#Config.Zones / 2)
local END_X = COLUMNS * SIZE -- кінець дороги
local SPAWN_X = -40 -- центр зони спавну
local MAX_FLYING = 60 -- скільки уламків максимум літає від одного вибуху (для швидкодії)

---------------------------------------------------------------- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function newRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local ReadyRemote = newRemote("Ready") -- клієнт -> сервер: "я завантажився"
local ThrowRemote = newRemote("Throw") -- клієнт -> сервер: кинути в точку
local BuyRemote = newRemote("Buy") -- клієнт -> сервер: купити / вибрати / ребьорт
local StateRemote = newRemote("State") -- сервер -> клієнт: дані гравця
local NotifyRemote = newRemote("Notify") -- сервер -> клієнт: повідомлення
local BoomRemote = newRemote("Boom") -- сервер -> всі: вибух (для тряски камери)
local EarnedRemote = newRemote("Earned") -- сервер -> клієнт: "+$" у точці вибуху

---------------------------------------------------------------- Освітлення: яскравий "іграшковий" світ
Lighting.ClockTime = 14
Lighting.Brightness = 3
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
Lighting.GlobalShadows = true
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Threshold = 1.5
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.2
cc.Contrast = 0.05
cc.Parent = Lighting

---------------------------------------------------------------- Map helpers
local old = workspace:FindFirstChild("Baseplate")
if old then
	old:Destroy()
end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local gates = Instance.new("Folder")
gates.Name = "Gates"
gates.Parent = map

local blocks = Instance.new("Folder")
blocks.Name = "Blocks"
blocks.Parent = workspace

-- лего-вигляд: пластик + пухирці зверху
local function lego(p: BasePart)
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
end

local function box(size: Vector3, pos: Vector3, color: Color3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	lego(p)
	p.Parent = parent or map
	return p
end

local function sign(parent: BasePart, text: string, color: Color3, offset: Vector3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	gui.Parent = parent
	return gui
end

---------------------------------------------------------------- Blocks & buildings
-- Кожна будівля має id; рахуємо, скільки блоків лишилось, щоб дати бонус за повне руйнування.
local buildingLeft: { [number]: number } = {}
local buildingValue: { [number]: number } = {}
local nextBuilding = 0

local function spawnBlock(zone: number, cf: CFrame, color: Color3, building: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.one * B
	p.CFrame = cf
	-- легкий розкид відтінку, щоб було видно окремі цеглинки
	p.Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.08)
	lego(p)
	p:SetAttribute("Zone", zone)
	p:SetAttribute("HP", Config.Zones[zone].hp)
	p:SetAttribute("BaseColor", color)
	p:SetAttribute("Building", building)
	p.Parent = blocks
	buildingLeft[building] = (buildingLeft[building] or 0) + 1
end

local function spawnBarrel(zone: number, cf: CFrame)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.Size = Vector3.new(4, 3, 3)
	p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2) -- циліндр стоїть вертикально
	p.Color = Color3.fromRGB(220, 30, 30)
	lego(p)
	p:SetAttribute("Zone", zone)
	p:SetAttribute("HP", Config.Zones[zone].hp)
	p:SetAttribute("Barrel", true)
	p.Parent = blocks
	local label = sign(p, "TNT", Color3.fromRGB(255, 230, 0), Vector3.new(0, 3, 0))
	label.Size = UDim2.fromOffset(80, 30)
	label.MaxDistance = 60
end

-- уламок відлітає і зникає, потім блок відбудовується
local function breakBlock(p: BasePart, fly: boolean)
	local zone = p:GetAttribute("Zone")
	local cf = p.CFrame
	local isBarrel = p:GetAttribute("Barrel")
	local color = p:GetAttribute("BaseColor")
	local building = p:GetAttribute("Building")

	if fly then
		p.Parent = workspace
		p.CanQuery = false
		p.Anchored = false
		p.AssemblyLinearVelocity = Vector3.new(math.random(-40, 40), math.random(40, 80), math.random(-40, 40))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		Debris:AddItem(p, 3)
	else
		p:Destroy()
	end

	if isBarrel then
		task.delay(Config.RESPAWN, spawnBarrel, zone, cf * CFrame.Angles(0, 0, -math.pi / 2))
	else
		buildingLeft[building] -= 1
		task.delay(Config.RESPAWN, spawnBlock, zone, cf, color, building)
	end
	return building
end

-- будинок: стіни по периметру з вікнами і дверима + повний дах
local function buildHouse(zone: number, center: Vector3, w: number, h: number, frontSide: number)
	local z = Config.Zones[zone]
	nextBuilding += 1
	local id = nextBuilding
	local count = 0
	for y = 0, h - 1 do
		for ix = 0, w - 1 do
			for iz = 0, w - 1 do
				local edge = ix == 0 or iz == 0 or ix == w - 1 or iz == w - 1
				local isRoof = y == h - 1
				local middle = (ix == 1 or ix == 2) and (iz == 0 or iz == w - 1) or (iz == 1 or iz == 2) and (ix == 0 or ix == w - 1)
				local front = if frontSide > 0 then iz == w - 1 else iz == 0
				local isDoor = y == 0 and front and (ix == 1 or ix == 2)
				if (edge or isRoof) and not isDoor then
					local pos = center + Vector3.new((ix - (w - 1) / 2) * B, B / 2 + y * B, (iz - (w - 1) / 2) * B)
					local color = z.wall
					if isRoof then
						color = z.roof
					elseif middle and y > 0 and y % 2 == 1 then
						color = Config.WINDOW
					end
					spawnBlock(zone, CFrame.new(pos), color, id)
					count += 1
				end
			end
		end
	end
	buildingValue[id] = math.floor(count * z.value * Config.BUILDING_BONUS)
end

-- паркан квадратом навколо будинків, з проходом спереду
local function buildFence(zone: number, center: Vector3, half: number, side: number)
	local color = Config.Zones[zone].fence
	nextBuilding += 1
	local id = nextBuilding
	local count = 0
	local function add(pos: Vector3)
		spawnBlock(zone, CFrame.new(center + pos), color, id)
		count += 1
	end
	local n = math.floor(half * 2 / B)
	for i = 0, n do
		local t = -half + i * B
		local frontZ = -side * half -- сторона, що дивиться на дорогу
		if math.abs(t) > 5 then
			add(Vector3.new(t, B / 2, frontZ))
		end
		add(Vector3.new(t, B / 2, -frontZ))
		if i > 0 and i < n then
			add(Vector3.new(-half, B / 2, t))
			add(Vector3.new(half, B / 2, t))
		end
	end
	buildingValue[id] = math.floor(count * Config.Zones[zone].value * Config.BUILDING_BONUS)
end

-- особлива будівля локації (див. Landmarks.luau)
local function buildLandmark(zone: number, center: Vector3): boolean
	local recipe = Landmarks[zone]
	if not recipe then
		return false
	end
	nextBuilding += 1
	local id = nextBuilding
	-- спершу збираємо всі клітинки (пізніший колір перекриває попередній), потім ставимо блоки
	local cells: { [string]: { pos: Vector3, color: Color3 } } = {}
	recipe(function(x: number, y: number, z: number, color: Color3)
		cells[x .. "," .. y .. "," .. z] = { pos = center + Vector3.new(x * B, B / 2 + y * B, z * B), color = color }
	end, Config.Zones[zone])
	local count = 0
	for _, c in cells do
		spawnBlock(zone, CFrame.new(c.pos), c.color, id)
		count += 1
	end
	-- особлива будівля дає подвійний бонус
	buildingValue[id] = math.floor(count * Config.Zones[zone].value * Config.BUILDING_BONUS * 2)
	return true
end

---------------------------------------------------------------- Build map
local GRASS = Color3.fromRGB(75, 151, 75)
local WALL = Color3.fromRGB(40, 40, 45)
local totalDepth = (ROAD + SIZE) * 2

-- земля, дорога, смуги швидкості
box(Vector3.new(END_X + 80, 2, totalDepth), Vector3.new((END_X - 80) / 2, -1, 0), GRASS)
box(Vector3.new(END_X, 0.2, ROAD * 2), Vector3.new(END_X / 2, 0.1, 0), Color3.fromRGB(60, 60, 65))
for x = 6, END_X - 4, 12 do
	local stripe = box(Vector3.new(3, 0.25, ROAD * 2 - 6), Vector3.new(x, 0.15, 0), Color3.fromRGB(30, 180, 255))
	stripe.Material = Enum.Material.Neon
end

-- межі карти
local function wall(size: Vector3, pos: Vector3)
	local w = box(size, pos, WALL)
	w.Material = Enum.Material.SmoothPlastic
	w.Transparency = 0.7
	w.CanQuery = false -- кліки проходять крізь стіни
end
wall(Vector3.new(2, 30, totalDepth), Vector3.new(-80, 15, 0))
wall(Vector3.new(2, 30, totalDepth), Vector3.new(END_X, 15, 0))
wall(Vector3.new(80, 30, 2), Vector3.new(-40, 15, totalDepth / 2))
wall(Vector3.new(80, 30, 2), Vector3.new(-40, 15, -totalDepth / 2))

-- спавн, крамниця, продаж
local spawnPoint = Instance.new("SpawnLocation")
spawnPoint.Anchored = true
spawnPoint.Size = Vector3.new(10, 1, 10)
-- дивимось праворуч, на першу локацію
spawnPoint.CFrame = CFrame.lookAt(Vector3.new(SPAWN_X - 15, 0.5, 0), Vector3.new(SPAWN_X + 100, 0.5, 0))
spawnPoint.Neutral = true
spawnPoint.Duration = 0
lego(spawnPoint)
spawnPoint.Parent = map

local shopPad = box(Vector3.new(14, 1, 14), Vector3.new(SPAWN_X, 0.5, -22), Color3.fromRGB(255, 138, 60))
shopPad.Name = "Shop"
sign(shopPad, "SHOP", Color3.fromRGB(255, 180, 90), Vector3.new(0, 6, 0))
local shopPrompt = Instance.new("ProximityPrompt")
shopPrompt.Name = "ShopPrompt"
shopPrompt.ActionText = "Open shop"
shopPrompt.ObjectText = "Bags, Weapons, Rebirth"
shopPrompt.HoldDuration = 0
shopPrompt.MaxActivationDistance = 14
shopPrompt.RequiresLineOfSight = false
shopPrompt.Parent = shopPad

local sellPad = box(Vector3.new(14, 1, 14), Vector3.new(SPAWN_X, 0.5, 22), Color3.fromRGB(60, 255, 110))
sellPad.Material = Enum.Material.Neon
sellPad.Name = "Sell"
sign(sellPad, "SELL", Color3.fromRGB(120, 255, 150), Vector3.new(0, 6, 0))

-- локації
for i, zone in Config.Zones do
	local col = math.floor((i - 1) / 2)
	local side = if i % 2 == 1 then 1 else -1 -- 1 = над дорогою, -1 = під
	local cx = col * SIZE + SIZE / 2
	local cz = side * (ROAD + SIZE / 2)
	local center = Vector3.new(cx, 0.4, cz)

	box(Vector3.new(SIZE, 0.4, SIZE), Vector3.new(cx, 0.2, cz), zone.floor)
	-- бокові та задня стіни
	wall(Vector3.new(1, 30, SIZE), Vector3.new(col * SIZE, 15, cz))
	wall(Vector3.new(1, 30, SIZE), Vector3.new((col + 1) * SIZE, 15, cz))
	wall(Vector3.new(SIZE, 30, 1), Vector3.new(cx, 15, side * (ROAD + SIZE)))

	-- будівлі 2x2 (двері дивляться на дорогу); ліва ближня до дороги = особлива будівля
	local landmarkSlot = Vector3.new(-12, 0, -12 * side)
	for _, off in { Vector3.new(-12, 0, -12), Vector3.new(12, 0, -12), Vector3.new(-12, 0, 12), Vector3.new(12, 0, 12) } do
		if not (off == landmarkSlot and buildLandmark(i, center + off)) then
			buildHouse(i, center + off, 4, zone.height, -side)
		end
	end
	buildFence(i, center, 24, side)
	for _, x in { -12, 0, 12 } do
		spawnBarrel(i, CFrame.new(center + Vector3.new(x, 2, 0)))
	end

	-- вхідна стіна (гейт)
	local gate = box(Vector3.new(SIZE, 30, 1), Vector3.new(cx, 15, side * ROAD), Color3.fromRGB(220, 40, 40), gates)
	gate.Material = Enum.Material.ForceField
	gate.Name = "Gate" .. i
	gate.CanQuery = false
	local title = i .. ". " .. zone.name
	if zone.price > 0 then
		sign(gate, title .. "\n$" .. zone.price, Color3.new(1, 1, 1), Vector3.new(0, -8, 0))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Unlock $" .. zone.price
		prompt.ObjectText = title
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = gate
	else
		sign(gate, title, Color3.new(1, 1, 1), Vector3.new(0, -8, 0))
		gate.CanCollide = false
		gate.Transparency = 1
	end
end

---------------------------------------------------------------- Player data
type Quest = { kind: string, goal: number, progress: number, reward: number }
type Data = {
	money: number,
	bag: number,
	bagLevel: number,
	weapon: number,
	weapons: { boolean },
	zones: { boolean },
	rebirths: number,
	destroyed: number,
	quests: { Quest },
	lastDay: number,
	streak: number,
	receipts: { string },
	-- ці поля не зберігаються, рахуються заново при кожному вході:
	autoSell: boolean,
	x2: boolean,
	friends: number,
	mult: number,
	nextGift: number,
}

local data: { [Player]: Data } = {}
local canSave: { [Player]: boolean } = {}
local lastThrow: { [Player]: number } = {}
local joinedAt: { [Player]: number } = {}
local giftsTaken: { [Player]: number } = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("DestroyIt_v1")
end)

local function notify(plr: Player, text: string)
	NotifyRemote:FireClient(plr, text)
end

local function highestZone(d: Data): number
	local h = 1
	for i, open in d.zones do
		if open then
			h = i
		end
	end
	return h
end

local function totalMultiplier(d: Data): number
	local friends = 1 + Config.FRIEND_BONUS * math.min(d.friends, Config.FRIEND_MAX)
	return Config.multiplier(d.rebirths) * (if d.x2 then 2 else 1) * friends
end

---------------------------------------------------------------- Квести
local function questTemplate(kind: string)
	for _, q in Config.QUESTS do
		if q.kind == kind then
			return q
		end
	end
	return nil
end

-- новий квест того типу, якого зараз немає серед активних
local function newQuest(d: Data): Quest
	local active = {}
	for _, q in d.quests do
		active[q.kind] = true
	end
	local options = {}
	for _, q in Config.QUESTS do
		if not active[q.kind] then
			table.insert(options, q)
		end
	end
	if #options == 0 then
		options = Config.QUESTS
	end
	local q = options[math.random(#options)]
	local base = Config.rewardBase(highestZone(d))
	local goal = if q.kind == "sell" then q.goal * base else q.goal
	return { kind = q.kind, goal = goal, progress = 0, reward = q.reward * base }
end

local function fillQuests(d: Data)
	while #d.quests < 3 do
		table.insert(d.quests, newQuest(d))
	end
end

---------------------------------------------------------------- Створення / завантаження / збереження
local function freshData(): Data
	local weapons, zones = {}, {}
	for i in Config.Weapons do
		weapons[i] = i == 1
	end
	for i in Config.Zones do
		zones[i] = i == 1
	end
	local d: Data = {
		money = 0,
		bag = 0,
		bagLevel = 1,
		weapon = 1,
		weapons = weapons,
		zones = zones,
		rebirths = 0,
		destroyed = 0,
		quests = {},
		lastDay = 0,
		streak = 0,
		receipts = {},
		autoSell = false,
		x2 = false,
		friends = 0,
		mult = 1,
		nextGift = -1,
	}
	fillQuests(d)
	return d
end

-- акуратно переносимо збережене в нову структуру (якщо змінився Config, нічого не зламається)
local function fromSaved(saved: any): Data
	local d = freshData()
	if type(saved) ~= "table" then
		return d
	end
	local function num(v: any, default: number): number
		return if type(v) == "number" and v == v and math.abs(v) ~= math.huge then v else default
	end
	d.money = math.max(0, num(saved.money, 0))
	d.bag = math.max(0, num(saved.bag, 0))
	d.bagLevel = math.clamp(math.floor(num(saved.bagLevel, 1)), 1, #Config.Bags)
	d.rebirths = math.max(0, math.floor(num(saved.rebirths, 0)))
	d.destroyed = math.max(0, math.floor(num(saved.destroyed, 0)))
	d.lastDay = math.floor(num(saved.lastDay, 0))
	d.streak = math.clamp(math.floor(num(saved.streak, 0)), 0, Config.DAILY_MAX_STREAK)
	if type(saved.weapons) == "table" then
		for i in Config.Weapons do
			d.weapons[i] = i == 1 or saved.weapons[i] == true
		end
	end
	if type(saved.zones) == "table" then
		for i in Config.Zones do
			d.zones[i] = i == 1 or saved.zones[i] == true
		end
	end
	local w = math.floor(num(saved.weapon, 1))
	d.weapon = if d.weapons[w] then w else 1
	if type(saved.receipts) == "table" then
		for _, r in saved.receipts do
			if type(r) == "string" then
				table.insert(d.receipts, r)
			end
		end
	end
	if type(saved.quests) == "table" then
		d.quests = {}
		for _, q in saved.quests do
			if type(q) == "table" and type(q.kind) == "string" and questTemplate(q.kind) and #d.quests < 3 then
				local goal = num(q.goal, 0)
				if goal > 0 then
					table.insert(d.quests, {
						kind = q.kind,
						goal = goal,
						progress = math.clamp(num(q.progress, 0), 0, goal),
						reward = math.max(0, num(q.reward, 0)),
					})
				end
			end
		end
		fillQuests(d)
	end
	return d
end

-- повертає true, якщо вдалося зберегти
local function save(plr: Player): boolean
	local d = data[plr]
	if not store or not d or not canSave[plr] then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync("p_" .. plr.UserId, d)
		end)
		if ok then
			return true
		end
		warn("Save failed for", plr.Name, err)
		task.wait(attempt)
	end
	return false
end

local function setStat(plr: Player, name: string, value: number)
	local stats = plr:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	if v then
		(v :: IntValue).Value = value
	end
end

local function giftSecondsLeft(plr: Player): number
	local gift = Config.GIFTS[(giftsTaken[plr] or 0) + 1]
	if not gift or not joinedAt[plr] then
		return -1 -- усі подарунки цієї сесії вже отримано
	end
	return math.max(0, gift.minutes * 60 - (os.clock() - joinedAt[plr]))
end

local function sendState(plr: Player)
	local d = data[plr]
	if not d then
		return
	end
	d.mult = totalMultiplier(d)
	d.nextGift = giftSecondsLeft(plr)
	StateRemote:FireClient(plr, d)
	setStat(plr, "Money", d.money)
	setStat(plr, "Rebirths", d.rebirths)
	setStat(plr, "Destroyed", d.destroyed)
end

-- нагорода одразу на баланс (квести, подарунки, щоденна)
local function reward(plr: Player, d: Data, amount: number, text: string)
	amount = math.floor(amount * totalMultiplier(d))
	d.money += amount
	notify(plr, text .. " +$" .. Config.short(amount))
end

local function questProgress(plr: Player, d: Data, kind: string, amount: number)
	if amount <= 0 then
		return
	end
	for i = #d.quests, 1, -1 do
		local q = d.quests[i]
		if q.kind == kind then
			q.progress = math.min(q.goal, q.progress + amount)
			if q.progress >= q.goal then
				table.remove(d.quests, i)
				reward(plr, d, q.reward, "Quest complete!")
				fillQuests(d)
			end
		end
	end
end

---------------------------------------------------------------- Щоденна нагорода, подарунки за час, друзі
local function checkDaily(plr: Player, d: Data)
	local today = math.floor(os.time() / 86400)
	if d.lastDay == today then
		return
	end
	d.streak = if d.lastDay == today - 1 then math.min(d.streak + 1, Config.DAILY_MAX_STREAK) else 1
	d.lastDay = today
	reward(plr, d, Config.rewardBase(highestZone(d)) * d.streak, "Daily reward (day " .. d.streak .. ")!")
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, plr in Players:GetPlayers() do
			local d = data[plr]
			if d and giftSecondsLeft(plr) == 0 then
				local n = (giftsTaken[plr] or 0) + 1
				giftsTaken[plr] = n
				reward(plr, d, Config.rewardBase(highestZone(d)) * Config.GIFTS[n].mult, "Playtime gift!")
				sendState(plr)
			end
		end
	end
end)

local friendCache: { [Player]: { [number]: boolean } } = {}
local function isFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if not cache then
		cache = {}
		friendCache[a] = cache
	end
	if cache[b.UserId] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		cache[b.UserId] = ok and result == true
	end
	return cache[b.UserId]
end

local function updateFriends()
	for _, plr in Players:GetPlayers() do
		local d = data[plr]
		if not d then
			continue
		end
		local n = 0
		for _, other in Players:GetPlayers() do
			if other ~= plr and isFriend(plr, other) then
				n += 1
			end
		end
		if n ~= d.friends then
			if n > d.friends then
				local percent = math.floor(Config.FRIEND_BONUS * 100 * math.min(n, Config.FRIEND_MAX) + 0.5)
				notify(plr, "Friend on server! Money +" .. percent .. "%")
			end
			d.friends = n
			sendState(plr)
		end
	end
end

local function ownsPass(plr: Player, id: number): boolean
	if id == 0 then
		return false
	end
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, id)
	return ok and result == true
end

---------------------------------------------------------------- Вхід / вихід
Players.PlayerAdded:Connect(function(plr)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Money", "Rebirths", "Destroyed" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = plr

	local saved = nil
	local ok = store ~= nil
	if store then
		for attempt = 1, 3 do
			ok, saved = pcall(function()
				return (store :: DataStore):GetAsync("p_" .. plr.UserId)
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
	end
	if not plr.Parent then
		return
	end
	-- якщо завантажити не вдалося, граємо без збереження, щоб не затерти старий прогрес
	canSave[plr] = ok
	local d = fromSaved(saved)
	d.autoSell = ownsPass(plr, Config.AUTO_SELL_PASS_ID)
	d.x2 = ownsPass(plr, Config.X2_PASS_ID)
	if not plr.Parent then
		return
	end
	data[plr] = d
	joinedAt[plr] = os.clock()
	giftsTaken[plr] = 0
	checkDaily(plr, d)
	sendState(plr)
	if not ok then
		notify(plr, "Progress will not save this session")
	end
	updateFriends()
end)

Players.PlayerRemoving:Connect(function(plr)
	save(plr)
	data[plr] = nil
	canSave[plr] = nil
	lastThrow[plr] = nil
	joinedAt[plr] = nil
	giftsTaken[plr] = nil
	friendCache[plr] = nil
	task.defer(updateFriends)
end)

game:BindToClose(function()
	local running = 0
	for plr in data do
		running += 1
		task.spawn(function()
			save(plr)
			running -= 1
		end)
	end
	local start = os.clock()
	while running > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, plr in Players:GetPlayers() do
			task.spawn(save, plr)
		end
	end
end)

ReadyRemote.OnServerEvent:Connect(sendState)

---------------------------------------------------------------- Explosions
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { blocks }

-- кладемо гроші в сумку (з урахуванням множника і місця в сумці)
local function addToBag(plr: Player, amount: number, pos: Vector3, text: string?)
	local d = data[plr]
	if not d or amount <= 0 then
		return
	end
	amount = math.floor(amount * totalMultiplier(d))
	if d.autoSell then
		d.money += amount
		EarnedRemote:FireClient(plr, pos, amount, text)
		return
	end
	local free = Config.Bags[d.bagLevel].capacity - d.bag
	if free <= 0 then
		notify(plr, "Bag is full! Go SELL at spawn")
		return
	end
	local added = math.min(amount, free)
	d.bag += added
	EarnedRemote:FireClient(plr, pos, added, text)
	if added < amount then
		notify(plr, "Bag is full! Go SELL at spawn")
	end
end

local function explode(plr: Player, damage: number, radius: number, pos: Vector3)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = radius
	e.BlastPressure = 0 -- нікого не відкидає
	e.DestroyJointRadiusPercent = 0 -- нікого не вбиває
	e.Parent = workspace
	BoomRemote:FireAllClients(pos, radius)

	local d = data[plr]
	if not d then
		return
	end

	local earned = 0
	local flying = 0
	local blocksBroken = 0
	local barrels = 0
	local buildings = 0
	for _, p in workspace:GetPartBoundsInRadius(pos, radius, overlap) do
		local zone = p:GetAttribute("Zone")
		if p.Parent ~= blocks or not d.zones[zone] then
			continue -- закриті локації не ламаються
		end
		local hp = p:GetAttribute("HP") - damage
		if hp > 0 then
			p:SetAttribute("HP", hp)
			p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.3)
			continue
		end

		local value = Config.Zones[zone].value
		if p:GetAttribute("Barrel") then
			-- бочка: ланцюговий вибух
			barrels += 1
			earned += value * Config.BARREL_VALUE
			local at = p.Position
			breakBlock(p, false)
			task.delay(0.15, explode, plr, Config.Zones[zone].hp * 3, Config.BARREL_RADIUS, at)
		else
			blocksBroken += 1
			earned += value
			flying += 1
			local at = p.Position
			local building = breakBlock(p, flying <= MAX_FLYING)
			if buildingLeft[building] == 0 then
				buildings += 1
				addToBag(plr, buildingValue[building], at + Vector3.new(0, 6, 0), "BUILDING DESTROYED!")
			end
		end
	end

	if blocksBroken + barrels == 0 then
		return
	end
	d.destroyed += blocksBroken + barrels
	addToBag(plr, earned, pos)
	questProgress(plr, d, "blocks", blocksBroken)
	questProgress(plr, d, "barrels", barrels)
	questProgress(plr, d, "buildings", buildings)
	sendState(plr)
end

local function launch(plr: Player, weapon, from: Vector3, to: Vector3)
	local proj = Instance.new("Part")
	proj.Size = Vector3.new(0.8, 0.8, 1.6)
	proj.Color = weapon.color
	lego(proj)
	proj.Anchored = true
	proj.CanCollide = false
	proj.CanQuery = false
	proj.CanTouch = false
	Instance.new("Sparkles").Parent = proj
	proj.Parent = workspace

	local dist = (to - from).Magnitude
	local duration = math.max(0.25, dist / weapon.speed)
	local height = dist * 0.25
	local t = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local a = math.min(t / duration, 1)
		local pos = from:Lerp(to, a) + Vector3.new(0, 4 * height * a * (1 - a), 0)
		proj.CFrame = CFrame.new(pos) * CFrame.Angles(t * 10, t * 7, 0)
		if a >= 1 then
			conn:Disconnect()
			proj:Destroy()
			explode(plr, weapon.damage, weapon.radius, to)
		end
	end)
end

ThrowRemote.OnServerEvent:Connect(function(plr, target)
	local d = data[plr]
	if not d or typeof(target) ~= "Vector3" or target ~= target or target.Magnitude > 1e5 then
		return
	end
	local weapon = Config.Weapons[d.weapon]
	local now = os.clock()
	if now - (lastThrow[plr] or 0) < weapon.cooldown then
		return
	end

	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	lastThrow[plr] = now

	local from = root.Position + Vector3.new(0, 2, 0)
	local offset = target - from
	if offset.Magnitude < 1 then
		return
	end
	if offset.Magnitude > Config.RANGE then
		target = from + offset.Unit * Config.RANGE
	end
	launch(plr, weapon, from, target)
end)

---------------------------------------------------------------- Sell, shop, rebirth, gates
sellPad.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	local d = plr and data[plr]
	if d and d.bag > 0 then
		local amount = d.bag
		d.money += amount
		d.bag = 0
		notify(plr, "Sold for $" .. Config.short(amount) .. "!")
		questProgress(plr, d, "sell", amount)
		sendState(plr)
	end
end)

local function nearShop(plr: Player): boolean
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - shopPad.Position).Magnitude < 30
end

-- ребьорт: скидаємо гроші/сумку/зброю/локації, решту залишаємо
local function doRebirth(plr: Player, d: Data)
	local n = freshData()
	n.rebirths = d.rebirths + 1
	n.destroyed = d.destroyed
	n.quests = d.quests
	n.lastDay = d.lastDay
	n.streak = d.streak
	n.receipts = d.receipts
	n.autoSell = d.autoSell
	n.x2 = d.x2
	n.friends = d.friends
	data[plr] = n
	notify(plr, "REBIRTH! Money x" .. Config.multiplier(n.rebirths))
	-- стіни знову закриті: повертаємо персонажа на спавн
	plr:LoadCharacter()
end

BuyRemote.OnServerEvent:Connect(function(plr, kind, index)
	local d = data[plr]
	if not d or typeof(index) ~= "number" then
		return
	end

	if kind == "weapon" then
		local weapon = Config.Weapons[index]
		if not weapon then
			return
		end
		if d.weapons[index] then
			d.weapon = index -- вже куплено: просто вибрати
		elseif not nearShop(plr) then
			notify(plr, "Go to the SHOP at spawn")
		elseif d.money < weapon.price then
			notify(plr, "Not enough money")
		else
			d.money -= weapon.price
			d.weapons[index] = true
			d.weapon = index
			notify(plr, "Bought " .. weapon.name .. "!")
		end
	elseif kind == "bag" then
		local bag = Config.Bags[index]
		if not bag or index ~= d.bagLevel + 1 then
			return
		end
		if not nearShop(plr) then
			notify(plr, "Go to the SHOP at spawn")
		elseif d.money < bag.price then
			notify(plr, "Not enough money")
		else
			d.money -= bag.price
			d.bagLevel = index
			notify(plr, "New bag: " .. bag.name .. "!")
		end
	elseif kind == "rebirth" then
		local price = Config.rebirthPrice(d.rebirths)
		if not nearShop(plr) then
			notify(plr, "Go to the SHOP at spawn")
		elseif d.money < price then
			notify(plr, "Rebirth costs $" .. Config.short(price))
		else
			doRebirth(plr, d)
		end
	end
	sendState(plr)
end)

for _, gate in gates:GetChildren() do
	local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		continue
	end
	local i = tonumber(string.sub(gate.Name, 5)) :: number
	prompt.Triggered:Connect(function(plr)
		local d = data[plr]
		if not d or d.zones[i] then
			return
		end
		local zone = Config.Zones[i]
		if not d.zones[i - 1] then
			notify(plr, "Unlock " .. Config.Zones[i - 1].name .. " first")
		elseif d.money < zone.price then
			notify(plr, "Need $" .. Config.short(zone.price))
		else
			d.money -= zone.price
			d.zones[i] = true
			notify(plr, zone.name .. " unlocked!")
			sendState(plr)
		end
	end)
end

---------------------------------------------------------------- Robux: gamepass'и і developer products
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
	local d = data[plr]
	if not d or not purchased or passId == 0 then
		return
	end
	if passId == Config.AUTO_SELL_PASS_ID then
		d.autoSell = true
		d.money += d.bag
		d.bag = 0
		notify(plr, "Auto-Sell activated! Money goes straight to your balance")
	elseif passId == Config.X2_PASS_ID then
		d.x2 = true
		notify(plr, "x2 Money activated!")
	end
	sendState(plr)
end)

MarketplaceService.ProcessReceipt = function(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local d = plr and data[plr]
	if not plr or not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox повторить, коли гравець зайде
	end
	local purchaseId = tostring(info.PurchaseId)
	if table.find(d.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- вже видано раніше
	end
	local product = nil
	for _, p in Config.PRODUCTS do
		if p.id ~= 0 and p.id == info.ProductId then
			product = p
		end
	end
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if product.kind == "money" then
		local amount = math.floor(Config.rewardBase(highestZone(d)) * product.amount)
		d.money += amount
		notify(plr, "Thanks for the purchase! +$" .. Config.short(amount))
	elseif product.kind == "rebirth" then
		doRebirth(plr, d)
		d = data[plr]
	end
	table.insert(d.receipts, purchaseId)
	while #d.receipts > 50 do
		table.remove(d.receipts, 1)
	end
	sendState(plr)

	-- якщо збереження доступне, але не вдалося — Roblox повторить пізніше (і прогрес теж не збережеться)
	if store and canSave[plr] and not save(plr) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------- Таблиця лідерів біля спавну
-- Глобальна (усі сервери) через OrderedDataStore; якщо недоступна, показує гравців цього сервера.
local board = box(Vector3.new(16, 20, 1), Vector3.new(-78, 10, 0), Color3.fromRGB(27, 42, 53))
board.CFrame = CFrame.lookAt(board.Position, board.Position + Vector3.new(1, 0, 0))
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Front
surface.CanvasSize = Vector2.new(400, 500)
surface.Parent = board
local boardTitle = Instance.new("TextLabel")
boardTitle.Size = UDim2.new(1, 0, 0, 60)
boardTitle.BackgroundTransparency = 1
boardTitle.Font = Enum.Font.FredokaOne
boardTitle.TextScaled = true
boardTitle.TextColor3 = Color3.fromRGB(255, 204, 77)
boardTitle.Text = "MOST DESTROYED"
boardTitle.Parent = surface
local rows = {}
for i = 1, 10 do
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, -20, 0, 40)
	row.Position = UDim2.fromOffset(10, 60 + (i - 1) * 43)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.FredokaOne
	row.TextScaled = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 0) elseif i <= 3 then Color3.fromRGB(220, 220, 230) else Color3.new(1, 1, 1)
	row.Text = ""
	row.Parent = surface
	rows[i] = row
end

local ordered: OrderedDataStore? = nil
pcall(function()
	ordered = DataStoreService:GetOrderedDataStore("DestroyIt_Destroyed_v1")
end)
local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then name else "Player"
	end
	return names[userId]
end

local function refreshBoard()
	local entries = {}
	local ok = false
	if ordered then
		-- записуємо результати тих, хто зараз у грі
		for _, plr in Players:GetPlayers() do
			local d = data[plr]
			if d and canSave[plr] then
				pcall(function()
					(ordered :: OrderedDataStore):SetAsync("p_" .. plr.UserId, math.floor(d.destroyed))
				end)
			end
		end
		ok = pcall(function()
			local page = (ordered :: OrderedDataStore):GetSortedAsync(false, 10):GetCurrentPage()
			for _, item in page do
				local id = tonumber(string.sub(item.key, 3))
				if id then
					table.insert(entries, { name = nameOf(id), value = Config.short(item.value) })
				end
			end
		end)
	end
	if not ok then
		entries = {}
		for plr, d in data do
			table.insert(entries, { name = plr.Name, raw = d.destroyed, value = Config.short(d.destroyed) })
		end
		table.sort(entries, function(a, b)
			return a.raw > b.raw
		end)
	end
	for i, row in rows do
		local e = entries[i]
		row.Text = if e then i .. ". " .. e.name .. "  " .. e.value else ""
	end
end

task.spawn(function()
	while true do
		refreshBoard()
		task.wait(60)
	end
end)

---------------------------------------------------------------- Адмін-команди (для тестування)
-- Пиши в чат: !money 100000, !unlock, !weapons, !bag, !autosell, !x2, !reset
local function isAdmin(plr: Player): boolean
	return RunService:IsStudio() or plr.UserId == game.CreatorId or table.find(Config.ADMINS, plr.UserId) ~= nil
end

local commands = {
	money = function(d: Data, arg: string?)
		d.money += tonumber(arg) or 100000
	end,
	unlock = function(d: Data)
		for i in d.zones do
			d.zones[i] = true
		end
	end,
	weapons = function(d: Data)
		for i in d.weapons do
			d.weapons[i] = true
		end
	end,
	bag = function(d: Data)
		d.bagLevel = #Config.Bags
	end,
	autosell = function(d: Data)
		d.autoSell = not d.autoSell
	end,
	x2 = function(d: Data)
		d.x2 = not d.x2
	end,
}

local function onChat(plr: Player, message: string)
	local cmd, arg = string.match(string.lower(message), "^!(%w+)%s*(%S*)")
	if not cmd or not isAdmin(plr) then
		return
	end
	if cmd == "reset" then
		data[plr] = freshData()
	elseif commands[cmd] and data[plr] then
		commands[cmd](data[plr], arg)
	else
		notify(plr, "Commands: !money N, !unlock, !weapons, !bag, !autosell, !x2, !reset")
		return
	end
	notify(plr, "Admin: " .. cmd .. " done")
	sendState(plr)
end

Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(message)
		onChat(plr, message)
	end)
end)
for _, plr in Players:GetPlayers() do
	plr.Chatted:Connect(function(message)
		onChat(plr, message)
	end)
end
