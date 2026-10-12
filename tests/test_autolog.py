"""Automatic chest journal (0.5.0): loot attribution, respawn evidence, routes, backup."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(register_eval=False,register_builtins=False)
A=lua.table()
load=lua.eval('function(code,A) return assert(loadstring(code))("ChestAtlas",A) end')
for file in ['Data.lua','CoverageData.lua','ClassicSpawnData.lua','ClassicLootData.lua','ClassicSpawnLoot.lua','InstanceData.lua','Core.lua','Features.lua','Loot.lua','Companion.lua','tests/wow_mock.lua','Runtime.lua','Navigation.lua','Widgets.lua','MapUI.lua','Minimap.lua','UI.lua','Instances.lua']:
    load((ROOT/file).read_text(encoding='utf-8'),A)
lua.globals().A=A
lua.execute(r'''
MockNow=10000;MockClock=100
function GetServerTime()return MockNow end
function GetTime()return MockClock end
function GetSpellInfo(id)return id==2366 and 'Herbalism' or 'Opening' end
function C_Map.GetMapWorldSize()return 4000,2700 end
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","ChestAtlas")
A.events.scripts.OnEvent(A.events,"PLAYER_LOGIN")
assert(A.settings.autoJournal==true)

-- A real Elwynn (area 12) exact, non-quest reference.
local ref,quest,generic
for _,n in ipairs(A.Data.nodes[12]) do
  local t=A.Data.types[n.typeID]
  if not ref and not t.generic and (t.category or "treasure")=="treasure" then ref=n end
  if not quest and t.category=="quest" then quest=n end
end
for area,nodes in pairs(A.Data.nodes) do
  for _,n in ipairs(nodes) do
    local t=A.Data.types[n.typeID]
    if t.generic and A.Data.zones[area] and not generic then
      for tid,v in pairs(A.Data.types) do if not v.generic and v.name==t.name and (v.category or "treasure")~="quest" then generic={node=n,area=area,exact=tid};break end end
    end
  end
end
assert(ref and quest and generic,"fixtures")
local px,py=ref.x+0.002,ref.y
function C_Map.GetPlayerMapPosition()return {GetXY=function()return px,py end}end
local guidSerial=0
local function loot(objectID,kind,items)
  guidSerial=guidSerial+1
  MockLootGUID=(kind or "GameObject").."-0-1-1-1-"..objectID.."-"..string.format("%010d",guidSerial)
  local list=items or {{117,2}}
  function GetNumLootItems()return math.max(1,#list)end
  function GetLootSlotLink(slot)return list[slot] and ("|Hitem:"..list[slot][1].."|h[x]|h") or nil end
  function GetLootSlotInfo(slot)return "tex","x",list[slot] and list[slot][2] or 0 end
  A.events.scripts.OnEvent(A.events,"LOOT_READY")
  A.events.scripts.OnEvent(A.events,"LOOT_OPENED")
  A.events.scripts.OnEvent(A.events,"LOOT_CLOSED")
  return MockLootGUID
end
local function count()local c=0;for _ in pairs(A.journal.nodes)do c=c+1 end;return c end
local function msg()return DEFAULT_CHAT_FRAME.messages[#DEFAULT_CHAT_FRAME.messages] end

-- 1. First loot creates a linked, looted personal find with contents.
local guid=loot(ref.typeID)
assert(count()==1)
local own=A.Observation(ref)
assert(own and own.referenceID==ref.id and own.typeID==ref.typeID)
assert(own.lastLooted==MockNow and own.loots==1 and own.lastGUID==guid)
assert(own.contents[117].count==2)
assert(A.LocationStatus(ref)=="looted")
assert(msg():find("added to your journal",1,true) and msg():find("1 item",1,true))

-- 2. Reopening the same spawn (same GUID) is not a respawn.
MockNow=MockNow+300
MockLootGUID=guid
A.events.scripts.OnEvent(A.events,"LOOT_READY");A.events.scripts.OnEvent(A.events,"LOOT_CLOSED")
assert(own.loots==1 and own.relootSeconds==nil and own.contents[117].count==2)

-- 3. A new GUID 20 min after the first loot is respawn evidence.
MockNow=10000+1200
loot(ref.typeID,nil,{{117,1},{159,3}})
assert(count()==1 and own.loots==2 and own.relootSeconds==1200)
assert(own.contents[117].count==3 and own.contents[159].count==3)
assert(msg():find("back after 20 min",1,true))
assert(A.Timer(own,MockNow+60):find("Respawned within 20 min",1,true))
assert(A.Timer(own,MockNow+60):find("2 loots",1,true))
-- A later, longer interval keeps the shortest observation.
MockNow=MockNow+5400;loot(ref.typeID)
assert(own.loots==3 and own.relootSeconds==1200)
assert(A.Ago(5400)=="1 h 30 min" and A.Ago(90000)=="1 d 1 h")

-- 4/5/6. Creatures, quest objects, Classic resources and gathering casts are ignored.
local before=count()
loot(ref.typeID,"Creature")
px,py=quest.x,quest.y;loot(quest.typeID)
loot(1617) -- Peacebloom: a Classic object, never a discovery
A.events.scripts.OnEvent(A.events,"UNIT_SPELLCAST_SUCCEEDED","player","cast",2366)
loot(999999) -- unknown object right after Herbalism: a new herb, not a chest
assert(count()==before and not A.Data.types[999999])
-- An object missing from both Classic databases becomes a named discovery.
MockClock=MockClock+60
A.events.scripts.OnEvent(A.events,"UNIT_SPELLCAST_SENT","player","Forever Strongbox","cast",3365)
px,py=0.3,0.3;loot(999998,nil,{{117,1}})
assert(count()==before+1 and A.Data.types[999998].discovered and A.TypeName(999998)=="Forever Strongbox")
assert(A.journal.discovered[999998].name=="Forever Strongbox")
local disc;for _,n in pairs(A.journal.nodes)do if n.typeID==999998 then disc=n end end
assert(disc and disc.loots==1 and disc.contents[117] and A.LocationSource(disc):find("discovery",1,true))
before=count()

-- 7. Coin-only chests are attributed through the slot source.
px,py=ref.x,ref.y
MockNow=MockNow+3600;loot(ref.typeID,nil,{})
assert(own.loots==4 and own.lastLooted==MockNow)
assert(msg():find("logged",1,true) and not msg():find("item",1,true))

-- 8. Turning auto-log off stops recording.
SlashCmdList.CHESTATLAS("auto");assert(A.settings.autoJournal==false)
MockNow=MockNow+3600;loot(ref.typeID);assert(own.loots==4)
SlashCmdList.CHESTATLAS("auto");assert(A.settings.autoJournal==true)

-- 9. Looting the current route stop advances the route; other chests do not.
A.journal.nodes={};A.journal.nextID=1
A.filters.containers="treasure";A.filters.areaID=0
px,py=ref.x,ref.y
assert(A.StartChestRoute(37))
local route=A.chestRoute
assert(route.nodes[1]==ref and route.index==1)
MockNow=MockNow+3600
local other
for _,n in ipairs(route.nodes) do if n~=ref and A.Data.types[n.typeID].name~=A.Data.types[ref.typeID].name then other=n;break end end
assert(#route.nodes>1 and other,"route needs another chest type")
px,py=other.x,other.y;loot(other.typeID);assert(route.index==1)
px,py=ref.x,ref.y;loot(ref.typeID)
assert(A.chestRoute==route and route.index==2)
A.StopNavigation()

-- 10. An exact variant looted at a family-only marker links to that marker.
local zoneMap=9100;A.Bind(generic.area,zoneMap)
local g=generic.node
local snap={time=MockNow,mapID=zoneMap,x=g.x,y=g.y,key="generic-1",items={},typeID=generic.exact,sourceGUID="GameObject-0-1-1-1-"..generic.exact.."-1"}
local gown,res=A.AutoRecord(snap,generic.area,MockNow)
assert(gown and gown.referenceID==g.id and gown.typeID==generic.exact and res.ref==g)
assert(A.AutoRecord(snap,generic.area,MockNow)==nil) -- same window is never processed twice

-- 11. Backup keeps loot history; malformed history is rejected atomically.
local ownRef=A.Observation(ref);assert(ownRef)
ownRef.relootSeconds=1500
local exported=A.Export()
assert(exported:find("\nR|"..ownRef.id.."|",1,true))
A.journal.nodes={};A.journal.discovered={};A.Data.types[999998]=nil
assert(exported:find("\nD|999998|",1,true))
assert(A.Import(exported,MockNow))
assert(A.Data.types[999998] and A.TypeName(999998)=="Forever Strongbox")
assert(A.journal.nodes[ownRef.id].loots==ownRef.loots and A.journal.nodes[ownRef.id].relootSeconds==1500)
local snapshotExport=A.Export()
assert(not A.Import(exported.."\nR|"..ownRef.id.."|1|-5",MockNow))
assert(not A.Import(exported.."\nR|own:424242|1|60",MockNow))
assert(A.Export()==snapshotExport)

-- Map UI and status still build with the new setting.
A.ShowMapSettings();A.Refresh()
SlashCmdList.CHESTATLAS("status")
TestRef=ref.id
''')
print(json.dumps({'result':'PASS','reference':lua.globals().TestRef,'checks':[
 'auto-linked find with contents','same GUID reopen ignored','respawn evidence (shortest interval)',
 'creature/quest/unknown objects ignored','coin-only chest attributed','/ca auto toggle',
 'route advances only on current stop','family marker resolves exact variant','duplicate window ignored',
 'backup R rows roundtrip and atomic rejection','map settings UI']}))
