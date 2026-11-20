-- Особливі будівлі для кожної локації, зібрані з блоків-цеглинок.
-- Кожна функція отримує put(x, y, z, color) і колір локації.
-- x/z: клітинки відносно центру (від -3 до 3), y: ряд від землі (0 = нижній).
local Landmarks = {}

type Put = (x: number, y: number, z: number, color: Color3) -> ()

local WINDOW = Color3.fromRGB(128, 187, 219)
local FIRE = Color3.fromRGB(255, 120, 0)

-- суцільний прямокутник
local function fill(put: Put, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3)
	for y = y0, y1 do
		for x = x0, x1 do
			for z = z0, z1 do
				put(x, y, z, color)
			end
		end
	end
end

-- тільки стіни (порожній всередині)
local function shell(put: Put, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3)
	for y = y0, y1 do
		for x = x0, x1 do
			for z = z0, z1 do
				if x == x0 or x == x1 or z == z0 or z == z1 then
					put(x, y, z, color)
				end
			end
		end
	end
end

-- 1. Село: млин з лопатями
Landmarks[1] = function(put: Put, z)
	shell(put, -1, 1, 0, 4, -1, 1, z.wall)
	fill(put, -1, 1, 5, 5, -1, 1, z.roof)
	put(0, 6, 0, z.roof)
	for i = -2, 2 do
		put(0, 4 + i, -2, z.fence) -- вертикальна лопать
		if i ~= 0 then
			put(i, 4, -2, z.fence) -- горизонтальна лопать
		end
	end
end

-- 2. Ферма: силос з куполом
Landmarks[2] = function(put: Put, z)
	shell(put, -1, 1, 0, 6, -1, 1, z.wall)
	for _, p in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		put(p[1], 7, p[2], z.roof)
	end
	put(0, 8, 0, z.roof)
	fill(put, 2, 2, 0, 0, -1, 1, Color3.fromRGB(245, 205, 48)) -- сіно
end

-- 3. Ранчо: водонапірна вежа
Landmarks[3] = function(put: Put, z)
	for _, p in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		fill(put, p[1], p[1], 0, 2, p[2], p[2], z.fence)
	end
	shell(put, -2, 2, 3, 5, -2, 2, z.wall)
	fill(put, -2, 2, 6, 6, -2, 2, z.roof)
end

-- 4. Передмістя: будинок зі скатним дахом
Landmarks[4] = function(put: Put, z)
	shell(put, -2, 2, 0, 2, -2, 1, z.wall)
	for _, x in { -1, 1 } do
		put(x, 1, -2, WINDOW)
		put(x, 1, 1, WINDOW)
	end
	fill(put, -2, 2, 3, 3, -2, 1, z.roof)
	fill(put, -1, 1, 4, 4, -2, 1, z.roof)
	fill(put, 0, 0, 5, 5, -2, 1, z.roof)
	fill(put, 1, 1, 5, 6, 0, 0, Color3.fromRGB(150, 60, 50)) -- комин
end

-- 5. Місто: хмарочос з вікнами і антеною
Landmarks[5] = function(put: Put, z)
	for y = 0, 13 do
		for x = -2, 2 do
			for zz = -2, 2 do
				if x == -2 or x == 2 or zz == -2 or zz == 2 then
					local corner = math.abs(x) == 2 and math.abs(zz) == 2
					put(x, y, zz, if y % 2 == 1 and not corner then WINDOW else z.wall)
				end
			end
		end
	end
	fill(put, -2, 2, 14, 14, -2, 2, z.roof)
	fill(put, 0, 0, 15, 17, 0, 0, z.fence)
end

-- 6. Завод: цех з двома трубами
Landmarks[6] = function(put: Put, z)
	shell(put, -2, 2, 0, 3, -2, 2, z.wall)
	fill(put, -2, 2, 4, 4, -2, 2, z.roof)
	for y = 5, 10 do
		put(-1, y, -1, if y % 3 == 0 then z.fence else z.roof)
	end
	for y = 5, 8 do
		put(1, y, 1, if y % 3 == 0 then z.fence else z.roof)
	end
end

-- 7. Військова база: танк
Landmarks[7] = function(put: Put, z)
	fill(put, -2, 2, 0, 0, -2, 2, z.roof) -- гусениці/корпус
	fill(put, -2, 2, 1, 1, -1, 1, z.wall)
	fill(put, -1, 1, 2, 2, -1, 1, z.wall) -- башта
	fill(put, 2, 3, 2, 2, 0, 0, z.roof) -- дуло
end

-- 8. Замок: вежа з зубцями і прапором
Landmarks[8] = function(put: Put, z)
	shell(put, -2, 2, 0, 5, -2, 2, z.wall)
	put(0, 3, -2, WINDOW)
	put(0, 3, 2, WINDOW)
	fill(put, -2, 2, 6, 6, -2, 2, z.wall)
	for x = -2, 2 do
		for zz = -2, 2 do
			local edge = x == -2 or x == 2 or zz == -2 or zz == 2
			if edge and (x + zz) % 2 == 0 then
				put(x, 7, zz, z.wall)
			end
		end
	end
	fill(put, 0, 0, 7, 9, 0, 0, z.fence)
	fill(put, 1, 1, 8, 9, 0, 0, z.roof)
end

-- 9. Лабораторія: купол
Landmarks[9] = function(put: Put, z)
	shell(put, -2, 2, 0, 1, -2, 2, z.wall)
	for x = -2, 2 do
		for zz = -2, 2 do
			if not (math.abs(x) == 2 and math.abs(zz) == 2) then
				put(x, 2, zz, z.roof)
			end
		end
	end
	fill(put, -1, 1, 3, 3, -1, 1, z.roof)
	put(0, 4, 0, z.roof)
	fill(put, 0, 0, 5, 6, 0, 0, z.fence)
end

-- 10. Космодром: ракета
Landmarks[10] = function(put: Put, z)
	put(0, 0, 0, FIRE)
	shell(put, -1, 1, 1, 10, -1, 1, z.wall)
	put(0, 8, -1, WINDOW)
	put(0, 8, 1, WINDOW)
	for _, p in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		put(p[1], 11, p[2], z.roof)
	end
	put(0, 12, 0, z.roof)
	for _, p in { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } } do
		fill(put, p[1], p[1], 0, 2, p[2], p[2], z.roof) -- стабілізатори
	end
end

return Landmarks
