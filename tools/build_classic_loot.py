from pathlib import Path
import sys,json,collections,importlib.util,hashlib,shutil
R=Path(__file__).resolve().parents[1];W=R/'tools';sys.path.insert(0,str(R/'tests/python_libs'))
sys.path.insert(0,str(W))
import audit_classic_loot as audit
spec=importlib.util.spec_from_file_location('base_build',R/'tools/build_data.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
A=audit.A;L=audit.L
E=L.table(pfDB=L.table(items=L.table()))
env=L.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')
namesource=(W/'sources/db_enUS_items.lua').read_bytes()
assert hashlib.sha256(namesource).hexdigest()=='98bbd02ed910f528f744162c9e0b993f04a0215e48afa88c78711b6f634f137d','Pinned English name source hash mismatch'
env(namesource.decode('utf-8'),E)
def paths(rows,activation=1,issues=(),trail=()):
    result=collections.defaultdict(list)
    grouped=collections.defaultdict(list)
    for r in rows:
        if int(r['groupid']):grouped[int(r['groupid'])].append(r)
    for r in rows:
        chance=float(r['ChanceOrQuestChance']);group=int(r['groupid']);count=int(r['mincountOrRef']);flags=list(issues)
        if int(r['condition_id']) or chance<0:flags.append('Quest / player conditions')
        if group:
            members=grouped[group];total=sum(abs(float(m['ChanceOrQuestChance'])) for m in members);zeroes=sum(float(m['ChanceOrQuestChance'])==0 for m in members)
            if total>100.000001:flags.append('Overfull loot group')
            if any(int(m['condition_id']) or float(m['ChanceOrQuestChance'])<0 for m in members):flags.append('Conditional loot group')
            prob=(max(0,100-total)/zeroes if chance==0 and zeroes else abs(chance))/100
        else:
            prob=min(1,abs(chance)/100)
            if chance==0:flags.append('Zero chance outside group')
        if count<0:
            ref=-count;assert ref not in trail and ref in audit.refs
            if int(r['maxcount'])!=1:flags.append('Repeated reference rolls')
            children=paths(audit.refs[ref],activation*prob,tuple(flags),trail+(ref,))
            for item,ps in children.items():result[item]+=ps
        elif int(r['item'])>0:
            result[int(r['item'])].append({'percent':activation*prob*100,'issues':sorted(set(flags))})
    return result
types={};names={};reports=[]
for tid,t in sorted(A.Data.types.items()):
    if t.generic:continue
    cm=audit.templates[int(tid)];kind=int(cm['type']);lootid=int(cm['data1']) if kind==3 else 0
    rows=audit.go.get(lootid,[]);expanded=audit.expand(rows);computed=paths(rows)
    chances={};uncertainty={}
    for item,ps in computed.items():
        issues=set(i for p in ps for i in p['issues'])
        if len(ps)!=1:issues.add('Multiple loot paths')
        if issues:uncertainty[item]='; '.join(sorted(issues))
        else:
            assert 0<=ps[0]['percent']<=100
            chances[item]=ps[0]['percent']
    for item in expanded:
        assert E.pfDB['items'].enUS[item],('Missing English item name',item)
        names[item]=E.pfDB['items'].enUS[item]
    old=[int(i) for _,i in t.loot.items()]
    cash={'minCopper':int(cm['mingold']),'maxCopper':int(cm['maxgold'])} if kind==3 else None
    if cash:assert 0<=cash['minCopper']<=cash['maxCopper']
    types[int(tid)]={'loot':sorted(expanded),'available':bool(lootid and rows),'lootID':lootid,'cash':cash,'chances':chances,'uncertainty':uncertainty,'objectType':kind}
    reports.append({'id':int(tid),'name':t.name,'oldCount':len(old),'classicCount':len(expanded),'added':len(expanded-set(old)),'sourceOnly':len(set(old)-expanded),'numericChances':len(chances),'unknownChances':len(uncertainty),'defaultSource':'CMaNGOS Classic' if lootid and rows else 'pfQuest Vanilla fallback','minCopper':cash['minCopper'] if cash else None,'maxCopper':cash['maxCopper'] if cash else None})
source='''-- Extracted Classic currency/loot reference data from CMaNGOS. GPL-3.0.
-- Base snapshot and inference limits: THIRD_PARTY.md and tools/loot_currency_manifest.json.
local _,A=...
A.ClassicLoot='''+b.lua_value(types)+'\nlocal names='+b.lua_value(names)+'\nfor id,name in pairs(names)do A.Data.items[id]=name end\n'
(R/'ClassicLootData.lua').write_text(source,encoding='utf-8',newline='\n')
manifest={'version':'0.3.4','source':'cmangos/classic-db','commit':'ec4f596146be6467ea93c57397858e329e2db852','sqlSHA256':hashlib.sha256(audit.raw).hexdigest(),'moduleSHA256':hashlib.sha256(source.encode()).hexdigest(),'typesChecked':len(types),'cashTypes':sum(t['cash'] is not None for t in types.values()),'completeClassicLootTypes':sum(t['available'] for t in types.values()),'itemLinks':sum(len(t['loot']) for t in types.values()),'uniqueItems':len(names),'numericChanceLinks':sum(len(t['chances']) for t in types.values()),'unknownChanceLinks':sum(len(t['uncertainty']) for t in types.values()),'chancePolicy':'Conservative 1x Classic single-path static estimates. Equal groups get remaining probability divided by zero-entry count. References multiply activation probabilities. Repeated rolls, multiple paths, conditional groups, quest requirements, overfull groups remain unknown. Not verified on Forever; quality rates, loot limits and eligibility may change actual results. No probability is copied from pfQuest positive-only export.','rows':reports}
(R/'tools/loot_currency_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
shutil.copyfile(W/'sources/cmangos-LICENSE.md',R/'LICENSE-CMaNGOS.txt')
shutil.copyfile(W/'sources/cmangos-LICENSE.md',R/'COPYING.txt')
print('BUILD',json.dumps({k:v for k,v in manifest.items() if k not in ('rows','chancePolicy')},indent=2))
