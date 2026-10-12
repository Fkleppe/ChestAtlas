from pathlib import Path
import re,gzip,csv,sys,json,hashlib,collections
R=Path(__file__).resolve().parents[1];W=R/'tools';sys.path.insert(0,str(R/'tests/python_libs'))
from lupa.lua51 import LuaRuntime
L=LuaRuntime();A=L.table();load=L.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')
for f in ['Data.lua','CoverageData.lua']:load((R/f).read_text(encoding='utf-8'),A)
raw=(W/'sources/cmangos-classic.sql.gz').read_bytes()
assert hashlib.sha256(raw).hexdigest()=='4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0','Pinned SQL source hash mismatch'
sql=gzip.decompress(raw).decode('utf-8')
def table(name):
    schema=re.search(r'CREATE TABLE `'+name+r'` \((.*?)\) ENGINE',sql,re.S)
    columns=re.findall(r'^\s*`([^`]+)`',schema[1],re.M)
    records=[]
    for ins in re.finditer(r'INSERT INTO `'+name+r'` VALUES (.*?);\n',sql,re.S):
        text=ins[1];quote=False;escape=False;depth=0;start=None
        for i,c in enumerate(text):
            if escape:escape=False;continue
            if quote and c=='\\':escape=True;continue
            if c=="'":quote=not quote;continue
            if quote:continue
            if c=='(':
                if depth==0:start=i+1
                depth+=1
            elif c==')':
                depth-=1
                if depth==0:
                    values=next(csv.reader([text[start:i]],delimiter=',',quotechar="'",escapechar='\\'))
                    assert len(values)==len(columns),(name,len(values),len(columns))
                    records.append(dict(zip(columns,values)))
    return records
templates={int(r['entry']):r for r in table('gameobject_template')}
go=collections.defaultdict(list);refs=collections.defaultdict(list)
for name,dest in [('gameobject_loot_template',go),('reference_loot_template',refs)]:
    for r in table(name):dest[int(r['entry'])].append(r)
print('SCHEMA',list(next(iter(templates.values())).keys()))
print('LOOT SCHEMA',next(iter(go.values()))[:1])
def expand(rows,path=()):
    result=set()
    for r in rows:
        count=int(r['mincountOrRef'])
        if count<0:
            ref=-count
            assert ref not in path,('cyclic loot reference',ref,path)
            assert ref in refs,('missing loot reference',ref)
            result|=expand(refs[ref],path+(ref,))
        elif int(r['item'])>0:result.add(int(r['item']))
    return result
report=[]
for tid,t in sorted(A.Data.types.items()):
    if t.generic:continue
    cm=templates.get(int(tid));old={int(item) for _,item in t.loot.items()}
    if not cm:
        report.append({'id':int(tid),'name':t.name,'status':'no independent object template','currentCount':len(old)});continue
    lootid=int(cm['data1']) if int(cm['type'])==3 else 0
    expanded=expand(go[lootid]) if lootid else set()
    missing=expanded-old;extra=old-expanded
    report.append({'id':int(tid),'name':t.name,'independentName':cm['name'],'objectType':int(cm['type']),'lootID':lootid,'currentCount':len(old),'independentCount':len(expanded),'missingFromCurrent':sorted(missing),'onlyInCurrent':sorted(extra),'minCopper':int(cm['mingold']),'maxCopper':int(cm['maxgold']),'expandedItems':sorted(expanded),'status':'agreement' if old==expanded else 'source disagreement'})
result={'source':'cmangos/classic-db','commit':'ec4f596146be6467ea93c57397858e329e2db852','sqlSHA256':hashlib.sha256(raw).hexdigest(),'tablesChecked':['gameobject_template','gameobject_loot_template','reference_loot_template'],'types':report}
(W/'chest-loot-independent-audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('SUMMARY',dict(collections.Counter(r['status'] for r in report)))
for r in report:
    if r['id'] in (2843,2849,106318,106319,153453,153454,4149,32,179697,142184):print(json.dumps({k:v for k,v in r.items() if k not in ('expandedItems','missingFromCurrent','onlyInCurrent')},ensure_ascii=False))
print('BIGGEST DISAGREEMENTS',json.dumps([{'id':r['id'],'name':r['name'],'current':r['currentCount'],'independent':r.get('independentCount'),'missing':len(r.get('missingFromCurrent',[])),'extra':len(r.get('onlyInCurrent',[]))} for r in sorted(report,key=lambda r:len(r.get('missingFromCurrent',[]))+len(r.get('onlyInCurrent',[])),reverse=True)[:12]]))
