"""Extract lock/opening data from the Forever client's DB2 tables (via wago.tools CSV export).

Writes tools/sources/forever-locks.json: Lock rows, lock-type names, the spells/items that open
each lock type (with skill), item-specific "Opening <object>" key spells, and instance map names.
Usage: python tools/extract_forever_locks.py [BUILD] [DIR_WITH_CSVS]
Without a directory the CSVs are downloaded from https://wago.tools/db2/<Table>/csv?build=BUILD.
"""
from pathlib import Path
import csv, io, json, sys, hashlib, urllib.request
from collections import defaultdict

R = Path(__file__).resolve().parents[1]
BUILD = sys.argv[1] if len(sys.argv) > 1 else '1.60.1.70338'
LOCAL = Path(sys.argv[2]) if len(sys.argv) > 2 else None
TABLES = ['Lock', 'LockType', 'SpellEffect', 'SpellName', 'ItemEffect', 'ItemXItemEffect', 'ItemSparse', 'Map']
digests = {}

def rows(name):
    if LOCAL and (LOCAL/f'{name}.csv').exists():
        raw = (LOCAL/f'{name}.csv').read_bytes()
    else:
        raw = urllib.request.urlopen(f'https://wago.tools/db2/{name}/csv?build={BUILD}', timeout=240).read()
    digests[name] = hashlib.sha256(raw).hexdigest()
    return list(csv.DictReader(io.StringIO(raw.decode('utf-8-sig'))))

locks = {}
for r in rows('Lock'):
    entries = []
    for i in range(8):
        t = int(r[f'Type_{i}'])
        if t: entries.append({'type': t, 'index': int(r[f'_Index_{i}']), 'skill': int(r[f'Skill_{i}'])})
    locks[int(r['ID'])] = entries
lockTypes = {int(r['ID']): r['Name_lang'] for r in rows('LockType')}
spellNames = {int(r['ID']): r['Name_lang'] for r in rows('SpellName')}
itemNames = {int(r['ID']): r['Display_lang'] for r in rows('ItemSparse')}
effectSpell = {int(r['ID']): int(r['SpellID']) for r in rows('ItemEffect')}
spellItems = defaultdict(list)
for r in rows('ItemXItemEffect'):
    s = effectSpell.get(int(r['ItemEffectID']))
    if s: spellItems[s].append(int(r['ItemID']))
openers = defaultdict(list)   # lock type -> [{spell,name,skill,items}]
for r in rows('SpellEffect'):
    if r['Effect'] == '33':   # SPELL_EFFECT_OPEN_LOCK; misc = lock type, base points = skill
        s = int(r['SpellID'])
        openers[int(r['EffectMiscValue_0'])].append({'spell': s, 'name': spellNames.get(s, ''), 'skill': int(float(r['EffectBasePointsF'] or 0)),
            'items': sorted({i: itemNames.get(i, '') for i in spellItems.get(s, [])}.items())})
instances = {int(r['ID']): r['MapName_lang'] for r in rows('Map') if r['InstanceType'] in ('1', '2')}
out = {'build': BUILD, 'source': 'Forever client DB2 via wago.tools CSV export', 'sha256': digests,
       'locks': locks, 'lockTypes': lockTypes, 'openers': openers, 'instances': instances}
(R/'tools'/'sources'/'forever-locks.json').write_text(json.dumps(out, indent=1, sort_keys=True), encoding='utf-8')
print('locks', len(locks), 'opener lock types', len(openers), 'instances', len(instances))
