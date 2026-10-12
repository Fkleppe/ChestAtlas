from pathlib import Path
import sys,json,math,hashlib,collections,runpy,re,gzip,sqlite3
R=Path(__file__).resolve().parents[1];W=R/'tools';sys.path.insert(0,str(R/'tests/python_libs'))
from lupa.lua51 import LuaRuntime
L=LuaRuntime();A=L.table();load=L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')
for f in ['Data.lua','CoverageData.lua']:load((R/f).read_text(encoding='utf-8'),A)
before={int(area):[(n.id,n.typeID,n.x,n.y) for _,n in ns.items()] for area,ns in A.Data.nodes.items()}
load((R/'ClassicSpawnData.lua').read_text(encoding='utf-8'),A)
ids=set();new=[]
for area,ns in A.Data.nodes.items():
 actual=[(n.id,n.typeID,n.x,n.y) for _,n in ns.items()]
 assert actual[:len(before.get(area,[]))]==before.get(area,[]),'Old indices changed'
 for i,n in ns.items():
  assert n.id not in ids;ids.add(n.id)
  assert n.id==f'legacy:{int(area)}:{int(i)}' and A.Data.types[n.typeID]
  assert math.isfinite(n.x) and math.isfinite(n.y) and 0<=n.x<=1 and 0<=n.y<=1
  if i>len(before.get(area,[])):new.append((int(area),n))
m=json.loads((R/'tools/current_spawn_manifest.json').read_text(encoding='utf-8'))
assert len(ids)==m['totalLocations']==10173 and len(new)==m['addedLocations']==5200
assert len(list(A.Data.types.keys()))==433
assert hashlib.sha256((R/'ClassicSpawnData.lua').read_bytes()).hexdigest()==m['moduleSHA256']
assert sum(A.Data.types[n.typeID].category=='treasure' for _,n in new)==29
report=json.loads((W/'current-chest-spawn-audit.json').read_text(encoding='utf-8'))
v=sqlite3.connect('file:'+str((W/'sources/vm-mangos.sqlite').resolve())+'?mode=ro',uri=True)
c=sqlite3.connect('file:'+str((W/'sources/cm-classicmangos.sqlite').resolve())+'?mode=ro',uri=True)
excluded=set(report['resourceExcludedIDs']);excludedNames=set(report['resourceExcludedNames'])
def eligible(tid,name,kind):return kind==3 and tid not in excluded and name not in excludedNames and not any(s in name.lower() for s in ('test','deprecated','should not'))
vt={r[0]:r for r in v.execute('select t.entry,t.name,t.type from gameobject_template t where t.patch=(select max(p.patch) from gameobject_template p where p.entry=t.entry and p.patch<=10)')}
expectedTypes={tid for tid,r in vt.items() if eligible(*r)}
known={int(tid) for tid,t in A.Data.types.items() if not t.generic}
expectedTypes.update(r[0] for r in c.execute('select entry,name,type from gameobject_template') if (r[0] in vt or r[0] in known) and eligible(*r))
assert set(map(int,report['typeCatalog']))==expectedTypes
expected={('vm',guid,tid) for guid,tid in v.execute('select guid,id from gameobject where patch_min<=10 and patch_max>=10') if tid in expectedTypes}
expected.update(('cm',guid,tid) for guid,tid in c.execute('select guid,id from gameobject where id<>0 UNION ALL select g.guid,e.entry from gameobject g join gameobject_spawn_entry e on g.guid=e.guid where g.id=0') if tid in expectedTypes)
actual={(r['source'],r['guid'],r['id']) for r in report['rows']}
assert expected==actual,'Source rows omitted from audit'
print('PASS independent SQL selection of all 621 non-resource type-3 variants and every source row, including alternative entries, instances and invalid positions')
assert report['counts'].get('missing',0)==0 and report['counts']['covered']==20160
for r in report['rows']:
 if r['status']=='covered':
  assert any(A.Data.types[n.typeID].name==r['name'] and math.hypot(n.x-r['x'],n.y-r['y'])<=.0015+1e-12 for _,n in A.Data.nodes[r['area']].items()),r
 elif r['status']=='zone unresolved':
  assert r['id']==179644 and r['source']=='vm' and not r['candidateAreas']
assert report['outdoorAlternatives']==4270
print('PASS 20,160 current DB outdoor records covered; alternative templates, patch filtering, all 5,200 additions, original IDs/coordinates and category separation preserved')
load((R/'ClassicLootData.lua').read_text(encoding='utf-8'),A)
oldLoot={int(t):[int(v) for _,v in e.loot.items()] for t,e in A.ClassicLoot.items()}
load((R/'ClassicSpawnLoot.lua').read_text(encoding='utf-8'),A)
for tid,items in oldLoot.items():assert [int(v) for _,v in A.ClassicLoot[tid].loot.items()]==items
# Independent numeric SQL parser for every NEW exact table and reference pool.
sql=gzip.decompress((W/'sources/cmangos-classic.sql.gz').read_bytes()).decode('utf-8');tables={}
for name in ['gameobject_loot_template','reference_loot_template']:
 rows=collections.defaultdict(list)
 for block in re.findall(r'INSERT INTO `'+name+r'` VALUES (.*?);\n',sql,re.S):
  for entry,item,chance,group,count,maxcount,condition in re.findall(r"\((\d+),(\d+),(-?[\d.]+),(\d+),(-?\d+),(\d+),(\d+),'",block):rows[int(entry)].append((int(item),int(count)))
 tables[name]=rows
links=0
for tid,t in A.ClassicLoot.items():
 if tid in oldLoot:continue
 queue=[(int(t.lootID),True)];seen=set();items=set()
 while queue:
  entry,root=queue.pop();key=(entry,root)
  if key in seen:continue
  seen.add(key)
  for item,count in tables['gameobject_loot_template' if root else 'reference_loot_template'].get(entry,[]):
   if count<0:queue.append((-count,False))
   elif item>0:items.add(item)
 assert {int(v) for _,v in t.loot.items()}==items
 assert {int(i) for i,_ in t.chances.items()}|{int(i) for i,_ in t.uncertainty.items()}==items
 links+=len(items)
assert links==426
print('PASS all 272 additional exact loot/currency variants; independent pool expansion, complete chance/unknown coverage, original tables unchanged')
fixture=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else R/'tests/forever_sources'
sys.argv=[str(R/'tests/test_mapcanvas.py'),str(fixture)]
state=runpy.run_path(str(R/'tests/test_mapcanvas.py'))
state['lua'].execute('''
A.settings.category="chests";A.settings.focus=false;A.settings.showPins=true;A.settings.cluster=false
A.settings.iconSize=26
A.filters.typeID=0;A.filters.source="all";A.filters.query="";A.filters.favoritesOnly=false;A.filters.areaID=0;A.filters.containers="treasure"
local node
for _,n in ipairs(A.Data.nodes[8])do if n.referenceSource=="cm-classic" and n.typeID==4149 then node=n;break end end
assert(node,"Previously unresolved Swamp chest absent")
A.Bind(8,99991);local old=C_Map.GetMapInfo
C_Map.GetMapInfo=function(id)if id==99991 then return {name="Swamp of Sorrows",mapType=3}end;return old(id)end
WorldMapFrame:SetMapID(99991);A.Refresh()
local pin
for _,p in ipairs(WorldMapFrame.pinPools.ChestAtlasPinTemplate.active)do if p.node==node then pin=p;break end end
assert(pin and pin.iconSize==13 and pin.width==13,"Supplemental marker or half-size world icon missing")
pin.scripts.OnMouseUp(pin,"LeftButton",true);assert(A.selected==node)
assert(A.mapDetail.variant.text:find("CMaNGOS Classic reference",1,true))
pin.scripts.OnMouseUp(pin,"RightButton",true)
assert(MockWaypoint.map==99991 and MockWaypoint.x==node.x and MockWaypoint.y==node.y)
A.ToggleFavorite(node);local saved=A.Export();assert(A.Import(saved,A.Now()) and A.IsFavorite(node))
''')
print('PASS new Swamp chest on real MapCanvas mixins: correct source label, half-size icon, exact click/waypoint and favorite backup')
