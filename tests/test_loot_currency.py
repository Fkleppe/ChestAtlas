from pathlib import Path
import sys, re, gzip, collections, runpy, math
R=Path(__file__).resolve().parents[1];W=R/'tools'
sys.path.insert(0,str(R/'tests/python_libs'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(register_eval=False,register_builtins=False);A=lua.table()
load=lua.eval('function(s,A)assert(loadstring(s))("ChestAtlas",A)end')
for f in ['Data.lua','CoverageData.lua','ClassicLootData.lua','RareData.lua','Core.lua','Features.lua','Rares.lua','Companion.lua','tests/wow_mock.lua','Runtime.lua','Widgets.lua']:
    load((R/f).read_text(encoding='utf-8'),A)
lua.globals().A=A
lua.execute('''
A.Init(nil);A.UseJournal("sort-test");A.RefreshUI=function()end;A.UpdateNavigation=function()end
local data={[777001]={"A",1,100},[777002]={"B",2,0},[777003]={"C",3,nil},[777004]={"D",1,500}}
C_Item={GetItemInfo=function(id)local i=data[id];if i then return i[1],"item:"..id,i[2],1,1,"","",1,"",134400,i[3]end end}
A.Data.types[999999]={name="Sort fixture",loot={777001}}
A.ClassicLoot[999999]={available=true,loot={777001,777002,777003,777004},chances={[777001]=10,[777002]=0,[777003]=80},uncertainty={[777004]="Conditional"},cash={minCopper=0,maxCopper=123}}
local n={typeID=999999,contents={[777002]={count=1}}}
local b=A.Widgets.Loot(UIParent,0,0,400,4);b:SetNode(n)
local expected={valueDesc={777004,777001,777002,777003},valueAsc={777002,777001,777004,777003},chanceDesc={777003,777001,777002,777004},chanceAsc={777002,777001,777003,777004}}
for mode,ids in pairs(expected)do
 A.settings.lootSort=mode;b:Refresh()
 for i,id in ipairs(ids)do assert(b.rows[i].item.id==id,mode.." row "..i)end
 assert(b.best.item.id==777004,"Sort changed most valuable highlight")
end
local picker
A.OpenPicker=function(anchor,title,entries,current,callback)picker={title=title,entries=entries,callback=callback}end
b.sort.scripts.OnClick(b.sort);assert(picker.title=="Sort loot" and #picker.entries==4)
b.page=2;picker.callback("chanceDesc");assert(b.page==1 and A.settings.lootSort=="chanceDesc")
A.InitSettings();assert(A.settings.lootSort=="chanceDesc","Sort was not persisted")
b.search:SetText("A");assert(b.rows[1].item.id==777001 and not b.rows[2]:IsShown())
b.search:SetText("");b.source.scripts.OnClick(b.source);assert(#picker.entries==3)
picker.callback("pf");assert(b.rows[1].item.id==777001 and not b.rows[2]:IsShown() and b.best.item.id==777001)
assert(A.DropChance(n,777001,"pf")==nil,"Chance leaked between source tables")
b.source.scripts.OnClick(b.source);picker.callback("legacy");assert(b.best.item.id==777004 and b.rows[1].item.id==777003,"Source cache stale")
b.source.scripts.OnClick(b.source);picker.callback("own");assert(b.rows[1].item.id==777002 and b.rows[1].item.chance==nil)
assert(A.CashRange(n).minCopper==0 and A.CashRange(n).maxCopper==123)
assert(A.CashText(n):find("0c",1,true) and A.CashText(n):find("1s 23c",1,true))
assert(A.CashText({typeID=153454}):find("8s 16c–15s 94c",1,true))
assert(A.CashRange({typeID=0})==nil and A.DropChance({typeID=0},777001)==nil)
assert(A.CashRange({typeID=-1,rare=true})==nil)
assert(A.DropChance(n,777002)==0 and A.ChanceText(n,777002):find("0%",1,true))
assert(A.DropChance(n,777004)==nil)
''')
print('PASS four sort directions, known zero vs missing, source switching, filters, most valuable highlight, picker actions, persisted sort, recorded loot, cash units and unknowns')
# Independent numeric-prefix parser: it does not use the builder's CSV/tuple parser.
sql=gzip.decompress((W/'sources/cmangos-classic.sql.gz').read_bytes()).decode('utf-8')
# Independent template tail fields: schema ends mingold, maxgold, StringId, ScriptName.
cash={}
for block in re.findall(r'INSERT INTO `gameobject_template` VALUES (.*?);\n',sql,re.S):
    records=re.findall(r"\((\d+),.*?,(\d+),(\d+),(\d+),'(?:\\.|[^'])*'\)(?:,|$)",block)
    assert len(records)==block.count('),(')+1
    for tid,lo,hi,_ in records:cash[int(tid)]=(int(lo),int(hi))
for tid,t in A.ClassicLoot.items():
    if tid==999999:continue
    if t.objectType==3:assert (t.cash.minCopper,t.cash.maxCopper)==cash[int(tid)]
    else:assert t.cash is None
print('PASS all 135 exact currency ranges against independent SQL tail-field parsing')
tables={}
for name in ['gameobject_loot_template','reference_loot_template']:
    d=collections.defaultdict(list)
    for block in re.findall(r'INSERT INTO `'+name+r'` VALUES (.*?);\n',sql,re.S):
        records=re.findall(r"\((\d+),(\d+),(-?[\d.]+),(\d+),(-?\d+),(\d+),(\d+),'",block)
        assert len(records)==block.count('),(')+1
        for entry,item,chance,group,count,maxcount,condition in records:
            d[int(entry)].append((int(item),float(chance),int(group),int(count),int(maxcount),int(condition)))
    tables[name]=d
links=0
for tid,t in A.ClassicLoot.items():
    if tid==999999:continue
    queue=[int(t.lootID)];seen=set();items=set()
    while queue:
        entry=queue.pop();table=tables['gameobject_loot_template'] if not seen else tables['reference_loot_template']
        # Separate root and reference traversal; do not rely on recursion from builder.
        rows=table.get(entry,[]);seen.add(entry)
        for item,chance,group,count,maxcount,condition in rows:
            assert count!=0 and maxcount>=1 and (chance!=0 or group!=0)
            if count<0:
                assert chance>0 and -count not in seen
                queue.append(-count)
            elif item>0:items.add(item)
    actual={int(v) for _,v in t.loot.items()}
    assert actual==items,(tid,len(actual),len(items))
    assert bool(t.available)==bool(int(t.lootID) and tables['gameobject_loot_template'].get(int(t.lootID)))
    links+=len(items)
    numeric={int(k) for k,_ in t.chances.items()};unknown={int(k) for k,_ in t.uncertainty.items()}
    assert numeric.isdisjoint(unknown) and numeric|unknown==items
    for _,v in t.chances.items():assert math.isfinite(v) and 0<=v<=100
assert links==18303
print('PASS independent numeric SQL parser: all 150 exact object item sets, 18,303 links, valid grouped entries/reference rows, complete chance-or-unknown coverage')
build=runpy.run_path(str(W/'build_classic_loot.py'));paths=build['paths'];audit=build['audit']
def row(item,chance,group=0,count=1,maxcount=1,condition=0):
    return dict(item=str(item),ChanceOrQuestChance=str(chance),groupid=str(group),mincountOrRef=str(count),maxcount=str(maxcount),condition_id=str(condition))
p=paths([row(1,20,1),row(2,0,1),row(3,0,1)])
assert [p[i][0]['percent'] for i in (1,2,3)]==[20,40,40]
audit.refs[999999]=[row(2,50),row(3,50)]
p=paths([row(0,10,count=-999999)])
assert p[2][0]['percent']==5 and not p[2][0]['issues']
p=paths([row(0,10,count=-999999,maxcount=2)]);assert 'Repeated reference rolls' in p[2][0]['issues']
p=paths([row(1,10),row(1,20)]);assert len(p[1])==2
p=paths([row(1,0,1),row(2,-20,1)]);assert 'Conditional loot group' in p[1][0]['issues']
p=paths([row(1,20,condition=4)]);assert p[1][0]['issues']
p=paths([row(1,80,1),row(2,80,1)]);assert 'Overfull loot group' in p[1][0]['issues']
print('PASS hand-calculated mixed equal group and activated reference probabilities; repeated, multi-path, quest/conditional and overfull uncertainty')
