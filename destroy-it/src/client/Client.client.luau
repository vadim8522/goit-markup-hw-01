-- Клієнт: інтерфейс, крамниця, квести, кидки по кліку, смуга швидкості, ефекти.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")

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
local giftDeadline = -1
local short = Config.short

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

local function corner(parent: Instance, radius: number?)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local DARK = Color3.fromRGB(25, 25, 32)
local PANEL = Color3.fromRGB(38, 38, 48)
local GREEN = Color3.fromRGB(40, 160, 70)
local GREY = Color3.fromRGB(60, 60, 72)
local GOLD = Color3.fromRGB(255, 204, 77)
local FONT = Enum.Font.FredokaOne

-- звуки (вбудовані в Roblox; можна замінити на свої rbxassetid://...)
local function sound(id: string, volume: number): Sound
	return new("Sound", { SoundId = id, Volume = volume, Parent = SoundService })
end
local clickSound = sound("rbxasset://sounds/clickfast.wav", 0.5)
local buySound = sound("rbxasset://sounds/electronicpingshort.wav", 0.6)

local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })

-- масштаб для маленьких екранів (телефон)
local scales = {}
local function scaled(obj: GuiObject): GuiObject
	table.insert(scales, new("UIScale", { Parent = obj }))
	return obj
end
local function updateScale()
	local s = math.clamp(camera.ViewportSize.Y / 720, 0.55, 1)
	for _, ui in scales do
		ui.Scale = s
	end
end

-- кнопка з ефектом наведення і звуком
local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	props.AutoButtonColor = false
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local b = new("TextButton", props)
	corner(b)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundTransparency = 0.15 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
	end)
	b.Activated:Connect(function()
		clickSound:Play()
		onClick()
	end)
	return b
end

---------------------------------------------------------------- HUD: гроші, сумка, подарунок
local left = scaled(new("Frame", {
	Size = UDim2.fromOffset(240, 160), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = gui,
}))

local moneyLabel = new("TextLabel", {
	Size = UDim2.fromOffset(240, 46), BackgroundColor3 = DARK, BackgroundTransparency = 0.25,
	TextColor3 = Color3.fromRGB(125, 255, 140), Font = FONT, TextScaled = true, Text = "$0", Parent = left,
})
corner(moneyLabel)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 60), Parent = moneyLabel })
local multBadge = new("TextLabel", {
	Size = UDim2.fromOffset(56, 30), Position = UDim2.new(1, 4, 0.5, -15), BackgroundColor3 = Color3.fromRGB(150, 60, 220),
	TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextScaled = true, Text = "x1", Visible = false, Parent = moneyLabel,
})
corner(multBadge)

local bagFrame = new("Frame", {
	Size = UDim2.fromOffset(240, 46), Position = UDim2.fromOffset(0, 52),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.25, Parent = left,
})
corner(bagFrame)
local bagLabel = new("TextLabel", {
	Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 2), BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Bag", Parent = bagFrame,
})
local barBack = new("Frame", {
	Size = UDim2.new(1, -12, 0, 12), Position = UDim2.fromOffset(6, 28), BackgroundColor3 = Color3.fromRGB(60, 60, 60), Parent = bagFrame,
})
corner(barBack, 6)
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, Parent = barBack })
corner(barFill, 6)

local giftLabel = new("TextLabel", {
	Size = UDim2.fromOffset(240, 32), Position = UDim2.fromOffset(0, 104), BackgroundColor3 = DARK, BackgroundTransparency = 0.25,
	TextColor3 = Color3.fromRGB(255, 170, 220), Font = FONT, TextScaled = true, Text = "🎁 ...", Parent = left,
})
corner(giftLabel)

---------------------------------------------------------------- Квести (праворуч)
local questPanel = scaled(new("Frame", {
	AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(260, 200), Position = UDim2.new(1, -12, 0, 60),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.25, Parent = gui,
}))
corner(questPanel)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, TextColor3 = GOLD, Font = FONT, TextSize = 22,
	Text = "📜 QUESTS", Parent = questPanel,
})
local questRows = {}
for i = 1, 3 do
	local row = new("Frame", { Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 34 + (i - 1) * 54), BackgroundTransparency = 1, Parent = questPanel })
	local text = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = FONT,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = row,
	})
	local back = new("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 26), BackgroundColor3 = Color3.fromRGB(60, 60, 60), Parent = row })
	corner(back, 6)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(80, 200, 255), Parent = back })
	corner(fill, 6)
	local count = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = FONT,
		TextScaled = true, TextStrokeTransparency = 0.5, Text = "", ZIndex = 2, Parent = back,
	})
	questRows[i] = { text = text, fill = fill, count = count }
end

---------------------------------------------------------------- Повідомлення
local toast = scaled(new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(600, 40), Position = UDim2.new(0.5, 0, 0, 70),
	BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0,
	Font = FONT, TextScaled = true, Text = "", Parent = gui,
}))
local function showToast(text: string)
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0
	TweenService:Create(toast, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 2), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
end

---------------------------------------------------------------- Панель зброї (внизу)
local hotbar = scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(#Config.Weapons * 98, 64), Position = UDim2.new(0.5, 0, 1, -12),
	BackgroundTransparency = 1, Parent = gui,
}))
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = hotbar })
local slots = {}
for i, weapon in Config.Weapons do
	local b = button({
		Size = UDim2.fromOffset(90, 64), BackgroundColor3 = DARK, TextSize = 15, Text = i .. ". " .. weapon.name, TextWrapped = true, Parent = hotbar,
	}, function()
		if state and state.weapons[i] then
			BuyRemote:FireServer("weapon", i)
		end
	end)
	new("UIStroke", { Color = GOLD, Thickness = 3, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	slots[i] = b
end

---------------------------------------------------------------- Крамниця з вкладками
-- holder масштабується під екран, а сама крамниця має свій UIScale для анімації відкриття
local shopHolder = scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(620, 470), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Parent = gui,
}))
local shop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = DARK, Visible = false, Parent = shopHolder })
corner(shop, 14)
new("UIStroke", { Color = Color3.fromRGB(255, 138, 60), Thickness = 3, Parent = shop })
local shopScale = new("UIScale", { Parent = shop })
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 138, 60),
	Font = FONT, TextSize = 34, Text = "🛒 SHOP", Parent = shop,
})
button({
	Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -48, 0, 8), BackgroundColor3 = Color3.fromRGB(200, 50, 50),
	TextSize = 24, Text = "X", Parent = shop,
}, function()
	shop.Visible = false
end)

local tabBar = new("Frame", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 54), BackgroundTransparency = 1, Parent = shop })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = tabBar })
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}

local function showTab(name: string)
	for n, page in pages do
		page.Visible = n == name
		tabButtons[n].BackgroundColor3 = if n == name then Color3.fromRGB(255, 138, 60) else GREY
	end
end

local function tab(name: string, label: string): ScrollingFrame
	local page = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -112), Position = UDim2.fromOffset(12, 102), BackgroundTransparency = 1,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, Parent = shop,
	})
	new("UIListLayout", { Padding = UDim.new(0, 8), Parent = page })
	pages[name] = page
	tabButtons[name] = button({ Size = UDim2.fromOffset(140, 40), BackgroundColor3 = GREY, TextSize = 18, Text = label, Parent = tabBar }, function()
		showTab(name)
	end)
	return page
end

-- рядок товару: назва + опис зліва, кнопка дії справа
local function row(page: ScrollingFrame, onClick: () -> ())
	local frame = new("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = PANEL, Parent = page })
	corner(frame, 10)
	local title = new("TextLabel", {
		Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(12, 4), BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = frame,
	})
	local desc = new("TextLabel", {
		Size = UDim2.new(1, -190, 0, 24), Position = UDim2.fromOffset(12, 34), BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(190, 190, 200), Font = Enum.Font.GothamMedium, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = frame,
	})
	local action = button({
		AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(160, 46), Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundColor3 = GREEN, TextSize = 20, Text = "", Parent = frame,
	}, onClick)
	return { title = title, desc = desc, action = action }
end

local weaponPage = tab("weapons", "💣 Weapons")
local bagPage = tab("bags", "🎒 Bags")
local rebirthPage = tab("rebirth", "🔁 Rebirth")
local robuxPage = tab("robux", "💎 Robux")

local weaponRows, bagRows = {}, {}
for i, weapon in Config.Weapons do
	weaponRows[i] = row(weaponPage, function()
		BuyRemote:FireServer("weapon", i)
	end)
	weaponRows[i].title.Text = weapon.name
	weaponRows[i].desc.Text = "Power " .. weapon.damage .. "  •  Radius " .. weapon.radius .. "  •  Reload " .. weapon.cooldown .. "s"
end
for i, bag in Config.Bags do
	bagRows[i] = row(bagPage, function()
		BuyRemote:FireServer("bag", i)
	end)
	bagRows[i].title.Text = bag.name
	bagRows[i].desc.Text = "Holds $" .. short(bag.capacity)
end

local rebirthInfo = new("TextLabel", {
	Size = UDim2.new(1, -10, 0, 150), BackgroundColor3 = PANEL, TextColor3 = Color3.new(1, 1, 1), Font = FONT,
	TextSize = 22, TextWrapped = true, Text = "", Parent = rebirthPage,
})
corner(rebirthInfo, 10)
local rebirthBtn = button({
	Size = UDim2.new(1, -10, 0, 60), BackgroundColor3 = Color3.fromRGB(150, 60, 220), TextSize = 26, Text = "REBIRTH", Parent = rebirthPage,
}, function()
	BuyRemote:FireServer("rebirth", 0)
end)

local function notSetUp()
	showToast("Not set up yet: put the ID in Config (see README)")
end

local passRows = {}
for _, pass in { { key = "autoSell", id = Config.AUTO_SELL_PASS_ID, name = "⚡ Auto-Sell", desc = "Money goes straight to balance, no bag" }, { key = "x2", id = Config.X2_PASS_ID, name = "💰 x2 Money", desc = "Double money forever" } } do
	local r = row(robuxPage, function()
		if state and state[pass.key] then
			return
		end
		if pass.id == 0 then
			notSetUp()
		else
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end)
	r.title.Text = pass.name
	r.desc.Text = pass.desc
	r.action.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
	passRows[pass.key] = r
end
local productRows = {}
for i, product in Config.PRODUCTS do
	local r = row(robuxPage, function()
		if product.id == 0 then
			notSetUp()
		else
			MarketplaceService:PromptProductPurchase(player, product.id)
		end
	end)
	r.title.Text = (if product.kind == "rebirth" then "🔁 " else "💵 ") .. product.name
	r.action.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
	r.action.Text = "BUY (Robux)"
	productRows[i] = r
end

showTab("weapons")

local function openShop()
	if shop.Visible then
		return
	end
	shop.Visible = true
	shopScale.Scale = 0.7
	TweenService:Create(shopScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

---------------------------------------------------------------- Ефекти: "+$" над вибухом, тряска камери
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

local shake = 0
local function onBoom(pos: Vector3, radius: number)
	local dist = (camera.CFrame.Position - pos).Magnitude
	local power = math.clamp(radius / 6, 0.5, 4) * math.clamp(1 - dist / 150, 0, 1)
	shake = math.max(shake, power)
end

---------------------------------------------------------------- Оновлення від сервера
local function setAction(btn: TextButton, text: string, color: Color3)
	btn.Text = text
	btn.BackgroundColor3 = color
end

local function render(newState)
	local old = state
	state = newState
	if old and (newState.money < old.money or (old.bag > 0 and newState.bag == 0)) then
		-- щось купили або продали
		buySound:Play()
	end

	moneyLabel.Text = "$" .. short(state.money)
	multBadge.Visible = state.mult > 1
	multBadge.Text = "x" .. (math.floor(state.mult * 10 + 0.5) / 10)

	local bag = Config.Bags[state.bagLevel]
	if state.autoSell then
		bagLabel.Text = "⚡ AUTO-SELL ON"
		barFill.Size = UDim2.fromScale(1, 1)
		barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
	else
		bagLabel.Text = "🎒 " .. bag.name .. ": " .. short(state.bag) .. " / " .. short(bag.capacity)
		barFill.Size = UDim2.fromScale(math.clamp(state.bag / bag.capacity, 0, 1), 1)
		barFill.BackgroundColor3 = if state.bag >= bag.capacity then Color3.fromRGB(255, 70, 70) else GOLD
	end

	giftDeadline = if state.nextGift >= 0 then os.clock() + state.nextGift else -1

	-- квести
	for i, ui in questRows do
		local q = state.quests[i]
		if q then
			local template
			for _, t in Config.QUESTS do
				if t.kind == q.kind then
					template = t
				end
			end
			ui.text.Text = string.format(template and template.text or q.kind, short(q.goal)) .. "  (+$" .. short(q.reward * state.mult) .. ")"
			ui.fill.Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1)
			ui.count.Text = short(q.progress) .. " / " .. short(q.goal)
		else
			ui.text.Text = ""
			ui.count.Text = ""
			ui.fill.Size = UDim2.fromScale(0, 1)
		end
	end

	-- зброя (панель + крамниця)
	for i, weapon in Config.Weapons do
		local owned = state.weapons[i]
		slots[i].Text = if owned then i .. ". " .. weapon.name else "🔒 " .. weapon.name
		slots[i].TextTransparency = if owned then 0 else 0.5
		slots[i].UIStroke.Enabled = state.weapon == i

		local r = weaponRows[i]
		if state.weapon == i then
			setAction(r.action, "EQUIPPED", GREY)
		elseif owned then
			setAction(r.action, "EQUIP", Color3.fromRGB(13, 105, 172))
		else
			setAction(r.action, "$" .. short(weapon.price), if state.money >= weapon.price then GREEN else Color3.fromRGB(120, 60, 60))
		end
	end

	for i, b in Config.Bags do
		local r = bagRows[i]
		if i <= state.bagLevel then
			setAction(r.action, if i == state.bagLevel then "EQUIPPED" else "OWNED", GREY)
		elseif i == state.bagLevel + 1 then
			setAction(r.action, "$" .. short(b.price), if state.money >= b.price then GREEN else Color3.fromRGB(120, 60, 60))
		else
			setAction(r.action, "🔒", GREY)
		end
	end

	local price = Config.rebirthPrice(state.rebirths)
	rebirthInfo.Text = "Rebirths: " .. state.rebirths
		.. "\nMoney now: x" .. Config.multiplier(state.rebirths) .. "  →  after rebirth: x" .. Config.multiplier(state.rebirths + 1)
		.. "\n\nResets money, bag, weapons and locations.\nKeeps rebirths, quests and Robux items."
	setAction(rebirthBtn, "REBIRTH  $" .. short(price), if state.money >= price then Color3.fromRGB(150, 60, 220) else Color3.fromRGB(90, 60, 110))

	for key, r in passRows do
		if state[key] then
			setAction(r.action, "OWNED ✔", GREY)
		else
			setAction(r.action, "BUY (Robux)", Color3.fromRGB(0, 170, 90))
		end
	end
	local highest = 1
	for i, open in state.zones do
		if open then
			highest = i
		end
	end
	for i, product in Config.PRODUCTS do
		productRows[i].desc.Text = if product.kind == "money"
			then "+$" .. short(Config.rewardBase(highest) * product.amount) .. " instantly"
			else "Rebirth right now, without paying money"
	end

	-- стіни локацій: відкриті зникають тільки для цього гравця
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
		openShop()
	end
end)

camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

---------------------------------------------------------------- Кидки
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

---------------------------------------------------------------- Кожен кадр: тряска, смуга швидкості, таймер подарунка
RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if humanoid then
		if shake > 0.01 then
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
			shake = math.max(0, shake - dt * 6)
		else
			humanoid.CameraOffset = Vector3.zero
		end
		if root then
			local p = root.Position
			local onRoad = p.X > 0 and math.abs(p.Z) < Config.ROAD_HALF
			humanoid.WalkSpeed = if onRoad then Config.ROAD_SPEED else Config.WALK_SPEED
		end
	end

	if giftDeadline < 0 then
		giftLabel.Text = "🎁 All gifts claimed!"
	else
		local left = math.max(0, math.ceil(giftDeadline - os.clock()))
		giftLabel.Text = string.format("🎁 Gift in %d:%02d", left // 60, left % 60)
	end
end)
