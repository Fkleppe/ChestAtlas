-- Run from the addon folder: luajit tests/test_map_projection.lua
-- Checks that reference points move from Classic 1.12 map fractions to Forever map fractions.
local A = {}
local function load(name)
  assert(loadfile(name))("ChestAtlas", A)
end
load("Data.lua"); load("CoverageData.lua"); load("ClassicSpawnData.lua")

local before = {}
for area, nodes in pairs(A.Data.nodes) do
  before[area] = {}
  for i, n in ipairs(nodes) do before[area][i] = { id = n.id, x = n.x, y = n.y, worldX = n.worldX } end
end

load("MapProjection.lua")

local failures, checks = 0, 0
local function check(ok, text)
  checks = checks + 1
  if not ok then failures = failures + 1; io.write("FAIL: " .. text .. "\n") end
end
local function find(area, id)
  for _, n in ipairs(A.Data.nodes[area]) do if n.id == id then return n end end
end
local function near(n, x, y, limit)
  return n and math.abs(n.x - x) <= limit and math.abs(n.y - y) <= limit
end

-- 1. Three chests that the player looted in Forever, build 1.60.1.70938 (positions from the addon journal).
local LIMIT = 0.003
check(near(find(139, "legacy:139:13"), 0.5928214, 0.3937396, LIMIT), "Eastwall Tower chest must be at 59.3, 39.4")
check(near(find(139, "legacy:139:3"), 0.3276787, 0.7938954, LIMIT), "Darrowshire chest must be at 32.8, 79.4")
check(near(find(139, "legacy:139:4"), 0.3394535, 0.6426028, LIMIT), "Crown Guard Tower chest must be at 33.9, 64.3")

-- 2. The Classic position stays available.
local eastwall = find(139, "legacy:139:13")
check(eastwall and near({ x = eastwall.classicX, y = eastwall.classicY }, 0.677, 0.480, 0.0006), "classicX and classicY must hold the 1.12 fractions")

-- 3. Order, ids and counts do not change. Zones with equal bounds do not change at all.
local changed = { [44] = true, [139] = true, [215] = true, [1377] = true, [1519] = true }
for area, old in pairs(before) do
  local now = A.Data.nodes[area]
  check(#now == #old, "node count changed in area " .. area)
  local same, ids, inside = true, true, true
  for i, o in ipairs(old) do
    local n = now[i]
    ids = ids and n.id == o.id
    same = same and n.x == o.x and n.y == o.y
    inside = inside and n.x >= 0 and n.x <= 1 and n.y >= 0 and n.y <= 1
  end
  check(ids, "node order changed in area " .. area)
  check(inside, "a node left the map in area " .. area)
  if changed[area] then check(not same, "area " .. area .. " must move") else check(same, "area " .. area .. " must not move") end
end

-- 4. Silithus: the pfQuest fractions already follow the Forever map. Only database points move.
local movedWorld, movedOther, worldCount = 0, 0, 0
for i, o in ipairs(before[1377]) do
  local n = A.Data.nodes[1377][i]
  local moved = n.x ~= o.x or n.y ~= o.y
  if o.worldX then worldCount = worldCount + 1; if moved then movedWorld = movedWorld + 1 end
  elseif moved then movedOther = movedOther + 1 end
end
check(worldCount > 0 and movedWorld == worldCount, "every Silithus database point must move")
check(movedOther == 0, "Silithus pfQuest points must not move")

-- 5. A database point lands on its own world position on the Forever map.
local z = A.MapProjection.zones[1377].forever
for _, n in ipairs(A.Data.nodes[1377]) do
  if n.worldX then
    local wy = z.left + (z.right - z.left) * n.x
    local wx = z.top + (z.bottom - z.top) * n.y
    check(math.abs(wx - n.worldX) < 1 and math.abs(wy - n.worldY) < 1, "Silithus point " .. n.id .. " is off its world position")
  end
end

-- 6. A second call does not move the points again.
local x1 = find(139, "legacy:139:13").x
A.ApplyMapProjection(A.Data)
check(find(139, "legacy:139:13").x == x1, "a second call must not move the points again")

-- 7. The point function works alone and leaves unknown zones as they are.
local px, py = A.ProjectPoint(47, 0.413, 0.593)
check(px == 0.413 and py == 0.593, "a zone without new bounds must return the same point")

io.write(string.format("%d checks, %d failures\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
