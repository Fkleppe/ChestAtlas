"""Build the explicitly historical reference pack from pinned MIT-licensed pfQuest data.

Requires Python and lupa (Lua 5.1). Run from any directory. No Forever drop chances
or timers are inferred from this data. Downloads are kept outside the addon folder.
"""
from pathlib import Path
import json
import urllib.request
import sys

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT.parents[1] / 'work' / 'sources'
sys.path.insert(0, str(ROOT.parents[1] / 'work' / 'python_libs'))
from lupa.lua51 import LuaRuntime

# Pinned to the source actually inspected for this release.
COMMIT = (ROOT / 'tools' / 'source_commit.txt').read_text().strip()
FILES = ['db/objects.lua', 'db/items.lua', 'db/enUS/objects.lua',
         'db/enUS/items.lua', 'db/enUS/zones.lua', 'LICENSE']
# Ordinary world treasure chests only, excluding quests, events and dungeon-only types.
CHESTS = [2843, 2849, 2850, 2852, 2855, 2857, 4149, 74448, 75293,
          75298, 75299, 75300, 106318, 106319, 153451, 153453, 153454,
          153462, 153463, 153464]
# These are recommended zone ranges, NOT opening requirements or chest item levels.
ZONES = {1:(1,10),12:(1,10),85:(1,10),141:(1,10),215:(1,10),14:(1,10),
         38:(10,20),40:(10,20),148:(10,20),17:(10,25),130:(10,20),
         44:(15,25),10:(18,30),11:(20,30),331:(18,30),267:(20,30),
         406:(15,27),405:(30,40),400:(25,35),33:(30,45),45:(30,40),
         3:(35,45),8:(35,45),15:(35,45),357:(40,50),440:(40,50),
         47:(40,50),51:(45,50),16:(45,55),490:(48,55),4:(45,55),
         46:(50,58),28:(50,60),139:(53,60),361:(48,55),618:(53,60),1377:(55,60)}

def lua_value(value):
    if value is None: return 'nil'
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int,float)): return repr(value)
    if isinstance(value,str): return json.dumps(value,ensure_ascii=False)
    if isinstance(value,list): return '{' + ','.join(map(lua_value,value)) + '}'
    if isinstance(value,dict):
        return '{' + ','.join('['+lua_value(k)+']='+lua_value(v) for k,v in value.items()) + '}'
    raise TypeError(value)

def main():
    WORK.mkdir(parents=True,exist_ok=True)
    for file in FILES:
        target = WORK / file.replace('/','_')
        if not target.exists():
            request = urllib.request.Request(f'https://raw.githubusercontent.com/shagu/pfQuest/{COMMIT}/{file}',headers={'User-Agent':'ChestAtlas-build'})
            target.write_bytes(urllib.request.urlopen(request,timeout=60).read())
    lua = LuaRuntime(register_eval=False,register_builtins=False)
    load = lua.eval('function(code, env) local f=assert(loadstring(code)); setfenv(f,env); f() end')
    env = lua.table()
    env['pfDB'] = lua.table_from({k:lua.table() for k in ['objects','items','zones']})
    for file in FILES[:-1]: load((WORK / file.replace('/','_')).read_text(encoding='utf-8'),env)
    db = env['pfDB']
    types, nodes, items, zone_data = {}, {}, {}, {}
    for obj_id in CHESTS:
        obj = db['objects']['data'][obj_id]
        if obj is None: continue
        types[obj_id] = {'name':db['objects']['enUS'][obj_id], 'loot':[]}
        for _,coord in obj['coords'].items():
            x,y,area,seconds = [coord[i] for i in range(1,5)]
            if area not in ZONES or x is None or y is None or not (0 <= x <= 100 and 0 <= y <= 100): continue
            # Keep source coordinates and source timer exactly; never promote them to Forever facts.
            nodes.setdefault(area,[]).append({'typeID':obj_id,'x':x/100,'y':y/100,'legacyRespawn':seconds if seconds and seconds>0 else None})
    for item_id,entry in db['items']['data'].items():
        if entry['O'] is None: continue
        for obj_id, chance in entry['O'].items():
            if obj_id in types:
                # No percentages shown: historical reference only and pool/group semantics unknown.
                types[obj_id]['loot'].append(int(item_id))
                items[int(item_id)] = db['items']['enUS'][item_id] or f'Item {item_id}'
    for area, area_nodes in nodes.items():
        unique = {}
        for n in area_nodes: unique[(n['typeID'],n['x'],n['y'])] = n
        nodes[area] = sorted(unique.values(),key=lambda n:(n['typeID'],n['x'],n['y']))
        zone_data[area] = {'name':db['zones']['enUS'][area], 'minLevel':ZONES[area][0], 'maxLevel':ZONES[area][1]}
        for i,n in enumerate(nodes[area]): n['id'] = f'legacy:{area}:{i+1}'
    for entry in types.values(): entry['loot'].sort()
    pack = {'source':'pfQuest / Vanilla (VMaNGOS reference)', 'commit':COMMIT,
            'version':'Vanilla 1.12; unverified in Forever', 'types':types,
            'items':items, 'zones':zone_data, 'nodes':nodes}
    (ROOT/'Data.lua').write_text('-- Generated historical reference data. See THIRD_PARTY.md.\nlocal _, A = ...\nA.Data = '+lua_value(pack)+'\n',encoding='utf-8')
    (ROOT/'LICENSE-pfQuest.txt').write_bytes((WORK/'LICENSE').read_bytes())
    (ROOT/'tools'/'source_commit.txt').write_text(COMMIT+'\n')
    counts = {'zones':len(nodes),'locations':sum(map(len,nodes.values())), 'types':len(types), 'possibleItems':len(items)}
    (ROOT/'tools'/'data_manifest.json').write_text(json.dumps({'commit':COMMIT,**counts},indent=2)+'\n')
    print(json.dumps(counts))

if __name__ == '__main__': main()
