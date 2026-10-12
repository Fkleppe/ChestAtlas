from pathlib import Path
import sys,runpy,json,hashlib
R=Path(__file__).resolve().parents[1];W=R/'tools';sys.path.insert(0,str(W))
base=runpy.run_path(str(W/'build_classic_loot.py'))
A,L,audit,paths,b=base['A'],base['L'],base['audit'],base['paths'],base['b'];E=base['E']
original=set(A.Data.types.keys())
L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')((R/'ClassicSpawnData.lua').read_text(encoding='utf-8'),A)
extra={};names={};absent=[]
for tid in sorted(set(A.Data.types.keys())-original):
 cm=audit.templates.get(int(tid))
 if not cm:absent.append(int(tid));continue
 kind=int(cm['type']);lootid=int(cm['data1']) if kind==3 else 0;rows=audit.go.get(lootid,[])
 expanded=audit.expand(rows);computed=paths(rows);chances={};uncertainty={}
 for item,ps in computed.items():
  issues=set(i for p in ps for i in p['issues'])
  if len(ps)!=1:issues.add('Multiple loot paths')
  if issues:uncertainty[item]='; '.join(sorted(issues))
  else:chances[item]=ps[0]['percent']
 for item in expanded:
  assert E.pfDB['items'].enUS[item],item;names[item]=E.pfDB['items'].enUS[item]
 cash={'minCopper':int(cm['mingold']),'maxCopper':int(cm['maxgold'])} if kind==3 else None
 extra[int(tid)]={'loot':sorted(expanded),'available':bool(lootid and rows),'lootID':lootid,'cash':cash,'chances':chances,'uncertainty':uncertainty,'objectType':kind}
s='''-- Classic loot/currency references for additional exact objects. CMaNGOS GPL-3.0.
-- Original 0.3.4 loot tables remain unchanged. Same pinned 1.12 full snapshot.
local _,A=...
local extra='''+b.lua_value(extra)+'''
for id,t in pairs(extra)do A.ClassicLoot[id]=t end
local names='''+b.lua_value(names)+'''
for id,name in pairs(names)do A.Data.items[id]=name end
'''
(R/'ClassicSpawnLoot.lua').write_text(s,encoding='utf-8',newline='\n')
report={'source':audit.result['source'],'commit':audit.result['commit'],'newExactTypes':len(extra),'sourceAbsentTypes':absent,'itemLinks':sum(len(t['loot']) for t in extra.values()),'numericChanceLinks':sum(len(t['chances']) for t in extra.values()),'unknownChanceLinks':sum(len(t['uncertainty']) for t in extra.values()),'moduleSHA256':hashlib.sha256(s.encode()).hexdigest()}
(R/'tools/current_spawn_loot_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('NEW LOOT',json.dumps(report))
