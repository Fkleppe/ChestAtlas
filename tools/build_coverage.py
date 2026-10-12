from pathlib import Path
import sys,json,hashlib,shutil,importlib.util
R=Path(__file__).resolve().parents[1];W=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else R/'tests'/'coverage_fixtures';sys.path.insert(0,str(W/'python_libs'))
from lupa.lua51 import LuaRuntime
spec=importlib.util.spec_from_file_location('base_build',R/'tools'/'build_data.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
L=LuaRuntime();load=L.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')
E=L.table(pfDB=L.table(objects=L.table(),items=L.table(),zones=L.table(),meta=L.table()))
for f in ['db_objects.lua','db_items.lua','db_enUS_objects.lua','db_enUS_items.lua','db_enUS_zones.lua','db_meta.lua']:load((W/'sources'/f).read_text(encoding='utf-8'),E)
A=L.table();L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')((R/'Data.lua').read_text(encoding='utf-8'),A)
def plain(t):return {k:plain(v) if hasattr(v,'items') else v for k,v in t.items()}
base=plain(A.Data);zoneRanges=dict(b.ZONES);zoneRanges[36]=(30,40)
types={};zones={};nodes={};items={};allNodes={area:list(ns.values()) for area,ns in base['nodes'].items()}
ordinary={tid for tid,name in E.pfDB.objects.enUS.items() if name in ['Battered Chest','Solid Chest','Large Solid Chest','Large Battered Chest','Large Iron Bound Chest','Large Mithril Bound Chest']}
faction={tid for tid,name in E.pfDB.objects.enUS.items() if name in ['Alliance Chest','Horde Chest']}
supplyNames={'Food Crate','Water Barrel','Barrel of Melon Juice','Barrel of Milk','Barrel of Sweet Nectar','Armor Crate','Weapon Crate','Box of Assorted Parts','Horde Supply Crate'}
supplies={tid for tid,name in E.pfDB.objects.enUS.items() if name in supplyNames}|{19017,19018}
locks={tid for tid,name in E.pfDB.objects.enUS.items() if name in ['Battered Footlocker','Waterlogged Footlocker','Dented Footlocker','Mossy Footlocker','Scarlet Footlocker','Practice Lockbox','Alliance Strongbox','Horde Strongbox','Hidden Strongbox']}
collectibles={157936,164958,176213}
events={142184,179697,3642,152608,152618}
meta={-int(tid) for tid in E.pfDB.meta.chests.keys() if tid<0}
named={tid for tid,name in E.pfDB.objects.enUS.items() if any(w in name.lower() for w in ['chest','treasure','footlocker','strongbox','lockbox']) and not any(w in name.lower() for w in ['trap','test','deprecated'])}
selected=ordinary|faction|supplies|locks|collectibles|events|meta|named|{2744,177784}
def category(tid):
    if tid in ordinary or tid in faction:return 'treasure'
    if tid in events:return 'event'
    if tid in supplies:return 'supplies'
    if tid in locks:return 'lockpicking'
    if tid in collectibles:return 'collectibles'
    return 'quest'
def hint(tid):
    cat=category(tid)
    if tid==179697:return 'Arena PvP event; availability varies.'
    if tid==142184:return 'Special treasure; Captain\'s Key in Classic.'
    if tid in (3642,152608,152618):return 'Special treasure; Kolkar Booty Key in Classic.'
    if cat=='lockpicking':return 'Lockpicking in Classic; skill requirement unknown.'
    if cat=='quest':return 'Quest / special interaction; requirements may apply.'
    if tid==176213:return 'Collectible; looting can trigger enemies in Classic.'
    if cat=='supplies':return 'Supply loot; historical item links may be incomplete.'
    if E.pfDB.objects.enUS[tid] in ['Large Iron Bound Chest','Large Mithril Bound Chest']:return 'Locked in Classic; opening requirements may apply.'
    return None
metadata={};inventory=[]
for tid in sorted(selected):
    obj=E.pfDB.objects.data[tid]
    name=E.pfDB.objects.enUS[tid]
    coords=list(obj.coords.values()) if obj and obj.coords else []
    eligible=[c for c in coords if c[3] in zoneRanges and 0<=c[1]<=100 and 0<=c[2]<=100]
    inventory.append({'id':tid,'name':name,'category':category(tid),'sourceCoordinates':len(coords),'eligibleCoordinates':len(eligible),'excludedAreas':sorted({int(c[3]) for c in coords if c[3] not in zoneRanges}),'reason': 'included' if eligible else 'no supported outdoor coordinates' if coords else 'source has no coordinates'})
    if tid in base['types']:metadata[tid]={'category':category(tid),'hint':hint(tid)}
    if not eligible:continue
    for c in eligible:
        x,y,area,respawn=c[1],c[2],c[3],c[4]
        if area not in zoneRanges or not 0<=x<=100 or not 0<=y<=100:continue
        if any(n['typeID']==tid and n['x']==x/100 and n['y']==y/100 for n in allNodes.get(area,[])):continue
        n={'typeID':tid,'x':x/100,'y':y/100,'referenceSource':'pfQuest'}
        if respawn and respawn>0:n['legacyRespawn']=respawn
        nodes.setdefault(area,[]).append(n);allNodes.setdefault(area,[]).append(n)
        if tid not in base['types']:types.setdefault(tid,{'name':name,'loot':[],'category':category(tid),'hint':hint(tid)})
for item,e in E.pfDB['items'].data.items():
    if not e.O:continue
    for tid,chance in e.O.items():
        if tid in types:
            types[tid]['loot'].append(item);items[item]=E.pfDB['items'].enUS[item] or f'Item {item}'
pfAdded=sum(map(len,nodes.values()));gmAdded=duplicates=0
comparison=json.loads((W/'chest-coverage-comparison.json').read_text(encoding='utf-8'))
for c in comparison['candidates']:
    area=c['area'];family=c['name'];x,y=c['x'],c['y']
    cat=c.get('category','treasure')
    same=[n for n in allNodes.get(area,[]) if (types.get(n['typeID']) or base['types'][n['typeID']])['name']==family and (types.get(n['typeID']) or metadata.get(n['typeID']) or {}).get('category','treasure')==cat]
    if any((n['x']-x)**2+(n['y']-y)**2<=0.0015**2 for n in same):duplicates+=1;continue
    tid=900000+c['kind']
    types.setdefault(tid,{'name':family,'loot':[],'generic':True,'gatherMateKind':c['kind'],'category':cat,'hint': 'Lockpicking in Classic; skill requirement unknown.' if cat=='lockpicking' else 'Collectible; looting can trigger enemies in Classic.' if c['kind']==513 else None})
    n={'typeID':tid,'x':x,'y':y,'referenceSource':'wowhead-classic','sourceMapID':c['mapID'],'sourceCoord':c['coord']}
    nodes.setdefault(area,[]).append(n);allNodes.setdefault(area,[]).append(n);gmAdded+=1
for area,ns in nodes.items():
    if area not in base['zones']:zones[area]={'name':E.pfDB.zones.enUS[area],'minLevel':zoneRanges[area][0],'maxLevel':zoneRanges[area][1]}
    # Append after the frozen base: existing journal/favorite IDs remain stable.
    for index,n in enumerate(ns,len(base['nodes'].get(area,{}))+1):n['id']=f'legacy:{area}:{index}'
for t in types.values():t['loot'].sort()
pack={'types':types,'items':items,'zones':zones,'nodes':nodes,'metadata':metadata}
source='''-- Generated additive Classic references. See THIRD_PARTY.md and tools/coverage_manifest.json.
local _,A=...
local extra='''+b.lua_value(pack)+'''
for id,t in pairs(extra.types)do A.Data.types[id]=t end
for id,m in pairs(extra.metadata)do for k,v in pairs(m)do A.Data.types[id][k]=v end end
for id,name in pairs(extra.items)do A.Data.items[id]=name end
for id,z in pairs(extra.zones)do A.Data.zones[id]=z end
for area,ns in pairs(extra.nodes)do
  A.Data.nodes[area]=A.Data.nodes[area] or {}
  for _,n in ipairs(ns)do A.Data.nodes[area][#A.Data.nodes[area]+1]=n end
end
'''
(R/'CoverageData.lua').write_text(source,encoding='utf-8')
manifest={'version':'0.3.3','baseLocations':sum(len(ns) for ns in base['nodes'].values()),'pfQuestAdded':pfAdded,'wowheadClassicAdded':gmAdded,'totalLocations':sum(map(len,allNodes.values())),'zones':len(allNodes),'types':len(base['types'])+len(types),'wowheadCommit':comparison['commit'],'wowheadSHA256':comparison['sha256'],'duplicateTolerancePercent':0.15,'genericLootPolicy':'family known; exact gameobject variant and loot unknown; no invented probabilities/timers','coverageSHA256':hashlib.sha256(source.encode()).hexdigest(),'byZone':{area:{'name':E.pfDB.zones.enUS[area],'before':len(base['nodes'].get(area,{})),'added':len(ns),'after':len(allNodes[area])} for area,ns in nodes.items()}}
from collections import Counter
manifest['byCategory']=dict(Counter((types.get(n['typeID']) or metadata.get(n['typeID']) or {}).get('category','treasure') for ns in allNodes.values() for n in ns))
manifest['possibleItems']=len(set(base['items'])|set(items))
manifest['sourceObservationsChecked']=len(comparison['candidates'])
manifest['pfQuestSourceCommit']=base['commit']
manifest['pfQuestSourceHashes']={f:hashlib.sha256((W/'sources'/f).read_bytes()).hexdigest() for f in ['db_objects.lua','db_items.lua','db_enUS_objects.lua','db_enUS_items.lua','db_enUS_zones.lua','db_meta.lua']}
manifest['pfQuestObjectInventory']=inventory
(R/'tools'/'coverage_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
shutil.copyfile(W/'sources'/'gitlab-LICENSE',R/'LICENSE-GatherMate2-Data.txt')
print(json.dumps(manifest,indent=2))
