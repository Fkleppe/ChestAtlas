local _, A = ...
local ui, backup
local W=A.Widgets
local sourceLabels={all="All sources",legacy="Classic references",own="Your finds"}
local page, pageSize = 1,8

local function label(parent,text,x,y,width,font)
  local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT",x,-y); fs:SetWidth(width); fs:SetJustifyH("LEFT"); fs:SetText(text)
  return fs
end
local function button(parent,text,x,y,width,fn)
  return W.Button(parent,text,x,y,width,fn)
end
local function edit(parent,x,y,width,text)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetPoint("TOPLEFT",x,-y); e:SetSize(width,24); e:SetAutoFocus(false); e:SetText(text or "")
  e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
  e:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
  return e
end
local function mapName(mapID)
  local info=mapID and A.MapInfo(mapID)
  return info and info.name or "Unknown zone"
end
local function areaName(id)
  return A.LocalAreaName(id) or ((A.Zones or A.Data.zones)[id] and (A.Zones or A.Data.zones)[id].name) or "Unknown zone"
end
local function refreshLoot(n)ui.lootBoard:SetNode(n)end
local function refreshDetail()
  local n=A.selected
  local controls={ui.waypoint,ui.seen,ui.looted,ui.attachLoot,ui.nodeType,ui.save}
  for _,b in ipairs(controls) do b:SetEnabled(n~=nil) end
  if not n then
    ui.detailTitle:SetText("Select a chest")
    ui.detailInfo:SetText("Choose a location • possible loot and navigation")
    ui.sources:SetText(W.SourceText(nil));ui.journalInfo:SetText("Select a chest to view your observations.")
    ui.lootBoard:SetNode(nil)
    ui.note:SetText(""); ui.estimate:SetText("");ui.favorite:SetEnabled(false);ui.editedNode=nil;return
  end
  ui.detailTitle:SetText(A.TypeDisplay(n.typeID))
  ui.favorite:SetEnabled(true);ui.favorite:SetText(A.IsFavorite(n) and "Favorited *" or "Favorite *")
  local _,status,colour=A.LocationStatus(n)
  ui.detailInfo:SetText(status.."\n"..string.format("%.1f, %.1f • ",n.x*100,n.y*100)..A.DistanceText(n,A.displayMapID));ui.detailInfo:SetTextColor(unpack(colour))
  ui.sources:SetText(W.SourceText(n,A.selectedArea))
  ui.journalInfo:SetText(A.Observation(n) and A.Timer(A.Observation(n),A.Now()) or "Stand beside this chest to record your first personal find.")
  if ui.editedNode~=n then
    ui.note:SetText(n.note or "")
    ui.estimate:SetText(n.estimate and tostring(n.estimate) or "")
    ui.editedNode=n
  end
  ui.nodeType:SetText("Type: "..A.TypeName(n.typeID)..(A.IsGenericType(n.typeID) and " • variant unknown" or n.typeID~=0 and (" #"..n.typeID) or ""))
  ui.seen:SetText(n.own and "Mark seen now" or "Record personal find")
  ui.seen:SetEnabled(not n.rare)
  ui.looted:SetEnabled(not not n.own); ui.attachLoot:SetEnabled(not not n.own)
  ui.nodeType:SetEnabled(not not n.own); ui.save:SetEnabled(not not n.own)
  if n.own then ui.note:Enable();ui.estimate:Enable()
  else ui.note:Disable();ui.estimate:Disable() end
  refreshLoot(n)
end
function A.RefreshUI()
  if not ui or not ui:IsShown() or not A.journal then return end
  if not ui.searchDirty and ui.search:GetText()~=(A.filters.query or "") then
    ui.syncSearch=true;ui.search:SetText(A.filters.query or "");ui.syncSearch=false
  end
  if A.filters.areaID==0 then
    if WorldMapFrame and WorldMapFrame:IsShown() then A.displayMapID=WorldMapFrame:GetMapID()
    else A.displayMapID=A.PlayerPosition() end
  end
  local mapID=A.displayMapID
  local name=mapName(mapID)
  local nodes,area={},nil
  if mapID then nodes,area=A.NodesForMap(mapID,name) end
  ui.zone:SetText(A.filters.areaID==0 and "Zone: current map / your position" or ("Zone: "..areaName(A.filters.areaID)))
  ui.source:SetText("Source: "..sourceLabels[A.filters.source])
  ui.typeFilter:SetText(A.filters.typeID==0 and A.ContainerLabel(A.filters.containers) or ("Type: "..A.TypeDisplay(A.filters.typeID)))
  ui.summary:SetText(name.." • "..#nodes.." locations"..(not area and " • reference zone unknown" or ""))
  ui.favorites:SetChecked(A.filters.favoritesOnly)
  ui.sort:SetText(A.settings.sort=="distance" and "Nearest first" or "Sort by type")
  ui.chestRoute:SetText(A.chestRoute and "Stop chest route" or "Start chest route")
  ui.category:SetText("Rares in RS");ui.category:SetEnabled(A.CompanionActive())
  ui.newFind:SetEnabled(A.settings.category~="rares" and A.filters.typeID>=0)
  local paired=A.CompanionActive and A.CompanionActive()
  ui.rareBrowser:SetEnabled(paired);ui.rareRoute:SetEnabled(paired);ui.rareStop:SetEnabled(paired)
  ui.companion:SetText(paired and "RareScanner handles rares • values below are per-item vendor prices" or "Best known loot • vendor prices per item • AH value unknown")
  local pages=math.max(1,math.ceil(#nodes/pageSize)); page=math.min(page,pages)
  ui.page:SetText(page.." / "..pages)
  for i,row in ipairs(ui.rows) do
    local n=nodes[(page-1)*pageSize+i]
    row.node,row.areaID=n,area
    if n then
      A.ApplyLocationIcon(row.icon,n)
      row.text:SetText((n.own and "|cff78ff99" or "|cffffcb70")..(A.IsFavorite(n) and "* " or "")..A.TypeName(n.typeID).."|r")
      local status,_,colour=A.LocationStatus(n)
      row.meta:SetText(string.format("%.1f, %.1f",n.x*100,n.y*100).." • "..(status=="looted" and "Looted by you" or status=="seen" and "Seen by you" or "Historical"))
      row.meta:SetTextColor(unpack(colour))
      local best=A.BestLoot(n);row.best.item,row.best.valueSummary=best.item,best
      row.best.icon:SetTexture(best.item and best.item.icon or 134400)
      row.best.name:SetText(best.item and best.item.name or (A.IsGenericType(n.typeID) and "Loot variant unknown" or best.total>0 and "Vendor value unknown" or "No known loot"));W.ItemColor(row.best.name,best.item)
      row.best.price:SetText(best.item and A.ShortMoney(best.item.price) or "—")
      row.best.node,row.best.lootMode=n,"legacy"
      row.selected:SetShown(A.selected and A.FavoriteKey(A.selected)==A.FavoriteKey(n))
      row:Show()
    else row:Hide() end
  end
  ui.empty:SetText(#nodes==0 and "No locations match these filters.\n\nSelect a zone, show Classic references or record a personal find." or "")
  if A.selected then
    local selectedMap=A.selected.mapID
    if (selectedMap and selectedMap~=mapID) or (not selectedMap and A.selectedArea~=area) then A.selected=nil end
  end
  refreshDetail()
end
local function createUI()
  ui=CreateFrame("Frame","ChestAtlasWindow",UIParent,"BackdropTemplate")
  ui:SetSize(940,910); ui:SetPoint("CENTER"); ui:SetFrameStrata("DIALOG");ui:SetClampedToScreen(true)
  ui:SetScale(math.min(1,UIParent:GetWidth()/1000,UIParent:GetHeight()/970))
  W.Surface(ui);W.Rule(ui,22,68,890);W.Rule(ui,22,200,890)
  ui:SetMovable(true); ui:EnableMouse(true); ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart",function(self)self:StartMoving()end)
  ui:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
  local close=CreateFrame("Button",nil,ui,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-3,-3)
  label(ui,"CHEST ATLAS",22,20,820,"GameFontNormalLarge"):SetTextColor(unpack(W.gold))
  label(ui,"Chests • possible loot • navigation • chest journal",22,49,580)
  button(ui,"Dungeon chests",615,43,140,function()ui:Hide();A.ShowInstances()end)
  button(ui,"Show on map",765,43,140,function()
    ui:Hide()
    if WorldMapFrame then
      WorldMapFrame:Show()
      if A.displayMapID then WorldMapFrame:SetMapID(A.displayMapID) end
    end
    A.Refresh()
  end)
  ui.zone=button(ui,"",22,78,310,function(self)A.OpenPicker(self,"Select zone",A.ZoneEntries(),A.filters.areaID,function(v)page=1;A.PickZone(v)end)end)
  ui.source=button(ui,"",344,78,220,function(self)A.OpenPicker(self,"Select source",{{value="all",text="All sources"},{value="legacy",text="Classic references"},{value="own",text="Your finds"}},A.filters.source,function(v)A.filters.source=v;page=1;A.Refresh()end)end)
  ui.typeFilter=button(ui,"",578,78,335,function(self)A.OpenPicker(self,"Select location type",A.TypeEntries(),A.filters.typeID,function(v)page=1;A.SelectType(v)end)end)
  label(ui,"Zone level",22,119,65)
  ui.minLevel=edit(ui,95,111,35,"1"); label(ui,"to",142,119,20); ui.maxLevel=edit(ui,165,111,35,"60")
  button(ui,"Apply",212,111,78,function()
    local lo,hi=tonumber(ui.minLevel:GetText()),tonumber(ui.maxLevel:GetText())
    if not lo or not hi or lo<1 or hi>60 or lo>hi then A.Print("Enter a level range from 1 to 60.");return end
    A.filters.minLevel,A.filters.maxLevel=lo,hi; page=1; A.Refresh()
  end)
  ui.newFind=button(ui,"New chest find",313,111,160,function() A.NewAtPlayer(A.filters.typeID) end)
  button(ui,"Export journal",490,111,180,function() A.ShowBackup(false)end)
  button(ui,"Import journal",686,111,180,function() A.ShowBackup(true)end)
  W.Line(ui,"Search chest / item",22,155,145)
  ui.search=edit(ui,174,147,325,A.filters.query);ui.search:SetMaxLetters(80)
  local pending=0
  ui.search:SetScript("OnTextChanged",function()if not ui.syncSearch then ui.searchDirty=true;pending=0.25 end end)
  ui.favorites=W.Check(ui,"Favorites",516,147,100,function(v)A.filters.favoritesOnly=v;page=1;A.Refresh()end)
  ui.sort=button(ui,"",646,147,155,function()A.settings.sort=A.settings.sort=="distance" and "type" or "distance";A.Refresh()end)
  button(ui,"Reset",811,147,101,function()A.ResetFilters();ui.search:SetText("");ui.minLevel:SetText("1");ui.maxLevel:SetText("60");page=1;A.Refresh()end)
  ui.summary=W.Line(ui,"",22,183,875)
  ui.rows={}
  for i=1,pageSize do
    local row=CreateFrame("Button",nil,ui,"BackdropTemplate")
    row:SetPoint("TOPLEFT",22,-(210+(i-1)*66));row:SetSize(302,62);W.Surface(row,true)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD");row:GetHighlightTexture():SetVertexColor(0.30,0.23,0.09,0.2)
    row.selected=row:CreateTexture(nil,"OVERLAY");row.selected:SetTexture("Interface\\Buttons\\WHITE8X8");row.selected:SetVertexColor(unpack(W.gold));row.selected:SetSize(3,60);row.selected:SetPoint("TOPLEFT",1,-1)
    row.icon=row:CreateTexture(nil,"ARTWORK");A.ApplyChestIcon(row.icon);row.icon:SetSize(30,30);row.icon:SetPoint("TOPLEFT",5,-8)
    row.text=W.Line(row,"",42,6,254,"GameFontNormal")
    row.meta=W.Line(row,"",42,25,254);row.meta:SetTextColor(0.60,0.69,0.77)
    row.best=CreateFrame("Button",nil,row);row.best:SetSize(254,19);row.best:SetPoint("TOPLEFT",42,-42)
    row.best.icon=row.best:CreateTexture(nil,"ARTWORK");row.best.icon:SetSize(17,17);row.best.icon:SetPoint("TOPLEFT",0,0)
    row.best.name=W.Line(row.best,"",22,1,169);row.best.price=W.Line(row.best,"",195,1,59);row.best.price:SetJustifyH("RIGHT");row.best.price:SetTextColor(unpack(W.gold))
    row.best:SetScript("OnEnter",W.ItemTooltip);row.best:SetScript("OnLeave",function()GameTooltip:Hide()end)
    row.best:SetScript("OnClick",function()A.selected,A.selectedArea=row.node,row.areaID;A.RefreshUI()end)
    row:SetScript("OnClick",function(self)A.selected,A.selectedArea=self.node,self.areaID;A.RefreshUI()end)
    row:SetScript("OnEnter",function(self)
      if self.node then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(A.TypeName(self.node.typeID),1,0.84,0.4)
        GameTooltip:AddLine(W.DetailText(self.node,self.areaID),0.9,0.9,0.9,true);GameTooltip:Show()end
    end)
    row:SetScript("OnLeave",function()GameTooltip:Hide()end)
    ui.rows[i]=row
  end
  ui.empty=label(ui,"",27,215,287)
  button(ui,"Previous",22,758,95,function()page=math.max(1,page-1);A.RefreshUI()end)
  ui.page=label(ui,"",137,766,75)
  button(ui,"Next",225,758,95,function()page=page+1;A.RefreshUI()end)
  button(ui,"Map / appearance",22,793,298,function()A.ShowMapSettings()end)
  ui.chestRoute=button(ui,"Start chest route",22,830,298,function()if A.chestRoute then A.StopNavigation()else A.StartChestRoute(A.displayMapID)end;A.RefreshUI()end)
  ui.rareBrowser=button(ui,"Rare browser",22,865,142,function()A.RareScannerCommand("explorer")end)
  ui.rareRoute=button(ui,"Rare routes",174,865,146,function(self)
    A.OpenPicker(self,"RareScanner routes",{{value="route",text="Start rare route"},{value="croute",text="Stop rare route"}},nil,A.RareScannerCommand)
  end)
  ui.rareStop=ui.rareRoute
  ui.companion=W.Line(ui,"",348,892,556);ui.companion:SetTextColor(0.60,0.69,0.77)
  ui.detailTitle=W.Line(ui,"",348,210,565,"GameFontNormalLarge")
  ui.detailInfo=label(ui,"",348,242,558); ui.detailInfo:SetHeight(40); ui.detailInfo:SetJustifyV("TOP")
  ui.waypoint=button(ui,"Go here + arrow",348,294,190,function()A.Waypoint(A.selected)end)
  ui.favorite=button(ui,"Favorite *",550,294,180,function()A.ToggleFavorite(A.selected)end)
  ui.category=button(ui,"",742,294,161,A.NextCategory)
  ui.tabs=W.Tabs(ui,348,334,556,548)
  local journal=ui.tabs.journal
  ui.journalInfo=W.Text(journal,"",0,0,556);ui.journalInfo:SetHeight(62);ui.journalInfo:SetJustifyV("TOP")
  ui.seen=button(journal,"",0,76,270,function()
    local n=A.MakeOwn(A.selected); if n then n.lastSeen=A.Now(); A.Refresh() end
  end)
  ui.looted=button(journal,"Mark looted",282,76,274,function()A.MarkLooted(A.selected,A.Now());A.Refresh()end)
  ui.attachLoot=button(journal,"Record latest loot window",0,114,556,function()
    local ok,err=A.RecordContents(A.selected,A.lastLoot,A.Now())
    A.Print(ok and "Loot window contents linked to your find. This does not confirm which items you took." or (err or "No recent loot snapshot."))
    A.Refresh()
  end)
  ui.nodeType=button(journal,"",0,152,556,function(self)
    if A.selected and A.selected.own then A.OpenPicker(self,"Type for your find",A.TypeEntries(true),A.selected.typeID,function(v)A.selected.typeID=v;A.Refresh()end)end
  end)
  label(journal,"Note",0,198,45); ui.note=edit(journal,54,190,496,""); ui.note:SetMaxLetters(500)
  W.Line(journal,"Your respawn estimate (minutes)",0,238,280); ui.estimate=edit(journal,294,230,100,"")
  ui.save=button(journal,"Save note and estimate",0,272,556,function()
    local n=A.selected; if not n or not n.own then return end
    local value=ui.estimate:GetText(); local minutes=value~="" and tonumber(value) or nil
    if value~="" and (not minutes or minutes~=minutes or minutes<=0 or minutes>10080) then A.Print("Enter 1–10080 minutes, or leave the field empty.");return end
    n.note=ui.note:GetText();n.estimate=minutes;ui.note:ClearFocus();ui.estimate:ClearFocus();A.Refresh()
  end)
  W.Text(journal,"Looting a known chest records it automatically (/ca auto). These buttons are for manual records.\n\nAn elapsed estimate does not mean the chest has respawned. Layer and live availability remain unknown.",0,322,556)
  ui.sources=W.Text(ui.tabs.sources,"",0,0,556);ui.sources:SetHeight(460);ui.sources:SetJustifyV("TOP")
  ui.lootBoard=W.Loot(ui.tabs.loot,0,0,556,5)
  ui.disclaimer=W.Text(ui.tabs.loot,"Classic estimates • Forever loot unconfirmed",0,0,555)
  ui.disclaimer:SetHeight(28);ui.disclaimer:ClearAllPoints();ui.disclaimer:SetPoint("TOPLEFT",ui.lootBoard,"BOTTOMLEFT",0,-12)
  ui:SetScript("OnShow",A.RefreshUI)
  -- Update elapsed time only; preserve unsaved edits and loot scroll position.
  local elapsed=0
  ui:SetScript("OnUpdate",function(_,dt)
    if pending>0 then pending=pending-dt;if pending<=0 then A.filters.query=ui.search:GetText();ui.searchDirty=false;page=1;A.Refresh()end end
    elapsed=elapsed+dt;if elapsed>=30 then elapsed=0
    if A.selected then
      local n=A.selected
      refreshDetail()
    end
  end end)
  if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ChestAtlasWindow" end
end
function A.ShowUI(tab)
  if not A.journal then return end
  if A.HideMapDetail then A.HideMapDetail() end
  if not ui then createUI() end
  A.AttachMap();ui:Show();if tab then ui.tabs:SetTab(tab)end;A.Refresh()
end
function A.ShowBackup(importing)
  if not backup then
    backup=CreateFrame("Frame","ChestAtlasBackup",UIParent,"BackdropTemplate")
    backup:SetSize(760,510);backup:SetPoint("CENTER");backup:SetFrameStrata("FULLSCREEN_DIALOG")
    backup:SetScale(math.min(1,UIParent:GetWidth()/820,UIParent:GetHeight()/570));backup:SetClampedToScreen(true)
    backup:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    backup:SetBackdropColor(0.035,0.055,0.075,0.99)
    local close=CreateFrame("Button",nil,backup,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3)
    backup.title=label(backup,"",20,20,700,"GameFontNormalLarge")
    backup.help=label(backup,"",20,55,700)
    local scroll=CreateFrame("ScrollFrame",nil,backup,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",23,-92);scroll:SetSize(686,345)
    backup.edit=CreateFrame("EditBox",nil,scroll)
    backup.edit:SetMultiLine(true);backup.edit:SetAutoFocus(false);backup.edit:SetFontObject(ChatFontNormal)
    backup.edit:SetWidth(676);backup.edit:SetHeight(345);backup.edit:SetMaxLetters(300000)
    backup.edit:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    scroll:SetScrollChild(backup.edit)
    backup.action=button(backup,"",20,462,220,function()
      if backup.importing then
        local ok,result=A.Import(backup.edit:GetText(),A.Now())
        A.Print(ok and ("Imported "..result.." locations.") or result)
        if ok then A.selected=nil;A.Refresh();backup:Hide()end
      else backup.edit:SetFocus();backup.edit:HighlightText() end
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ChestAtlasBackup" end
  end
  backup.importing=importing
  backup.title:SetText(importing and "Import chest journal" or "Export chest journal")
  backup.help:SetText(importing and "Paste a CHESTATLAS1 backup from the same region/realm. Valid locations are merged; matching IDs are updated." or "Copy the text to a file with Ctrl+C. Use /ca import to restore it. This export is for your current region/realm.")
  backup.action:SetText(importing and "Import" or "Select all / copy with Ctrl+C")
  backup.edit:SetText(importing and "" or A.Export());backup:Show()
  backup.edit:SetFocus();if not importing then backup.edit:HighlightText()end
end
