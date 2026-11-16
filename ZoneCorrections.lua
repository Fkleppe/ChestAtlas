-- Chest Atlas: chest points that the Classic data lists under a neighbour zone only.
--
-- Zone map rectangles overlap. The build tools put each database spawn in one zone. For the
-- three spawns below, the Forever terrain (area ID of the terrain chunk, build 1.60.1.70938)
-- puts the spawn in another zone than the data does. The pin was thus absent from the map of
-- the zone where the chest is. This file adds the same spawn to that zone. The neighbour
-- point stays, because it is at the correct place on the neighbour map.
--
-- x and y are Forever map fractions of the zone below. They come from the world position and
-- the map edges of UiMapAssignment. This file must load after MapProjection.lua.
local _, A = ...

A.ZoneCorrections = {
  build = "1.60.1.70938",
  nodes = {
    [4] = { -- Blasted Lands, at the border to Swamp of Sorrows
      { typeID = 4149, x = 0.727049, y = 0.177508, alsoListedAs = "legacy:8:207", referenceSource = "cm-classic",
        sourceGUID = 55524, worldMapID = 0, worldX = -10963.099609375, worldY = -3677.2800292969, worldZ = 27.790000915527 },
      { typeID = 4149, x = 0.732574, y = 0.173747, alsoListedAs = "legacy:8:208", referenceSource = "cm-classic",
        sourceGUID = 56704, worldMapID = 0, worldX = -10954.700195312, worldY = -3695.7900390625, worldZ = 27.309999465942 },
    },
    [267] = { -- Hillsbrad Foothills, Dun Garok
      { typeID = 4096, x = 0.729540, y = 0.803452, alsoListedAs = "legacy:45:188", referenceSource = "cm-classic",
        sourceGUID = 85830, worldMapID = 0, worldX = -1314.0300292969, worldY = -1267.8599853516, worldZ = 39.346199035645 },
    },
  },
}

local function copyWithID(node, id)
  local copy = {}
  for key, value in pairs(node) do copy[key] = value end
  copy.id = id
  return copy
end

-- Appends the points to their zones. The id holds the list position, as for all reference points.
-- A second call does nothing.
function A.ApplyZoneCorrections(data)
  if type(data) ~= "table" or type(data.nodes) ~= "table" or data.zoneCorrections then return false end
  for area, additions in pairs(A.ZoneCorrections.nodes) do
    local nodes = data.nodes[area]
    if nodes then
      local extended = {}
      for index, node in ipairs(nodes) do extended[index] = node end
      for _, node in ipairs(additions) do
        local index = #extended + 1
        extended[index] = copyWithID(node, "legacy:" .. area .. ":" .. index)
      end
      data.nodes[area] = extended
    end
  end
  data.zoneCorrections = A.ZoneCorrections.build
  return true
end

A.ApplyZoneCorrections(A.Data)
