local _, A = ...
_G.ChestAtlas = A
A.version = "0.6.0"
A.filters = { source = "all", typeID = 0, minLevel = 1, maxLevel = 60, areaID = 0 }

local function finite(n)
  return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
function A.ValidPosition(mapID, x, y)
  return finite(mapID) and mapID > 0 and mapID == math.floor(mapID)
    and finite(x) and finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
end
function A.Init(saved)
  local db = type(saved) == "table" and saved or {}
  db.version = 1
  db.journals = type(db.journals) == "table" and db.journals or {}
  db.bindings = type(db.bindings) == "table" and db.bindings or {}
  A.db = db
  A.mapAreas = {}
  if A.InitSettings then A.InitSettings() end
  return db
end
function A.UseJournal(key)
  local journal = A.db.journals[key]
  if type(journal) ~= "table" then journal = { nextID = 1, nodes = {} }; A.db.journals[key] = journal end
  journal.nodes = type(journal.nodes) == "table" and journal.nodes or {}
  local nextID = tonumber(journal.nextID)
  journal.nextID = finite(nextID) and nextID >= 1 and math.floor(nextID) or 1
  for id in pairs(journal.nodes) do
    local num=type(id)=="string" and tonumber(id:match("^own:(%d+)$"))
    if num then journal.nextID=math.max(journal.nextID,num+1) end
  end
  A.journal, A.journalKey = journal, key
  journal.favorites=type(journal.favorites)=="table" and journal.favorites or {}
  journal.discovered=type(journal.discovered)=="table" and journal.discovered or {}
  journal.instances=type(journal.instances)=="table" and journal.instances or {}
  for id,d in pairs(journal.discovered) do
    if type(id)=="number" and type(d)=="table" then A.RegisterDiscovered(id,d.name,d.instance) else journal.discovered[id]=nil end
  end
end
-- Objects missing from both Classic databases are Forever discoveries. They become
-- ordinary journal types so the existing map, list, loot and backup code applies.
function A.IsNewObject(id)
  return type(id)=="number" and A.ClassicObjectIDs~=nil and not A.ClassicObjectIDs[id] and not A.Data.types[id]
end
function A.RegisterDiscovered(id, name, instance)
  if type(id)~="number" or id<=0 or id~=math.floor(id) then return nil end
  name=type(name)=="string" and name~="" and name:sub(1,80) or nil
  local d=A.journal.discovered[id] or {}
  d.name=d.name or name;d.instance=d.instance or instance
  A.journal.discovered[id]=d
  local t=A.Data.types[id]
  if not t then
    t={loot={},category="treasure",discovered=true,hint="Your discovery: this object is not in the Classic databases."}
    A.Data.types[id]=t
  end
  if t.discovered then t.name=d.name or ("Unrecorded object #"..id) end
  return t
end
-- Instances have no Forever dungeon maps and no player coordinates; keep a per-instance
-- log of looted chests and discoveries instead of map locations.
function A.RecordInstanceLoot(snapshot, now)
  local iid,id=snapshot and snapshot.instanceID,snapshot and snapshot.typeID
  if not iid or not id or snapshot.sourceRejected or not snapshot.sourceGUID then return nil end
  local listed=false
  for _,c in ipairs(A.Instances and A.Instances[iid] and A.Instances[iid].chests or {}) do listed=listed or c.typeID==id end
  local t=A.Data.types[id]
  if not listed and not (t and t.discovered) then return nil end
  local log=A.journal.instances[iid] or {};A.journal.instances[iid]=log
  local e=log[id] or {loots=0,contents={}};log[id]=e
  if e.lastKey==snapshot.key then return nil end
  e.lastKey=snapshot.key
  if e.lastGUID==snapshot.sourceGUID then return e,{same=true} end
  e.loots,e.last,e.lastGUID=e.loots+1,now,snapshot.sourceGUID
  for _,item in ipairs(snapshot.items or {}) do
    local c=e.contents[item.id] or {count=0,sightings=0}
    c.count,c.sightings=c.count+item.count,c.sightings+1;e.contents[item.id]=c
  end
  return e,{items=#(snapshot.items or {})}
end
local function normalize(s)
  return (s or ""):lower():gsub("^the ", ""):gsub("[%s%-']", "")
end
function A.ResolveArea(mapID, name)
  if A.mapAreas[mapID] then return A.mapAreas[mapID] end
  for area, boundMap in pairs(A.db.bindings) do
    if boundMap == mapID and (A.Zones or A.Data.zones)[area] then A.mapAreas[mapID] = area; return area end
  end
  for area, zone in pairs((A.Zones or A.Data.zones)) do
    local localized = A.LocalAreaName and A.LocalAreaName(area)
    if normalize(zone.name) == normalize(name) or (localized and normalize(localized) == normalize(name)) then A.mapAreas[mapID] = area; return area end
  end
end
function A.Bind(areaID, mapID)
  if not (A.Zones or A.Data.zones)[areaID] or not finite(mapID) or mapID <= 0 or mapID ~= math.floor(mapID) then return false end
  for area, bound in pairs(A.db.bindings) do if bound == mapID then A.db.bindings[area] = nil end end
  A.db.bindings[areaID] = mapID
  A.mapAreas = {}
  return true
end
function A.Passes(node, areaID,ignoreAreaFilter)
  local f = A.filters
  if not ignoreAreaFilter and f.areaID ~= 0 and areaID ~= f.areaID then return false end
  if f.typeID ~= 0 and node.typeID ~= f.typeID then return false end
  if f.source == "own" and not node.own then return false end
  if f.source == "legacy" and node.own then return false end
  if A.PassesExtra and not A.PassesExtra(node) then return false end
  local zone = areaID and (A.Zones or A.Data.zones)[areaID]
  -- Unknown level ranges remain visible, rather than pretending a low level is safe.
  if zone and (zone.maxLevel < f.minLevel or zone.minLevel > f.maxLevel) then return false end
  return true
end
function A.NodesForMap(mapID, name,ignoreAreaFilter)
  local area = A.ResolveArea(mapID, name)
  local result = {}
  for _, n in ipairs(area and A.Data.nodes[area] or {}) do
    if A.Passes(n, area,ignoreAreaFilter) then result[#result+1] = n end
  end
  for _, n in pairs(A.journal.nodes) do
    if n.mapID == mapID and A.Passes(n, area,ignoreAreaFilter) then result[#result+1] = n end
  end
  table.sort(result, function(a,b)
    if not not a.own ~= not not b.own then return not not a.own end
    if a.typeID ~= b.typeID then return a.typeID < b.typeID end
    return a.id < b.id
  end)
  if A.SortNodes then A.SortNodes(result,mapID) end
  return result, area
end
function A.TypeName(typeID)
  return A.Data.types[typeID] and A.Data.types[typeID].name or "Unknown chest type"
end
function A.ItemName(id)
  return A.Data.items[id] or ("Item " .. id)
end
function A.FindNearby(mapID, x, y, typeID)
  local nearest, distance = nil, 0.000004 -- 0.2% of a zone map; deliberately small.
  for _, node in pairs(A.journal.nodes) do
    if node.mapID == mapID and node.typeID == typeID then
      local d = (x-node.x)^2 + (y-node.y)^2
      if d <= distance then nearest, distance = node, d end
    end
  end
  return nearest
end
function A.AddObservation(mapID, x, y, typeID, now, build)
  typeID = tonumber(typeID) or 0
  if not A.ValidPosition(mapID,x,y) or (typeID ~= 0 and not A.Data.types[typeID]) then return nil, "Invalid position or chest type." end
  local n = A.FindNearby(mapID,x,y,typeID)
  if not n then
    local id = "own:" .. A.journal.nextID
    A.journal.nextID = A.journal.nextID + 1
    n = { id=id, mapID=mapID, x=x, y=y, typeID=typeID, own=true, contents={}, note="", build=build }
    A.journal.nodes[id] = n
  end
  n.lastSeen = now
  return n
end
function A.MarkLooted(n, now)
  if not n or not n.own then return false end
  n.lastLooted, n.lastSeen = now, now
  return true
end
function A.Ago(seconds)
  local m = math.floor(math.max(0,seconds or 0)/60)
  if m < 60 then return m .. " min" end
  if m < 1440 then return string.format("%d h %d min",math.floor(m/60),m%60) end
  return string.format("%d d %d h",math.floor(m/1440),math.floor(m%1440/60))
end
local function relootText(n)
  if not n.relootSeconds then return "" end
  return " Respawned within "..A.Ago(n.relootSeconds).." at least once (your loots; layer may differ)."
end
function A.Timer(n, now)
  if not n.lastLooted then return "No personal looting recorded." end
  local elapsed = math.max(0,now-n.lastLooted)
  local since = "Last looted: " .. A.Ago(elapsed) .. " ago" .. (n.loots and n.loots>1 and (" • "..n.loots.." loots") or "") .. "."
  if not n.estimate or n.estimate <= 0 then return since .. " Respawn unknown." .. relootText(n) end
  local remaining = n.estimate*60-elapsed
  if remaining > 0 then
    return since .. string.format(" Your estimate: about %d min remaining; layer unknown.",math.ceil(remaining/60)) .. relootText(n)
  end
  return since .. " Your estimate has elapsed. Availability unknown." .. relootText(n)
end
function A.RecordContents(n, snapshot, now)
  if not n or not n.own or not snapshot or now-snapshot.time > 90 or now < snapshot.time then return false,"The loot snapshot is older than 90 seconds." end
  if snapshot.sourceRejected then return false,"The loot source was a creature/player or multiple objects." end
  if not snapshot.items or #snapshot.items==0 then return false,"No items were captured from the loot window." end
  if n.mapID ~= snapshot.mapID or (n.x-snapshot.x)^2+(n.y-snapshot.y)^2 > 0.0001 then return false,"The loot window was too far from this location." end
  local generic=A.Data.types[n.typeID] and A.Data.types[n.typeID].generic
  local actual=snapshot.typeID and A.Data.types[snapshot.typeID]
  local resolvesGeneric=generic and actual and not actual.generic and actual.name==A.Data.types[n.typeID].name
  if snapshot.typeID and snapshot.typeID ~= n.typeID and n.typeID ~= 0 and not resolvesGeneric then return false,"The loot source has a different chest type." end
  if n.lastSnapshot == snapshot.key then return false,"This loot window is already recorded here." end
  for _, other in pairs(A.journal.nodes) do
    if other.lastSnapshot == snapshot.key then return false,"This loot window is already linked to another location." end
  end
  n.contents = n.contents or {}
  if resolvesGeneric then n.typeID=snapshot.typeID end
  for _, item in ipairs(snapshot.items) do
    local entry = n.contents[item.id] or { count=0, sightings=0 }
    entry.count = entry.count + item.count
    entry.sightings = entry.sightings + 1
    n.contents[item.id] = entry
  end
  n.lastSnapshot = snapshot.key
  return true
end

-- Automatic journal: a looted, known container object is linked to the nearest
-- same-family reference. This records evidence only; it never asserts a live spawn.
local autoSkip = { quest=true }
function A.FindReference(area, x, y, typeID)
  local t = A.Data.types[typeID]
  if not t then return nil end
  local best, bestD = nil, 0.0001 -- about 1% of a zone map, as for manual finds
  for _, ref in ipairs(area and A.Data.nodes[area] or {}) do
    local rt = A.Data.types[ref.typeID]
    if ref.typeID == typeID or (rt and rt.name == t.name) then
      local d = (x-ref.x)^2 + (y-ref.y)^2
      if d < bestD or (d == bestD and ref.typeID == typeID) then best, bestD = ref, d end
    end
  end
  return best
end
function A.AutoRecord(snapshot, area, now)
  if type(snapshot) ~= "table" or snapshot.sourceRejected or not snapshot.typeID or not snapshot.sourceGUID then return nil end
  local t = A.Data.types[snapshot.typeID]
  if not t or t.generic or autoSkip[t.category or "treasure"] then return nil end
  if not A.ValidPosition(snapshot.mapID, snapshot.x, snapshot.y) then return nil end
  for _, other in pairs(A.journal.nodes) do
    if other.autoKey == snapshot.key then return nil end
  end
  local ref = A.FindReference(area, snapshot.x, snapshot.y, snapshot.typeID)
  local n
  if ref then
    for _, own in pairs(A.journal.nodes) do
      if own.referenceID == ref.id and (own.typeID == snapshot.typeID or own.typeID == 0 or A.Data.types[own.typeID] and A.Data.types[own.typeID].name == t.name) then n = own; break end
    end
  end
  local isNew = false
  if not n then
    isNew = A.FindNearby(snapshot.mapID, snapshot.x, snapshot.y, snapshot.typeID) == nil
    n = A.AddObservation(snapshot.mapID, snapshot.x, snapshot.y, snapshot.typeID, now, A.build)
    if not n then return nil end
    if ref and not n.referenceID then n.referenceID, n.legacyRespawn = ref.id, ref.legacyRespawn end
  end
  n.autoKey, n.lastSeen = snapshot.key, now
  -- The same object GUID means the same spawn reopened, not a respawn.
  if n.lastGUID == snapshot.sourceGUID then return n, { same=true } end
  if n.typeID == 0 then n.typeID = snapshot.typeID end
  local reloot
  if n.lastLooted and now - n.lastLooted >= 60 then
    reloot = now - n.lastLooted
    n.relootSeconds = math.min(n.relootSeconds or reloot, reloot)
  end
  A.RecordContents(n, snapshot, now)
  A.MarkLooted(n, now)
  n.loots, n.lastGUID = (n.loots or 0) + 1, snapshot.sourceGUID
  return n, { new=isNew, reloot=reloot, ref=ref, items=#(snapshot.items or {}) }
end

-- Backup is an inert, versioned text format. Never execute imported Lua.
local function hex(s)
  return (s or ""):gsub(".", function(c) return string.format("%02x",string.byte(c)) end)
end
local function unhex(s)
  if #s % 2 ~= 0 or s:find("[^%da-f]") then return nil end
  return (s:gsub("..",function(c) return string.char(tonumber(c,16)) end))
end
function A.Export()
  local lines = { "CHESTATLAS1|" .. hex(A.journalKey) }
  -- Discoveries precede locations so imported finds can refer to them.
  local found = {}; for id in pairs(A.journal.discovered or {}) do found[#found+1]=id end; table.sort(found)
  for _,id in ipairs(found) do local d=A.journal.discovered[id];lines[#lines+1] = table.concat({"D",id,hex(d.name),d.instance or 0},"|") end
  for area,mapID in pairs(A.db.bindings) do lines[#lines+1] = "B|"..area.."|"..mapID end
  local ids = {}; for id in pairs(A.journal.nodes) do ids[#ids+1]=id end; table.sort(ids)
  for _,id in ipairs(ids) do
    local n = A.journal.nodes[id]
    lines[#lines+1] = table.concat({"N",id,n.mapID,string.format("%.8f",n.x),string.format("%.8f",n.y),n.typeID,n.lastSeen or 0,n.lastLooted or 0,n.estimate or 0,hex(n.note),hex(n.build),hex(n.referenceID),n.legacyRespawn or 0},"|")
    for item,e in pairs(n.contents or {}) do lines[#lines+1] = table.concat({"L",id,item,e.count,e.sightings},"|") end
    if n.loots or n.relootSeconds then lines[#lines+1] = table.concat({"R",id,n.loots or 0,n.relootSeconds or 0},"|") end
  end
  local favorites={}
  for id,value in pairs(A.journal.favorites or {}) do if value==true then favorites[#favorites+1]=id end end
  table.sort(favorites)
  for _,id in ipairs(favorites) do lines[#lines+1]="F|"..id end
  for iid,log in pairs(A.journal.instances or {}) do
    for id,e in pairs(log) do lines[#lines+1]=table.concat({"I",iid,id,e.loots or 0,e.last or 0},"|") end
  end
  return table.concat(lines,"\n")
end
local function split(line)
  local fields = {}; for field in (line.."|"):gmatch("(.-)|") do fields[#fields+1]=field end; return fields
end
function A.Import(text, now)
  if type(text) ~= "string" or #text>300000 then return false,"Backup is too large." end
  local nodes, bindings, boundMaps, favorites, nextID, count = {}, {}, {}, {}, 1, 0
  local discovered, instanceLog = {}, {}
  local header = true
  for line in text:gmatch("[^\r\n]+") do
    local p = split(line)
    if header then
      if #p~=2 or p[1] ~= "CHESTATLAS1" or unhex(p[2] or "") ~= A.journalKey then return false,"Invalid format or a different region/realm." end
      header = false
    elseif p[1] == "N" then
      local id,mapID,x,y,t,seen,looted,estimate = p[2],tonumber(p[3]),tonumber(p[4]),tonumber(p[5]),tonumber(p[6]),tonumber(p[7]),tonumber(p[8]),tonumber(p[9])
      local num = id and tonumber(id:match("^own:(%d+)$"))
      local note,build = unhex(p[10] or ""),unhex(p[11] or "")
      if (#p~=11 and #p~=13) or not num or num>100000000 or nodes[id] or not A.ValidPosition(mapID,x,y) or not finite(t) or (t~=0 and not A.Data.types[t] and not discovered[t]) or not finite(seen) or not finite(looted) or seen<0 or looted<0 or seen>now+60 or looted>now+60 or not finite(estimate) or estimate<0 or estimate>10080 or not note or #note>2000 or not build or #build>100 then return false,"Invalid chest in backup." end
      local referenceID,legacyRespawn
      if #p==13 then
        referenceID=unhex(p[12]);local timer=tonumber(p[13])
        if not referenceID or #referenceID>100 or not finite(timer) then return false,"Invalid reference in backup." end
        if referenceID~="" then
          local area,index=referenceID:match("^legacy:(%d+):(%d+)$")
          local ref=A.Data.nodes[tonumber(area)] and A.Data.nodes[tonumber(area)][tonumber(index)]
          if not ref or ref.id~=referenceID or timer~=(ref.legacyRespawn or 0) then return false,"Unknown reference in backup." end
          legacyRespawn=ref.legacyRespawn
        elseif timer~=0 then return false,"The timer has no historical reference." end
      end
      count=count+1; if count>2000 then return false,"Too many locations." end
      nodes[id] = {id=id,mapID=mapID,x=x,y=y,typeID=t,lastSeen=seen>0 and seen or nil,lastLooted=looted>0 and looted or nil,estimate=estimate>0 and estimate or nil,note=note,build=build,contents={},own=true,referenceID=referenceID~="" and referenceID or nil,legacyRespawn=legacyRespawn}
      nextID=math.max(nextID,num+1)
    elseif p[1] == "L" then
      local n,item,amount,sightings = nodes[p[2]],tonumber(p[3]),tonumber(p[4]),tonumber(p[5])
      if #p~=5 or not n or not finite(item) or item<=0 or item~=math.floor(item) or n.contents[item] or not finite(amount) or amount<1 or amount>1000000 or amount~=math.floor(amount) or not finite(sightings) or sightings<1 or sightings>1000000 or sightings~=math.floor(sightings) then return false,"Invalid loot in backup." end
      n.contents[item]={count=amount,sightings=sightings}
    elseif p[1] == "D" then
      local id,name,iid = tonumber(p[2]),unhex(p[3] or ""),tonumber(p[4])
      if #p~=4 or not finite(id) or id<1 or id~=math.floor(id) or discovered[id] or not name or #name>80 or not finite(iid) or iid<0 or iid~=math.floor(iid) then return false,"Invalid discovery in backup." end
      discovered[id]={name=name~="" and name or nil,instance=iid>0 and iid or nil}
    elseif p[1] == "I" then
      local iid,id,loots,last = tonumber(p[2]),tonumber(p[3]),tonumber(p[4]),tonumber(p[5])
      if #p~=5 or not finite(iid) or iid<1 or iid~=math.floor(iid) or not finite(id) or id<1 or id~=math.floor(id) or not finite(loots) or loots<0 or loots>1000000 or loots~=math.floor(loots) or not finite(last) or last<0 or last>now+60 then return false,"Invalid instance log in backup." end
      instanceLog[iid]=instanceLog[iid] or {}
      if instanceLog[iid][id] then return false,"Duplicate instance log in backup." end
      instanceLog[iid][id]={loots=loots,last=last>0 and last or nil}
    elseif p[1] == "R" then
      local n,loots,reloot = nodes[p[2]],tonumber(p[3]),tonumber(p[4])
      if #p~=4 or not n or n.loots or not finite(loots) or loots<0 or loots>1000000 or loots~=math.floor(loots) or not finite(reloot) or reloot<0 or reloot>31536000 then return false,"Invalid loot history in backup." end
      n.loots=loots>0 and loots or nil;n.relootSeconds=reloot>0 and reloot or nil
    elseif p[1] == "B" then
      local area,mapID=tonumber(p[2]),tonumber(p[3])
      if #p~=3 or not (A.Zones or A.Data.zones)[area] or bindings[area] or boundMaps[mapID] or not finite(mapID) or mapID<1 or mapID~=math.floor(mapID) then return false,"Invalid map binding." end
      bindings[area]=mapID
      boundMaps[mapID]=true
    elseif p[1] == "F" then
      if #p~=2 or not p[2] or favorites[p[2]] then return false,"Invalid favorite in backup." end
      favorites[p[2]]=true
    else return false,"Unknown row in backup." end
  end
  if header then return false,"Empty backup." end
  for id in pairs(favorites) do
    local area,index=id:match("^legacy:(%d+):(%d+)$")
    local ref=A.Data.nodes[tonumber(area)] and A.Data.nodes[tonumber(area)][tonumber(index)]
    -- Preserve inert favorites from the removed NPC module in old backups.
    -- They do not load NPC data or produce markers/routes.
    local oldArea=id:match("^rare:(%d+):%d+:%d+:%d+$")
    local rareRef=oldArea and #id<=100 and A.Data.zones[tonumber(oldArea)]~=nil
    if not rareRef and not (ref and ref.id==id) and not nodes[id] and not A.journal.nodes[id] then return false,"The favorite refers to an unknown location." end
  end
  -- Validate the entire document before touching saved state; merge, never wipe a journal.
  for id,d in pairs(discovered) do A.RegisterDiscovered(id,d.name,d.instance) end
  for iid,log in pairs(instanceLog) do
    local target=A.journal.instances[iid] or {};A.journal.instances[iid]=target
    for id,e in pairs(log) do
      local old=target[id] or {loots=0,contents={}};target[id]=old
      local last=math.max(old.last or 0,e.last or 0)
      old.loots,old.last=math.max(old.loots or 0,e.loots),last>0 and last or nil
    end
  end
  for id,n in pairs(nodes) do A.journal.nodes[id]=n end
  for id in pairs(favorites) do A.journal.favorites[id]=true end
  A.journal.nextID=math.max(A.journal.nextID,nextID)
  for area,mapID in pairs(bindings) do A.Bind(area,mapID) end
  return true,count
end
