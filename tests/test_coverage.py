from pathlib import Path
import sys,json,hashlib,runpy,math
W=Path(__file__).resolve().parent;R=W.parent;sys.path.insert(0,str(W/'python_libs'))
from lupa.lua51 import LuaRuntime
AUDIT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else W/'coverage_fixtures'
if not (AUDIT/'chest-coverage-comparison.json').exists():
    raise SystemExit('Pass the frozen audit directory containing sources/, validation_sources/ and chest-coverage-comparison.json.')
L=LuaRuntime();A=L.table();load=L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')
load((R/'Data.lua').read_text(encoding='utf-8'),A)
base={n.id:(area,n.typeID,n.x,n.y,n.legacyRespawn) for area,ns in A.Data.nodes.items() for _,n in ns.items()}
for f in ['CoverageData.lua','ClassicLootData.lua','RareData.lua','Core.lua','Features.lua','Rares.lua','Companion.lua','tests/wow_mock.lua','Runtime.lua','Widgets.lua','MapUI.lua','UI.lua']:load((R/f).read_text(encoding='utf-8'),A)
L.globals().A=A
manifest=json.loads((R/'tools'/'coverage_manifest.json').read_text(encoding='utf-8'))
ids={};generic=[]
for area,ns in A.Data.nodes.items():
    for index,n in ns.items():
        assert n.id not in ids;ids[n.id]=n
        assert n.id==f'legacy:{int(area)}:{int(index)}'
        assert A.Data.types[n.typeID] is not None and A.ValidPosition(1,n.x,n.y)
        if n.id in base:assert base[n.id]==(area,n.typeID,n.x,n.y,n.legacyRespawn)
        elif n.referenceSource=='wowhead-classic':
            generic.append(n)
            assert A.IsGenericType(n.typeID) and len(A.ReferenceLoot(n))==0 and n.legacyRespawn is None
            assert 'variant unknown' in A.TypeDisplay(n.typeID) and '#900' not in A.TypeDisplay(n.typeID)
assert len(ids)==manifest['totalLocations'] and len(base)==1030 and len(generic)==manifest['wowheadClassicAdded']
assert len(ids)>4500 and len(generic)>500
assert A.Data.zones[36].name=='Alterac Mountains' and len(A.Data.nodes[36])>42
# Independently check full source coverage, rather than validating only imported rows.
comparison=json.loads((AUDIT/'chest-coverage-comparison.json').read_text(encoding='utf-8'))
for c in comparison['candidates']:
    ns=[n for _,n in A.Data.nodes[c['area']].items() if A.Data.types[n.typeID].name==c['name'] and A.ContainerCategory(n.typeID)==c['category']]
    assert any(math.hypot(n.x-c['x'],n.y-c['y'])<=0.001500000001 for n in ns),c
E=L.table(pfDB=L.table(objects=L.table(),zones=L.table(),items=L.table()))
envLoad=L.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')
for f in ['db_objects.lua','db_enUS_objects.lua','db_enUS_zones.lua','db_items.lua','db_enUS_items.lua']:envLoad((AUDIT/'sources'/f).read_text(encoding='utf-8'),E)
for tid,t in A.Data.types.items():
    if t.generic:continue
    expected={int(item) for item,e in E.pfDB['items'].data.items() if e.O and e.O[tid] is not None}
    assert {int(item) for _,item in t.loot.items()}==expected,(tid,'incorrect possible loot')
    for _,item in t.loot.items():
        assert E.pfDB['items'].data[item].O[tid]>0
        assert A.Data['items'][item]==E.pfDB['items'].enUS[item]
families={'Battered Chest','Solid Chest','Large Battered Chest','Large Solid Chest','Large Iron Bound Chest','Large Mithril Bound Chest'}
included={r['id'] for r in manifest['pfQuestObjectInventory'] if r['eligibleCoordinates']}
for tid,name in E.pfDB.objects.enUS.items():
    obj=E.pfDB.objects.data[tid]
    if tid not in included or not obj or not obj.coords:continue
    for _,c in obj.coords.items():
        if A.Data.zones[c[3]] and 0<=c[1]<=100 and 0<=c[2]<=100:
            assert any(n.typeID==tid and n.x==c[1]/100 and n.y==c[2]/100 for _,n in A.Data.nodes[c[3]].items()),(tid,c[3],c[1],c[2])
# Independent omission checks: original hard-coded IDs/names missed these families.
for tid in [4096,3715,105578,105579,105581,111095,19017,19018,3658,3662,179486,2039,3714,32,2744,142184,179697,3642,157936,164958,176213]:
    assert tid in included and A.Data.types[tid] is not None,(tid,'omitted source family')
assert A.ContainerCategory(4096)=='treasure' and A.ContainerCategory(32)=='quest'
assert A.ContainerCategory(2744)=='quest' and A.ContainerCategory(19017)=='supplies'
assert A.ContainerCategory(179486)=='lockpicking' and A.ContainerCategory(179697)=='event'
L.execute('''
A.Init(nil);A.UseJournal("test")
A.settings.category="chests"
A.Bind(141,57)
assert(A.filters.containers=="treasure")
local function nodesForScope(scope)
 A.SetContainerCategory(scope);return A.NodesForMap(57,"Teldrassil")
end
for _,node in ipairs(nodesForScope("treasure"))do assert(A.ContainerCategory(node.typeID)=="treasure")end
local all=nodesForScope("all");local treasure=nodesForScope("treasure")
assert(#all>#treasure,"Optional categories lost from map list")
A.SetContainerCategory("quest");local quests=A.NodesForMap(57,"Teldrassil");assert(#quests>=4)
for _,node in ipairs(quests)do assert(A.ContainerCategory(node.typeID)=="quest")end
A.filters.typeID=2739;assert(A.Passes(A.Data.nodes[141][1],141)==false)
A.ResetFilters();assert(A.filters.containers=="treasure" and A.filters.typeID==0)
local saved=A.db;A.SetContainerCategory("supplies");A.Init(saved);assert(A.filters.containers=="supplies")
A.SetContainerCategory("treasure")
local generic
for _,n in ipairs(A.Data.nodes[141])do if A.IsGenericType(n.typeID)then generic=n;break end end
assert(generic)
assert(A.LocationSource(generic)=="Classic Wowhead reference")
A.ShowMapDetail({generic},141,57)
assert(A.mapDetail.variant.text:find("Variant unknown",1,true) and not A.mapDetail.variant.text:find("900502",1,true))
assert(A.mapDetail.loot.best.name.text=="Exact chest variant unknown")
assert(A.mapDetail.loot.summary.text:find("Exact variant unknown",1,true))
A.Bind(141,57);WorldMapFrame:SetMapID(57);WorldMapFrame:Show()
A.ShowUI();A.selected=generic;A.selectedArea=141;A.RefreshUI()
assert(ChestAtlasWindow.detailTitle.text:find("variant unknown",1,true))
assert(ChestAtlasWindow.detailInfo.text:find("exact loot variant unknown",1,true))
-- Favorites and generic personal references survive the existing inert backup format.
A.ToggleFavorite(generic)
local own=A.AddObservation(57,generic.x,generic.y,generic.typeID,1000,"test")
own.referenceID=generic.id
local encoded=A.Export();assert(A.Import(encoded,1000));assert(A.IsFavorite(generic))
local wrong={time=1000,mapID=57,x=generic.x,y=generic.y,typeID=153454,key="wrong",items={{id=117,count=1}}}
local solid=generic.typeID
if A.TypeName(generic.typeID)=="Battered Chest"then
  assert(not A.RecordContents(own,wrong,1000) and own.typeID==solid)
end
local sourceID=A.TypeName(generic.typeID)=="Battered Chest" and 106318 or 153454
local snapshot={time=1000,mapID=57,x=generic.x,y=generic.y,typeID=sourceID,key="fresh",items={{id=117,count=1}}}
snapshot.time=1;assert(not A.RecordContents(own,snapshot,1000) and own.typeID==solid)
snapshot.time=1000;assert(A.RecordContents(own,snapshot,1000) and own.typeID==sourceID)
assert(not A.RecordContents(own,snapshot,1000),"Duplicate loot accepted")
''')
print(f"PASS all {len(comparison['candidates'])} eligible Classic Wowhead observations covered within source dedup tolerance; {len(included)} pfQuest container types completely represented in supported outdoor zones; {len(ids)} stable references; {len(generic)} explicit unknown variants; category separation/persistence; actual UI labels, backup and loot source checks")
# Real client MapCanvas harness tests a NEW supplemental marker's click/waypoint.
sys.argv=[str(W/'test_mapcanvas.py'),str(AUDIT/'validation_sources')]
state=runpy.run_path(str(W/'test_mapcanvas.py'))
state['lua'].execute('''
A.settings.category="chests";A.settings.focus=false;A.settings.showPins=true
A.filters.typeID=0;A.filters.source="all";A.filters.query="";A.filters.favoritesOnly=false;A.filters.areaID=0
WorldMapFrame:SetMapID(57);A.Refresh()
local pool=WorldMapFrame.pinPools.ChestAtlasPinTemplate;local added
for _,pin in ipairs(pool.active)do if pin.node.referenceSource=="wowhead-classic"then added=pin;break end end
assert(added,"Supplemental point missing from actual map provider")
added.scripts.OnMouseUp(added,"LeftButton",true);assert(A.selected==added.node)
added.scripts.OnMouseUp(added,"RightButton",true)
assert(MockWaypoint.map==57 and MockWaypoint.x==added.node.x and MockWaypoint.y==added.node.y,"Used Classic source UiMapID instead of current Forever map")
A.ToggleFavorite(added.node);local encoded=A.Export();assert(A.Import(encoded,A.Now()))
''')
print('PASS new supplemental marker on real MapCanvas mixins: details, exact current-client waypoint and favorite backup')
