-- Усі налаштування гри в одному місці. Міняй цифри тут.
local Config = {}

-- Знаряддя: damage = шкода блоку, radius = радіус вибуху, cooldown = пауза між кидками
Config.Weapons = {
	{ name = "Dynamite", price = 0, damage = 10, radius = 6, cooldown = 0.8, speed = 60, color = Color3.fromRGB(220, 40, 40) },
	{ name = "Grenade", price = 300, damage = 30, radius = 8, cooldown = 0.7, speed = 80, color = Color3.fromRGB(60, 170, 60) },
	{ name = "Bazooka", price = 4000, damage = 100, radius = 11, cooldown = 0.7, speed = 120, color = Color3.fromRGB(60, 60, 70) },
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

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Локації по порядку зліва направо: непарні над дорогою, парні під нею.
-- hp = міцність блока, value = гроші за блок, height = висота будівель у блоках
-- Стиль: яскраві пластикові цеглинки, як конструктор.
Config.Zones = {
	{ name = "Village", price = 0, hp = 10, value = 1, height = 3, floor = rgb(75, 151, 75), wall = rgb(245, 205, 48), roof = rgb(196, 40, 28), fence = rgb(160, 95, 53) },
	{ name = "Farm", price = 300, hp = 15, value = 2, height = 3, floor = rgb(120, 180, 60), wall = rgb(196, 40, 28), roof = rgb(242, 243, 243), fence = rgb(242, 243, 243) },
	{ name = "Ranch", price = 1000, hp = 25, value = 3, height = 3, floor = rgb(215, 197, 154), wall = rgb(160, 95, 53), roof = rgb(98, 71, 50), fence = rgb(124, 92, 70) },
	{ name = "Suburbs", price = 2500, hp = 40, value = 5, height = 4, floor = rgb(75, 151, 75), wall = rgb(13, 105, 172), roof = rgb(27, 42, 53), fence = rgb(242, 243, 243) },
	{ name = "City", price = 5000, hp = 60, value = 8, height = 7, floor = rgb(99, 95, 98), wall = rgb(163, 162, 165), roof = rgb(27, 42, 53), fence = rgb(255, 176, 0) },
	{ name = "Factory", price = 15000, hp = 100, value = 12, height = 5, floor = rgb(91, 93, 105), wall = rgb(218, 133, 65), roof = rgb(99, 95, 98), fence = rgb(245, 205, 48) },
	{ name = "Military Base", price = 30000, hp = 160, value = 20, height = 3, floor = rgb(124, 156, 107), wall = rgb(39, 70, 45), roof = rgb(75, 74, 61), fence = rgb(163, 162, 165) },
	{ name = "Castle", price = 70000, hp = 250, value = 30, height = 6, floor = rgb(75, 151, 75), wall = rgb(163, 162, 165), roof = rgb(107, 50, 124), fence = rgb(99, 95, 98) },
	{ name = "Laboratory", price = 150000, hp = 400, value = 60, height = 5, floor = rgb(242, 243, 243), wall = rgb(248, 248, 248), roof = rgb(180, 128, 255), fence = rgb(4, 175, 236) },
	{ name = "Spaceport", price = 500000, hp = 650, value = 100, height = 8, floor = rgb(27, 42, 53), wall = rgb(242, 243, 243), roof = rgb(13, 105, 172), fence = rgb(255, 176, 0) },
}

Config.WINDOW = Color3.fromRGB(128, 187, 219) -- колір вікон

Config.BLOCK = 3 -- розмір одного блока
Config.ZONE_SIZE = 60 -- ширина й глибина локації
Config.ROAD_HALF = 15 -- половина ширини дороги
Config.RESPAWN = 30 -- через скільки секунд зламаний блок з'являється знову
Config.RANGE = 90 -- як далеко можна кинути
Config.WALK_SPEED = 16
Config.ROAD_SPEED = 55 -- швидкість на смузі

-- Бочки з ланцюговим вибухом
Config.BARREL_RADIUS = 12
Config.BARREL_VALUE = 10 -- у скільки разів бочка дорожча за блок

-- Бонус за повністю зруйновану будівлю: частка від вартості всіх її блоків
Config.BUILDING_BONUS = 0.5

-- Rebirth: скидає прогрес, але кожен ребьорт дає +1 до множника грошей (x2, x3, ...)
Config.REBIRTH_PRICE = 1000000 -- ціна першого, далі множиться на номер ребьорту

-- Подарунки за час у грі (за одну сесію). mult = скільки "базових нагород" дає подарунок.
Config.GIFTS = {
	{ minutes = 5, mult = 1 },
	{ minutes = 15, mult = 3 },
	{ minutes = 30, mult = 6 },
}

-- Щоденна нагорода: день 1 = 1 базова нагорода, день 2 = 2, ... до DAILY_MAX_STREAK
Config.DAILY_MAX_STREAK = 7

-- Квести: у гравця завжди 3 активних. goal = скільки треба, reward = скільки базових нагород дає.
-- Для "sell" goal множиться на базову нагороду (щоб масштабувалось із прогресом).
Config.QUESTS = {
	{ kind = "blocks", text = "Destroy %s blocks", goal = 150, reward = 3 },
	{ kind = "barrels", text = "Blow up %s TNT barrels", goal = 6, reward = 3 },
	{ kind = "buildings", text = "Destroy %s buildings", goal = 2, reward = 4 },
	{ kind = "sell", text = "Sell $%s", goal = 4, reward = 2 },
}

-- Бонус за друзів на сервері: +10% за кожного, максимум 5 друзів (+50%)
Config.FRIEND_BONUS = 0.1
Config.FRIEND_MAX = 5

-- Gamepass'и. Створи їх на create.roblox.com (твоя гра -> Monetization -> Passes) і встав ID.
Config.AUTO_SELL_PASS_ID = 0 -- гроші одразу на баланс, без сумки
Config.X2_PASS_ID = 0 -- x2 гроші назавжди

-- Developer Products (можна купувати багато разів). Monetization -> Developer Products.
-- Для "money" amount множиться на базову нагороду, тож пак завжди корисний.
Config.PRODUCTS = {
	{ id = 0, name = "Money Pack", kind = "money", amount = 100 },
	{ id = 0, name = "Huge Money Pack", kind = "money", amount = 1000 },
	{ id = 0, name = "Instant Rebirth", kind = "rebirth" },
}

-- Адміни (UserId), яким дозволені команди !money і т.д. Автор гри і Studio дозволені завжди.
Config.ADMINS = {}

-- Базова нагорода залежить від найдальшої відкритої локації
function Config.rewardBase(highestZone: number): number
	return Config.Zones[highestZone].value * 50
end

-- 12345 -> "12.3K", 2500000 -> "2.5M"
function Config.short(n: number): string
	if n >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

function Config.multiplier(rebirths: number): number
	return 1 + rebirths
end

function Config.rebirthPrice(rebirths: number): number
	return Config.REBIRTH_PRICE * (rebirths + 1)
end

return Config
