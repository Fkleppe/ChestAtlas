from pathlib import Path
import sys
WORK=Path(__file__).resolve().parent
ROOT=WORK.parent
VENDOR=Path(sys.argv[1]).resolve()/'ExternalLibs' if len(sys.argv)>1 else ROOT.parent/'RareScanner'/'ExternalLibs'
sys.path.insert(0,str(WORK/'python_libs'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(register_eval=False,register_builtins=False)
A=lua.table();load=lua.eval('function(s,A)return assert(loadstring(s))("ChestAtlas",A)end')
for name in ['Data.lua','CoverageData.lua','ClassicSpawnData.lua','ClassicLootData.lua','ClassicSpawnLoot.lua','RareData.lua','Core.lua','Features.lua','Rares.lua','Companion.lua','tests/wow_mock.lua','Runtime.lua','Widgets.lua','MapUI.lua']:
    load((ROOT/name).read_text(encoding='utf-8'),A)
lua.globals().A=A
lua.execute('''
function UnitFactionGroup()return "Alliance"end
function UnitClass()return "Hunter","HUNTER"end
function UnitRace()return "Night Elf","NightElf"end
function UnitName()return "Test Hunter"end
function GetLocale()return "enUS"end
function GetCurrentRegionName()return "EU"end
function GetCurrentRegion()return 3 end
function strlenutf8(s)return #s end
function securecallfunction(fn,...)return fn(...)end
Enum={GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}}
C_GameRules={IsGameRuleActive=function()return false end}
''')
for name in ['LibStub/LibStub.lua','CallbackHandler-1.0/CallbackHandler-1.0.lua','AceDB-3.0/AceDB-3.0.lua']:
    lua.execute((VENDOR/name).read_text(encoding='utf-8'))
lua.execute('''
local ace=LibStub:NewLibrary("AceAddon-3.0",1)
local rs
function ace:GetAddon(name)assert(name=="RareScanner");return rs end
local defaults={profile={general={scanRares=true,scanContainers=true,scanEvents=true},map={displayNpcIcons=true,displayContainerIcons=true,displayEventIcons=true},display={displayMiniature=false},loot={},collections={}}}
local function makeRS()
  local db=LibStub("AceDB-3.0"):New({},defaults,true)
  db:SetProfile("Original")
  local r={db=db}
  function r:RefreshOptions(_,database)self.privateProfile=database.profile end
  db.RegisterCallback(r,"OnProfileChanged","RefreshOptions")
  db.RegisterCallback(r,"OnProfileCopied","RefreshOptions")
  return r
end
A.Init(nil);A.UseJournal("test");A.Refresh=function()end
rs=makeRS()
local original=rs.db.profile;original.general.customSetting=42
assert(A.SetupRareScanner())
assert(rs.db:GetCurrentProfile()=="Chest Atlas" and rs.privateProfile==rs.db.profile)
rs.db:SetProfile("Original")
assert(rs.db.profile.general.scanContainers and rs.db.profile.map.displayContainerIcons and rs.db.profile.general.customSetting==42)
rs.db:SetProfile("Chest Atlas")
assert(rs.db.profile.general.customSetting==42 and not rs.privateProfile.general.scanContainers)
assert(not rs.privateProfile.map.displayContainerIcons and not rs.privateProfile.map.displayEventIcons)
assert(A.settings.focus and A.settings.category=="chests" and A.settings.rareScannerPairVersion==2)
-- Saved Both/Rares selections must never enable a second NPC layer when paired.
local rare=A.RareData.nodes[618][1];local chest=A.Data.nodes[618][1]
for _,category in ipairs({"both","rares","chests"})do
  A.settings.category=category;assert(not A.PassesExtra(rare) and A.PassesExtra(chest))
  local nodes=A.NodesForMap(83,"Winterspring");assert(#nodes>0)
  for _,n in ipairs(nodes)do assert(not n.rare,"Duplicate rare in paired map/minimap/list feed")end
end
for _,e in ipairs(A.TypeEntries())do assert(e.value>=0,"Duplicate rare picker")end
local commands={};SlashCmdList.ACECONSOLE_RS=function(c)commands[#commands+1]=c end
A.NextCategory();A.SetCategory("rares");A.SelectType(rare.typeID)
assert(#commands==3 and commands[1]=="explorer")
A.SetCategory("both");assert(A.settings.category=="chests")
-- Migration repairs an existing 0.3.1 profile without copying it over itself.
rs.privateProfile.map.displayContainerIcons=true;rs.privateProfile.general.scanContainers=true
rs.privateProfile.display.displayMiniature=false
A.settings.rareScannerPairVersion=1;assert(A.SetupRareScanner())
assert(not rs.privateProfile.map.displayContainerIcons and not rs.privateProfile.general.scanContainers)
assert(rs.privateProfile.display.displayMiniature==false,"Migration reset unrelated RS preferences")
A.settings.focus=false;A.SetupRareScanner();assert(not A.settings.focus,"Repeated migration forced focus back on")
rs=nil;A.settings.category="both";assert(A.PassesExtra(rare),"Standalone rare support removed")
assert(not A.SetupRareScanner())
-- RareScanner becomes ready after login: entering-world setup repairs pairing.
rs=makeRS();A.settings.rareScannerPairVersion=nil
A.events.scripts.OnEvent(A.events,"PLAYER_ENTERING_WORLD")
assert(A.settings.rareScannerPairVersion==2 and rs.db:GetCurrentProfile()=="Chest Atlas")
''')
print('PASS real RareScanner LibStub/AceDB pairing and profile callbacks, 0.3.1 migration, separate originals, no duplicate NPC feed, picker/shortcuts, late initialization and standalone fallback')
