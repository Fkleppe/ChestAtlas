-- Run from the addon folder: luajit tests/test_zone_corrections.lua
-- Checks the chest points that the Classic data lists under a neighbour zone only.
local A = {}
local function load(name)
  assert(loadfile(name))("ChestAtlas", A)
end
load("Data.lua"); load("CoverageData.lua"); load("ClassicSpawnData.lua"); load("MapProjection.lua")

local before = {}
for area, nodes in pairs(A.Data.nodes) do before[area] = #nodes end

load("ZoneCorrections.lua")

local failures, checks = 0, 0
local function check(ok, text)
  checks = checks + 1
  if not ok then failures = failures + 1; io.write("FAIL: " .. text .. "\n") end
end
local function find(area, id)
  for index, n in ipairs(A.Data.nodes[area]) do if n.id == id then return n, index end end
end

-- Map edges of the true zones in Forever build 1.60.1.70938 (UiMapAssignment).
local EDGES = {
  [4] = { left = -1241.6666259766, right = -4591.6665039062, top = -10566.666015625, bottom = -12800 },
  [267] = { left = 1066.6666259766, right = -2133.3332519531, top = 400, bottom = -1733.3332519531 },
}
-- area, type, world x, world y, the point that the data already has under the neighbour zone.
local WANT = {
  { 4, 4149, -10963.1, -3677.28, 8, "legacy:8:207" },
  { 4, 4149, -10954.7, -3695.79, 8, "legacy:8:208" },
  { 267, 4096, -1314.03, -1267.86, 45, "legacy:45:188" },
}

local added = {}
for _, w in ipairs(WANT) do
  local area, typeID, worldX, worldY, fromArea, fromID = w[1], w[2], w[3], w[4], w[5], w[6]
  local e, hit = EDGES[area], nil
  for index, n in ipairs(A.Data.nodes[area]) do
    if index > before[area] and n.typeID == typeID then
      local wy = e.left + (e.right - e.left) * n.x
      local wx = e.top + (e.bottom - e.top) * n.y
      if math.abs(wx - worldX) < 1 and math.abs(wy - worldY) < 1 then hit = { node = n, index = index } end
    end
  end
  check(hit ~= nil, "no new point for " .. fromID .. " in area " .. area)
  if hit then
    added[area] = (added[area] or 0) + 1
    local n = hit.node
    check(n.id == "legacy:" .. area .. ":" .. hit.index, "the id must hold the list position: " .. tostring(n.id))
    check(n.alsoListedAs == fromID, "alsoListedAs must name the neighbour point")
    check(n.x > 0 and n.x < 1 and n.y > 0 and n.y < 1, "the point must be on the map")
    local source = find(fromArea, fromID)
    check(source ~= nil, "the neighbour point must stay: " .. fromID)
    if source then
      check(source.typeID == n.typeID and source.sourceGUID == n.sourceGUID, "type and source row must equal the neighbour point")
      check(math.abs(source.worldX - n.worldX) < 0.01 and math.abs(source.worldY - n.worldY) < 0.01, "world position must equal the neighbour point")
    end
  end
end

-- Only the named zones grow, by the expected count. No point is removed.
for area, count in pairs(before) do
  check(#A.Data.nodes[area] == count + (added[area] or 0), "unexpected point count in area " .. area)
end
check(added[4] == 2 and added[267] == 1, "expected two points in Blasted Lands and one in Hillsbrad Foothills")

-- A second call adds nothing.
A.ApplyZoneCorrections(A.Data)
check(#A.Data.nodes[4] == before[4] + 2 and #A.Data.nodes[267] == before[267] + 1, "a second call must not add points again")

io.write(string.format("%d checks, %d failures\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
