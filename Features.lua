local _,A=...
A.iconPath="Interface\\WorldMap\\TreasureChest_64"
A.sparklePath="Interface\\AddOns\\ChestAtlas\\Media\\Sparkle.tga"
A.iconAtlas="VignetteLoot"
A.arrowPath="Interface\\AddOns\\ChestAtlas\\Media\\Arrow.tga"
local defaults={showPins=true,minimap=true,focus=false,keepPlayer=true,labels=false,cluster=false,iconSize=26,sort="distance",category="both",lootSort="valueDesc",autoJournal=true}
function A.WorldMapIconSize()return A.settings.iconSize*0.5 end
function A.IsGenericType(typeID)
  return A.Data.types[typeID] and A.Data.types[typeID].generic==true
end
local containerLabels={treasure="Treasure chests",supplies="Supplies / clams",lockpicking="Lockpicking",quest="Quest / special",event="Event / key treasure",collectibles="Collectibles",instance="Dungeon / raid chests",all="All containers"}
function A.ContainerCategory(typeID)
  return A.Data.types[typeID] and A.Data.types[typeID].category or "treasure"
end
function A.ContainerLabel(category)return containerLabels[category] or containerLabels.treasure end
function A.ContainerHint(typeID)return A.Data.types[typeID] and A.Data.types[typeID].hint end
function A.ContainerEntries()
  local result={}
  for _,category in ipairs({"treasure","supplies","lockpicking","event","quest","collectibles","all"})do
    result[#result+1]={value=category,text=A.ContainerLabel(category)}
  end
  return result
end
function A.SetContainerCategory(category)
  if not containerLabels[category]then return end
  A.filters.containers=category;A.filters.typeID=0;A.selected=nil;A.Refresh()
end
function A.TypeDisplay(typeID)
  return A.TypeName(typeID)..(A.IsGenericType(typeID) and " • variant unknown" or typeID~=0 and (" #"..math.abs(typeID)) or "")
end
function A.LocationSource(n)
  if n.own then return A.Data.types[n.typeID] and A.Data.types[n.typeID].discovered and "Your discovery • not in Classic data" or n.loots and "Your find (looted)" or "Your find (manual)" end
  if n.referenceSource=="wowhead-classic" then return "Classic Wowhead reference" end
  if n.referenceSource=="vm-classic" then return "VMaNGOS Classic reference" end
  if n.referenceSource=="cm-classic" then return "CMaNGOS Classic reference" end
  return "Vanilla reference"
end
-- Personal evidence never means a chest is currently spawned. Resolve linked
-- observations without replacing the historical coordinate or loot variant.
function A.Observation(n)
  if not n then return end
  if n.own then return n end
  local latest
  for _,own in pairs(A.journal and A.journal.nodes or {}) do
    if own.referenceID==n.id and (not latest or (own.lastSeen or 0)>(latest.lastSeen or 0)) then latest=own end
  end
  return latest
end
function A.LocationStatus(n)
  local own=A.Observation(n)
  if own and own.lastLooted then
    return "looted","Looted by you • "..A.Ago(A.Now()-own.lastLooted).." ago",{0.93,0.72,0.38}
  elseif own then
    return "seen","Seen by you • availability unknown",{0.39,0.85,0.69}
  end
  return "reference","Historical location • not observed by you",{0.64,0.72,0.80}
end
function A.LocationStatusText(n)local _,text=A.LocationStatus(n);return text end
function A.DistanceText(n,mapID)
  local map,x,y=A.PlayerPosition()
  if not map then return "Distance unavailable" end
  if map~=(n.mapID or mapID) then return "In another zone" end
  local w,h
  if C_Map then w,h=A.Safe(C_Map.GetMapWorldSize,map) end
  if type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return "Distance unavailable" end
  return string.format("%.0f m • straight line",math.sqrt(((n.x-x)*w)^2+((n.y-y)*h)^2)*0.9144)
end
function A.ApplyChestIcon(texture)
  if C_Texture and A.Safe(C_Texture.GetAtlasInfo,A.iconAtlas) then
    texture:SetAtlas(A.iconAtlas,false)
  else
    local ok=texture:SetTexture(A.iconPath)
    if ok==false then texture:SetTexture("Interface\\Icons\\INV_Misc_TreasureChest01a") end
    texture:SetTexCoord(0,1,0,1)
  end
end
function A.InitSettings()
  A.db.settings=type(A.db.settings)=="table" and A.db.settings or {}
  A.settings=A.db.settings
  for k,v in pairs(defaults) do if type(A.settings[k])~=type(v) then A.settings[k]=v end end
  if A.settings.individualSpawnsVersion~=1 then
    A.settings.cluster=false
    A.settings.individualSpawnsVersion=1
  end
  if A.settings.iconSize~=20 and A.settings.iconSize~=26 and A.settings.iconSize~=32 then A.settings.iconSize=26 end
  if A.settings.sort~="distance" and A.settings.sort~="type" then A.settings.sort="distance" end
  if A.settings.lootSort~="valueDesc" and A.settings.lootSort~="valueAsc" and A.settings.lootSort~="chanceDesc" and A.settings.lootSort~="chanceAsc"then A.settings.lootSort="valueDesc"end
  A.settings.category="chests"
  local f=type(A.db.filters)=="table" and A.db.filters or {}
  A.filters={source=(f.source=="own" or f.source=="legacy") and f.source or "all",
    typeID=A.Data.types[f.typeID] and f.typeID or 0,
    areaID=(A.Zones or A.Data.zones)[f.areaID] and f.areaID or 0,minLevel=1,maxLevel=60,
    query=type(f.query)=="string" and f.query:sub(1,80) or "",favoritesOnly=f.favoritesOnly==true,
    containers=containerLabels[f.containers] and f.containers or "treasure"}
  if type(f.minLevel)=="number" and type(f.maxLevel)=="number" and f.minLevel>=1 and f.maxLevel<=60 and f.minLevel<=f.maxLevel then
    A.filters.minLevel,A.filters.maxLevel=f.minLevel,f.maxLevel
  end
  A.db.filters=A.filters
end
function A.FavoriteKey(n)return n.referenceID or n.id end
function A.IsFavorite(n)return A.journal and A.journal.favorites and A.journal.favorites[A.FavoriteKey(n)]==true end
function A.ToggleFavorite(n)
  if not n then return end
  local key=A.FavoriteKey(n)
  A.journal.favorites[key]=not A.IsFavorite(n) or nil
  A.Refresh()
end
local matchCache,previousQuery={},nil
function A.PassesExtra(n)
  local scope=A.filters.containers or "treasure"
  if not n.rare and A.filters.typeID==0 and scope~="all" and A.ContainerCategory(n.typeID)~=scope then return false end
  if A.filters.favoritesOnly and not A.IsFavorite(n) then return false end
  local q=(A.filters.query or ""):lower()
  if q=="" then return true end
  if q~=previousQuery then matchCache={};previousQuery=q end
  local key=A.LootContextKey and A.LootContextKey(n) or n.typeID
  if matchCache[key]==nil then
    local match=A.TypeName(n.typeID):lower():find(q,1,true)~=nil or tostring(n.typeID)==q or (n.npcID and tostring(n.npcID)==q)
    for _,id in ipairs(A.ReferenceLoot and A.ReferenceLoot(n) or (A.Data.types[n.typeID] and A.Data.types[n.typeID].loot or {})) do
      if tostring(id)==q or A.ItemName(id):lower():find(q,1,true) then match=true;break end
    end
    matchCache[key]=match
  end
  if matchCache[key] then return true end
  if (n.note or ""):lower():find(q,1,true) then return true end
  for id in pairs(n.contents or {}) do if tostring(id)==q or A.ItemName(id):lower():find(q,1,true) then return true end end
  return false
end
function A.SortNodes(nodes,mapID)
  local playerMap,x,y
  if A.PlayerPosition then playerMap,x,y=A.PlayerPosition() end
  local distance=A.settings and A.settings.sort=="distance" and playerMap==mapID and x and y
  table.sort(nodes,function(a,b)
    if distance then
      local da,db=(a.x-x)^2+(a.y-y)^2,(b.x-x)^2+(b.y-y)^2
      if da~=db then return da<db end
    end
    if a.typeID~=b.typeID then return A.TypeName(a.typeID)<A.TypeName(b.typeID) end
    return a.id<b.id
  end)
end
-- Group only on screen: exact coordinates, loot variants and journal nodes stay intact.
function A.GroupNodes(nodes,width,height,radius)
  local groups={}
  for _,n in ipairs(nodes) do
    local group
    for _,g in ipairs(groups) do
      if not not n.rare==not not g.nodes[1].rare and ((n.x-g.x)*width)^2+((n.y-g.y)*height)^2<radius^2 then group=g;break end
    end
    if not group then group={x=n.x,y=n.y,nodes={},own=false};groups[#groups+1]=group end
    group.nodes[#group.nodes+1]=n;group.own=group.own or n.own
  end
  return groups
end
function A.ResetFilters()
  local f=A.filters
  f.source,f.typeID,f.areaID,f.minLevel,f.maxLevel,f.query,f.favoritesOnly,f.containers="all",0,0,1,60,"",false,"treasure"
  A.selected=nil;A.Refresh()
end
function A.ItemDetails(id)
  local name,link,quality,level,required,class,subclass,stack,equip,icon,price
  local getter=C_Item and C_Item.GetItemInfo or GetItemInfo
  local cached=C_Item and C_Item.IsItemDataCachedByID and A.Safe(C_Item.IsItemDataCachedByID,id)
  if getter and cached~=false then name,link,quality,level,required,class,subclass,stack,equip,icon,price=A.Safe(getter,id) end
  if not icon and C_Item and C_Item.GetItemIconByID then icon=A.Safe(C_Item.GetItemIconByID,id) end
  return {id=id,name=name or A.ItemName(id),link=link or ("|Hitem:"..id.."|h["..A.ItemName(id).."]|h"),
    quality=quality,required=required,class=class,subclass=subclass,icon=icon,
    price=type(price)=="number" and price==price and price>=0 and price<math.huge and price or nil}
end
-- Price is the client's sell price for ONE item. It is never an AH estimate.
function A.ValueOrder(a,b)
  if (a.price~=nil)~=(b.price~=nil) then return a.price~=nil end
  if (a.price or -1)~=(b.price or -1) then return (a.price or -1)>(b.price or -1) end
  if (a.quality or -1)~=(b.quality or -1) then return (a.quality or -1)>(b.quality or -1) end
  if a.name~=b.name then return a.name<b.name end
  return a.id<b.id
end
