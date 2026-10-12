local _,A=...
-- Integrate through AceAddon/AceDB and RareScanner's existing slash commands.
-- No RareScanner code or reference data is copied or patched.
function A.GetRareScanner()
  if not LibStub then return end
  local ok,lib=pcall(LibStub,"AceAddon-3.0",true)
  if not ok or not lib or not lib.GetAddon then return end
  local found,addon=pcall(lib.GetAddon,lib,"RareScanner",true)
  if found and addon and addon.db and addon.db.profile then return addon end
end
function A.CompanionActive()return A.GetRareScanner()~=nil end
function A.SetupRareScanner()
  local rs=A.GetRareScanner()
  if not rs or not A.settings then return false end
  if A.settings.rareScannerPairVersion==2 then return true end
  local db=rs.db
  if not db.SetProfile or not db.GetCurrentProfile or not db.GetProfiles or not db.CopyProfile then return false end
  local previous=db:GetCurrentProfile();local exists=false
  for _,name in ipairs(db:GetProfiles())do if name=="Chest Atlas"then exists=true end end
  db:SetProfile("Chest Atlas")
  if not exists and previous~="Chest Atlas" then
    db:CopyProfile(previous)
  end
  local p=db.profile
  -- Repair the owned companion profile even if it was created by an earlier version.
  -- Other RareScanner profiles remain intact.
  for _,key in ipairs({"general","map","display","loot","collections"})do
    if type(p[key])~="table" then p[key]={}end
  end
  p.general.scanRares=true;p.general.scanContainers=false;p.general.scanEvents=false
  p.map.displayNpcIcons=true;p.map.displayContainerIcons=false;p.map.displayEventIcons=false
  if not exists then
    p.general.enableWaypointsSupport=true;p.general.autoWaypoints=false
    p.map.displayMinimapIcons=true;p.display.displayMiniature=true
    p.loot.displayLoot=true;p.loot.displayLootOnMap=true
    p.collections.showWithoutCollectibles=true
  end
  if previous~="Chest Atlas" then A.settings.rareScannerPreviousProfile=previous end
  A.settings.rareScannerPairVersion=2
  A.settings.category="chests";A.filters.typeID=math.max(0,A.filters.typeID)
  A.settings.focus=true;A.settings.showPins=true
  A.selected=nil
  A.Print("RareScanner companion ready: Chest Atlas shows chests; RareScanner shows rares. /rs explorer opens the rare browser. Enable enemy nameplates for nearby alerts.")
  return true
end
function A.RareScannerCommand(command)
  if command~="explorer" and command~="route" and command~="croute" then return false end
  local handler=SlashCmdList and SlashCmdList.ACECONSOLE_RS
  if not A.CompanionActive() or not handler then A.Print("Enable RareScanner Forever and restart WoW to use this feature.");return false end
  local ok=pcall(handler,command)
  if not ok then A.Print("RareScanner could not open this feature. Check the first Lua error.")end
  return ok
end
