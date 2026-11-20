-- Усі налаштування гри в одному місці. Міняй цифри тут.
local Config = {}

-- Знаряддя: damage = шкода блоку, radius = радіус вибуху, cooldown = пауза між кидками
Config.Weapons = {
	{ name = "Dynamite", price = 0, damage = 10, radius = 6, cooldown = 0.8, speed = 60, color = Color3.fromRGB(200, 40, 40) },
	{ name = "Grenade", price = 300, damage = 30, radius = 8, cooldown = 0.7, speed = 80, color = Color3.fromRGB(60, 140, 60) },
	{ name = "Bazooka", price = 4000, damage = 100, radius = 11, cooldown = 0.7, speed = 120, color = Color3.fromRGB(70, 70, 70) },
	{ name = "Mini Nuke", price = 100000, damage = 500, radius = 18, cooldown = 1.5, speed = 70, color = Color3.fromRGB(255, 220, 0) },
}

-- Сумки: скільки грошей влазить, поки не підеш продавати
Config.Bags = {
	{ name = "Pocket", capacity = 25, price = 0 },
	{ name = "Backpack", capacity = 100, price = 100 },
	{ name = "Big Sack", capacity = 500, price = 800 },
	{ name = "Suitcase", capacity = 3000, price = 6000 },
	{ name = "Truck", capacity = 25000, price = 50000 },
}

local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Локації по порядку зліва направо: непарні над дорогою, парні під нею.
-- hp = міцність блока, value = гроші за блок, height = висота будівель у блоках
Config.Zones = {
	{ name = "Village", price = 0, hp = 10, value = 1, height = 3, floor = rgb(93, 138, 58), wall = rgb(176, 122, 69), roof = rgb(139, 45, 34), fence = rgb(201, 160, 106), material = M.WoodPlanks },
	{ name = "Farm", price = 300, hp = 15, value = 2, height = 3, floor = rgb(110, 150, 70), wall = rgb(170, 40, 40), roof = rgb(240, 240, 230), fence = rgb(230, 230, 220), material = M.WoodPlanks },
	{ name = "Ranch", price = 1000, hp = 25, value = 3, height = 3, floor = rgb(196, 160, 100), wall = rgb(150, 100, 60), roof = rgb(90, 60, 40), fence = rgb(120, 80, 50), material = M.Wood },
	{ name = "Suburbs", price = 2500, hp = 40, value = 5, height = 4, floor = rgb(80, 130, 70), wall = rgb(220, 210, 180), roof = rgb(70, 70, 90), fence = rgb(250, 250, 250), material = M.Brick },
	{ name = "City", price = 5000, hp = 60, value = 8, height = 7, floor = rgb(110, 110, 115), wall = rgb(120, 140, 160), roof = rgb(60, 60, 65), fence = rgb(150, 150, 150), material = M.Glass },
	{ name = "Factory", price = 15000, hp = 100, value = 12, height = 5, floor = rgb(90, 85, 80), wall = rgb(140, 70, 50), roof = rgb(80, 80, 80), fence = rgb(110, 110, 110), material = M.CorrodedMetal },
	{ name = "Military Base", price = 30000, hp = 160, value = 20, height = 3, floor = rgb(110, 105, 70), wall = rgb(80, 95, 60), roof = rgb(60, 70, 45), fence = rgb(140, 140, 130), material = M.Concrete },
	{ name = "Castle", price = 70000, hp = 250, value = 30, height = 6, floor = rgb(90, 120, 70), wall = rgb(150, 150, 145), roof = rgb(70, 40, 100), fence = rgb(120, 120, 115), material = M.Cobblestone },
	{ name = "Laboratory", price = 150000, hp = 400, value = 60, height = 5, floor = rgb(200, 200, 210), wall = rgb(240, 240, 250), roof = rgb(110, 70, 160), fence = rgb(80, 200, 220), material = M.SmoothPlastic },
	{ name = "Spaceport", price = 500000, hp = 650, value = 100, height = 8, floor = rgb(50, 55, 70), wall = rgb(200, 205, 215), roof = rgb(40, 80, 160), fence = rgb(255, 160, 0), material = M.DiamondPlate },
}

Config.BLOCK = 3 -- розмір одного блока
Config.ZONE_SIZE = 60 -- ширина й глибина локації
Config.ROAD_HALF = 15 -- половина ширини дороги
Config.RESPAWN = 30 -- через скільки секунд зламаний блок з'являється знову
Config.RANGE = 90 -- як далеко можна кинути
Config.WALK_SPEED = 16
Config.ROAD_SPEED = 55 -- швидкість на смузі

return Config
