from pathlib import Path
import sys,json,collections,hashlib,importlib.util,shutil,math
R=Path(__file__).resolve().parents[1];W=R/'tools';sys.path.insert(0,str(R/'tests/python_libs'))
from lupa.lua51 import LuaRuntime
spec=importlib.util.spec_from_file_location('base',R/'tools/build_data.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
L=LuaRuntime();A=L.table();load=L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')
for f in ['Data.lua','CoverageData.lua']:load((R/f).read_text(encoding='utf-8'),A)
E=L.table(pfDB=L.table(objects=L.table(),items=L.table(),zones=L.table()))
env=L.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')
for f in ['db_objects.lua','db_items.lua','db_enUS_items.lua','db_enUS_zones.lua']:env((W/'sources'/f).read_text(encoding='utf-8'),E)
audit=json.loads((W/'current-chest-spawn-audit.json').read_text(encoding='utf-8'))
catalog={int(t):v for t,v in audit['typeCatalog'].items()}
nodes={};types={};zones={};names={};existing={int(a):list(ns.values()) for a,ns in A.Data.nodes.items()}
baseline={int(a):len(ns) for a,ns in A.Data.nodes.items()}
TOL=.0015
def type_info(tid):return types.get(tid) or A.Data.types[tid]
def family(tid):
 t=type_info(tid);return t['name']
def cat(tid):
 t=type_info(tid);return t['category'] or 'treasure'
def ensure(tid):
 if A.Data.types[tid] or tid in types:return
 name=catalog[tid]['name']
 category='supplies' if name in ('Food Crate','Water Barrel','Barrel of Milk','Barrel of Melon Juice','Barrel of Sweet Nectar','Ammo Crate') else 'quest'
 types[tid]={'name':name,'loot':[],'category':category,'hint':'Quest / special interaction; requirements may apply.' if category=='quest' else 'Supply container; source availability varies.'}
def add(tid,area,x,y,source,extra=None):
 ensure(tid)
 f,c=family(tid),cat(tid)
 nearby=[n for n in existing.get(area,[]) if family(int(n['typeID']))==f and cat(int(n['typeID']))==c and math.hypot(n['x']-x,n['y']-y)<=TOL]
 if nearby:return False
 if area not in A.Data.zones:zones.setdefault(area,{'name':E.pfDB.zones.enUS[area],'minLevel':1,'maxLevel':60})
 n={'typeID':tid,'x':x,'y':y,'referenceSource':source}
 if extra:n.update(extra)
 n['id']=f"legacy:{area}:{baseline.get(area,0)+len(nodes.get(area,[]))+1}"
 nodes.setdefault(area,[]).append(n);existing.setdefault(area,[]).append(n);return True
# Source-backed extra PF containers, including named caches/baskets/crates omitted
# by the prior chest-word selection. Keep source percentage coordinates unchanged.
supported=set(b.ZONES)|{36,41,493,1519,1537,1637,1638,1497,1657}
pfAdded=0
for tid in sorted(catalog):
 obj=E.pfDB.objects.data[tid]
 if not obj or not obj.coords:continue
 for _,p in obj.coords.items():
  if int(p[3]) in supported and 0<=p[1]<=100 and 0<=p[2]<=100:
   pfAdded+=add(tid,int(p[3]),p[1]/100,p[2]/100,'pfQuest')
# Current DB positions fill remaining holes, retaining real object ID, world
# location and source GUID for reproducibility. Never assign live respawn timers.
dbAdded=collections.Counter();sourceRows=[]
for r in sorted(audit['rows'],key=lambda r:(r['source']!='vm',r['guid'],r['id'])):
 if r['status'] not in ('covered','missing'):continue
 before=add(r['id'],r['area'],r['x'],r['y'],r['source']+'-classic',{'worldX':r['worldX'],'worldY':r['worldY'],'worldZ':r['worldZ'],'worldMapID':r['map'],'sourceGUID':r['guid']})
 if before:dbAdded[r['source']]+=1;sourceRows.append(r)
for item,e in E.pfDB['items'].data.items():
 if e.O:
  for tid,_ in e.O.items():
   if tid in types:types[tid]['loot'].append(int(item));names[int(item)]=E.pfDB['items'].enUS[item]
for t in types.values():t['loot'].sort()
# Do not add unused dungeon-only types to the world-map type picker.
used={n['typeID'] for ns in nodes.values() for n in ns}
types={tid:t for tid,t in types.items() if tid in used}
data={'types':types,'zones':zones,'items':names,'nodes':nodes}
s='''-- Additional Classic container references. GPL-3.0 where derived from CMaNGOS/VMaNGOS.
-- Projection/source limits and reproduction: tools/current_spawn_manifest.json.
local _,A=...
local extra='''+b.lua_value(data)+'''
for id,t in pairs(extra.types)do A.Data.types[id]=t end
for id,z in pairs(extra.zones)do A.Data.zones[id]=z end
for id,name in pairs(extra.items)do A.Data.items[id]=name end
for area,ns in pairs(extra.nodes)do
 A.Data.nodes[area]=A.Data.nodes[area] or {}
 for _,n in ipairs(ns)do A.Data.nodes[area][#A.Data.nodes[area]+1]=n end
end
'''
(R/'ClassicSpawnData.lua').write_text(s,encoding='utf-8',newline='\n')
result={'version':'0.3.5','baseLocations':sum(baseline.values()),'pfAdded':pfAdded,'currentDBAdded':dict(dbAdded),'addedLocations':sum(map(len,nodes.values())),'totalLocations':sum(map(len,existing.values())),'newTypes':len(types),'types':len(list(A.Data.types.keys()))+len(types),'newZones':zones,'dedupTolerancePercent':.15,'projectionPolicy':'Pinned 1.12 WorldMapArea affine conversion. Unique rectangle, exact/name pfQuest anchor or nearby object anchor; Uldaman exterior manually assigned to Badlands. City references use city bounds. No inferred terrain/live positions or timers. Name-and-category matches cover family observations; source rows are not counts of distinct simultaneously existing chests.','moduleSHA256':hashlib.sha256(s.encode()).hexdigest(),'sources':audit['sources'],'byCategory':dict(collections.Counter(cat(n['typeID']) for ns in nodes.values() for n in ns)),'addedSourceRows':sourceRows}
(R/'tools/current_spawn_manifest.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('sources','projectionPolicy','addedSourceRows')},indent=2))
