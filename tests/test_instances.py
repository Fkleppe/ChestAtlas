"""Dungeon/raid chests (0.6.0): data, opening requirements, instance loot log, discoveries, panel, backup."""
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
MockNow=50000;MockClock=500
function GetServerTime()return MockNow end
function GetTime()return MockClock end
function GetSpellInfo(id)return id==2575 and 'Mining' or 'Opening' end
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","ChestAtlas")
A.events.scripts.OnEvent(A.events,"PLAYER_LOGIN")

-- Data: every listed chest has a type, loot entry and named keys/tools.
local function find(map,name,pick)
  for _,c in ipairs(A.Instances[map].chests) do
    if A.TypeName(c.typeID)==name and (not pick or c.pickLock==pick) then return c end
  end
end
local chests=0
for map,inst in pairs(A.Instances) do
  assert(A.ForeverInstances[map]==inst.name)
  for _,c in ipairs(inst.chests) do
    chests=chests+1
    local t=A.Data.types[c.typeID];assert(t and A.ClassicLoot[c.typeID],c.typeID)
    assert(c.spawns>0)
    for _,id in ipairs(c.keys or {}) do assert(A.Data.items[id],id) end
    for _,id in ipairs(c.tools or {}) do assert(A.Data.items[id],id) end
  end
end
assert(chests>=40,chests)
local relic=find(230,"Relic Coffer");assert(relic.keys[1]==11078 and #relic.keys==1 and not relic.pickLock)
assert(find(230,"Dark Coffer").keys[1]==11197 and #find(230,"Dark Coffer").keys==1) -- no source-less test key
local mithril=find(229,"Large Mithril Bound Chest");assert(mithril.pickLock==275 and #mithril.tools==1 and mithril.tools[1]==15872)
local solid=find(229,"Large Solid Chest");assert(not solid.pickLock and not solid.keys and solid.sharesWith[1]==mithril.typeID)
assert(find(509,"Scarab Coffer").keys[1]==21761 and find(531,"Large Scarab Coffer").keys[1]==21762)
local firelord=find(409,"Cache of the Firelord");assert(firelord.event and firelord.trigger:find("Majordomo",1,true))
local iron=find(33,"Large Iron Bound Chest");assert(iron.pickLock==1)
for _,id in ipairs(iron.tools) do assert(not A.ItemName(id):find("Tome",1,true)) end
assert(find(70,"Large Mithril Bound Chest").pickLock==175)
assert(#A.ReferenceLoot({typeID=relic.typeID})>0)
local short,long=A.ChestRequirement(mithril)
assert(short:find("Lockpicking 275",1,true) and long:find("Arcanite Skeleton Key",1,true))
assert(select(1,A.ChestRequirement(solid)):find("anyone can open",1,true))
assert(select(2,A.ChestRequirement(firelord)):find("encounter",1,true))
-- Instance types never appear in the outdoor type picker or family loot.
for _,e in ipairs(A.TypeEntries()) do assert(e.value==0 or A.Data.types[e.value].category~="instance") end
assert(A.ClassicObjectIDs[1617] and A.ClassicObjectIDs[relic.typeID] and not A.ClassicObjectIDs[400001])

-- Inside Blackrock Depths: no coordinates, loot goes to the instance log.
function IsInInstance()return true,"party" end
function GetInstanceInfo()return "Blackrock Depths","party",1,"Normal",5,0,false,230 end
function C_Map.GetPlayerMapPosition()return nil end
function GetItemCount(id)return id==11078 and 2 or 0 end
function GetNumSkillLines()return 1 end
function GetSkillLineInfo()return "Lockpicking",nil,nil,280 end
A.events.scripts.OnEvent(A.events,"PLAYER_ENTERING_WORLD")
local msg=DEFAULT_CHAT_FRAME.messages[#DEFAULT_CHAT_FRAME.messages]
assert(msg:find("Blackrock Depths",1,true) and msg:find("Relic Coffer (key)",1,true),msg)
local serial=0
local function loot(objectID,items)
  serial=serial+1;MockLootGUID="GameObject-0-1-230-1-"..objectID.."-"..string.format("%010d",serial)
  local list=items or {{11078,1}}
  function GetNumLootItems()return math.max(1,#list)end
  function GetLootSlotLink(slot)return list[slot] and ("|Hitem:"..list[slot][1].."|h[x]|h") or nil end
  function GetLootSlotInfo(slot)return "tex","x",list[slot] and list[slot][2] or 0 end
  A.events.scripts.OnEvent(A.events,"LOOT_READY");A.events.scripts.OnEvent(A.events,"LOOT_CLOSED")
  return MockLootGUID
end
local nodesBefore=0;for _ in pairs(A.journal.nodes)do nodesBefore=nodesBefore+1 end
local guid=loot(relic.typeID,{{11753,1}})
local e=A.journal.instances[230][relic.typeID]
assert(e and e.loots==1 and e.contents[11753].count==1 and e.last==MockNow)
MockLootGUID=guid;A.events.scripts.OnEvent(A.events,"LOOT_READY");A.events.scripts.OnEvent(A.events,"LOOT_CLOSED")
assert(e.loots==1) -- reopening the same coffer
MockNow=MockNow+600;loot(relic.typeID);assert(e.loots==2)
loot(3662) -- Food Crate: a Classic object that is not a listed chest
assert(A.journal.instances[230][3662]==nil)
local nodesAfter=0;for _ in pairs(A.journal.nodes)do nodesAfter=nodesAfter+1 end
assert(nodesAfter==nodesBefore) -- nothing written to open-world locations
-- A Forever-only object inside the instance is a discovery listed for that instance.
MockClock=MockClock+60
A.events.scripts.OnEvent(A.events,"UNIT_SPELLCAST_SENT","player","Shadowforge Hoard","cast",3365)
loot(400001,{{12364,1}})
assert(A.journal.discovered[400001].instance==230 and A.TypeName(400001)=="Shadowforge Hoard")
assert(A.journal.instances[230][400001].loots==1)
-- ...but not right after a gathering cast.
MockClock=MockClock+60
A.events.scripts.OnEvent(A.events,"UNIT_SPELLCAST_SUCCEEDED","player","cast",2575)
loot(400002);assert(not A.journal.discovered[400002])

-- Panel: list, requirement text, what you carry, log and loot board.
A.ShowInstances()
assert(ChestAtlasInstances:IsShown())
local list=A.InstanceChests(230);local last=list[#list]
assert(last.discovered and last.typeID==400001)
local detail=A.InstanceChestDetail(230,relic)
assert(detail:find("Requires a key: Relic Coffer Key",1,true) and detail:find("Relic Coffer Key x2",1,true) and detail:find("Looted by you 2x",1,true),detail)
assert(A.InstanceChestDetail(229,mithril):find("Lockpicking 280 (enough)",1,true))
assert(A.InstanceChestDetail(230,last):find("not in the Classic databases",1,true))
local entries=A.InstanceEntries();assert(#entries>=20)
A.ShowInstances(229);A.RefreshInstances()
SlashCmdList.CHESTATLAS("dungeons")

-- Backup: discoveries and instance log roundtrip; malformed rows are rejected atomically.
local exported=A.Export()
assert(exported:find("\nD|400001|",1,true) and exported:find("\nI|230|"..relic.typeID.."|2|",1,true))
A.journal.instances={};A.journal.discovered={};A.Data.types[400001]=nil
assert(A.Import(exported,MockNow))
assert(A.journal.instances[230][relic.typeID].loots==2 and A.TypeName(400001)=="Shadowforge Hoard")
local before=A.Export()
assert(not A.Import(exported.."\nI|230|1|-1|0",MockNow))
assert(not A.Import(exported.."\nD|x|00|0",MockNow))
assert(A.Export()==before)
TestChests=chests
''')
print(json.dumps({'result':'PASS','instanceChestTypes':lua.globals().TestChests,'checks':[
 'every chest has type/loot/named keys','Relic/Dark/Scarab coffer keys','Mithril Bound lockpicking 275 + Arcanite key',
 'shared Solid/Mithril spawn points','event chests','requirement texts','instance types kept out of outdoor pickers',
 'instance announcement','instance loot log, same-GUID reopen, non-chest objects ignored','no open-world writes inside instances',
 'Forever-only object discovery in instance','gathering casts excluded','panel detail incl. carried keys and Lockpicking',
 'backup D/I rows roundtrip and atomic rejection']}))
