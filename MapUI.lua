local _,A=...
local W=A.Widgets
local toolbar,settings,detail
function A.ZoneEntries()
  local entries={{value=0,text="Current map / your position"}}
  local zones={};for id,z in pairs((A.Zones or A.Data.zones)) do zones[#zones+1]={value=id,text=(A.LocalAreaName(id) or z.name).." • level "..z.minLevel.."–"..z.maxLevel} end
  table.sort(zones,function(a,b)return a.text<b.text end)
  for _,e in ipairs(zones) do entries[#entries+1]=e end;return entries
end
function A.TypeEntries(chestOnly)
  local entries={{value=0,text=chestOnly and "Unknown chest type" or "All location types"}};local types={}
  for id,t in pairs(A.Data.types) do if t.category~="instance" then types[#types+1]={value=id,text=A.TypeDisplay(id).." • "..A.ContainerLabel(A.ContainerCategory(id))..(t.generic and " • possible family loot" or (" • "..#A.ReferenceLoot({typeID=id}).." possible items"))} end end
  table.sort(types,function(a,b)return a.text<b.text end)
  for _,e in ipairs(types) do entries[#entries+1]=e end;return entries
end
function A.PickZone(area)
  A.filters.areaID=area;A.selected=nil
  if area~=0 then
    local map=A.FindMapForArea(area)
    if map then A.displayMapID=map;WorldMapFrame:SetMapID(map)
    else A.Print("Select the zone on the world map. If unrecognized, use /ca bind "..area.." while standing there.") end
  end
  A.Refresh()
end
local function updateSettings()
  if not settings then return end
  local s=A.settings;settings.show:SetChecked(s.showPins);settings.focus:SetChecked(s.focus)
  settings.focus.caption:SetText(A.CompanionActive and A.CompanionActive() and "Atlas + RareScanner — hide other markers" or "Atlas only — hide other markers")
  settings.minimap:SetChecked(s.minimap)
  settings.category:SetText(A.CompanionActive() and "Rares: open RareScanner" or "RareScanner is not enabled")
  settings.category:SetEnabled(A.CompanionActive())
  settings.player:SetChecked(s.keepPlayer);settings.names:SetChecked(s.labels);settings.cluster:SetChecked(s.cluster)
  settings.favorites:SetChecked(A.filters.favoritesOnly);settings.auto:SetChecked(s.autoJournal);settings.size:SetText("World map icon: "..A.WorldMapIconSize())
  settings.source:SetText(A.filters.source=="all" and "All sources" or A.filters.source=="own" and "Your finds" or "Classic references")
  settings.type:SetText(A.filters.typeID==0 and "All location types" or A.TypeDisplay(A.filters.typeID))
  settings.containers:SetText("Containers: "..A.ContainerLabel(A.filters.containers))
end
function A.ShowMapSettings()
  if not settings then
    settings=W.Panel("ChestAtlasMapSettings",UIParent,420,555);settings:SetPoint("CENTER",WorldMapFrame,"CENTER")
    settings:SetScale(math.min(1,UIParent:GetHeight()/595))
    W.Text(settings,"MAP AND FILTERS",18,19,355,"GameFontNormalLarge")
    W.Text(settings,"Keep the map tidy. Your preferences are saved.",18,48,380)
    settings.show=W.Check(settings,"World map markers",18,74,180,function(v)A.settings.showPins=v;if not v then A.settings.focus=false end;A.Refresh()end)
    settings.minimap=W.Check(settings,"Minimap markers",230,74,150,function(v)A.settings.minimap=v;A.Refresh()end)
    settings.focus=W.Check(settings,"Atlas only — hide other markers",18,105,350,function(v)A.settings.focus=v;if v then A.settings.showPins=true end;A.Refresh()end)
    settings.player=W.Check(settings,"Keep player / group in focus mode",18,136,350,function(v)A.settings.keepPlayer=v;A.Refresh()end)
    settings.names=W.Check(settings,"Always show names",18,167,350,function(v)A.settings.labels=v;A.Refresh()end)
    settings.cluster=W.Check(settings,"Group nearby locations (count on the icon)",18,198,350,function(v)A.settings.cluster=v;A.Refresh()end)
    settings.favorites=W.Check(settings,"Show favorites only",18,229,180,function(v)A.filters.favoritesOnly=v;A.Refresh()end)
    settings.auto=W.Check(settings,"Auto-log looted chests",230,229,150,function(v)A.settings.autoJournal=v;A.Refresh()end)
    settings.size=W.Button(settings,"",18,263,180,function(self)
      A.OpenPicker(self,"World map chest icon size",{{value=20,text="Small • 10"},{value=26,text="Medium • 13"},{value=32,text="Large • 16"}},A.settings.iconSize,function(v)A.settings.iconSize=v;A.Refresh()end)
    end)
    settings.source=W.Button(settings,"",214,263,186,function(self)
      A.OpenPicker(self,"Source",{{value="all",text="All sources"},{value="legacy",text="Classic references"},{value="own",text="Your finds"}},A.filters.source,function(v)A.filters.source=v;A.Refresh()end)
    end)
    settings.type=W.Button(settings,"",18,298,382,function(self)A.OpenPicker(self,"Location type",A.TypeEntries(),A.filters.typeID,A.SelectType)end)
    settings.containers=W.Button(settings,"",18,333,382,function(self)
      A.OpenPicker(self,"Container category",A.ContainerEntries(),A.filters.containers,A.SetContainerCategory)
    end)
    W.Text(settings,"Search chest name, possible item or item ID",18,371,380)
    settings.search=W.Edit(settings,24,391,370,"");settings.search:SetMaxLetters(80)
    local debounce=0
    settings.search:SetScript("OnTextChanged",function()debounce=0.25 end)
    settings:SetScript("OnUpdate",function(_,dt)if debounce>0 then debounce=debounce-dt;if debounce<=0 then A.filters.query=settings.search:GetText();A.Refresh()end end end)
    W.Button(settings,"Reset filters",18,471,180,function()A.ResetFilters();settings.search:SetText("");updateSettings()end)
    W.Button(settings,"Done",214,471,186,function()A.filters.query=settings.search:GetText();A.Refresh();settings:Hide()end)
    settings.category=W.Button(settings,"",18,433,382,function(self)
      A.RareScannerCommand("explorer")
    end)
    W.Text(settings,"S = seen by you   L = looted by you   * = favorite.\nLive availability remains unknown.",18,509,380)
  end
  settings.search:SetText(A.filters.query or "");settings:Show();updateSettings()
end
local function refreshDetail()
  if not detail or not detail:IsShown() then return end
  local n=detail.nodes[detail.index]
  if not n then detail:Hide();return end
  A.selected,A.selectedArea=n,detail.area
  detail.title:SetText(A.TypeName(n.typeID))
  local _,status,colour=A.LocationStatus(n);detail.variant:SetText(status);detail.variant:SetTextColor(unpack(colour))
  detail.info:SetText(string.format("%.1f, %.1f • ",n.x*100,n.y*100)..A.DistanceText(n,detail.mapID))
  detail.sources:SetText(W.SourceText(n,detail.area))
  detail.journalInfo:SetText((A.Observation(n) and A.Timer(A.Observation(n),A.Now()) or "Stand beside the chest to record your first observation.").."\n\nLooting a known chest logs it automatically. Records do not detect respawn or current availability.")
  detail.group:SetText(#detail.nodes==1 and "Individual spawn location" or (detail.index.." / "..#detail.nodes.." nearby spawn locations"))
  detail.prev:SetShown(#detail.nodes>1);detail.next:SetShown(#detail.nodes>1)
  detail.prev:SetEnabled(detail.index>1);detail.next:SetEnabled(detail.index<#detail.nodes)
  detail.favorite:SetText(A.IsFavorite(n) and "Remove favorite *" or "Favorite *")
  detail.seen:SetText(n.own and "Mark seen" or "Record a find here")
  detail.seen:SetEnabled(not n.rare)
  detail.looted:SetEnabled(not not n.own);detail.capture:SetEnabled(not not n.own)
  detail.loot:SetNode(n)
end
function A.ShowMapDetail(nodes,area,mapID)
  if not detail then
    detail=W.Panel("ChestAtlasMapDetail",WorldMapFrame,420,760)
    detail:SetPoint("TOPRIGHT",WorldMapFrame,"TOPRIGHT",-8,-55);detail:SetScale(math.min(1,UIParent:GetHeight()/820))
    detail.title=W.Line(detail,"",18,18,350,"GameFontNormalLarge")
    detail.variant=W.Line(detail,"",18,45,375)
    detail.info=W.Line(detail,"",18,70,377)
    detail.prev=W.Button(detail,"<",18,94,55,function()detail.index=math.max(1,detail.index-1);refreshDetail()end)
    detail.group=W.Line(detail,"",84,100,250)
    detail.next=W.Button(detail,">",346,94,55,function()detail.index=math.min(#detail.nodes,detail.index+1);refreshDetail()end)
    detail.go=W.Button(detail,"Go here + arrow",18,130,222,function()A.Waypoint(detail.nodes[detail.index],detail.mapID)end)
    detail.favorite=W.Button(detail,"",251,130,150,function()A.ToggleFavorite(detail.nodes[detail.index])end)
    detail.tabs=W.Tabs(detail,18,172,383,555)
    local journal=detail.tabs.journal
    detail.journalInfo=W.Text(journal,"",0,0,383);detail.journalInfo:SetHeight(100);detail.journalInfo:SetJustifyV("TOP")
    detail.seen=W.Button(journal,"",0,118,183,function()
      local n=A.MakeOwn(detail.nodes[detail.index]);if n then n.lastSeen=A.Now();detail.nodes={n};detail.index=1;A.Refresh()end
    end)
    detail.looted=W.Button(journal,"Mark looted",197,118,186,function()A.MarkLooted(detail.nodes[detail.index],A.Now());A.Refresh()end)
    detail.capture=W.Button(journal,"Record latest loot window",0,154,383,function()
      local ok,err=A.RecordContents(detail.nodes[detail.index],A.lastLoot,A.Now());A.Print(ok and "Loot contents recorded for this find." or err);A.Refresh()
    end)
    detail.fullList=W.Button(journal,"Edit notes / respawn estimate in Atlas",0,192,383,function()A.displayMapID=detail.mapID;detail:Hide();A.ShowUI("journal")end)
    detail.sources=W.Text(detail.tabs.sources,"",0,0,383);detail.sources:SetHeight(450);detail.sources:SetJustifyV("TOP")
    detail.loot=W.Loot(detail.tabs.loot,0,0,383,5)
    detail.disclaimer=W.Line(detail.tabs.loot,"Classic estimates • Forever loot unconfirmed",0,0,383)
    detail.disclaimer:ClearAllPoints();detail.disclaimer:SetPoint("TOPLEFT",detail.loot,"BOTTOMLEFT",0,-12)
  end
  detail.nodes,detail.area,detail.mapID,detail.index=nodes,area,mapID,1
  detail:Show();refreshDetail();A.mapDetail=detail
end
function A.HideMapDetail()if detail then detail:Hide() end end
function A.CreateMapToolbar()
  if toolbar or not WorldMapFrame then return end
  local parent=WorldMapFrame.ScrollContainer or WorldMapFrame
  toolbar=CreateFrame("Frame","ChestAtlasMapToolbar",parent,"BackdropTemplate")
  toolbar:SetPoint("TOPLEFT",8,-8);toolbar:SetSize(574,64);toolbar:SetFrameStrata("HIGH")
  W.Surface(toolbar)
  toolbar.chests=W.Button(toolbar,"",7,5,100,function()
    A.settings.showPins=not A.settings.showPins;if not A.settings.showPins then A.settings.focus=false end;A.Refresh()
  end)
  toolbar.focus=W.Button(toolbar,"",112,5,119,function()
    A.settings.focus=not A.settings.focus;if A.settings.focus then A.settings.showPins=true end;A.Refresh()
  end)
  W.Button(toolbar,"Filters",236,5,128,function()A.ShowMapSettings()end)
  W.Button(toolbar,"List",369,5,94,function()A.ShowUI()end)
  toolbar.category=W.Button(toolbar,"",468,5,99,A.NextCategory)
  toolbar.summary=W.Line(toolbar,"",11,36,552)
  toolbar.rares=W.Button(toolbar,"Rare browser",354,32,109,function()A.RareScannerCommand("explorer")end)
  toolbar.dungeons=W.Button(toolbar,"Dungeons",354,32,109,function()A.ShowInstances()end)
  toolbar.route=W.Button(toolbar,"Chest route",468,32,99,function()
    if A.chestRoute then A.StopNavigation()else A.StartChestRoute(WorldMapFrame:GetMapID())end
  end)
  toolbar:Show();A.toolbar=toolbar
end
function A.RefreshMapUI()
  A.CreateMapToolbar()
  if toolbar then
    toolbar.chests:SetText(A.settings.showPins and "Markers: on" or "Markers: off")
    toolbar.focus:SetText(A.settings.focus and "Focus: on" or "Focus: off")
    local paired=A.CompanionActive and A.CompanionActive()
    toolbar.category:SetText(paired and "Rares in RS" or A.CategoryLabel())
    toolbar.category:SetEnabled(paired)
    toolbar.rares:Hide();toolbar.route:Show();toolbar.route:SetText(A.chestRoute and "Stop route" or "Chest route");toolbar.summary:SetWidth(338)
    toolbar.summary:SetText((A.expectedPins or 0).." locations • "..(A.drawnPins or 0).." icons • "..A.ContainerLabel(A.filters.containers))
  end
  updateSettings()
  if detail and detail:IsShown() then
    if WorldMapFrame:GetMapID()~=detail.mapID then detail:Hide() else refreshDetail() end
  end
end
