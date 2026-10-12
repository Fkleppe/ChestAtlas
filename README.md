# Chest Atlas 0.6.0

## Install on another PC

1. Close WoW.
2. In `World of Warcraft\_classic_beta_\Interface\AddOns\`, run
   `git clone https://github.com/Fkleppe/ChestAtlas.git`
   (or download the ZIP from GitHub and unpack it there as a folder named `ChestAtlas`).
3. Start WoW. Update later with `git pull` inside the `ChestAtlas` folder, then restart WoW.

Your journal (looted chests, discoveries, dungeon log) is not part of the addon folder. It lives in
`WTF\Account\<ACCOUNT>\SavedVariables\ChestAtlas.lua`. Move it with `/ca backup` on one PC and
`/ca import` on the other, or copy that file while WoW is closed.

## Dungeon and raid chests (0.6.0)

`/ca dungeons` (or **Dungeon chests** in the Atlas, **Dungeons** on the map toolbar)
lists 43 treasure chest types in 20 dungeons and raids, 235 Classic spawn points,
with full Classic loot. Forever has no dungeon maps (its UiMap table holds only zones,
continents and battlegrounds) and no player coordinates inside instances, so chests
are listed per instance instead of pinned. Entering an instance prints its chests.

Opening requirements come from the Forever client's own Lock, LockType, SpellEffect
and Item tables (build 1.60.1.70338), combined with each chest's lock and "locked" flag:
- **Key**: Relic Coffer Key (BRD Relic Coffers), Dark Keeper Key (Dark Coffer),
  Scarab Coffer Key (AQ20) and Greater Scarab Coffer Key (AQ40).
- **Locked**: Rogue Pick Lock at the listed skill (Iron Bound 1/25/70/125, Uldaman
  Mithril Bound 175, BRS/Stratholme/Dire Maul Mithril Bound 275), or a Blacksmithing
  skeleton key with enough skill (Silver 25, Golden 125, Truesilver 200, Arcanite 300).
  The client also contains a new Forever "Scroll of Khadgar's Unlocking" (125).
  Seaforium charges do not apply: none of these locks accepts Blasting.
- **After encounter**: Cache of the Firelord, Four Horsemen Chest, Chest of The Seven,
  Gordok Tribute and Knot Thimblejack's Cache are spawned by the fight or event.
Iron/Mithril Bound chests share their spawn points with Large Solid/Darkwood chests:
each point holds one of them. The panel shows keys you carry and your Lockpicking.
Quest-only containers (crates, parcels, quest strongboxes) are left out.

Looting inside an instance is logged per instance (counts, last loot, contents).
Nothing is written to open-world locations. **Forever discoveries**: anything you loot
whose object ID is in neither Classic database (876 known lootable objects) is saved
with its name from your cast target or mouseover, in the open world as a journal
location, in instances under that instance. Loot right after Herbalism, Mining,
Fishing or Skinning is never a discovery. Backups include discoveries and instance logs.

Rebuild: `python tools/extract_forever_locks.py`, then `python tools/build_instance_chests.py`.
**Restart WoW completely**: InstanceData.lua and Instances.lua are new TOC files.

## Automatic chest journal (0.5.0)

Looting a known chest now records it for you. When the loot window closes, Chest
Atlas reads the loot source's object GUID. If it is a single known container
object, the find is linked to the nearest same-family marker within about 1% of the
zone map, marked looted and its loot window contents are stored. No button is needed.
The marker shows **L** with the time since you looted it.

Every later loot of the same spot with a **new object GUID** counts as respawn
evidence. The details show the shortest gap you observed, for example "Respawned
within 20 min at least once". This is real Forever evidence from your own play,
not a guaranteed timer: a different layer can make the gap look shorter. Reopening
the same spawn (same GUID) is never counted. Coin-only chests are attributed too.

Creature/player loot, mixed sources, quest/special objects and unknown objects
(herbs, ore, fishing) are ignored. During a **Chest route**, looting the current
stop's chest moves to the next stop automatically. Next/Skip still work for empty
spots. Turn it off with `/ca auto` or **Map and filters > Auto-log looted chests**.
Loot counts and respawn gaps are included in `/ca backup`. The manual journal
buttons still work. `/reload` is enough; no new files were added to the TOC.

Every one of the 10,173 historical reference markers has been checked against
its original coordinate source and loot-table links. The per-marker audit is
in `AUDIT-ALL-CHESTS.csv`; counts and limits are in `AUDIT-SUMMARY.json`.
There were zero source discrepancies. 10,092 markers have documented possible
loot; 81 quest/special locations have no historical item list. This verifies
the bundled references, not actual Forever spawns or server loot.

## Missing family loot (0.4.1)

All 576 family-level reference markers now display possible historical loot.
The reported Battered Chest at 10.4, 22.6 in Ashenvale is included. Candidate
variants are limited to the same family in the same historical zone, with an
explicit family-wide fallback where zone candidates are absent. Sources lists
the candidate object IDs. This is a union of possibilities, not one confirmed
chest table: not every listed item belongs to every variant.

Family markers keep unknown probabilities and coin ranges; the frequent-drop
filter is disabled until an exact variant is known. Recorded finds can still
resolve their exact variant through existing loot-source checks. Best-value
and item-search caches respect zone boundaries. Exact object loot, coordinates,
stable IDs, favorites and personal journals are preserved. Some quest/special
objects genuinely have no historical item table in the bundled sources.

Restart WoW completely to load the new module/file list in this release.

The custom rare NPC module has been removed. Chest Atlas loads chest data only,
even if RareScanner is disabled. Rare browser/route shortcuts open RareScanner;
old NPC type/category filters migrate to chests. The installed RareScanner is
preserved. Removing the separate AzerothUI Christmas addon also requires restarting
WoW so its already-loaded hooks and textures are discarded.

## Chest routes and clearer details (0.4.0)

The map toolbar now starts a **Chest route**, independently of RareScanner.
The Atlas window has the same shortcut. `/ca route` builds a visit order from
the current zone's filtered chest locations, starting near your player position.
Linked historical/personal finds share one stop; rares are excluded.
Routes use straight-line map-world distances, without terrain or enemy checks.
Start in the target zone outside combat. For more than 150 stops, narrow the
filters or choose favorites. An active route keeps its original stop list when
you change filters. Routes are session-only and do not resume after reload.

Use **Next stop** (`/ca next`) or **Skip stop** (`/ca skip`) to advance manually.
Reaching a location does not advance it, detect a chest, or write to the journal.
**Stop route** (`/ca stop`) clears only an owned native waypoint. Choosing a new
individual waypoint ends the visit route. RareScanner routes remain separate,
under **Rare routes** in the Atlas.

Both detail views have **Loot / Journal / Sources** tabs. Navigation and favorite
controls remain above the tabs. Notes, loot capture and manual respawn estimates
are in Journal; source IDs and historical limits are in Sources. Map tooltips
show name, coordinates/distance, personal status and click controls.

**S** (mint) means personally seen; **L** (amber) means marked looted by you.
Linked historical pins also display your observation. Neither is a live spawn
indicator. The list and detail header show the same status.

The highest-vendor card now displays the historical probability alongside the
possible item. **All drops** toggles to **Frequent drops (Classic ≥1%)** for full
Classic tables, excluding unknown probabilities and rare possibilities below
the threshold. The top-value card stays visible for context. This is a static
Classic estimate, not a measured Forever rate. Changing to recorded loot or a
source without probabilities clears this filter.

Lua 5.1, existing regression suites, route state and all detail tabs were tested.
See TEST-RESULTS.txt for the exact live-validation status. No reference spawn,
loot table, personal SavedVariables or RareScanner files were replaced.
The TOC load list is unchanged; `/reload` loads this update in a running client.

Forum research (8 October 2026): see FORUM-RESEARCH.txt. Anecdotal fishing chest
rates and conflicting supply-crate claims were not added to the loot tables.


## Classic spawn completeness audit (0.3.5)

This release expands 4,973 reference locations to **10,173**, across **45 zones/cities**
and **433 object/family types**. It adds 5,200 locations: 4,548 additional pinned
pfQuest references and 652 positions from current CMaNGOS/VMaNGOS snapshots.
Only 29 additions are ordinary treasure-chest locations. The rest include quest loot,
supply containers, footlockers and collectibles. Keep **Treasure chests** selected for
ordinary treasure; choose **Filters > All containers** to include the other categories.
General quest objects include lootable plants, books, eggs and supplies: a chest icon
marks a loot reference, not a promise that the object is shaped like a wooden chest.

The audit selects every server CHEST/type-3 template by object type, independent of
its name. Profession herbs/mining nodes, test/deprecated objects and CM templates
absent from Vanilla references are excluded. VMaNGOS uses active patch 10 (1.12)
spawns and the latest eligible template version. CMaNGOS alternative spawn entries
are expanded; these were missed by a simple gameobject.id scan. Events/pools are
possible source positions, never claims that every marker is spawned simultaneously.

The resulting pack covers all **20,160** valid outdoor/city source records from the
two databases as same-family map references within **0.15% map distance**. These are
two source inventories, with duplicates/alternative variants, not 20,160 unique chests.
That tolerance can merge nearby observations; it is not proof of every exact server
GUID or loot variant. Data.lua, CoverageData.lua, RareData.lua and the original
ClassicLootData.lua are preserved; new records append without changing existing IDs.
Exact variant details remain historical rather than live validation. The original
loot tables remain intact; 272 new exact types receive separate same-snapshot loot
references (426 item links). Missing or conditional probabilities remain unknown.

Two VMaNGOS Imprisoned Doomguard records lie outside every supported zone on their
recorded continent. They are retained in the audit with a rejection reason, rather
than moved to a guessed map. **3,119 dungeon/raid/battleground source records** are
inventoried separately and are **not placed on the world/minimap** in this release.
Therefore this is not a claim of every Classic chest everywhere or all live Forever
positions. Live Forever loot/map geometry is unverified; Classic server references
are the working baseline.

Cities use their own historical map bounds; outdoor overlaps use source anchors.
These are 1.12 world-to-map projections, not navigation mesh/terrain measurements.
Source labels identify VMaNGOS or CMaNGOS additions. Icons, arrow, minimap, vendor/
chance sort and RareScanner separation remain available. Fully exit and restart WoW:
ClassicSpawnData.lua and ClassicSpawnLoot.lua are new TOC files.

## Full Classic loot, coins and sorting (0.3.4)

The default **Classic loot** choice uses the full CMaNGOS Classic snapshot where
available, matched by exact gameobject ID. All reference pools are expanded.
The old pfQuest item-object export omits direct grouped entries with stored chance
zero: these share the remainder of their group, rather than having no chance.
All 150 exact object types were audited; 68 source tables differ. The full snapshot
supplies 125 usable tables, 18,303 item associations and 2,375 English item names.
Solid Chest #153454, for example, changes from 123 to 492 associated items.
These are independent historical sources, neither a confirmed Forever loot table.

The source picker offers **Classic loot**, **Vanilla loot** (original pfQuest list),
and **Recorded loot**. If the full snapshot has no table, the original list remains
as fallback. Family-only locations receive no guessed loot, coins or percentages.
The complete table also powers the most valuable item in lists and navigation.

**Classic coins** is direct money inside a chest, separate from item vendor value.
Exact mingold/maxgold fields are copper at 1x server money rate. #153454 has
8s 16c–15s 94c in this snapshot. A historical 0c range does not prove Forever has
zero coins. Missing exact currency references display unknown; hover for context.

The loot sort button next to the quality filter offers Value and Drop chance in
both directions. Unknowns always stay last. The most valuable card stays pinned.
**Classic est.** percentages use static 1x chances, remaining probability divided
among equal-share entries, and activation probabilities for single reference paths.
Repeated rolls, multiple paths, conditional/quest groups and overfull groups remain
**Chance unknown**. There are 18,238 numeric and 65 unknown item associations.
Eligibility, quality/rate multipliers, duplicate suppression, loot limits and later
database updates can change actual results. These are not measured Forever rates.
Original pfQuest and recorded lists receive no fabricated probabilities.

This release preserves all 4,973 location records. World chest icons retain the
50% size reduction (10/13/16 px presets); minimap/rare sizes are unchanged.
It does not establish that every live Forever spawn is mapped.

Completely exit and restart WoW after updating: the TOC has a new data file.
All interface text is English.

## New overlay and most valuable loot

Dark slate panels, gold accents, compact buttons, larger location cards and selected-row
highlights replace the old dense list. Each location row includes an item icon, name and
the highest known per-item vendor value. Hover the item to see its full tooltip.
The map details, full Atlas and navigation overlay retain the same value highlight.
Loot has a **Sort** picker: Value highest/lowest first and Drop chance highest/lowest first.
Value means vendor sell price for one item. Missing values always sort last, including
in ascending order. The saved choice applies across panels and resets the page.
Quality/name/item ID break ties. The most valuable card stays pinned under every sort.
The highlight is independent of loot pagination, search, quality and recorded-loot mode.

Prices come from the running client's item API, never an invented auction-house estimate.
The card shows how many item prices are available. Missing prices stay unknown and may
change which item leads when the client supplies more data. Requests cover the whole
possible loot table and run in batches of six per 0.2 seconds. Failed requests are not
repeated during the session. Values are for one item, not a stack or expected profit.
Unknown personal chest types use recorded contents when no reference loot table exists.
Historical possible loot does not guarantee that a particular item will drop.

## RareScanner companion

Install RareScanner's Forever package, currently `RareScanner_FOREVER_1.60.1.b7.zip`:
https://www.curseforge.com/wow/addons/rarescanner/files/9055146
RareScanner remains a separate addon and is not bundled, forked or patched.
After a full WoW restart, enable both addons. Chest Atlas creates a dedicated
**Chest Atlas** RareScanner profile, copies the previous profile into it and enables
rare map/minimap icons, nearby rare alerts, model previews and loot. Container/event
icons and scanning are disabled in that profile to keep Chest Atlas responsible for
chests. Your earlier RareScanner profiles remain intact; switch them in its settings.
Version 0.3.2 repairs container/event settings in the owned companion profile,
including profiles created by 0.3.1. Other RareScanner profiles stay intact.

When RareScanner is active, Atlas renders and lists chests only, including on the
minimap. Saved `Both` or `Rares` selections cannot duplicate RareScanner NPC pins.
The category shortcut opens RareScanner instead of enabling another rare overlay.
Atlas retains standalone rare support when RareScanner is disabled. First migration
enables focus mode, retaining player/group and RareScanner pins while hiding unrelated
native markers. You can turn focus off. Setup also retries on entering the world if
RareScanner was not ready at PLAYER_LOGIN. Loot and models for rares belong to RS;
chest loot, value highlights, journal and chest navigation belong to Atlas.

The Atlas window and map toolbar provide **Rare browser** and **Farm route** shortcuts.
Enable enemy nameplates with **V** for nearby detection. Classic/Forever detection does
not provide a zone-wide live radar. RareScanner's data and Forever support are beta.

- `/rs explorer`: rare browser with models and loot where available.
- `/rs route`: start a visiting route between the currently active rare map markers.
- `/rs croute`: stop the visiting route.
- RareScanner's options control alerts, sounds, filters and custom NPCs.

The visiting route is a route for the player; it does not establish an NPC's patrol.
RareScanner can display its recorded map overlays; some are spawn/search areas rather
than ordered patrols. Chest Atlas's historical coordinates remain unordered positions.
Neither addon can promise a spawn is currently alive or a precise Forever respawn timer.

## Rares on the world map and minimap

This release adds 334 historical rare NPCs, 423 recorded locations and 5,570 NPC-item
associations across 37 outdoor zones. The classification, names, levels, locations and
loot associations come from the pinned pfQuest Vanilla source and were independently
validated. These records are unverified on Forever and do not detect a living NPC.

Use the **Both / Chests / Rares** button on the map toolbar or full Atlas to switch
categories. **Filters** offers the same choice and a searchable location-type picker.
The choice applies to both maps. Both categories are enabled by default after upgrading.
The existing source, zone-level, search and favorite filters still apply. Selecting Rares
changes a personal-only source filter to Vanilla references, because rare journal capture
is not supported.

Rare markers use Blizzard's VignetteKill atlas, with an icon fallback. Hover shows name,
NPC level, coordinates and historical details. Left-click shows the possible loot table;
right-click starts a waypoint and arrow. Minimap markers follow position, zoom and rotation.
You can search rare names, NPC IDs, possible item names or item IDs, favorite a location
and export/import favorites. Every source position has its own icon by default. Rare and
chest markers never combine into the same cluster when optional grouping is enabled.

NPCs can patrol between positions; markers are historical coordinates, not an exact patrol
route. Source respawns remain historical references; live availability and Forever timers
are unknown. Loot lists can include rare world drops and conditional items and do not
promise guaranteed loot or drop chances. Required item level is separate from NPC level.
Chest observations and loot capture remain chest-only; these controls are disabled for rares.

## Layout corrections in 0.2.2

Loot panels now reserve space for every row and their page controls. Following buttons
and footnotes anchor to the panel's bottom instead of fixed offsets. Rows have separate
bounded name and metadata lines. Button labels stay within their button and reveal full
text on hover. Empty results, first/last-page controls and item-quality labels are clearer.
The Atlas, detail card, navigation and backup windows have revised spacing and screen fit.
Item metadata explicitly labels the required level; it is not a chest or zone level.

All 1,030 coordinates, 20 variants, 3,580 chest-item links and 1,525 item names were
independently compared with the pinned upstream source. The source files were fetched
again and checked byte-for-byte. No coordinate or loot mismatches were found.
Guard/patrol data is unavailable: a chest marker is not a guarantee of a safe location.

Seven panels were checked for overlapping controls and content outside their parent,
with diagnostic renders of actual Lua frame geometry and approximate text metrics.
Screen fit was checked at 1280x720, 1920x1080 and 2560x1440. These checks do not replace
visual verification in the real client.

Chest locations, possible historical loot and a personal field journal for WoW: Forever.
The pack contains 4,973 historical container records in 38 outdoor zones.
1,489 ordinary/faction chest records are shown by default; other categories are optional.
These Vanilla locations and loot tables have not been confirmed on Forever.

## Map and minimap

- Every known spawn has its own icon by default. Upgrading from 0.2.0 also turns
  grouping off once. Icons mark possible locations, not chests detected alive.
- Icons use Blizzard's treasure chest artwork with a gold glow and animated glint.
  Blizzard artwork is read from the client and is not bundled with this addon.
- Hover shows chest type and coordinates. Left-click opens details and possible loot.
  Right-click sets a waypoint and starts the arrow. **Go here + arrow** on the details
  card does the same for the selected location.
- Nearby locations also appear on the minimap, following movement, zoom and rotation.
  Locations outside its visible area are hidden. The minimap follows your current zone
  even when you view another zone on the world map.
- The map toolbar offers **Chests**, **Atlas only**, filters and the full list.
  Appearance settings independently toggle world map and minimap icons, permanent
  labels, icon size and optional grouping. With grouping explicitly enabled, a number
  means nearby locations grouped under one icon. Select an exact location using the
  previous/next buttons on its card. The original coordinates remain intact.
- **Atlas only** hides other MapCanvas markers, including quests and points of interest.
  Map artwork stays visible; player/group markers can be kept or hidden. Turning it off
  restores its suppressed markers. Icons drawn outside MapCanvas are not controlled.
- A green **+** marks a personal find; a **\*** marks a favorite.

The movable arrow shows direction relative to your character and straight-line distance
in meters. It does not calculate a walking route. In another zone it shows the destination
zone. Position restrictions, including combat, pause navigation and minimap placement.
**Stop arrow** clears the native waypoint only if it still matches Chest Atlas's target.

## Filters and loot

Search by chest type, possible item name, item ID or personal notes. Zone and chest-type
pickers have search fields. Filter by source, approximate zone level and favorites,
and sort by distance or type. Zone levels are rough Vanilla recommendations, not
opening requirements or a guarantee of safety.

The item panel switches between possible Vanilla loot and your recorded contents.
It has icons, quality filters, search and pagination. Hover opens the game's item tooltip;
Shift-click inserts a link into the chat editor. Quality, required level and vendor price
appear when the client supplies item information. Vendor price is per item, not an
auction-house estimate. Uncached items remain visible.

Possible loot is the historical table for the exact chest variant, including rare world
drops. Items are not guaranteed. Variants can share a name; object IDs distinguish
their loot tables. The English reference name is used where available.

## Personal journal

Stand beside a chest outside combat and choose **New find here**, or use `/ca add 2843`
for a Battered Chest variant. `/ca add` records an unknown type that you can change later.
Coordinates come from your player position and are approximate.

At a historical location, **Record personal find** creates an observation near your position
without replacing the reference. Nearby personal findings of the same type are reused.
**Mark seen now** updates your observation time; **Mark looted** records that you looted it.
Neither action detects current availability.

After opening a chest, select your personal location and use **Record latest loot window
(manual)** within 90 seconds while still nearby. Identified creature/player loot, mismatched
chest types, mixed object sources and previously attached snapshots are rejected. When
the source ID is unavailable, the association is your manual observation. This records
contents seen in the loot window, not items actually taken. Autoloot or client restrictions
may prevent complete capture. Observation counts are not drop chances.

## Respawn information

Reliable Forever respawn timers are unknown. Historical source values are 300 seconds
(5 minutes) and 7,200 seconds (2 hours), from an old emulator-based Vanilla database.
Spawn pools, layers, changed locations and Forever rules may differ. There is no confirmed
shared daily/weekly reset for these ordinary chests.

For personal locations, save your own estimate in minutes. The addon shows time since
you marked the location looted. After the estimate expires it says **Availability unknown**.
Clear the field to remove an estimate. It cannot identify layers, other players' looting
or a different location chosen by a spawn pool.

## Commands

| Command | Action |
|---|---|
| `/ca` | Open full list, contents and journal |
| `/ca map` | Open world map |
| `/ca focus` | Toggle Atlas only |
| `/ca auto` | Toggle automatic logging of looted chests |
| `/ca dungeons` | Dungeon and raid chests, keys and loot |
| `/ca route` / `/ca next` / `/ca skip` | Chest route in the current zone |
| `/ca stop` | Stop navigation |
| `/ca reset` | Reset filters, preserving journal and favorites |
| `/ca status` | Version, map, world/minimap icon counts and drawing errors |
| `/ca add [objectID]` | Record a personal find at your position |
| `/ca backup` / `/ca import` | Export/import journal text |
| `/ca bind <areaID>` | Bind the current map to a reference zone |

## Installation and storage

Close WoW completely, copy `ChestAtlas` into the Forever client's `Interface\AddOns`
folder and start WoW again. The path must end with `ChestAtlas\ChestAtlas.toc`.
Enable **Chest Atlas** in the addon list. This update adds a module and the separate RareScanner companion,
so use a full client restart when upgrading. Both standard and `_Camelot.toc` manifests
support interface 16001/160001 and use Blizzard_WorldMap. No third-party addon is required.

Journal, settings and favorites use `ChestAtlasDB` SavedVariables in the client's WTF
folder. Entries are separated by region, realm and recognized Forever/other client.
Updating does not require deleting SavedVariables. `/ca backup` opens export text;
select all and copy it with Ctrl+C into a text file. `/ca import` validates a backup for
your region/realm before merging entries; matching IDs are updated. Favorites are included
in text backups; appearance settings are stored locally.

If a renamed map is not recognized, open the correct zone and bind it manually.
Reference area IDs include Elwynn Forest 12, Dun Morogh 1, Durotar 14, Mulgore 215,
Tirisfal Glades 85, Teldrassil 141, Westfall 40 and The Barrens 17. A binding does not
prove old coordinates fit a changed map.

## Validation

Lua 5.1 syntax, data integrity, filtering, observations, backup/import and UI construction
are tested. The pinned Forever client's actual MapCanvas and frame-level manager run
with simulated native widgets. Tests cover every default-category Teldrassil reference pin, focus
restoration, individual-spawn migration, minimap geometry/rotation/zoom/interaction
and exact waypoints. This updated version has not been visually verified in the real client.
See `TEST-RESULTS.txt` for the complete scope.

After restarting, check map/minimap icons and hover information, then right-click a
location to check the arrow. At a real chest, compare its position and record a find.
Export a backup before checking persistence through `/reload`, logout and restart.
If a problem remains, preserve `/ca status` output and the first Lua error.

Developer checks require Python and `lupa`: run `tests/test_chestatlas.py`,
`tools/fetch_validation_sources.py`, then `tests/test_mapcanvas.py`. Fixture downloads
are pinned and never run in WoW. `tools/build_data.py` rebuilds the pack from pinned
pfQuest data. See `THIRD_PARTY.md` for attribution.

## Expanded chest coverage (0.3.3)

The full pack has 4,973 historical references across 38 outdoor zones.
The 1,489 ordinary/faction chest records include the previously omitted
Alterac Mountains and Alliance/Horde Chests. Separate filters expose supplies/clams,
lockpicking objects, quest/special interactions, key/event treasure and collectibles.
Open the world map -> Filters -> Containers -> All containers to inspect everything.
Reset filters returns to ordinary treasure chests. An exact type overrides category.

The original 1,030 references and stable journal/favorite IDs are unchanged.
3,367 additional pfQuest records and 576 deduplicated Classic Wowhead
observations extend the dataset. Item links are checked against exact pfQuest object IDs.
Source-only families show **variant unknown**, with no guessed loot table or timer.
Recording an actual same-family loot source can resolve a personal generic record.
Map, minimap and list share filters; every selected point supports exact waypoints.

All 2,436 eligible GatherMate Classic observations and every eligible pfQuest
container coordinate were checked. A reverse audit of 1,057 CMaNGOS outdoor
chest/strongbox spawns found 1,052 same-family pack references within 40 yards;
five position discrepancies remain documented in tools/reverse_audit_summary.json.
No claim of complete Forever coverage, current availability or confirmed respawns is made.
Instance locations and source types without outdoor coordinates are not fabricated.

Restart the client completely so the new CoverageData.lua TOC module is indexed.
Clear saved type/source/level filters if expected markers are hidden. Coverage rules,
excluded types, categories, sources and hashes are in tools/coverage_manifest.json.
The frozen base builder reconstructs the original pack; the additive builder and
coverage tests accept the saved audit fixture directory as a command-line argument.

## Reproduce the 0.3.4 loot audit

Python with lupa (Lua 5.1) is required. Pinned SQL and English name sources are
bundled under tools/sources/. Run `python tools/build_classic_loot.py`, then
`python tests/test_loot_currency.py`. Independent numeric SQL parsing checks all
exact item sets; tests also exercise sort/source controls, currency units and
hand-calculated probability cases. Runtime/layout checks simulate native widgets;
live Forever rendering and server loot have not been verified.

The combined release is distributed under GPL v3 because ClassicLootData.lua derives
from CMaNGOS. Original MIT components retain their component licenses. See COPYING.txt,
LICENSE-CMaNGOS.txt and THIRD_PARTY.md. Addon and generator source is included.

## Reproduce the current spawn audit

Tools include read-only SQLite source-table fixtures, exact copied source rows,
source asset IDs/digests, fixture hashes, pinned pfQuest data and 1.12 map bounds.
Run `python tools/audit_current_spawns.py`, `python tools/build_current_spawns.py`,
and `python tools/build_current_spawn_loot.py`. Run
`python tests/test_current_spawns.py PATH_TO_PINNED_FOREVER_UI_FIXTURES` for independent
SQL selection, coverage, unchanged IDs, additional loot and native MapCanvas mocks.
Fetch the UI fixtures with tools/fetch_validation_sources.py when needed.
Current source-table fixtures include only the tables consumed by the generator;
whole upstream databases are available at the manifest's URLs and verified digests.
