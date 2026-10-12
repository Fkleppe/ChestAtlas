from pathlib import Path
import sys,urllib.request,json,hashlib,importlib.util
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT.parent/'ChestAtlas-build'
(WORK/'sources').mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(WORK/'python_libs'))
from lupa.lua51 import LuaRuntime
spec=importlib.util.spec_from_file_location('chest_build',ROOT/'tools'/'build_data.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
COMMIT='104f35678ca39ab1fb78b655f815cc7016f5e0c8'
files=['db/units.lua','db/enUS/units.lua','db/meta.lua','db/items.lua','db/enUS/items.lua','db/enUS/zones.lua']
def fetch(file):
    path=WORK/'sources'/file.replace('/','_')
    content=urllib.request.urlopen('https://raw.githubusercontent.com/shagu/pfQuest/'+COMMIT+'/'+file,timeout=45).read()
    if path.exists():assert path.read_bytes()==content,file
    else:path.write_bytes(content)
    return file,hashlib.sha256(content).hexdigest()
hashes=dict(ThreadPoolExecutor(max_workers=6).map(fetch,files))
lua=LuaRuntime(register_eval=False,register_builtins=False)
env=lua.table();env.pfDB=lua.table_from({k:lua.table() for k in ['units','items','zones']})
load=lua.eval('function(code,e)local f=assert(loadstring(code));setfenv(f,e);f()end')
for f in files:load((WORK/'sources'/f.replace('/','_')).read_text(encoding='utf-8'),env)
db=env.pfDB;units,items=db['units'],db['items']
npcs,nodes,zones,names={}, {}, {}, {}
for npc,level in db.meta.rares.items():
    u=units.data[npc]
    if u is None or u.coords is None:continue
    found=[]
    for _,c in u.coords.items():
        if c[3] in builder.ZONES and c[1] is not None and c[2] is not None and 0<=c[1]<=100 and 0<=c[2]<=100:
            found.append((int(c[3]),c[1]/100,c[2]/100,c[4]))
    if not found:continue
    npcs[int(npc)]={'name':units.enUS[npc] or 'NPC '+str(npc),'level':str(u.lvl or level),'loot':[]}
    for area,x,y,timer in sorted(set(found)):
        nodes.setdefault(area,[]).append({'id':f'rare:{int(npc)}:{area}:{x:.5f}:{y:.5f}','npcID':int(npc),'typeID':-int(npc),'rare':True,'x':x,'y':y,'legacyRespawn':timer})
        zones[area]={'name':db.zones.enUS[area],'minLevel':builder.ZONES[area][0],'maxLevel':builder.ZONES[area][1]}
for item,e in items.data.items():
    if e.U is None:continue
    for npc,chance in e.U.items():
        if npc in npcs:
            npcs[int(npc)]['loot'].append(int(item));names[int(item)]=items.enUS[item] or 'Item '+str(item)
for npc in npcs.values():npc['loot'].sort()
for area in nodes:nodes[area].sort(key=lambda n:(n['npcID'],n['x'],n['y']))
pack={'source':'pfQuest Vanilla rare metadata, NPC coordinates and U loot associations','commit':COMMIT,'npcs':npcs,'nodes':nodes,'zones':zones,'items':names}
(ROOT/'RareData.lua').write_text('-- Generated historical rare references; unverified in Forever. See THIRD_PARTY.md.\nlocal _,A=...\nA.RareData='+builder.lua_value(pack)+'\n',encoding='utf-8')
manifest={'commit':COMMIT,'sourceSHA256':hashes,'rares':len(npcs),'locations':sum(map(len,nodes.values())),'zones':len(zones),'items':len(names),'lootLinks':sum(len(n['loot']) for n in npcs.values())}
(ROOT/'tools'/'rare_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest))
