"""Build InstanceData.lua: treasure chests inside dungeons/raids, how to open them, and their Classic loot.

Sources (all bundled under tools/sources):
  * cm-classicmangos.sqlite / vm-mangos.sqlite  - spawns, templates, flags, respawn sign
  * cmangos-classic.sql.gz                      - gameobject/reference loot tables (same snapshot as 0.3.4)
  * forever-locks.json                          - Forever client Lock/LockType/SpellEffect/Item data
  * db_enUS_items.lua                           - English item names (pfQuest)
Also emits A.ClassicObjectIDs: every lootable Classic object entry (types 3/17/25) in either database,
used at runtime to recognise objects that do not exist in Classic data (Forever discoveries).
Usage: python tools/build_instance_chests.py [--report]
"""
from pathlib import Path
import re, gzip, csv, sys, json, hashlib, sqlite3, collections
from lupa.lua51 import LuaRuntime

R = Path(__file__).resolve().parents[1]; S = R/'tools'/'sources'
REPORT = '--report' in sys.argv
F = json.loads((S/'forever-locks.json').read_text(encoding='utf-8'))
LOCKS = {int(k): v for k, v in F['locks'].items()}
OPENERS = {int(k): v for k, v in F['openers'].items()}
INSTANCES = {int(k): v for k, v in F['instances'].items()}
FOREVER_NAMES = {i: n for ops in OPENERS.values() for op in ops for i, n in op['items'] if n}

# ---- CMaNGOS loot tables (same parser as tools/audit_classic_loot.py) ----
raw = (S/'cmangos-classic.sql.gz').read_bytes()
assert hashlib.sha256(raw).hexdigest() == '4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0', 'Pinned SQL source hash mismatch'
sql = gzip.decompress(raw).decode('utf-8')
def table(name):
    schema = re.search(r'CREATE TABLE `'+name+r'` \((.*?)\) ENGINE', sql, re.S)
    columns = re.findall(r'^\s*`([^`]+)`', schema[1], re.M); records = []
    for ins in re.finditer(r'INSERT INTO `'+name+r'` VALUES (.*?);\n', sql, re.S):
        text = ins[1]; quote = escape = False; depth = 0; start = None
        for i, c in enumerate(text):
            if escape: escape = False; continue
            if quote and c == '\\': escape = True; continue
            if c == "'": quote = not quote; continue
            if quote: continue
            if c == '(':
                if depth == 0: start = i+1
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    values = next(csv.reader([text[start:i]], delimiter=',', quotechar="'", escapechar='\\'))
                    assert len(values) == len(columns); records.append(dict(zip(columns, values)))
    return records
go = collections.defaultdict(list); refs = collections.defaultdict(list)
for name, dest in [('gameobject_loot_template', go), ('reference_loot_template', refs)]:
    for r in table(name): dest[int(r['entry'])].append(r)
def expand(rows, path=()):
    out = set()
    for r in rows:
        n = int(r['mincountOrRef'])
        if n < 0: assert -n not in path; out |= expand(refs[-n], path+(-n,))
        elif int(r['item']) > 0: out.add(int(r['item']))
    return out
def paths(rows, activation=1, issues=(), trail=()):   # identical policy to tools/build_classic_loot.py
    result = collections.defaultdict(list); grouped = collections.defaultdict(list)
    for r in rows:
        if int(r['groupid']): grouped[int(r['groupid'])].append(r)
    for r in rows:
        chance = float(r['ChanceOrQuestChance']); group = int(r['groupid']); count = int(r['mincountOrRef']); flags = list(issues)
        if int(r['condition_id']) or chance < 0: flags.append('Quest / player conditions')
        if group:
            members = grouped[group]; total = sum(abs(float(m['ChanceOrQuestChance'])) for m in members); zeroes = sum(float(m['ChanceOrQuestChance']) == 0 for m in members)
            if total > 100.000001: flags.append('Overfull loot group')
            if any(int(m['condition_id']) or float(m['ChanceOrQuestChance']) < 0 for m in members): flags.append('Conditional loot group')
            prob = (max(0, 100-total)/zeroes if chance == 0 and zeroes else abs(chance))/100
        else:
            prob = min(1, abs(chance)/100)
            if chance == 0: flags.append('Zero chance outside group')
        if count < 0:
            ref = -count; assert ref not in trail and ref in refs
            if int(r['maxcount']) != 1: flags.append('Repeated reference rolls')
            for item, ps in paths(refs[ref], activation*prob, tuple(flags), trail+(ref,)).items(): result[item] += ps
        elif int(r['item']) > 0:
            result[int(r['item'])].append({'percent': activation*prob*100, 'issues': sorted(set(flags))})
    return result
def questOnly(rows):
    """True when every item path is a quest drop (negative chance), i.e. a quest container."""
    flat = []
    def walk(rs, trail=()):
        for r in rs:
            n = int(r['mincountOrRef'])
            if n < 0: walk(refs[-n], trail+(-n,))
            elif int(r['item']) > 0: flat.append(float(r['ChanceOrQuestChance']) < 0)
    walk(rows); return bool(flat) and all(flat)

# ---- spawns and templates ----
cm = sqlite3.connect(S/'cm-classicmangos.sqlite'); vm = sqlite3.connect(S/'vm-mangos.sqlite')
ctpl = {r[0]: r for r in cm.execute('select entry,type,name,flags,data0,data1,mingold,maxgold from gameobject_template')}
vtpl = {}
for r in vm.execute('select entry,patch,type,name,flags,data0,data1,mingold,maxgold from gameobject_template order by patch'):
    if r[1] <= 10: vtpl[r[0]] = (r[0],) + r[2:]
known = sorted({e for e, t in ((e, r[1]) for e, r in ctpl.items()) if t in (3, 17, 25)} | {e for e, r in vtpl.items() if r[1] in (3, 17, 25)})
spawns = collections.defaultdict(lambda: {'cm': 0, 'vm': 0, 'event': 0, 'total': 0})
points = collections.defaultdict(list)   # (map, entry) -> VM positions, to find shared spawn points
alt = collections.defaultdict(list)
for g, e in cm.execute('select guid,entry from gameobject_spawn_entry'): alt[g].append(e)
for g, i, m, t in cm.execute('select guid,id,map,spawntimesecsmin from gameobject'):
    for e in ([i] if i else []) + alt.get(g, []):
        if m in INSTANCES and e in ctpl and ctpl[e][1] == 3:
            s = spawns[(m, e)]; s['cm'] += 1
for i, m, t, pmin, pmax, x, y, z in vm.execute('select id,map,spawntimesecsmin,patch_min,patch_max,position_x,position_y,position_z from gameobject'):
    if m in INSTANCES and pmin <= 10 <= pmax and i in vtpl and vtpl[i][1] == 3:
        s = spawns[(m, i)]; s['vm'] += 1; s['event'] += t < 0; points[(m, i)].append((x, y, z))
def shared(m, a, b):
    return sum(1 for p in points[(m, a)] if any(sum((p[k]-q[k])**2 for k in range(3)) < 9 for q in points[(m, b)]))

CHEST = re.compile(r'(Chest|Coffer|Cache|Strongbox|Tribute|Treasure)', re.I)
NOT_CHEST = re.compile(r'(Crate|Parcel|Belongings|Box of)', re.I)
# Community-known triggers; only stated where well established. Everything else is derived from data.
TRIGGERS = {'Cache of the Firelord': 'Appears after defeating Majordomo Executus.',
    'Four Horsemen Chest': 'Appears after defeating the Four Horsemen.',
    'Chest of The Seven': 'Appears after defeating the Seven (Gloom\'rel event).',
    'Gordok Tribute': 'Appears after King Gordok dies; rewards depend on surviving guards (tribute run).',
    "Baelog's Chest": 'Belongs to the Lost Dwarves encounter (Baelog, Eric, Olaf).'}
KEYWORDS = ('Skeleton Key', "Scroll of Khadgar")   # 'Tome of Khadgar's Unlocking' items are unused Vanilla leftovers
# Item-specific key spells can name test items with no source; require a pfQuest source for those.
NO_SOURCE = {int(i) for i in re.findall(r'^  \[(\d+)\] = \{\},', (S/'db_items.lua').read_text(encoding='utf-8', errors='ignore'), re.M)}

def requirement(entry, name, flags, lock):
    entries = LOCKS.get(lock, [])
    keys = [e['index'] for e in entries if e['type'] == 1]
    pick = [e['skill'] for e in entries if e['type'] == 2 and e['index'] == 1]
    named = []   # item-specific key spells ("Opening Relic Coffer")
    for op in OPENERS.get(0, []):
        if op['name'].lower() in ('opening ' + name.lower(), 'opening ' + name.lower().replace('large ', 'greater ')):
            named += [i for i, _ in op['items'] if i not in NO_SOURCE]
    locked = bool(flags & 0x2)
    req = {'lockID': lock, 'locked': locked}
    if keys or named: req['keys'] = sorted(set(keys + named))
    if pick and (locked or not keys):
        skill = max(pick)
        if skill > 1 or locked:
            req['pickLock'] = skill
            req['tools'] = sorted({(i, n, op['skill']) for op in OPENERS.get(1, []) for i, n in op['items']
                                  if op['skill'] >= skill and any(k in n for k in KEYWORDS)}, key=lambda t: (t[2], t[0]))
    return req

itemsLua = LuaRuntime(register_eval=False, register_builtins=False)
E = itemsLua.table(pfDB=itemsLua.table(items=itemsLua.table()))
itemsLua.eval('function(s,e)local f=assert(loadstring(s));setfenv(f,e);f()end')((S/'db_enUS_items.lua').read_text(encoding='utf-8'), E)
def itemName(i): return E.pfDB['items'].enUS[i]

instances = collections.defaultdict(list); types = {}; loot = {}; names = {}; report = []
chosen = []
for (m, e), s in sorted(spawns.items()):
    t = ctpl.get(e) or vtpl.get(e); _, _, name, flags, lock, lootid, gmin, gmax = t
    if not CHEST.search(name) or NOT_CHEST.search(name): continue
    rows = go.get(int(ctpl[e][5]) if e in ctpl else 0, [])
    if questOnly(rows): report.append({'map': m, 'entry': e, 'name': name, 'excluded': 'quest-only loot'}); continue
    flags = (ctpl[e][3] if e in ctpl else 0) | (vtpl[e][3] if e in vtpl else 0)
    req = requirement(e, name, flags, lock)
    computed = paths(rows); chances = {}; uncertainty = {}
    for item, ps in computed.items():
        issues = {i for p in ps for i in p['issues']}
        if len(ps) != 1: issues.add('Multiple loot paths')
        if issues: uncertainty[item] = '; '.join(sorted(issues))
        else: chances[item] = ps[0]['percent']
    items = sorted(expand(rows))
    for i in items + req.get('keys', []) + [k for k, _, _ in req.get('tools', [])]:
        n = itemName(i) or FOREVER_NAMES.get(i)
        if n: names[i] = n
    event = s['vm'] > 0 and s['event'] == s['vm']
    entry = {'typeID': e, 'spawns': s['vm'] or s['cm'], 'sources': ('VM' if s['vm'] else '') + ('CM' if s['cm'] else ''),
             'event': event, 'trigger': TRIGGERS.get(name), **{k: v for k, v in req.items() if k != 'tools'},
             'tools': [k for k, _, _ in req.get('tools', [])]}
    instances[m].append(entry); chosen.append((m, e))
    types[e] = {'name': name, 'loot': items, 'category': 'instance', 'hint': 'Inside ' + INSTANCES[m] + '.'}
    loot[e] = {'loot': items, 'available': bool(rows), 'cash': {'minCopper': int(gmin), 'maxCopper': int(gmax)},
               'chances': chances, 'uncertainty': uncertainty, 'objectType': 3}
    report.append({'map': m, 'instance': INSTANCES[m], 'entry': e, 'name': name, 'spawns': entry['spawns'], 'sources': entry['sources'],
                   'flags': flags, 'event': event, 'items': len(items), **{k: v for k, v in req.items()}})

for m, e in chosen:   # alternate variants that occupy the same spawn point (e.g. Solid vs Mithril Bound)
    for c in instances[m]:
        if c['typeID'] == e:
            others = {o: shared(m, e, o) for mm, o in chosen if mm == m and o != e}
            c['sharesWith'] = sorted(o for o, n in others.items() if n)
            for r in report:
                if r.get('map') == m and r.get('entry') == e: r['sharesWith'] = c['sharesWith']
if REPORT:
    for r in report: print(json.dumps(r, ensure_ascii=False))
    sys.exit()

def lua(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'nil'
    if isinstance(v, (int,)): return str(v)
    if isinstance(v, float): return repr(round(v, 6))
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list): return '{' + ','.join(lua(x) for x in v) + '}'
    if isinstance(v, dict):
        return '{' + ','.join(f'[{k}]={lua(x)}' if isinstance(k, int) else f'[{json.dumps(k)}]={lua(x)}' for k, x in v.items() if x is not None) + '}'
    raise TypeError(v)
inst = {m: {'name': INSTANCES[m], 'chests': c} for m, c in sorted(instances.items())}
src = ('-- Treasure chests inside dungeons/raids. Spawns/loot: CMaNGOS/VMaNGOS (GPL-3.0). Opening requirements:\n'
       '-- Forever client Lock/Spell/Item data ' + F['build'] + '. Built by tools/build_instance_chests.py.\n'
       'local _,A=...\n'
       'A.Instances=' + lua(inst) + '\n'
       'A.ForeverInstances=' + lua(INSTANCES) + '\n'
       'local types=' + lua(types) + '\n'
       'for id,t in pairs(types)do if not A.Data.types[id] then A.Data.types[id]=t end end\n'
       'local loot=' + lua(loot) + '\n'
       'for id,t in pairs(loot)do if not A.ClassicLoot[id] then A.ClassicLoot[id]=t end end\n'
       'local names=' + lua(names) + '\n'
       'for id,name in pairs(names)do A.Data.items[id]=A.Data.items[id] or name end\n'
       '-- Every lootable Classic object entry (types 3/17/25). Anything else looted is a Forever discovery.\n'
       'local known={' + ','.join(map(str, known)) + '}\n'
       'A.ClassicObjectIDs={}\nfor _,id in ipairs(known)do A.ClassicObjectIDs[id]=true end\n')
(R/'InstanceData.lua').write_text(src, encoding='utf-8', newline='\n')
manifest = {'forever': {'build': F['build'], 'sha256': F['sha256']}, 'sqlSHA256': hashlib.sha256(raw).hexdigest(),
            'moduleSHA256': hashlib.sha256(src.encode()).hexdigest(), 'instances': len(inst),
            'chestTypes': sum(len(c) for c in instances.values()), 'spawnPoints': sum(c['spawns'] for v in instances.values() for c in v),
            'knownClassicObjects': len(known), 'rows': report}
(R/'tools'/'instance_chest_manifest.json').write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding='utf-8')
print(json.dumps({k: v for k, v in manifest.items() if k != 'rows'}, indent=1))
