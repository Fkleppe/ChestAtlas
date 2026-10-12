local _,A=...
-- Chest loot references only. RareScanner owns all rare NPC tracking.
A.Zones=A.Data.zones
function A.LootSource(n,source)
  if n and A.IsGenericType(n.typeID) then
    local pool=A.GenericLootPool(n,source)
    return pool and pool.source or "pf"
  end
  if n and not n.rare and source~="pf" and A.ClassicLoot and A.ClassicLoot[n.typeID] and A.ClassicLoot[n.typeID].available then return "cm" end
  return "pf"
end
function A.LootSourceLabel(n,source)
  if n and A.IsGenericType(n.typeID) then
    local pool=A.GenericLootPool(n,source)
    return pool and #pool.loot>0 and ((pool.source=="cm" and "Classic" or "Vanilla").." • possible family loot; exact variant unknown") or "No historical family loot available"
  end
  return A.LootSource(n,source)=="cm" and "Classic • full table" or "Vanilla • pfQuest list"
end
function A.ReferenceLoot(n,source)
  if n and A.IsGenericType(n.typeID) then
    local pool=A.GenericLootPool(n,source)
    return pool and pool.loot or {}
  end
  if A.LootSource(n,source)=="cm" then return A.ClassicLoot[n.typeID].loot end
  local t=n and A.Data.types[n.typeID]
  return t and t.loot or {}
end
function A.DropChance(n,itemID,source)
  if n and A.IsGenericType(n.typeID) then return nil,"Exact object variant unknown; family loot is a list of possibilities, not one chest's drop table." end
  if not n or n.rare or A.LootSource(n,source)~="cm" then return nil,"Per-chest probability unavailable for this source." end
  local t=A.ClassicLoot[n.typeID]
  return t.chances[itemID],t.uncertainty[itemID] or (not t.chances[itemID] and "Item has no probability in this source." or nil)
end
function A.CashRange(n)
  if not n or n.rare then return nil end
  local t=A.ClassicLoot and A.ClassicLoot[n.typeID]
  return t and t.cash
end
-- GatherMate coordinates identify a family rather than a gameobject ID. Show
-- candidate loot without assigning an exact variant, probabilities or currency.
-- Prefer variants actually represented in the same historical outdoor zone.
local familyIndex,poolCache
local function nodeArea(n)
  local id=n.referenceID or n.id
  local area=type(id)=="string" and tonumber(id:match("^legacy:(%d+):"))
  if area then return area end
  if n.areaID then return n.areaID end
  if n.mapID then
    local info=A.MapInfo and A.MapInfo(n.mapID)
    return A.ResolveArea(n.mapID,info and info.name)
  end
end
function A.LootContextKey(n)
  return tostring(n and n.typeID)..(n and A.IsGenericType(n.typeID) and (":"..tostring(nodeArea(n) or "global")) or "")
end
function A.GenericLootPool(n,source)
  local family=n and A.Data.types[n.typeID]
  if not family or not family.generic then return end
  if not familyIndex then
    familyIndex={};poolCache={}
    for tid,t in pairs(A.Data.types) do
      if not t.generic and t.category~="instance" and not t.discovered then
        local entry=familyIndex[t.name] or {all={},areas={}};familyIndex[t.name]=entry
        entry.all[tid]=true
      end
    end
    for area,nodes in pairs(A.Data.nodes) do
      for _,p in ipairs(nodes) do
        local t=A.Data.types[p.typeID]
        local entry=t and not t.generic and familyIndex[t.name]
        if entry then
          entry.areas[area]=entry.areas[area] or {};entry.areas[area][p.typeID]=true
        end
      end
    end
  end
  local key=A.LootContextKey(n)..":"..(source=="pf" and "pf" or "legacy")
  if poolCache[key] then return poolCache[key] end
  local entry=familyIndex[family.name];local area=nodeArea(n)
  local candidates=entry and (entry.areas[area] or entry.all) or {}
  local pool={loot={},variants={},source="pf",areaID=area,scope=entry and entry.areas[area] and "zone" or "family"}
  local seen={}
  for tid in pairs(candidates) do
    local classic=source~="pf" and A.ClassicLoot and A.ClassicLoot[tid]
    local useClassic=classic and classic.available
    local ids=useClassic and classic.loot or A.Data.types[tid].loot or {}
    if #ids>0 then
      pool.variants[#pool.variants+1]=tid
      if useClassic then pool.source="cm" end
      for _,id in ipairs(ids) do if not seen[id] then seen[id]=true;pool.loot[#pool.loot+1]=id end end
    end
  end
  table.sort(pool.loot);table.sort(pool.variants);poolCache[key]=pool
  return pool
end
function A.GenericLootDetails(n,source)
  local pool=A.GenericLootPool(n,source)
  if not pool or #pool.loot==0 then return "No historical loot available for this family." end
  local ids={};for _,id in ipairs(pool.variants) do ids[#ids+1]="#"..id end
  return "Possible loot from "..#ids.." historical "..(pool.scope=="zone" and "variants in this zone" or "family variants; zone match unavailable")..".\n"..
    "Candidate objects: "..table.concat(ids,", ")..".\nNot every listed item belongs to every variant. No per-chest probability or coin range is assigned."
end

local passesExtra=A.PassesExtra
function A.PassesExtra(n)
  if n.rare or n.typeID<0 then return false end
  return passesExtra(n)
end
function A.ApplyLocationIcon(texture)A.ApplyChestIcon(texture)end
function A.SelectType(typeID)
  if typeID<0 then A.RareScannerCommand("explorer");return end
  if typeID~=0 and not A.Data.types[typeID] then return end
  A.filters.typeID=typeID;A.selected=nil
  if A.HideMapDetail then A.HideMapDetail()end
  A.Refresh()
end
function A.SetCategory(category)
  if category=="rares" then A.RareScannerCommand("explorer");return end
  A.settings.category="chests";A.filters.typeID=math.max(0,A.filters.typeID);A.selected=nil
  if A.HideMapDetail then A.HideMapDetail()end
  A.Refresh()
end
function A.NextCategory()A.RareScannerCommand("explorer")end
function A.CategoryLabel()return "Chests"end
