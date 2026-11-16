"""Map projection in the loaded addon: files in the .toc order, default filters, automatic journal.

Run with Python and lupa: python tests/test_map_projection_runtime.py
The three positions are places where a chest was looted in Forever build 1.60.1.70938.
"""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MOCK_BEFORE = 'Runtime.lua'
FINDS = [  # uiMapID, x, y, typeID, expected reference, place
    (1423, 0.5928214, 0.3937396, 153454, 'legacy:139:13', 'Eastwall Tower'),
    (1423, 0.3276787, 0.7938954, 153453, 'legacy:139:3', 'Darrowshire'),
    (1423, 0.3394535, 0.6426028, 153453, 'legacy:139:4', 'Crown Guard Tower'),
    (1425, 0.4132391, 0.5926368, 4149, 'legacy:47:8', 'Valorwind Lake (zone without new edges)'),
]


def toc_files():
    files = [line.strip() for line in (ROOT / 'ChestAtlas.toc').read_text().splitlines()
             if line.strip().endswith('.lua')]
    assert files.index('MapProjection.lua') == files.index('InstanceData.lua') + 1, 'MapProjection.lua must follow the data files'
    assert files.index('ZoneCorrections.lua') == files.index('MapProjection.lua') + 1, 'ZoneCorrections.lua must follow MapProjection.lua'
    assert files.index('ZoneCorrections.lua') < files.index('Core.lua'), 'the data files must load before Core.lua'
    position = files.index(MOCK_BEFORE)
    return files[:position] + ['tests/wow_mock.lua'] + files[position:]


def main():
    assert (ROOT / 'ChestAtlas.toc').read_text().replace('\r', '') == (ROOT / 'ChestAtlas_Camelot.toc').read_text().replace('\r', ''), 'both .toc files must be equal'
    lua = LuaRuntime(register_eval=False, register_builtins=False)
    A = lua.table()
    load = lua.eval('function(code,A) return assert(loadstring(code))("ChestAtlas",A) end')
    for name in toc_files():
        load((ROOT / name).read_text(encoding='utf-8'), A)
    lua.globals().A = A
    lua.globals().FINDS = lua.table_from([lua.table_from(f) for f in FINDS])
    lua.execute(r'''
MockNow=10000;MockClock=100
function GetServerTime()return MockNow end
function GetTime()return MockClock end
function GetSpellInfo()return 'Opening' end
function C_Map.GetMapWorldSize()return 4302,2867 end
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","ChestAtlas")
A.events.scripts.OnEvent(A.events,"PLAYER_LOGIN")
assert(A.Data.projection=="1.60.1.70938","projection must run at load")
assert(A.filters.containers==nil or A.filters.containers=="treasure","default container filter")
local names={[1423]="Eastern Plaguelands",[1425]="The Hinterlands"}
-- An own node saved before 0.6.2 has no reference (the old pins were too far away).
local seeded=A.AddObservation(1423,0.5928214,0.3937396,153454,MockNow,"1.60.1.70938")
assert(seeded and not seeded.referenceID,"seeded own node")
Linked=0
for i,f in ipairs(FINDS) do
  local mapID,x,y,typeID,want,place=f[1],f[2],f[3],f[4],f[5],f[6]
  local area=A.ResolveArea(mapID,names[mapID])
  assert(area,"zone must resolve: "..place)
  -- 1. The reference pin is on the map with the default filters, at the place of the find.
  local shown
  for _,n in ipairs(A.NodesForMap(mapID,names[mapID])) do if n.id==want then shown=n end end
  assert(shown,"reference pin not shown with default filters: "..place)
  assert(math.abs(shown.x-x)<0.003 and math.abs(shown.y-y)<0.003,"reference pin is not at the find: "..place)
  -- 2. The automatic journal links a find at this place to the reference.
  MockNow=MockNow+1000
  local node=A.AutoRecord({typeID=typeID,sourceGUID="GameObject-0-1-0-1-"..typeID.."-00000000"..i,mapID=mapID,x=x,y=y,key="k"..i,time=MockNow,items={}},area,MockNow)
  assert(node,"find not recorded: "..place)
  assert(node.referenceID==want,"find linked to "..tostring(node.referenceID)..", expected "..want.." ("..place..")")
  Linked=Linked+1
end
-- 2b. Chests that the data lists under a neighbour zone are also on the map of their own zone.
local function shownNear(mapID,name,typeID,x,y)
  for _,n in ipairs(A.NodesForMap(mapID,name)) do
    if n.typeID==typeID and n.alsoListedAs and math.abs(n.x-x)<0.001 and math.abs(n.y-y)<0.001 then return n end
  end
end
assert(A.Data.zoneCorrections=="1.60.1.70938","zone corrections must run at load")
assert(shownNear(1419,"Blasted Lands",4149,0.727049,0.177508),"Blasted Lands chest 1 not shown")
assert(shownNear(1419,"Blasted Lands",4149,0.732574,0.173747),"Blasted Lands chest 2 not shown")
local dunGarok=shownNear(1424,"Hillsbrad Foothills",4096,0.729540,0.803452)
assert(dunGarok,"Dun Garok chest not shown on the Hillsbrad Foothills map")
-- A find at the new point links to it, and the link survives backup and import (id = list position).
MockNow=MockNow+1000
local found=A.AutoRecord({typeID=4096,sourceGUID="GameObject-0-1-0-1-4096-0000000099",mapID=1424,x=0.7296,y=0.8034,key="k99",time=MockNow,items={}},A.ResolveArea(1424,"Hillsbrad Foothills"),MockNow)
assert(found and found.referenceID==dunGarok.id,"Dun Garok find must link to "..dunGarok.id)
local area,index=dunGarok.id:match("^legacy:(%d+):(%d+)$")
assert(A.Data.nodes[tonumber(area)][tonumber(index)]==dunGarok,"the id must resolve by list position")
-- 3. The own node saved before 0.6.2 got its reference at the next find, with no second node.
assert(seeded.referenceID=="legacy:139:13","old own node must get its reference")
local count=0
for _,n in pairs(A.journal.nodes) do if n.referenceID=="legacy:139:13" then count=count+1 end end
assert(count==1,"one own node for the Eastwall Tower chest, found "..count)
''')
    print(json.dumps({'result': 'PASS', 'linkedFinds': int(lua.globals().Linked),
                      'checks': ['.toc order', 'both .toc files equal', 'projection at load', 'pins shown with default filters',
                                 'pins at the looted positions', 'automatic journal links finds to references',
                                 'old own node gets its reference',
                                 'neighbour-zone chests shown on their own zone map']}))


if __name__ == '__main__':
    main()
