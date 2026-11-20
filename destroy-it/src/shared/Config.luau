-- Усі налаштування гри в одному місці. Міняй цифри тут.
local Config = {}

-- Зброя: damage = шкода, radius = радіус вибуху, cooldown = пауза між кидками
Config.Weapons = {
	{ name = "Dynamite", price = 0, damage = 10, radius = 6, cooldown = 1, color = Color3.fromRGB(200, 40, 40) },
	{ name = "Grenade", price = 300, damage = 30, radius = 9, cooldown = 0.8, color = Color3.fromRGB(60, 140, 60) },
	{ name = "Rocket", price = 3000, damage = 100, radius = 13, cooldown = 0.8, color = Color3.fromRGB(80, 80, 80) },
}

-- Сумки: скільки грошей влазить, поки не підеш продавати
Config.Bags = {
	{ name = "Pocket", capacity = 30, price = 0 },
	{ name = "Backpack", capacity = 100, price = 100 },
	{ name = "Big Bag", capacity = 500, price = 1000 },
	{ name = "Truck", capacity = 3000, price = 8000 },
}

-- Зони (секції): hp = міцність блока, value = гроші за блок
Config.Zones = {
	{ name = "Wood", price = 0, hp = 10, value = 1, color = Color3.fromRGB(160, 110, 60) },
	{ name = "Stone", price = 1000, hp = 50, value = 6, color = Color3.fromRGB(130, 130, 130) },
	{ name = "Gold", price = 15000, hp = 250, value = 40, color = Color3.fromRGB(240, 200, 40) },
}

Config.BLOCK = 4 -- розмір блока
Config.ZONE_LENGTH = 80 -- довжина секції
Config.RESPAWN = 20 -- через скільки секунд блок з'являється знову
Config.RANGE = 80 -- як далеко можна кинути

return Config
