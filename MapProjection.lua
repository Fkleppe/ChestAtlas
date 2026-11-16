-- Chest Atlas: move reference points from Classic 1.12 map fractions to Forever map fractions.
--
-- The reference data stores each point as a fraction of the Classic 1.12 zone map. Forever has
-- other map edges in five zones, so the same fraction is a different place there. This file
-- changes the points of those zones once, at load, before any other file reads them.
--
-- Edges are world coordinates: left and right are world y, top and bottom are world x.
--   classic: tools/sources/worldmaparea.csv (the edges that the build tools used).
--   forever: UiMapAssignment of the build below.
-- worldOnly: the pfQuest points of the zone already follow the Forever edges. Only points that
-- the build tools made from a world position (they have worldX) used the classic edges.
local _, A = ...

A.MapProjection = {
  build = "1.60.1.70938",
  zones = {
    [44] = { -- Redridge Mountains
      classic = { left = -1570.8333, right = -3741.6665, top = -8575, bottom = -10022.916 },
      forever = { left = -1681.25, right = -3852.083984375, top = -8575, bottom = -10022.916015625 },
    },
    [139] = { -- Eastern Plaguelands
      classic = { left = -2185.4165, right = -6056.25, top = 3799.9998, bottom = 1218.75 },
      forever = { left = -2256.25, right = -6558.333984375, top = 3691.6669921875, bottom = 825 },
    },
    [215] = { -- Mulgore
      classic = { left = 2047.9166, right = -3089.5833, top = -272.91666, bottom = -3697.9165 },
      forever = { left = 2479.1669921875, right = -3675, top = 266.666015625, bottom = -3835.416015625 },
    },
    [1377] = { -- Silithus
      classic = { left = 4641.6665, right = -2308.3333, top = -5800, bottom = -10433.333 },
      forever = { left = 2537.5, right = -945.833984375, top = -5958.333984375, bottom = -8281.25 },
      worldOnly = true,
    },
    [1519] = { -- Stormwind City
      classic = { left = 1380.9714, right = 36.70063, top = -8278.851, bottom = -9175.205 },
      forever = { left = 1722.9200439453, right = -14.58399963379, top = -7995.830078125, bottom = -9154.169921875 },
    },
  },
}

local function clamp(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

-- Returns the Forever fraction of a Classic fraction. Zones with equal edges return the input.
function A.ProjectPoint(area, x, y, hasWorldPosition)
  local zone = A.MapProjection.zones[area]
  if not zone or (zone.worldOnly and not hasWorldPosition) then return x, y end
  local c, f = zone.classic, zone.forever
  local worldY = c.left + (c.right - c.left) * x
  local worldX = c.top + (c.bottom - c.top) * y
  return clamp((worldY - f.left) / (f.right - f.left)), clamp((worldX - f.top) / (f.bottom - f.top))
end

local function projectNode(area, node)
  local x, y = A.ProjectPoint(area, node.x, node.y, node.worldX ~= nil)
  if x == node.x and y == node.y then return node end
  local copy = {}
  for key, value in pairs(node) do copy[key] = value end
  copy.classicX, copy.classicY, copy.x, copy.y = node.x, node.y, x, y
  return copy
end

-- Replaces the point lists of the changed zones. A second call does nothing.
function A.ApplyMapProjection(data)
  if type(data) ~= "table" or type(data.nodes) ~= "table" or data.projection then return false end
  for area in pairs(A.MapProjection.zones) do
    local nodes = data.nodes[area]
    if nodes then
      local projected = {}
      for index, node in ipairs(nodes) do projected[index] = projectNode(area, node) end
      data.nodes[area] = projected
    end
  end
  data.projection = A.MapProjection.build
  return true
end

A.ApplyMapProjection(A.Data)
