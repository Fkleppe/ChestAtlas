"""Meaningful domain and mocked UI integration tests; requires Python + lupa."""
from pathlib import Path
import sys
import json
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parents[1]/'work'/'python_libs'))
from lupa.lua51 import LuaRuntime

lua=LuaRuntime(register_eval=False,register_builtins=False)
A=lua.table()
load=lua.eval('function(code,A) return assert(loadstring(code))("ChestAtlas",A) end')
for file in [p.name for p in ROOT.glob('*.lua')]:
    lua.execute('assert(loadstring(...))', (ROOT/file).read_text(encoding='utf-8'))
for file in ['Data.lua','CoverageData.lua','ClassicSpawnData.lua','ClassicLootData.lua','ClassicSpawnLoot.lua','Core.lua','Features.lua','Loot.lua','Companion.lua']:
    load((ROOT/file).read_text(encoding='utf-8'),A)
lua.globals().A=A
lua.execute('''
local total, loot = 0, 0
for area,nodes in pairs(A.Data.nodes) do
  assert(A.Data.zones[area])
  local seen={}
  for _,n in ipairs(nodes) do
    assert(A.Data.types[n.typeID] and A.ValidPosition(1,n.x,n.y))
    assert(not seen[n.id]); seen[n.id]=true
    assert(not n.own and not n.lastLooted and n.id:match("^legacy:"))
    total=total+1
  end
end
assert(total>4500);TestLocationCount=total
for _,t in pairs(A.Data.types) do
  for _,id in ipairs(t.loot) do assert(A.Data.items[id]);loot=loot+1 end
end
assert(loot>1000)
A.Init(nil);A.UseJournal("3:Test:Forever");A.settings.category="chests"
assert(A.ResolveArea(37,"Elwynn Forest")==12)
assert(A.ResolveArea(10,"The Barrens")==17)
assert(A.ResolveArea(999,"Different Zone")==nil)
assert(A.Bind(12,9001));assert(A.ResolveArea(9001,"Translated Zone")==12)
assert(not A.Bind(999999,37))
assert(not A.ValidPosition(37,0/0,0.5))
assert(not A.ValidPosition(37,-0.1,0.5))
assert(not A.ValidPosition(0,0.1,0.5))
assert(not A.AddObservation(37,2,0.5,2843,1000,"test"))
local n=A.AddObservation(37,0.524,0.519,2843,1000,"test")
local same=A.AddObservation(37,0.525,0.519,2843,1010,"test")
assert(n==same and A.journal.nextID==2)
local other=A.AddObservation(37,0.7,0.6,2843,1020,"test")
assert(other~=n)
local typesSeparate=A.AddObservation(37,0.524,0.519,2850,1020,"test")
assert(typesSeparate~=n)
local nodes=A.NodesForMap(37,"Elwynn Forest"); assert(#nodes>3)
A.filters.source="own";nodes=A.NodesForMap(37,"Elwynn Forest");assert(#nodes==3)
A.filters.typeID=2850;nodes=A.NodesForMap(37,"Elwynn Forest");assert(#nodes==1)
A.filters.typeID=0;A.filters.minLevel=20;nodes=A.NodesForMap(37,"Elwynn Forest");assert(#nodes==0)
A.filters.minLevel=1;A.filters.source="all"
assert(A.Timer(n,1030):find("Respawn unknown",1,true)==nil) -- No looting yet.
A.MarkLooted(n,1030);assert(A.Timer(n,1090):find("Respawn unknown",1,true))
n.estimate=5
assert(A.Timer(n,1090):find("4 min remaining",1,true))
assert(A.Timer(n,1400):find("Availability unknown",1,true))
assert(not A.Timer(n,1400):find("spawned",1,true))
local snapshot={time=1090,mapID=37,x=0.524,y=0.519,key="one",items={{id=117,count=2}},typeID=2843}
assert(A.RecordContents(n,snapshot,1100));assert(n.contents[117].count==2)
assert(not A.RecordContents(n,snapshot,1101))
assert(not A.RecordContents(typesSeparate,snapshot,1101))
snapshot.key="two";snapshot.sourceRejected=true;assert(not A.RecordContents(n,snapshot,1101))
snapshot.sourceRejected=nil;snapshot.time=900;assert(not A.RecordContents(n,snapshot,1101))
snapshot.time=1090;snapshot.x=0.99;assert(not A.RecordContents(n,snapshot,1101))
snapshot.x=0.524;snapshot.typeID=2850;assert(not A.RecordContents(n,snapshot,1101))
n.note="Hule | nord\\nVÃ¦r obs pÃ¥ mobs Ã¦Ã¸Ã¥"
local exported=A.Export()
A.Init(nil);A.UseJournal("3:Test:Forever");A.settings.category="chests"
local ok,count=A.Import(exported,1500);assert(ok and count==3)
assert(A.journal.nodes[n.id].note==n.note)
assert(A.journal.nodes[n.id].contents[117].count==2)
assert(A.journal.nodes[n.id].estimate==5 and A.db.bindings[12]==9001)
local before=A.Export()
assert(not A.Import(exported.."\\nN|own:900|1|nan|0.2|0|0|0|0||",1500))
assert(A.Export()==before) -- Failure must be atomic.
assert(not A.Import('print("execute")',1500))
A.UseJournal("3:AnotherRealm:Forever");assert(not A.Import(exported,1500))
assert(next(A.journal.nodes)==nil)
A.UseJournal("3:Test:Forever")
''')

load((ROOT/'tests'/'wow_mock.lua').read_text(encoding='utf-8'),A)
load((ROOT/'Runtime.lua').read_text(encoding='utf-8'),A)
for file in ['Navigation.lua','Widgets.lua','MapUI.lua','Minimap.lua','UI.lua']:
    load((ROOT/file).read_text(encoding='utf-8'),A)
lua.execute('''
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","ChestAtlas")
A.settings.category="chests"
A.events.scripts.OnEvent(A.events,"PLAYER_LOGIN")
assert(A.isForever and A.provider)
A.ShowUI(); assert(ChestAtlasWindow:IsShown())
A.NewAtPlayer(2843); assert(A.selected and A.selected.own)
A.MarkLooted(A.selected,A.Now());A.Refresh()
A.events.scripts.OnEvent(A.events,"LOOT_READY")
A.events.scripts.OnEvent(A.events,"LOOT_OPENED")
assert(#A.lastLoot.items==1 and A.lastLoot.items[1].count==2)
assert(A.lastLoot.typeID==2843 and not A.lastLoot.sourceRejected)
assert(A.RecordContents(A.selected,A.lastLoot,A.Now()))
A.events.scripts.OnEvent(A.events,"LOOT_CLOSED")
MockLootGUID="Creature-0-1-1-1-123-000000001"
A.events.scripts.OnEvent(A.events,"LOOT_READY")
assert(A.lastLoot.sourceRejected)
assert(not A.RecordContents(A.selected,A.lastLoot,A.Now()))
A.events.scripts.OnEvent(A.events,"LOOT_CLOSED")
MockLootGUID=nil
A.events.scripts.OnEvent(A.events,"LOOT_READY")
assert(A.lastLoot.typeID==nil) -- Unknown source is never automatically attributed.
A.Waypoint(A.selected);assert(MockWaypoint)
A.ShowBackup(false);assert(ChestAtlasBackup:IsShown())
A.ShowBackup(true);assert(ChestAtlasBackup:IsShown())
assert(A.FindMapForArea(12)==37)
local n=A.selected
ChestAtlasWindow.scripts.OnUpdate(ChestAtlasWindow,31)
assert(A.selected==n)
SlashCmdList.CHESTATLAS("status")
''')
pin_xml=ET.parse(ROOT/'Pins.xml')
# MapCanvas attaches its own scripts and asserts that OnEnter/OnLeave are absent.
assert not pin_xml.findall('.//{http://www.blizzard.com/wow/ui/}Scripts')
toc=(ROOT/'ChestAtlas.toc').read_text()
for line in toc.splitlines():
    if line and not line.startswith('#'): assert (ROOT/line).exists(),line
timers=sorted({int(node['legacyRespawn']) for _,nodes in A['Data']['nodes'].items() for _,node in nodes.items() if node['legacyRespawn'] is not None})
print(json.dumps({'result':'PASS','lua':'5.1','historicalLocations':int(lua.globals().TestLocationCount),'legacyRespawnSeconds':timers,'checks':['source integrity','zone/type/level/source filters','observation deduplication','unknown vs estimated timers','loot attribution and duplicate protection','backup roundtrip and atomic rejection','realm separation','runtime events','UI construction','map pins provider','waypoints','XML and TOC']}))
