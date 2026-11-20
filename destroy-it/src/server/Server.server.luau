-- Сервер: будує карту, рахує гроші, вибухи, продаж і покупки.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local B = Config.BLOCK
local SIZE = Config.ZONE_SIZE
local ROAD = Config.ROAD_HALF
local COLUMNS = math.ceil(#Config.Zones / 2)
local END_X = COLUMNS * SIZE -- кінець дороги
local SPAWN_X = -40 -- центр зони спавну

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
local BuyRemote = newRemote("Buy") -- клієнт -> сервер: купити / вибрати
local StateRemote = newRemote("State") -- сервер -> клієнт: дані гравця
local NotifyRemote = newRemote("Notify") -- сервер -> клієнт: повідомлення

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

local function box(size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local function sign(parent: BasePart, text: string, color: Color3, offset: Vector3)
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
end

---------------------------------------------------------------- Blocks
local function spawnBlock(zone: number, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.one * B
	p.CFrame = cf
	p.Color = color
	p.Material = Config.Zones[zone].material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Zone", zone)
	p:SetAttribute("HP", Config.Zones[zone].hp)
	p.Parent = blocks
	-- запам'ятовуємо, як відбудувати
	p:SetAttribute("BaseColor", color)
end

local function breakBlock(p: BasePart)
	local zone = p:GetAttribute("Zone")
	local color = p:GetAttribute("BaseColor")
	local cf = p.CFrame
	-- уламок відлітає і зникає
	p.Parent = workspace
	p.CanQuery = false
	p.Anchored = false
	p.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(30, 60), math.random(-30, 30))
	Debris:AddItem(p, 2)
	task.delay(Config.RESPAWN, spawnBlock, zone, cf, color)
end

-- будинок: стіни по периметру + повний дах
local function buildHouse(zone: number, center: Vector3, w: number, h: number)
	local z = Config.Zones[zone]
	for y = 0, h - 1 do
		for ix = 0, w - 1 do
			for iz = 0, w - 1 do
				local edge = ix == 0 or iz == 0 or ix == w - 1 or iz == w - 1
				local isRoof = y == h - 1
				if edge or isRoof then
					local pos = center + Vector3.new((ix - (w - 1) / 2) * B, B / 2 + y * B, (iz - (w - 1) / 2) * B)
					spawnBlock(zone, CFrame.new(pos), if isRoof then z.roof else z.wall)
				end
			end
		end
	end
end

-- паркан квадратом навколо будинків, з проходом спереду
local function buildFence(zone: number, center: Vector3, half: number, side: number)
	local color = Config.Zones[zone].fence
	local n = math.floor(half * 2 / B)
	for i = 0, n do
		local t = -half + i * B
		local frontZ = -side * half -- сторона, що дивиться на дорогу
		if math.abs(t) > 5 then
			spawnBlock(zone, CFrame.new(center + Vector3.new(t, B / 2, frontZ)), color)
		end
		spawnBlock(zone, CFrame.new(center + Vector3.new(t, B / 2, -frontZ)), color)
		if i > 0 and i < n then
			spawnBlock(zone, CFrame.new(center + Vector3.new(-half, B / 2, t)), color)
			spawnBlock(zone, CFrame.new(center + Vector3.new(half, B / 2, t)), color)
		end
	end
end

---------------------------------------------------------------- Build map
local GRASS = Color3.fromRGB(70, 110, 50)
local WALL = Color3.fromRGB(40, 40, 45)
local totalDepth = (ROAD + SIZE) * 2

-- земля, дорога, смуги швидкості
box(Vector3.new(END_X + 80, 2, totalDepth), Vector3.new((END_X - 80) / 2, -1, 0), GRASS, Enum.Material.Grass)
box(Vector3.new(END_X, 0.2, ROAD * 2), Vector3.new(END_X / 2, 0.1, 0), Color3.fromRGB(45, 45, 50), Enum.Material.Asphalt)
for x = 6, END_X - 4, 12 do
	box(Vector3.new(3, 0.25, ROAD * 2 - 6), Vector3.new(x, 0.15, 0), Color3.fromRGB(30, 180, 255), Enum.Material.Neon)
end

-- межі карти
local function wall(size: Vector3, pos: Vector3)
	local w = box(size, pos, WALL, Enum.Material.SmoothPlastic)
	w.Transparency = 0.6
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
spawnPoint.Position = Vector3.new(SPAWN_X - 15, 0.5, 0)
spawnPoint.Neutral = true
spawnPoint.Duration = 0
spawnPoint.Parent = map

local shopPad = box(Vector3.new(14, 1, 14), Vector3.new(SPAWN_X, 0.5, -22), Color3.fromRGB(255, 138, 60), Enum.Material.Neon)
shopPad.Name = "Shop"
sign(shopPad, "SHOP", Color3.fromRGB(255, 180, 90), Vector3.new(0, 6, 0))
local shopPrompt = Instance.new("ProximityPrompt")
shopPrompt.Name = "ShopPrompt"
shopPrompt.ActionText = "Open shop"
shopPrompt.ObjectText = "Bags & Weapons"
shopPrompt.HoldDuration = 0
shopPrompt.MaxActivationDistance = 14
shopPrompt.RequiresLineOfSight = false
shopPrompt.Parent = shopPad

local sellPad = box(Vector3.new(14, 1, 14), Vector3.new(SPAWN_X, 0.5, 22), Color3.fromRGB(60, 255, 110), Enum.Material.Neon)
sellPad.Name = "Sell"
sign(sellPad, "SELL", Color3.fromRGB(120, 255, 150), Vector3.new(0, 6, 0))

-- локації
for i, zone in Config.Zones do
	local col = math.floor((i - 1) / 2)
	local side = if i % 2 == 1 then 1 else -1 -- 1 = над дорогою, -1 = під
	local cx = col * SIZE + SIZE / 2
	local cz = side * (ROAD + SIZE / 2)
	local center = Vector3.new(cx, 0.4, cz)

	box(Vector3.new(SIZE, 0.4, SIZE), Vector3.new(cx, 0.2, cz), zone.floor, Enum.Material.Grass)
	-- бокові та задня стіни
	wall(Vector3.new(1, 30, SIZE), Vector3.new(col * SIZE, 15, cz))
	wall(Vector3.new(1, 30, SIZE), Vector3.new((col + 1) * SIZE, 15, cz))
	wall(Vector3.new(SIZE, 30, 1), Vector3.new(cx, 15, side * (ROAD + SIZE)))

	-- будівлі 2x2 + паркан
	for _, off in { Vector3.new(-12, 0, -12), Vector3.new(12, 0, -12), Vector3.new(-12, 0, 12), Vector3.new(12, 0, 12) } do
		buildHouse(i, center + off, 4, zone.height)
	end
	buildFence(i, center, 24, side)

	-- вхідна стіна (гейт)
	local gate = box(Vector3.new(SIZE, 30, 1), Vector3.new(cx, 15, side * ROAD), Color3.fromRGB(220, 40, 40), Enum.Material.ForceField, gates)
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

---------------------------------------------------------------- Player data (без збереження)
type Data = {
	money: number,
	bag: number,
	bagLevel: number,
	weapon: number,
	weapons: { boolean },
	zones: { boolean },
}

local data: { [Player]: Data } = {}
local lastThrow: { [Player]: number } = {}

local function notify(plr: Player, text: string)
	NotifyRemote:FireClient(plr, text)
end

local function sendState(plr: Player)
	local d = data[plr]
	if not d then
		return
	end
	StateRemote:FireClient(plr, d)
	local stats = plr:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	if money then
		(money :: IntValue).Value = d.money
	end
end

Players.PlayerAdded:Connect(function(plr)
	local weapons, zones = {}, {}
	for i in Config.Weapons do
		weapons[i] = i == 1
	end
	for i in Config.Zones do
		zones[i] = i == 1
	end
	data[plr] = { money = 0, bag = 0, bagLevel = 1, weapon = 1, weapons = weapons, zones = zones }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Parent = stats
	stats.Parent = plr
end)

Players.PlayerRemoving:Connect(function(plr)
	data[plr] = nil
	lastThrow[plr] = nil
end)

ReadyRemote.OnServerEvent:Connect(sendState)

---------------------------------------------------------------- Explosions
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { blocks }

local function explode(plr: Player, weapon, pos: Vector3)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = weapon.radius
	e.BlastPressure = 0 -- нікого не відкидає
	e.DestroyJointRadiusPercent = 0 -- нікого не вбиває
	e.Parent = workspace

	local d = data[plr]
	if not d then
		return
	end

	local earned = 0
	for _, p in workspace:GetPartBoundsInRadius(pos, weapon.radius, overlap) do
		local zone = p:GetAttribute("Zone")
		if p.Parent ~= blocks or not d.zones[zone] then
			continue -- закриті локації не ламаються
		end
		local hp = p:GetAttribute("HP") - weapon.damage
		if hp <= 0 then
			earned += Config.Zones[zone].value
			breakBlock(p)
		else
			p:SetAttribute("HP", hp)
			p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.3)
		end
	end

	if earned > 0 then
		local free = Config.Bags[d.bagLevel].capacity - d.bag
		if free <= 0 then
			notify(plr, "Bag is full! Go sell at spawn")
			return
		end
		d.bag += math.min(earned, free)
		sendState(plr)
	end
end

local function launch(plr: Player, weapon, from: Vector3, to: Vector3)
	local proj = Instance.new("Part")
	proj.Size = Vector3.new(0.8, 0.8, 1.6)
	proj.Color = weapon.color
	proj.Material = Enum.Material.Neon
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
			explode(plr, weapon, to)
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
	if not root then
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

---------------------------------------------------------------- Sell, shop, gates
sellPad.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	local d = plr and data[plr]
	if d and d.bag > 0 then
		d.money += d.bag
		notify(plr, "Sold for $" .. d.bag)
		d.bag = 0
		sendState(plr)
	end
end)

local function nearShop(plr: Player): boolean
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - shopPad.Position).Magnitude < 30
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
			notify(plr, "Go to the shop at spawn")
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
			notify(plr, "Go to the shop at spawn")
		elseif d.money < bag.price then
			notify(plr, "Not enough money")
		else
			d.money -= bag.price
			d.bagLevel = index
			notify(plr, "New bag: " .. bag.name .. "!")
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
			notify(plr, "Need $" .. zone.price)
		else
			d.money -= zone.price
			d.zones[i] = true
			notify(plr, zone.name .. " unlocked!")
			sendState(plr)
		end
	end)
end
