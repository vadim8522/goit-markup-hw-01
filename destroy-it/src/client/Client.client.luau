-- Клієнт: інтерфейс, кидки по кліку, смуга швидкості, відкриті стіни.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ThrowRemote = remotes:WaitForChild("Throw") :: RemoteEvent
local BuyRemote = remotes:WaitForChild("Buy") :: RemoteEvent
local StateRemote = remotes:WaitForChild("State") :: RemoteEvent
local NotifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
local ReadyRemote = remotes:WaitForChild("Ready") :: RemoteEvent
local BoomRemote = remotes:WaitForChild("Boom") :: RemoteEvent
local EarnedRemote = remotes:WaitForChild("Earned") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gates = workspace:WaitForChild("Map"):WaitForChild("Gates")

local state = nil -- дані від сервера
local lastThrow = 0

---------------------------------------------------------------- UI helpers
local function new(class: string, props: { [string]: any }): any
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent: Instance)
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = parent })
end

local function short(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

local DARK = Color3.fromRGB(25, 25, 30)
local FONT = Enum.Font.FredokaOne

local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })

-- гроші
local moneyLabel = new("TextLabel", {
	Size = UDim2.fromOffset(220, 46), Position = UDim2.fromOffset(12, 12),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.3, TextColor3 = Color3.fromRGB(125, 255, 140),
	Font = FONT, TextScaled = true, Text = "$0", Parent = gui,
})
corner(moneyLabel)

-- сумка
local bagFrame = new("Frame", {
	Size = UDim2.fromOffset(220, 46), Position = UDim2.fromOffset(12, 64),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.3, Parent = gui,
})
corner(bagFrame)
local bagLabel = new("TextLabel", {
	Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 2), BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Bag", Parent = bagFrame,
})
local barBack = new("Frame", {
	Size = UDim2.new(1, -12, 0, 12), Position = UDim2.fromOffset(6, 28),
	BackgroundColor3 = Color3.fromRGB(60, 60, 60), Parent = bagFrame,
})
corner(barBack)
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 204, 77), Parent = barBack })
corner(barFill)

-- повідомлення
local toast = new("TextLabel", {
	Size = UDim2.fromOffset(420, 40), Position = UDim2.new(0.5, -210, 0, 70),
	BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0,
	Font = FONT, TextScaled = true, Text = "", Parent = gui,
})

-- панель зброї
local hotbar = new("Frame", {
	Size = UDim2.fromOffset(#Config.Weapons * 98, 64), Position = UDim2.new(0.5, -#Config.Weapons * 49, 1, -76),
	BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = hotbar })
local slots = {}
for i, weapon in Config.Weapons do
	local b = new("TextButton", {
		Size = UDim2.fromOffset(90, 64), BackgroundColor3 = DARK, BackgroundTransparency = 0.2,
		TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 16, Text = weapon.name, Parent = hotbar,
	})
	corner(b)
	new("UIStroke", { Color = Color3.fromRGB(255, 204, 77), Thickness = 3, Enabled = false, Parent = b })
	b.Activated:Connect(function()
		if state and state.weapons[i] then
			BuyRemote:FireServer("weapon", i)
		end
	end)
	slots[i] = b
end

-- крамниця
local shop = new("Frame", {
	Size = UDim2.fromOffset(560, 500), Position = UDim2.new(0.5, -280, 0.5, -250),
	BackgroundColor3 = DARK, Visible = false, Parent = gui,
})
corner(shop)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 138, 60),
	Font = FONT, TextSize = 30, Text = "SHOP", Parent = shop,
})
local closeBtn = new("TextButton", {
	Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -42, 0, 6), BackgroundColor3 = Color3.fromRGB(200, 50, 50),
	TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 22, Text = "X", Parent = shop,
})
corner(closeBtn)
closeBtn.Activated:Connect(function()
	shop.Visible = false
end)

local function column(title: string, x: number): Frame
	new("TextLabel", {
		Size = UDim2.new(0.5, -20, 0, 28), Position = UDim2.new(x, 10, 0, 48), BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 22, Text = title, Parent = shop,
	})
	local list = new("Frame", {
		Size = UDim2.new(0.5, -20, 1, -210), Position = UDim2.new(x, 10, 0, 80), BackgroundTransparency = 1, Parent = shop,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	return list
end
local bagList = column("Bags", 0)
local weaponList = column("Weapons", 0.5)

local bagButtons, weaponButtons = {}, {}
local function shopButton(list: Frame, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(50, 50, 58),
		TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 16, Text = "", Parent = list,
	})
	corner(b)
	b.Activated:Connect(onClick)
	return b
end
for i in Config.Bags do
	bagButtons[i] = shopButton(bagList, function()
		BuyRemote:FireServer("bag", i)
	end)
end
for i in Config.Weapons do
	weaponButtons[i] = shopButton(weaponList, function()
		BuyRemote:FireServer("weapon", i)
	end)
end

-- ребьорт: скидає прогрес, але гроші множаться
local rebirthBtn = new("TextButton", {
	Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -116), BackgroundColor3 = Color3.fromRGB(150, 60, 220),
	TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 18, Text = "REBIRTH", Parent = shop,
})
corner(rebirthBtn)
rebirthBtn.Activated:Connect(function()
	BuyRemote:FireServer("rebirth", 0)
end)

-- gamepass Auto-Sell (за Robux)
local autoSellBtn = new("TextButton", {
	Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -60), BackgroundColor3 = Color3.fromRGB(0, 170, 90),
	TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 18, Text = "AUTO-SELL (Robux): money goes straight to balance", Parent = shop,
})
corner(autoSellBtn)
autoSellBtn.Activated:Connect(function()
	if state and state.autoSell then
		return
	end
	if Config.AUTO_SELL_PASS_ID == 0 then
		toast.Text = "Auto-Sell gamepass is not set up yet"
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Config.AUTO_SELL_PASS_ID)
end)

---------------------------------------------------------------- State updates
local function showToast(text: string)
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0
	TweenService:Create(toast, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1.5), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
end

-- "+$5" вилітає над місцем вибуху
local function worldPopup(pos: Vector3, text: string, big: boolean)
	local anchor = new("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.one, Position = pos, Parent = workspace,
	})
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(if big then 360 else 140, if big then 70 else 44), AlwaysOnTop = true, Parent = anchor,
	})
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Font = FONT,
		TextColor3 = if big then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(125, 255, 140),
		TextStrokeTransparency = 0, Text = text, Parent = bb,
	})
	local info = TweenInfo.new(if big then 2 else 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffset = Vector3.new(0, if big then 10 else 6, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(info.Time, anchor.Destroy, anchor)
end

-- тряска камери: сильніше, якщо вибух ближче і більший
local shake = 0
local function onBoom(pos: Vector3, radius: number)
	local dist = (camera.CFrame.Position - pos).Magnitude
	local power = math.clamp(radius / 6, 0.5, 4) * math.clamp(1 - dist / 150, 0, 1)
	shake = math.max(shake, power)
end

local GREEN = Color3.fromRGB(40, 140, 60)
local GREY = Color3.fromRGB(50, 50, 58)

local function render(newState)
	state = newState

	local mult = Config.multiplier(state.rebirths)
	moneyLabel.Text = "$" .. short(state.money) .. (if mult > 1 then "  x" .. mult else "")
	rebirthBtn.Text = "REBIRTH: $" .. short(Config.rebirthPrice(state.rebirths))
		.. "  ->  money x" .. Config.multiplier(state.rebirths + 1) .. " (resets progress)"
	local bag = Config.Bags[state.bagLevel]
	bagLabel.Text = bag.name .. ": " .. short(state.bag) .. " / " .. short(bag.capacity)
	barFill.Size = UDim2.fromScale(math.clamp(state.bag / bag.capacity, 0, 1), 1)
	if state.autoSell then
		bagLabel.Text = "AUTO-SELL ON"
		barFill.Size = UDim2.fromScale(1, 1)
	end
	autoSellBtn.Text = if state.autoSell then "AUTO-SELL: OWNED" else "AUTO-SELL (Robux): money goes straight to balance"
	barFill.BackgroundColor3 = if state.bag >= bag.capacity then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 204, 77)

	for i, weapon in Config.Weapons do
		local owned = state.weapons[i]
		slots[i].Text = if owned then weapon.name else weapon.name .. "\n$" .. short(weapon.price)
		slots[i].TextTransparency = if owned then 0 else 0.6
		slots[i].UIStroke.Enabled = state.weapon == i

		local b = weaponButtons[i]
		if state.weapon == i then
			b.Text, b.BackgroundColor3 = weapon.name .. "  (equipped)", GREEN
		elseif owned then
			b.Text, b.BackgroundColor3 = weapon.name .. "  (equip)", GREY
		else
			b.Text, b.BackgroundColor3 = weapon.name .. "  $" .. short(weapon.price), GREY
		end
	end

	for i, b in Config.Bags do
		local btn = bagButtons[i]
		local text = b.name .. " (" .. short(b.capacity) .. ")"
		if i <= state.bagLevel then
			btn.Text, btn.BackgroundColor3 = text .. "  owned", GREEN
		else
			btn.Text, btn.BackgroundColor3 = text .. "  $" .. short(b.price), GREY
		end
	end

	-- відкриті локації: стіна зникає тільки для цього гравця
	for i, open in state.zones do
		local gate = gates:FindFirstChild("Gate" .. i)
		if gate then
			gate.CanCollide = not open
			gate.Transparency = if open then 1 else 0
			local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = not open
			end
		end
	end
end

StateRemote.OnClientEvent:Connect(render)
NotifyRemote.OnClientEvent:Connect(showToast)
BoomRemote.OnClientEvent:Connect(onBoom)
EarnedRemote.OnClientEvent:Connect(function(pos: Vector3, amount: number, text: string?)
	if text then
		worldPopup(pos, text .. "\n+$" .. short(amount), true)
	else
		worldPopup(pos, "+$" .. short(amount), false)
	end
end)
ReadyRemote:FireServer()

task.delay(2, showToast, "Click to throw dynamite! Destroy buildings, then SELL at spawn")

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		shop.Visible = true
	end
end)

---------------------------------------------------------------- Throwing
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not state or shop.Visible then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local weapon = Config.Weapons[state.weapon]
	if os.clock() - lastThrow < weapon.cooldown then
		return
	end
	lastThrow = os.clock()

	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	rayParams.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
	ThrowRemote:FireServer(if hit then hit.Position else ray.Origin + ray.Direction * 500)
end)

-- кнопки 1-4 для зброї
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not state then
		return
	end
	local i = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
	if i >= 1 and i <= #Config.Weapons and state.weapons[i] then
		BuyRemote:FireServer("weapon", i)
	end
end)

---------------------------------------------------------------- Camera shake
RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if shake > 0.01 then
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
		shake = math.max(0, shake - dt * 6)
	else
		humanoid.CameraOffset = Vector3.zero
	end
end)

---------------------------------------------------------------- Speed lane
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local p = root.Position
	local onRoad = p.X > 0 and math.abs(p.Z) < Config.ROAD_HALF
	humanoid.WalkSpeed = if onRoad then Config.ROAD_SPEED else Config.WALK_SPEED
end)
