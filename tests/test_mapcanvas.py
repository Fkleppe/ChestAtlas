from pathlib import Path
import sys,json,zipfile,re,random
import xml.etree.ElementTree as ET

WORK=Path(__file__).resolve().parent
ROOT=WORK.parent
SOURCE=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else WORK/'forever_sources'
if not (SOURCE/'manifest.json').exists():
    raise SystemExit('Fetch pinned fixtures with tools/fetch_validation_sources.py or pass their directory.')
sys.path.insert(0,str(WORK/'python_libs'))
from lupa.lua51 import LuaRuntime

def new_runtime():
    lua=LuaRuntime(register_eval=False,register_builtins=False)
    A=lua.table()
    load=lua.eval('function(code,A) return assert(loadstring(code))("ChestAtlas",A) end')
    for file in ['Data.lua','CoverageData.lua','ClassicSpawnData.lua','ClassicLootData.lua','ClassicSpawnLoot.lua','RareData.lua','Core.lua','Features.lua','Rares.lua','Companion.lua']:
        load((ROOT/file).read_text(encoding='utf-8'),A)
    lua.globals().A=A
    lua.globals().expectedTeldrassil=sum(A.ContainerCategory(n.typeID)=='treasure' for _,n in A.Data.nodes[141].items())
    load((ROOT/'tests'/'wow_mock.lua').read_text(encoding='utf-8'),A)
    return lua,A,load

lua,A,load=new_runtime()
# Execute the real client mixins with native Frame/pool primitives simulated.
lua.execute('''
CallbackRegistryMixin={}
TaggableObjectMixin={RemoveAllTags=function(self)self.tags={}end}
InputUtil={IsGamepadUIEnabled=function()return false end}
Minimap=CreateFrame("Frame");Minimap:SetSize(200,200);Minimap:Show()
C_Minimap={GetViewRadius=function()return 200 end,IsRotateMinimapIgnored=function()return false end}
function C_Map.GetMapWorldSize()return 1000,2000 end
''')
lua.execute((SOURCE/'MapCanvas_DataProviderBase.lua').read_text(encoding='utf-8'))
lua.execute((SOURCE/'Blizzard_MapCanvas.lua').read_text(encoding='utf-8'))
lua.execute('function Clamp(v,lo,hi)return math.max(lo,math.min(hi,v))end')
lua.execute((SOURCE/'MapCanvas_PinFrameLevelsManager.lua').read_text(encoding='utf-8'))
lua.globals().nativeWorldMapSource=(SOURCE/'Blizzard_WorldMap.lua').read_text(encoding='utf-8')
load((WORK/'native_map_harness.lua').read_text(encoding='utf-8'),A)
for file in ['Runtime.lua','Navigation.lua','Widgets.lua','MapUI.lua','Minimap.lua','UI.lua']:load((ROOT/file).read_text(encoding='utf-8'),A)
lua.execute('''
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","ChestAtlas")
A.settings.category="chests"
A.settings.cluster=false
A.events.scripts.OnEvent(A.events,"PLAYER_LOGIN")
assert(A.provider and A.provider.owningMap==WorldMapFrame)
A.provider:RefreshAllData()
local pool=WorldMapFrame.pinPools.ChestAtlasPinTemplate
assert(pool and pool:GetNumActive()>0,"No native map pins rendered")
local pin=pool.active[1]
assert(pin.Icon.texture==A.iconPath and pin.normalizedX and pin.anchor,"Pin texture/position missing")
assert(pin.Label.text==A.TypeName(pin.node.typeID),"Permanent chest-type label missing")
local levels=WorldMapFrame:GetPinFrameLevelsManager()
assert(levels:GetValidFrameLevel(nil)<levels:GetValidFrameLevel("PIN_FRAME_LEVEL_FOG_OF_WAR"),"Regression setup lacks fog above default pins")
assert(pin.frameLevel>levels:GetValidFrameLevel("PIN_FRAME_LEVEL_FOG_OF_WAR"),"Chest hidden under fog")
assert(pin.frameLevel>levels:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_EXPLORATION"),"Chest hidden under exploration")
assert(pin:GetFrameLevelType()=="PIN_FRAME_LEVEL_CHESTATLAS")
assert(pin.scripts.OnEnter and pin.scripts.OnMouseUp,"MapCanvas handlers missing")
pin.shimmerTime=0;pin.shimmerPhase=0;pin.scripts.OnUpdate(pin,0.5)
assert(pin.Sparkle.alpha>0.9 and pin.Glow.alpha>0.2,"Shimmer did not light up")
pin.scripts.OnUpdate(pin,1);assert(pin.Sparkle.alpha==0,"Shimmer did not fade out")
C_Texture={GetAtlasInfo=function(name)return name=="VignetteLoot" and {} end}
A.ApplyChestIcon(pin.Icon);assert(pin.Icon.atlas=="VignetteLoot","Wrong native chest atlas")
C_Texture=nil
-- Right-click must use the pin's current map, even before the Atlas window opens.
A.displayMapID=nil
pin.scripts.OnMouseUp(pin,"RightButton",true)
assert(MockWaypoint and MockWaypoint.map==37,"Waypoint map was not taken from pin")
pin.scripts.OnEnter(pin);pin.scripts.OnLeave(pin)
local clickedNode=pin.node
pin.scripts.OnMouseUp(pin,"LeftButton",true)
assert(A.selected==clickedNode and ChestAtlasMapDetail:IsShown())
local firstCount=pool:GetNumActive()
A.provider:RefreshAllData()
assert(pool:GetNumActive()==firstCount,"Pin pool refresh lost nodes")
-- Teldrassil must show references independently of the character's location.
WorldMapFrame.mapID=57
A.provider:RefreshAllData()
assert(pool:GetNumActive()>0,"Teldrassil references missing")
assert(A.ResolveArea(57,"Teldrassil")==141)
pin=pool.active[1]
A.displayMapID=37
pin.scripts.OnMouseUp(pin,"RightButton",true)
assert(MockWaypoint.map==57,"Pin incorrectly reused Atlas window map")
-- Cycles release old pins rather than accumulating hidden or stale pins.
for i=1,20 do A.provider:RefreshAllData()end
assert(pool:GetNumActive()==expectedTeldrassil)
A.filters.source="own";A.provider:RefreshAllData();assert(pool:GetNumActive()==0)
A.filters.source="legacy";A.provider:RefreshAllData();assert(pool:GetNumActive()>0)
pool:ReleaseAll();assert(pool:GetNumActive()==0)
WorldMapFrame:Show();assert(pool:GetNumActive()==expectedTeldrassil,"Opening map did not refresh pins")
''')
print('PASS actual Forever MapCanvas: acquire, reuse, release, positioning, click, hover, Teldrassil')

# Integration of focus, item cards, settings, grouping and compass direction.
lua.execute(r''' 
local canvas=WorldMapFrame:GetCanvas()
local pool=WorldMapFrame.pinPools.ChestAtlasPinTemplate
local otherPool=CreateFramePool("FRAME",canvas,nil,function()end)
WorldMapFrame.pinPools.OtherPins=otherPool
local function other(name)
  local pin=otherPool:Acquire();Mixin(pin,MapCanvasPinMixin);pin.pinTemplate=name;pin:SetOwningMap(WorldMapFrame);pin:Show();return pin
end
local quest=other("QuestOfferPinTemplate")
local player=other("GroupMembersPinTemplate")
local fog=other("FogOfWarPinTemplate")
local external=other("ExternalQuestPinTemplate");local owner={};external:SetSuppressed(owner)
A.settings.focus=true;A.provider:RefreshAllData();WorldMapFrame:UpdatePinSuppression()
assert(not quest:IsShown() and quest:IsSuppressed(),"Focus failed to hide quest pins")
assert(player:IsShown() and fog:IsShown(),"Focus hid player/artwork")
assert(external:GetPinSuppressor()==owner,"Focus stole another suppressor's pin")
assert(pool.active[1]:IsShown(),"Focus hid chest pins")
local late=other("VignettePinTemplate")
local focus=WorldMapFrame.pinPools.ChestAtlasFocusTemplate.active[1]
focus.scripts.OnUpdate(focus,0.25);WorldMapFrame:UpdatePinSuppression()
assert(not late:IsShown(),"Late pin escaped focus")
A.settings.keepPlayer=false;A.provider:RefreshAllData();WorldMapFrame:UpdatePinSuppression()
assert(not player:IsShown(),"Player toggle did not hide units")
A.settings.focus=false;A.provider:RefreshAllData();WorldMapFrame:UpdatePinSuppression()
assert(quest:IsShown() and late:IsShown() and player:IsShown(),"Focus did not restore pins")
assert(external:GetPinSuppressor()==owner,"Focus cleared someone else's suppression")
A.settings.showPins=false;A.Refresh();assert(pool:GetNumActive()==0)
A.settings.showPins=true;A.settings.cluster=true;A.Refresh()
assert(pool:GetNumActive()<expectedTeldrassil and pool:GetNumActive()>0,"Dense chests were not grouped")
local grouped=0
for _,pin in ipairs(pool.active) do grouped=grouped+#pin.group.nodes;assert(not pin.Label:IsShown()) end
assert(grouped==expectedTeldrassil,"Grouping lost spawn points")
local clustered
for _,pin in ipairs(pool.active) do if #pin.group.nodes>1 then clustered=pin;break end end
assert(clustered and clustered.Count.text~="")
clustered.scripts.OnEnter(clustered);assert(clustered.Label:IsShown())
clustered.scripts.OnLeave(clustered);assert(not clustered.Label:IsShown())
clustered.scripts.OnMouseUp(clustered,"LeftButton",true)
assert(A.mapDetail:IsShown() and #A.mapDetail.nodes>1)
A.mapDetail.next.scripts.OnClick(A.mapDetail.next)
assert(A.selected==A.mapDetail.nodes[2],"Cluster selection lost exact node")
A.mapDetail.go.scripts.OnClick(A.mapDetail.go)
assert(A.navFrame:IsShown() and MockWaypoint.map==57 and MockWaypoint.x==A.selected.x and MockWaypoint.y==A.selected.y,"Go-here button failed exact waypoint")
local n=A.selected;A.ToggleFavorite(n);assert(A.IsFavorite(n))
A.filters.favoritesOnly=true;A.Refresh();assert(A.expectedPins==1)
A.filters.favoritesOnly=false;A.filters.query="117";A.Refresh()
assert(A.expectedPins>0,"Item ID search lost known drops")
A.ResetFilters();assert(A.filters.query=="" and not A.filters.favoritesOnly)
A.ShowMapSettings();assert(ChestAtlasMapSettings:IsShown())
A.OpenPicker(A.toolbar,"Zones",A.ZoneEntries(),0,function()end)
assert(ChestAtlasPicker:IsShown())
ChestAtlasPicker.search:SetText("Teldrassil")
assert(ChestAtlasPicker.rows[1].entry.value==141)
-- Four compass directions, turning and physical map aspect ratio.
local angle,dist=A.NavigationVector(0.5,0.5,0.5,0.4,1000,2000,0)
assert(math.abs(angle)<0.0001 and math.abs(dist-200)<0.0001)
angle=A.NavigationVector(0.5,0.5,0.6,0.5,1000,2000,0);assert(math.abs(angle+math.pi/2)<0.0001)
angle=A.NavigationVector(0.5,0.5,0.4,0.5,1000,2000,0);assert(math.abs(angle-math.pi/2)<0.0001)
angle=A.NavigationVector(0.5,0.5,0.5,0.6,1000,2000,0);assert(math.abs(math.abs(angle)-math.pi)<0.0001)
angle=A.NavigationVector(0.5,0.5,0.4,0.5,1000,2000,math.pi/2);assert(math.abs(angle)<0.0001)
function GetPlayerFacing()return 0 end
function C_Map.GetMapWorldSize()return 1000,2000 end
WorldMapFrame.mapID=37;A.StartNavigation(A.Data.nodes[12][1],37)
assert(A.navFrame:IsShown() and A.navFrame.arrow:IsShown())
assert(A.navFrame.arrow.rotation~=nil)
A.StartNavigation(A.Data.nodes[141][1],57);assert(not A.navFrame.arrow:IsShown(),"Cross-zone arrow lied about direction")
A.navFrame.details.scripts.OnClick(A.navFrame.details)
assert(A.mapDetail:IsShown() and A.mapDetail.mapID==57 and WorldMapFrame:GetMapID()==57)
local goal=A.navigation
local clears=0
function C_Map.ClearUserWaypoint()clears=clears+1 end
function C_Map.GetUserWaypoint()return {uiMapID=99,position={GetXY=function()return 0.1,0.1 end}}end
A.StopNavigation();assert(not A.navFrame:IsShown() and clears==0,"Stop erased another waypoint")
A.StartNavigation(goal.node,goal.mapID)
function C_Map.GetUserWaypoint()return {uiMapID=goal.mapID,position={GetXY=function()return goal.node.x,goal.node.y end}}end
A.StopNavigation();assert(clears==1,"Owned waypoint was not cleared")
WorldMapFrame.mapID=37
local personal=A.AddObservation(37,0.524,0.519,2843,A.Now(),"test")
A.selected=personal;A.selectedArea=12;A.ShowUI()
ChestAtlasWindow.note:SetText("Unsaved field note");ChestAtlasWindow.estimate:SetText("17")
A.Refresh()
assert(ChestAtlasWindow.note:GetText()=="Unsaved field note" and ChestAtlasWindow.estimate:GetText()=="17","Refresh destroyed unsaved edits")
-- All item metadata returns must survive safe reads, including texture and vendor price.
C_Item={GetItemInfo=function(id)return "Cached item","item:"..id,2,5,3,"Weapon","Bow",1,"RANGED",123456,4567 end}
local item=A.ItemDetails(117)
assert(item.icon==123456 and item.price==4567 and item.subclass=="Bow")
local secret={};issecretvalue=function(v)return v==secret end
assert(A.Safe(function()return 1,2,3,4,5,6,7,8,9,secret end)==nil)
issecretvalue=function()return false end
-- Settings and favorites remain in SavedVariables across initialization.
A.settings.iconSize=32;A.filters.query="Chest";local saved=A.db;local key=A.journalKey
A.Init(saved);A.UseJournal(key)
assert(A.settings.iconSize==32 and A.filters.query=="Chest" and A.IsFavorite(n))
''')
print('PASS focus hide/restore/late pins; grouped exact nodes; item search/favorites; compass; safe item metadata; settings restore')

# Individual spawn migration and minimap geometry/interactions.
lua.execute(r'''
local saved,key=A.db,A.journalKey
saved.settings.cluster=true;saved.settings.individualSpawnsVersion=nil
A.Init(saved);A.UseJournal(key)
assert(A.settings.cluster==false,"Upgrade retained grouped spawn icons")
A.settings.cluster=true;A.Init(saved);A.UseJournal(key)
assert(A.settings.cluster==true,"Migration repeated after explicit user opt-in")
A.settings.cluster=false
A.filters.areaID=0;A.filters.typeID=0;A.filters.source="legacy"
A.filters.query="";A.filters.favoritesOnly=false;A.filters.minLevel=1;A.filters.maxLevel=60
WorldMapFrame:SetMapID(57);A.Refresh()
local pool=WorldMapFrame.pinPools.ChestAtlasPinTemplate
assert(pool:GetNumActive()==expectedTeldrassil,"Individual mode lost spawn points")
for _,p in ipairs(pool.active)do assert(#p.group.nodes==1 and p.Count.text=="")end
local function close(a,b)return math.abs(a-b)<0.00001 end
local x,y=A.MinimapPoint(50,0,200,200,200,0,"ROUND",20)
assert(close(x,25) and close(y,0))
x,y=A.MinimapPoint(0,-50,200,200,200,0,"ROUND",20)
assert(close(x,0) and close(y,25))
x,y=A.MinimapPoint(50,0,200,200,200,math.pi/2,"ROUND",20)
assert(close(x,0) and close(y,-25))
assert(A.MinimapPoint(200,0,200,200,200,0,"ROUND",20)==nil)
assert(A.MinimapPoint(150,150,200,200,200,0,"ROUND",20)==nil)
assert(A.MinimapPoint(150,150,200,200,200,0,"SQUARE",20)~=nil)
assert(A.MinimapPoint(0,0,0,200,200,0,"ROUND",20)==nil)
local n=A.Data.nodes[12][1]
local playerMap,px,py=37,n.x-0.03,n.y
local radius,rotate=200,"0"
function C_Map.GetBestMapForUnit()return playerMap end
function C_Map.GetPlayerMapPosition()return {GetXY=function()return px,py end}end
function C_Map.GetMapWorldSize()return 1000,2000 end
function C_Minimap.GetViewRadius()return radius end
C_CVar={GetCVar=function()return rotate end}
function GetPlayerFacing()return math.pi/2 end
A.settings.minimap=true
-- Viewing a different zone on the world map must not hide local minimap spawns.
A.filters.areaID=141;A.UpdateMinimap(true)
assert(A.minimapArea==12 and A.minimapPinCount>0,"World-map zone filter hid local minimap points")
local function findPin(node)
  for _,p in ipairs(A.minimapPins)do
    if p:IsShown() then
      assert(p.mapID==playerMap and #p.group.nodes==1 and p.Count.text=="")
      assert(p.Icon.texture==A.iconPath)
      if p.node==node then return p end
    end
  end
end
local p=assert(findPin(n),"Nearby spawn missing on minimap")
assert(close(p.anchor[4],15) and close(p.anchor[5],0))
rotate="1";A.minimapUpdater.scripts.OnUpdate(A.minimapUpdater,0.2)
p=assert(findPin(n));assert(close(p.anchor[4],0) and close(p.anchor[5],-15),"Rotating minimap misplaced spawn")
radius=10;A.UpdateMinimap(false);assert(findPin(n)==nil,"Zoom did not clip off-map spawn")
px=n.x;py=n.y;A.UpdateMinimap(false)
p=assert(findPin(n));assert(close(p.anchor[4],0) and close(p.anchor[5],0))
p.scripts.OnEnter(p);p.scripts.OnLeave(p)
p.scripts.OnClick(p,"RightButton")
assert(MockWaypoint.map==37 and MockWaypoint.x==n.x and MockWaypoint.y==n.y)
assert(A.navigation.node==n and A.navFrame:IsShown())
p.scripts.OnClick(p,"LeftButton")
assert(WorldMapFrame:GetMapID()==37 and A.selected==n and A.mapDetail:IsShown())
A.settings.minimap=false;A.UpdateMinimap(false)
assert(A.minimapPinCount==0);for _,q in ipairs(A.minimapPins)do assert(not q:IsShown())end
A.settings.minimap=true;A.UpdateMinimap(false);assert(findPin(n))
radius=nil;A.UpdateMinimap(false);assert(A.minimapPinCount==0)
radius=200;playerMap=57;px=A.Data.nodes[141][1].x;py=A.Data.nodes[141][1].y
A.UpdateMinimap(false);assert(A.minimapArea==141 and A.minimapPinCount>0)
for _,q in ipairs(A.minimapPins)do if q:IsShown()then assert(q.mapID==57)end end
A.StopNavigation()
''')
print('PASS individual-spawn upgrade; minimap bounds, rotation, zoom, zone transitions, toggles, exact click/waypoint')

lua.execute(r'''
A.filters.source="all";A.filters.query="";A.filters.typeID=0;A.filters.areaID=0;A.filters.favoritesOnly=false
A.settings.cluster=false;WorldMapFrame:SetMapID(57);A.SetCategory("rares")
local pool=WorldMapFrame.pinPools.ChestAtlasPinTemplate
assert(pool:GetNumActive()==#A.RareData.nodes[141] and pool:GetNumActive()>0,"Rare world pins missing")
local p=pool.active[1];local n=p.node
assert(n.rare and n.typeID==-n.npcID and A.TypeName(n.typeID)==A.RareData.npcs[n.npcID].name)
assert(p.Icon.texture=="Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
C_Texture={GetAtlasInfo=function(atlas)return atlas=="VignetteKill" and {}end}
A.ApplyLocationIcon(p.Icon,n);assert(p.Icon.atlas=="VignetteKill")
C_Texture=nil
p.scripts.OnEnter(p);p.scripts.OnLeave(p)
p.scripts.OnMouseUp(p,"RightButton",true)
assert(MockWaypoint.map==57 and MockWaypoint.x==n.x and A.navigation.node==n)
p.scripts.OnMouseUp(p,"LeftButton",true)
assert(A.selected==n and A.mapDetail.variant:GetText():find("Rare NPC #",1,true))
assert(not A.mapDetail.seen.enabled and not A.mapDetail.capture.enabled and not A.mapDetail.looted.enabled)
assert(A.mapDetail.info:GetText():find("level",1,true))
assert(A.mapDetail.loot.mode=="legacy" and not A.mapDetail.loot.source.enabled)
assert(#A.ReferenceLoot(n)==#A.RareData.npcs[n.npcID].loot)
local count=pool:GetNumActive()
A.SetCategory("both");assert(pool:GetNumActive()==count+expectedTeldrassil,"Both mode lost chests or rares")
A.SetCategory("chests");assert(pool:GetNumActive()==expectedTeldrassil)
A.filters.source="own";A.SelectType(n.typeID)
assert(A.settings.category=="rares" and A.filters.source=="legacy" and pool:GetNumActive()>0)
A.SelectType(2843);assert(A.settings.category=="chests" and pool:GetNumActive()>0)
A.SetCategory("chests");A.filters.source="own";A.SetCategory("rares")
assert(A.filters.source=="legacy" and pool:GetNumActive()>0)
A.SetCategory("rares");A.filters.query=A.TypeName(n.typeID);A.Refresh()
assert(pool:GetNumActive()>0);for _,pin in ipairs(pool.active)do assert(pin.node.npcID==n.npcID)end
A.filters.query=tostring(n.npcID);A.Refresh();assert(pool:GetNumActive()>0)
for _,pin in ipairs(pool.active)do assert(pin.node.npcID==n.npcID)end
A.filters.query=tostring(A.ReferenceLoot(n)[1]);A.Refresh();assert(pool:GetNumActive()>0,"Rare loot ID search failed")
A.filters.query="";A.filters.typeID=n.typeID;A.Refresh()
for _,pin in ipairs(pool.active)do assert(pin.node.npcID==n.npcID)end
-- Native gameobject IDs and NPC IDs never share a type/cache key.
assert(A.RareType(n.typeID) and not A.RareType(n.npcID) and not A.RareType("invalid"))
local both=A.GroupNodes({n,{id="chest-test",typeID=2843,x=n.x,y=n.y}},1000,668,30)
assert(#both==2,"Grouping merged chest and rare icons")
A.filters.typeID=0;A.ToggleFavorite(n)
local exported=A.Export();A.journal.favorites[n.id]=nil
assert(A.Import(exported,A.Now()) and A.IsFavorite(n),"Rare favorite failed backup roundtrip")
local before=A.Export();assert(not A.Import(exported.."\nF|rare:999999:1:0:0",A.Now()));assert(A.Export()==before)
function C_Map.GetBestMapForUnit()return 57 end
function C_Map.GetPlayerMapPosition()return {GetXY=function()return n.x,n.y end}end
function C_Minimap.GetViewRadius()return 200 end
C_CVar={GetCVar=function()return "0"end}
A.settings.minimap=true;A.UpdateMinimap(true)
local mp
for _,pin in ipairs(A.minimapPins)do if pin:IsShown()then assert(pin.node.rare);if pin.node==n then mp=pin end end end
assert(mp,"Rare minimap pin missing")
mp.scripts.OnClick(mp,"RightButton");assert(A.navigation.node==n and MockWaypoint.map==57)
mp.scripts.OnClick(mp,"LeftButton");assert(A.selected==n)
A.ShowUI();assert(not ChestAtlasWindow.seen.enabled and not ChestAtlasWindow.attachLoot.enabled and not ChestAtlasWindow.newFind.enabled)
assert(ChestAtlasWindow.lootBoard.mode=="legacy")
local found=false;for _,e in ipairs(A.TypeEntries())do found=found or e.value==n.typeID end;assert(found)
for _,e in ipairs(A.TypeEntries(true))do assert(e.value>=0,"NPC type leaked into chest journal editor")end
-- Rare-only zones resolve and can be manually bound without changing chest data.
assert(A.ResolveArea(9991,"Winterspring")==618 and A.Bind(618,9992))
assert(#A.NodesForMap(9992,"Renamed Winterspring")>0)
A.db.settings.category="rares";local saved,key=A.db,A.journalKey
A.Init(saved);A.UseJournal(key);assert(A.settings.category=="rares")
A.StopNavigation();A.settings.category="chests";A.filters.typeID=0;A.filters.query=""
''')
print('PASS rare world/minimap pins, native icon, NPC details/loot, categories/search, exact waypoint, favorites, rare-only zones and journal separation')

lua.execute('''
local rs={db={profile={}}}
LibStub=function()return {GetAddon=function()return rs end}end
A.settings.focus=true
local focus=CreateFromMixins(ChestAtlasFocusMixin)
assert(not focus:ShouldSuppressPin({pinTemplate="RSEntityPinTemplate"}))
assert(not focus:ShouldSuppressPin({pinTemplate="RSGroupPinTemplate"}))
assert(not focus:ShouldSuppressPin({pinTemplate="RSGuideTemplate"}))
assert(focus:ShouldSuppressPin({pinTemplate="QuestOfferPinTemplate"}))
LibStub=nil
assert(focus:ShouldSuppressPin({pinTemplate="RSEntityPinTemplate"}))
A.settings.focus=false
''')
print('PASS Atlas focus preserves active RareScanner entity/group/guide pins and still suppresses quest markers')

lua2,A2,load2=new_runtime()
load2((ROOT/'Runtime.lua').read_text(encoding='utf-8'),A2)
for file in ['Navigation.lua','Widgets.lua','MapUI.lua','Minimap.lua','UI.lua']:load2((ROOT/file).read_text(encoding='utf-8'),A2)
lua2.execute('''
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","ChestAtlas")
A.settings.category="chests"
A.events.scripts.OnEvent(A.events,"PLAYER_LOGIN")
local n=A.AddObservation(37,0.524,0.519,2843,2000,"1.60.1.test")
n.referenceID="legacy:12:1"; n.legacyRespawn=A.Data.nodes[12][1].legacyRespawn
n.note=string.rep("æ",500)
A.journal.favorites[n.referenceID]=true
local exported=A.Export();A.journal.nodes={};A.journal.favorites={}
assert(A.Import(exported,2000))
local restored=A.journal.nodes[n.id]
assert(restored.referenceID==n.referenceID and restored.legacyRespawn==n.legacyRespawn)
assert(restored.note==n.note,"UTF-8 note failed backup roundtrip")
assert(A.IsFavorite(restored),"Favorite lost in backup")
local beforeFavoriteImport=A.Export()
assert(not A.Import(exported.."\\nF|legacy:999999:1",2000))
assert(A.Export()==beforeFavoriteImport,"Bad favorite mutated journal")
-- A missing/stale sequence number must never overwrite the recovered node.
A.journal.nextID=1;A.UseJournal(A.journalKey)
local another=A.AddObservation(37,0.9,0.9,0,2000,"test")
assert(another.id~=n.id and A.journal.nodes[n.id]==restored)
-- Mixed chest GUIDs of the same variant must not masquerade as one chest.
function GetNumLootItems()return 2 end
function GetLootSourceInfo(slot)return "GameObject-0-1-1-1-2843-"..slot,2 end
A.CaptureLoot();assert(A.lastLoot.sourceRejected)
assert(not A.RecordContents(restored,A.lastLoot,2000))
-- Read API absence/restrictions are expected to degrade without crashing.
function InCombatLockdown()return true end
assert(A.PlayerPosition()==nil);A.NewAtPlayer(2843)
assert(A.Safe(function()error("blocked")end)==nil)
local secret={}
function issecretvalue(value)return value==secret end
assert(A.Safe(function()return nil,secret end)==nil)
''')
print('PASS backup metadata, 500 UTF-8 letters, ID recovery, mixed loot sources, restricted APIs')

# Fuzz the inert importer: malformed input must neither crash nor mutate state.
before=A2.Export()
random.seed(20261005)
alphabet='NLB|own:0123456789abcdefABC xyz\n\r.-'
for _ in range(500):
    payload=''.join(random.choice(alphabet) for _ in range(random.randint(0,220)))
    outcome=A2.Import(payload,2000)
    assert outcome[0] is False
    assert A2.Export()==before
print('PASS 500 malformed backup inputs: no crashes or partial writes')

# Check all GUI methods against actual widget docs (plus known inherited/native scroll APIs).
docs={}
for p in SOURCE.glob('Simple*Documentation.lua'):
    docs[p.name]=set(re.findall(r'Name\s*=\s*"([A-Za-z][A-Za-z0-9_]*)"',p.read_text(encoding='utf-8')))
all_methods=set().union(*docs.values())
calls=set()
for file in ['Runtime.lua','Navigation.lua','Widgets.lua','MapUI.lua','Minimap.lua','UI.lua','Rares.lua']:
    calls|=set(re.findall(r':([A-Z][A-Za-z0-9_]*)\(', (ROOT/file).read_text(encoding='utf-8')))
custom=set(re.findall(r'function [\w.]+:([A-Z][A-Za-z0-9_]*)\(', ''.join(p.read_text(encoding='utf-8') for p in SOURCE.glob('*MapCanvas*.lua'))))
custom|=set(re.findall(r'function [\w.]+:([A-Z][A-Za-z0-9_]*)\(', ''.join(p.read_text(encoding='utf-8') for p in ROOT.glob('*.lua'))))
known={'AddMessage','Clear','SetFading','SetMaxLines','ScrollToTop','ScrollUp','ScrollDown',
       'SetBackdrop','SetBackdropColor','SetBackdropBorderColor','AddLine','SetOwner','SetHyperlink','AddDataProvider',
       'RemoveAllPinsByTemplate','AcquirePin','GetMapID','SetMapID','RefreshAllData','GetMap',
       'SetPinTemplateType','SetPosition'}
missing=sorted(calls-all_methods-custom-known)
assert not missing,missing
print('PASS widget method names checked against pinned Forever API docs')

result={'status':'PASS','foreverSourceCommit':json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))['commit'],
        'lua':'5.1','mapEngine':'actual MapCanvas source; simulated native widgets',
        'fuzzInputs':500,'inGameValidation':False}
(WORK/'validation-result.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
