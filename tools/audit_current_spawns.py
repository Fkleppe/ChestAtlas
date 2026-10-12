from pathlib import Path
import sqlite3,sys,json,csv,collections,math,re
R=Path(__file__).resolve().parents[1];W=R/'tools';sys.path.insert(0,str(R/'tests/python_libs'))
from lupa.lua51 import LuaRuntime
L=LuaRuntime();A=L.table();load=L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')
for f in ['Data.lua','CoverageData.lua']:load((R/f).read_text(encoding='utf-8'),A)
def db(name):
 c=sqlite3.connect('file:'+str((W/'sources'/name).resolve())+'?mode=ro',uri=True);c.row_factory=sqlite3.Row;return c
cm=db('cm-classicmangos.sqlite');vm=db('vm-mangos.sqlite')
vtypes={}
for r in vm.execute('select * from gameobject_template where patch<=10 order by patch'):
 vtypes[r['entry']]=dict(r)
ctypes={r['entry']:dict(r) for r in cm.execute('select * from gameobject_template')}
known={int(tid) for tid,t in A.Data.types.items() if not t.generic}
Meta=L.table(pfDB=L.table())
L.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')((W/'sources/db_meta.lua').read_text(encoding='utf-8'),Meta)
resourceIDs={abs(int(tid)) for cat in ('mines','herbs') for tid in Meta.pfDB.meta[cat].keys()}
resourceNames={t['name'] for tid,t in vtypes.items() if tid in resourceIDs}
keywords=('chest','treasure','footlocker','strongbox','lockbox','coffer','cache','crate','box','barrel','locker','sack','basket','bag','urn','stash','rack','clam','warpwood pod')
def selected(t):
 return t['type']==3 and t['entry'] not in resourceIDs and t['name'] not in resourceNames and not any(k in t['name'].lower() for k in ('test','deprecated','should not'))
# Require CM templates to exist in Vanilla VMaNGOS/pfQuest; CM contains some later-era templates.
selectedTypes={tid:t for tid,t in vtypes.items() if selected(t)}
selectedTypes.update({tid:t for tid,t in ctypes.items() if (tid in vtypes or tid in known) and selected(t)})
rows=[]
for r in vm.execute('select * from gameobject where patch_min<=10 and patch_max>=10'):
 if r['id'] in selectedTypes:rows.append(dict(r,source='vm'))
alternate=collections.defaultdict(list)
for r in cm.execute('select * from gameobject_spawn_entry'):alternate[r['guid']].append(r['entry'])
for r in cm.execute('select * from gameobject'):
 for tid in ([r['id']] if r['id'] else alternate[r['guid']]):
  if tid in selectedTypes:rows.append(dict(r,id=tid,source='cm',alternative=r['id']==0))
bounds={int(r['AreaID']):r for r in csv.DictReader((W/'sources/worldmaparea.csv').open()) if int(r['AreaID'])>0 and int(r['MapID']) in (0,1)}
E=L.table(pfDB=L.table(objects=L.table(),zones=L.table()))
env=L.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')
for f in ['db_objects.lua','db_enUS_zones.lua']:env((W/'sources'/f).read_text(encoding='utf-8'),E)
for area in bounds:
 if not A.Data.zones[area]:A.Data.zones[area]=L.table(name=E.pfDB.zones.enUS[area],minLevel=1,maxLevel=60)
pack=[]
for area,ns in A.Data.nodes.items():
 if area not in bounds:continue
 b=bounds[area]
 for _,n in ns.items():
  pack.append(dict(area=int(area),id=int(n.typeID),name=A.Data.types[n.typeID].name,x=n.x,y=n.y,map=int(b['MapID']),worldX=float(b['LocTop'])+(float(b['LocBottom'])-float(b['LocTop']))*n.y,worldY=float(b['LocLeft'])+(float(b['LocRight'])-float(b['LocLeft']))*n.x))
byName=collections.defaultdict(list);byID=collections.defaultdict(list)
for n in pack:byName[(n['map'],n['name'])].append(n);byID[(n['map'],n['id'])].append(n)
anchorsByID=collections.defaultdict(list)
allAnchors=collections.defaultdict(list)
for tid,obj in E.pfDB.objects.data.items():
 if not obj.coords:continue
 for _,p in obj.coords.items():
  b=bounds.get(int(p[3]))
  if b and 0<=p[1]<=100 and 0<=p[2]<=100:
   allAnchors[int(b['MapID'])].append(dict(area=int(p[3]),worldX=float(b['LocTop'])+(float(b['LocBottom'])-float(b['LocTop']))*p[2]/100,worldY=float(b['LocLeft'])+(float(b['LocRight'])-float(b['LocLeft']))*p[1]/100))
for tid,t in selectedTypes.items():
 obj=E.pfDB.objects.data[tid]
 if obj and obj.coords:
  for _,p in obj.coords.items():
   area=int(p[3]);b=bounds.get(area)
   if not b:continue
   anchorsByID[(int(b['MapID']),tid)].append(dict(area=area,worldX=float(b['LocTop'])+(float(b['LocBottom'])-float(b['LocTop']))*p[2]/100,worldY=float(b['LocLeft'])+(float(b['LocRight'])-float(b['LocLeft']))*p[1]/100))
# Project from the frozen source anchors, never from the generated additions.
# Generated nodes are used only to measure coverage; otherwise rebuilds feed their
# previous zone choices back into the next audit and change provenance/IDs.
if (R/'ClassicSpawnData.lua').exists():load((R/'ClassicSpawnData.lua').read_text(encoding='utf-8'),A)
coverageByName=collections.defaultdict(list)
for area,ns in A.Data.nodes.items():
 if area not in bounds:continue
 b=bounds[area]
 for _,n in ns.items():coverageByName[(int(b['MapID']),A.Data.types[n.typeID].name)].append(dict(area=int(area),x=n.x,y=n.y))
out=[]
for r in rows:
 t=selectedTypes[r['id']];m=r['map'];wx,wy=r['position_x'],r['position_y']
 n=dict(source=r['source'],guid=r['guid'],id=r['id'],name=t['name'],map=m,worldX=wx,worldY=wy,worldZ=r['position_z'],alternative=r.get('alternative',False))
 if m not in (0,1):n['status']='instance / other map';out.append(n);continue
 candidates=byName[(m,t['name'])]
 nearest=min(candidates,key=lambda p:math.hypot(wx-p['worldX'],wy-p['worldY'])) if candidates else None
 n['nearestYards']=math.hypot(wx-nearest['worldX'],wy-nearest['worldY']) if nearest else None
 # Determine zone only inside its bounds, with exact/name anchor to resolve overlapping rectangles.
 areas=[]
 for area,b in bounds.items():
  if int(b['MapID'])!=m:continue
  x=(wy-float(b['LocLeft']))/(float(b['LocRight'])-float(b['LocLeft']));y=(wx-float(b['LocTop']))/(float(b['LocBottom'])-float(b['LocTop']))
  if 0<=x<=1 and 0<=y<=1:areas.append((area,x,y))
 anchors=anchorsByID[(m,r['id'])] or byID[(m,r['id'])] or candidates
 anchor=min(anchors,key=lambda p:math.hypot(wx-p['worldX'],wy-p['worldY'])) if anchors else None
 chosen=next((p for p in areas if anchor and p[0]==anchor['area']),None)
 # A close same-family location is stronger than a distant same-ID anchor in a
 # different overlapping rectangle. Border-spanning templates occur in both DBs.
 if nearest and n['nearestYards']<=40:
  chosen=next((p for p in areas if p[0]==nearest['area']),chosen)
 if len(areas)==1:chosen=areas[0]
 if r['id'] in (124388,124389):
  # Uldaman's exterior halls, on Badlands' map; excluded from old outdoor PF coordinates.
  chosen=next((p for p in areas if p[0]==3),chosen);n['zoneEvidence']='Uldaman exterior quest chest (Badlands); exact 1.12 world position'
 if not chosen:
  local=[p for p in allAnchors[m] if p['area'] in {a[0] for a in areas}]
  close=min(local,key=lambda p:math.hypot(wx-p['worldX'],wy-p['worldY'])) if local else None
  if close and math.hypot(wx-close['worldX'],wy-close['worldY'])<=40:
   chosen=next(p for p in areas if p[0]==close['area']);n['zoneEvidence']='Nearby pfQuest object anchor within 40 yards'
 if not chosen:
  n['status']='zone unresolved';n['candidateAreas']=[p[0] for p in areas];out.append(n);continue
 n['area'],n['x'],n['y']=chosen;n['zone']=A.Data.zones[n['area']].name
 same=[p for p in coverageByName[(m,t['name'])] if p['area']==n['area']]
 dist=min(math.hypot(n['x']-p['x'],n['y']-p['y']) for p in same) if same else None
 n['nearestPercent']=dist*100 if dist is not None else None
 n['status']='covered' if dist is not None and dist<=.0015 else 'missing'
 out.append(n)
report={'scope':'All server CHEST/type-3 templates, independent of name. Excludes pinned pfQuest herbs/mines by ID and family name, test/deprecated objects and CM later-era-only templates. VMaNGOS patch 10 (1.12) active rows; CMaNGOS current plus alternate spawn entries. Dungeon/other-map rows inventoried separately. Zone projection is historical and not live client validation.','sources':json.loads((W/'sources/current-db-source-manifest.json').read_text()),'resourceExcludedIDs':sorted(resourceIDs),'resourceExcludedNames':sorted(resourceNames),'typeCatalog':{tid:{'name':t['name'],'known':tid in known} for tid,t in selectedTypes.items()},'counts':dict(collections.Counter(n['status'] for n in out)),'bySource':{s:dict(collections.Counter(n['status'] for n in out if n['source']==s)) for s in ['cm','vm']},'outdoorAlternatives':sum(n['alternative'] and n['map'] in (0,1) for n in out),'missingTypeNames':sorted({(n['id'],n['name']) for n in out if n['status']=='missing' and n['id'] not in known}),'rows':out}
(W/'current-chest-spawn-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'counts':report['counts'],'bySource':report['bySource'],'outdoorAlternatives':report['outdoorAlternatives'],'missingTypes':len(report['missingTypeNames'])},indent=2))
