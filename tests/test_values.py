from pathlib import Path
import sys
WORK=Path(__file__).resolve().parent
ROOT=WORK.parent
sys.path.insert(0,str(WORK/'python_libs'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(register_eval=False,register_builtins=False)
A=lua.table();load=lua.eval('function(s,A)return assert(loadstring(s))("ChestAtlas",A)end')
for name in ['Data.lua','CoverageData.lua','ClassicSpawnData.lua','ClassicLootData.lua','ClassicSpawnLoot.lua','RareData.lua','Core.lua','Features.lua','Rares.lua','Companion.lua','tests/wow_mock.lua','Runtime.lua','Widgets.lua']:
    load((ROOT/name).read_text(encoding='utf-8'),A)
lua.globals().A=A
lua.execute('''
A.Init(nil);A.UseJournal("test");A.RefreshUI=function()end;A.UpdateNavigation=function()end
local items={
 [777001]={"Epic cheap",4,25},[777002]={"Green valuable",2,50000},
 [777003]={"Blue later",3,nil},[777004]={"No sell price",1,0},
 [777005]={"Invalid price",3,-25}
}
local requests={}
C_Item={GetItemInfo=function(id)
 local i=items[id];if not i then return end
 return i[1],"item:"..id,i[2],10,5,"Armor","Leather",1,"CHEST",134400,i[3]
end,RequestLoadItemDataByID=function(id)requests[#requests+1]=id end}
A.Data.types[999997]={name="Test loot",loot={777001,777002,777003,777004,777005}}
local n={typeID=999997}
local best=A.BestLoot(n)
assert(best.item.id==777002 and best.total==5 and best.known==3,"Vendor ranking used quality or unknown/invalid prices")
local board=A.Widgets.Loot(UIParent,0,0,400,2);board:SetNode(n)
assert(board.rows[1].item.id==777002 and board.rows[2].item.id==777001)
board.page=2;board:Refresh();assert(board.best.item.id==777002,"Best item disappeared on page 2")
board.search:SetText("Epic cheap");assert(board.rows[1].item.id==777001 and board.best.item.id==777002,"Search hid the pinned top item")
board.quality=4;board:Refresh();assert(board.best.item.id==777002,"Quality filter hid top item")
board.search:SetText("");board.quality=nil
-- Warm every possible item, including items not on the current page.
A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2)
assert(#requests==2 and requests[1]==777003 and requests[2]==777005)
board:Refresh();A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2);assert(#requests==2,"Duplicated pending requests")
items[777003][3]=90000;A.RefreshItemWidgets(777003,true)
A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2)
assert(board.best.item.id==777003 and board.rows[1].item.id==777003,"Async higher-value item did not replace the top item")
A.RefreshItemWidgets(777005,false);A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2)
board:Refresh();A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2);assert(#requests==2,"Failed item was requested forever")
board.mode="own";n.contents={[777001]={count=100,sightings=2}};board:Refresh()
assert(board.rows[1].item.id==777001 and board.best.item.id==777003,"Recorded mode replaced possible-loot highlight")
A.Data.types[999998]={name="Zero value",loot={777004}}
assert(A.BestLoot({typeID=999998}).item.price==0,"Zero sell price treated as unknown")
local personal={typeID=0,own=true,contents={[777002]={count=1}}}
assert(A.BestLoot(personal).item.id==777002,"Unknown personal type lost recorded value")
personal.contents[777003]={count=1};assert(A.BestLoot(personal).item.id==777003,"Personal contents cache went stale")
-- More than a page: pending requests are bounded to six per update.
local ids={};for i=1,14 do ids[i]=888000+i end
A.Data.types[999996]={name="Uncached",loot=ids};A.BestLoot({typeID=999996})
local before=#requests;A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2);assert(#requests-before==6)
before=#requests;A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2);assert(#requests-before==6)
before=#requests;A.valueLoader.scripts.OnUpdate(A.valueLoader,0.2);assert(#requests-before==2)
local unknown=A.BestLoot({typeID=999996});assert(unknown.item==nil and unknown.known==0,"Unknown value fabricated a winner")
assert(A.ValueOrder({id=1,name="A",quality=1,price=100},{id=2,name="B",quality=4,price=25}))
local getter=C_Item.GetItemInfo;local reads=0
C_Item.IsItemDataCachedByID=function()return false end
C_Item.GetItemInfo=function(id)reads=reads+1;return getter(id)end
assert(A.ItemDetails(777002).price==nil and reads==0,"Uncached lookup bypassed the request throttle")
C_Item.IsItemDataCachedByID=nil
assert(A.events.events.ITEM_DATA_LOAD_RESULT and A.events.events.GET_ITEM_INFO_RECEIVED)
''')
print('PASS vendor ranking, incomplete/zero/invalid prices, pinned best loot across filters/pages/modes, async updates, bounded requests and recorded finds')
lua.execute('''
local previous={general={},map={},display={},loot={},collections={}}
local rs={db={profile=previous}}
local profileCalls,commands=0,{}
function rs.db:GetCurrentProfile()return "Original"end
function rs.db:GetProfiles()return {"Original"}end
function rs.db:SetProfile(name)assert(name=="Chest Atlas");profileCalls=profileCalls+1;self.profile={general={},map={},display={},loot={},collections={}}end
function rs.db:CopyProfile(name)assert(name=="Original")end
LibStub=function()return {GetAddon=function(_,name)assert(name=="RareScanner");return rs end}end
SlashCmdList.ACECONSOLE_RS=function(cmd)commands[#commands+1]=cmd end
A.settings.category="both";A.SetupRareScanner()
assert(A.CompanionActive() and A.settings.category=="chests")
assert(rs.db.profile.map.displayNpcIcons and not rs.db.profile.map.displayContainerIcons)
assert(rs.db.profile.general.scanRares and not rs.db.profile.general.scanContainers)
assert(rs.db.profile.display.displayMiniature and rs.db.profile.collections.showWithoutCollectibles)
assert(next(previous.general)==nil and next(previous.map)==nil,"Previous RS profile mutated")
A.settings.category="both";A.SetupRareScanner();assert(profileCalls==1 and A.settings.category=="both","Repeated setup overrode user preferences")
assert(A.RareScannerCommand("explorer") and A.RareScannerCommand("route") and A.RareScannerCommand("croute"))
assert(#commands==3 and not A.RareScannerCommand("arbitrary"))
LibStub=nil;assert(not A.CompanionActive() and not A.RareScannerCommand("explorer"))
''')
print('PASS optional RareScanner pairing, separate profile, one-time setup, preserved user changes, whitelisted commands and safe addon absence')
