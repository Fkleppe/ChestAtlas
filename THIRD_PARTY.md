# Sources and attribution

`Data.lua` is a filtered and reformatted subset of pfQuest's Vanilla data.
The frozen base retains 20 ordinary chest variants and 34 outdoor zones. Coordinates are
normalized from percentages to 0-1, duplicates removed and object-to-item lists built
from item-to-object data. Source percentages are omitted. Rough zone-level ranges
were added by Chest Atlas; they are not chest-database fields. Nothing is marked
Forever-confirmed.

- Project: https://github.com/shagu/pfQuest
- Pinned commit: `104f35678ca39ab1fb78b655f815cc7016f5e0c8`
- Files: `db/objects.lua`, `db/items.lua`, `db/enUS/objects.lua`,
  `db/enUS/items.lua`, `db/enUS/zones.lua`.
- MIT license, Copyright (c) 2017-2021 Eric Mauser (Shagu).
  The unmodified license is included in `LICENSE-pfQuest.txt`.
- pfQuest describes its Vanilla database as based on VMaNGOS.
- `coords[4]` is interpreted as historical respawn in seconds because pfQuest's
  `database.lua` unpacks `x, y, zone, respawn` and displays `SecondsToTime(respawn)`.
  This establishes the source field's meaning, not its applicability to Forever.

Client API references inspected on October 5, 2026:

- https://github.com/Gethe/wow-ui-source/tree/forever
  Client UI/API mirror pinned for validation at
  `e3ecc27b64d30fdc735a3f6579b866858f9f9df1`.
  Tests execute MapCanvas and its frame-level manager with simulated native widgets.
  Client runtime files are fetched separately for tests and are not distributed
  with, or loaded by, the addon.
- https://github.com/Thunderz96/forever-addon-kit
  Early beta observations used to check available API names.
- https://github.com/wowdev/wow-listfile
  Used to verify native treasure chest texture paths.

The chest icon uses Blizzard's native `VignetteLoot` atlas with native texture fallbacks.
Blizzard artwork is read from the installed client and is not redistributed.
`Media/Sparkle.tga` and `Media/Arrow.tga` are original Chest Atlas artwork covered by
`LICENSE.txt`. WoW names, items and content belong to Blizzard and their owners.

RareData.lua uses the same pinned MIT-licensed pfQuest source: db/units.lua,
db/enUS/units.lua, db/meta.lua, db/items.lua and English item/zone names.
The source extractor selects rank 2 or 4 into meta.rares. NPC-item links come
from items.data[itemID].U, never vendor or gameobject associations. Only recorded
outdoor-zone coordinates are retained. See tools/rare_manifest.json for source hashes.

## Additive coverage (0.3.3)

CoverageData.lua preserves the frozen base and appends 3,367 pfQuest coordinates
from the same MIT source. The broader selection includes ordinary/faction chests,
locked strongboxes and footlockers, supply containers, quest/special interactions,
key/event treasure, clams and selected collectibles. English names, coordinates and
item links come from pfQuest. Category/hint text is authored by Chest Atlas; Classic
requirements are never promoted to confirmed Forever requirements.

576 additional family-level observations come from the Classic Era file
of GatherMate2 Data Wowhead. Family pseudo-IDs are NOT gameobject IDs. Since 0.4.1,
they show a clearly labelled union of possible loot from same-name historical
variants represented in the same zone; if none occur in that zone, the display
explicitly falls back to family-wide candidates. This does not identify the exact
variant or assign per-chest probabilities, currency or timers. Candidate object IDs
and scope are displayed under Sources; the raw frozen reference modules are unchanged.
Category separation keeps
quest clams distinct from ordinary clam references even when the names match.

- Source: https://gitlab.com/marhag87/gathermate2_data_wowhead
- File: GatherMate2_Data/Era/TreasureData.lua
- Commit: 2a8840c4cfec43f85b87348839bbbb0c139f148a
- SHA256: e60be016eefc607b863072d30e1e283876787d3765d8ccb89cc500a1d57a3aeb
- License: WTFPL v2; unmodified LICENSE-GatherMate2-Data.txt included.
- Family codes: GatherMate2 Constants.lua (ordinary chest, clam, footlocker and collectible codes).
- Encoding: XXXXYYYY00; explicit Classic Era UiMapID -> AreaID conversion.
- New observations within 0.15% map distance of an accepted same-family AND same-category
  record are deduplicated. Original individual records are not moved or clustered.

Audit-only comparison inspected cmangos/classic-db Full_DB snapshot at
ec4f596146be6467ea93c57397858e329e2db852 (GPL v3) and Vanilla WorldMapArea bounds
from TheGrayDot/wow-vanilla-world-coords. That 0.3.3 comparison did not distribute CM spawn coordinates or DBC bounds.
The 0.3.5 additions described below now distribute separate reference positions.
The 0.3.4 loot/currency module is described below. Summary findings are authored
audit results in tools/reverse_audit_summary.json. 1,052 of 1,057 outdoor
chest/strongbox spawns have a same-family pack reference within 40 world yards.
Five positional disagreements remain unresolved; this Full_DB snapshot excludes
later SQL updates and is not proof of current Forever spawns. The forward comparison
of ordinary chest observations found 1,286/1,531 within 40 yards; 280 of 431 initially
unmatched observations had additional historical support. These are source agreement
counts, not confirmed live chest counts or proof of unique physical locations.

## Full Classic loot and currency (0.3.4)

ClassicLootData.lua is extracted CMaNGOS Classic DB reference data, GPL v3. The
combined release is distributed under GPL v3; original Chest Atlas and pfQuest MIT
components retain their notices. COPYING.txt and LICENSE-CMaNGOS.txt contain the
full license. Complete compressed SQL and English name source are bundled under
tools/sources/, with tools/build_classic_loot.py and tools/audit_classic_loot.py.

- Project: https://github.com/cmangos/classic-db
- Commit: ec4f596146be6467ea93c57397858e329e2db852
- File: Full_DB/ClassicDB_1_12_1_z2815.sql.gz
- SHA256: 4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0
- Tables: gameobject_template, gameobject_loot_template, reference_loot_template.
- This Full_DB snapshot excludes subsequent Updates SQL.
- Semantics: https://github.com/cmangos/issues/wiki/loot_template and
  https://github.com/cmangos/issues/wiki/gameobject_template
- Money/rate and eligibility behavior inspected in CMaNGOS LootMgr.cpp.

Exact IDs select loot IDs; references expand recursively with cycle/missing checks.
No data is unioned between databases or inferred from chest names. Original tables
remain available for comparison/fallback. Static 1x estimates exclude complex and
conditional paths; Forever rates/eligibility are unverified. See the per-type manifest
in tools/loot_currency_manifest.json. English item names use pinned pfQuest above.

The same pinned pfQuest toolbox/extractor.lua only exports positive direct object
chances. Expanding db/refloot.lua added zero items for selected chest types; missing
direct equal-share grouped entries are the demonstrated export gap.

## Current Classic spawns (0.3.5)

ClassicSpawnData.lua combines original MIT pfQuest references with additional
CMaNGOS/VMaNGOS reference positions. The combined distribution remains GPL v3.
VMaNGOS's source notice grants GPL v2 or later; the full GPL v2 text is included
in LICENSE-VMaNGOS.txt and its upstream notice in tools/sources/vm-GPL-notice.txt.
CMaNGOS GPL v3 and pfQuest MIT notices remain included. New loot/currency references
in ClassicSpawnLoot.lua derive from the same pinned 0.3.4 CMaNGOS full snapshot,
not from a merged loot table or new probability assumption.

- CMaNGOS development DB, 2026-10-06: https://github.com/cmangos/classic-db/releases/tag/latest
- Asset classic-sqlite-db.zip, ID 615443317, digest
  071bdfd864dfd75cb20fae1fb8e26a2c28ae0308ca0058aa691c30b74630d40c
- VMaNGOS development DB, 2026-09-28: https://github.com/vmangos/core/releases/tag/db_latest
- Asset db-sqlite-4641790.zip, ID 595362291, digest
  bb2f1dd69171043a52657574f54948fd30941530fdc6eec12bce62c655428501
- WorldMapArea.csv: 1.12.1.5875 client data documented by
  https://github.com/TheGrayDot/wow-vanilla-world-coords
- Projection bounds are factual client coordinates; Blizzard content ownership remains.

Source SQLite fixtures copy raw rows of gameobject_template/gameobject and CM
gameobject_spawn_entry. They omit unrelated tables and database constraints/indexes.
All corresponding data consumed by the generator is bundled with hashes. Full source
asset manifests, derived audit, raw pfQuest source, map bounds and generator/test
source are included under tools/. Scope/exclusions/projection rules and per-record
provenance are in tools/current-chest-spawn-audit.json and current_spawn_manifest.json.
The moving release URLs identify the project; asset ID and digest identify the copy.
No live Forever availability, exact source agreement or complete dungeon coverage is
claimed. Family/proximity coverage is not exact GUID/loot-variant completeness.
