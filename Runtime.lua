local addonName, A = ...
A.addonName = addonName

function A.Print(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd36aChest Atlas:|r "..text) end
end
function A.Now() return GetServerTime and GetServerTime() or time() end
function A.Safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local function pack(...)return {n=select('#',...),...}end
  local values=pack(pcall(fn,...))
  if not values[1] then return nil end
  for i=2,values.n do if issecretvalue and issecretvalue(values[i]) then return nil end end
  return unpack(values,2,values.n)
end
function A.PlayerPosition()
  if InCombatLockdown and InCombatLockdown() then return nil end
  if not C_Map then return nil end
  local mapID = A.Safe(C_Map.GetBestMapForUnit,"player")
  if not mapID then return nil end
  local pos = A.Safe(C_Map.GetPlayerMapPosition,mapID,"player")
  if not pos then return nil end
  local x,y = A.Safe(pos.GetXY,pos)
  if not A.ValidPosition(mapID,x,y) then return nil end
  return mapID,x,y
end
function A.MapInfo(mapID)
  return C_Map and A.Safe(C_Map.GetMapInfo,mapID)
end
function A.LocalAreaName(areaID)
  return C_Map and A.Safe(C_Map.GetAreaInfo,areaID)
end
function A.FindMapForArea(areaID)
  if A.db.bindings[areaID] then return A.db.bindings[areaID] end
  local mapID=A.PlayerPosition()
  if not mapID then return nil end
  local seen={}
  while mapID and not seen[mapID] do
    seen[mapID]=true
    local info=A.MapInfo(mapID)
    if info and A.ResolveArea(mapID,info.name)==areaID then return mapID end
    local children=A.Safe(C_Map.GetMapChildrenInfo,mapID,nil,true) or {}
    for _,child in ipairs(children) do
      if child.mapID and A.ResolveArea(child.mapID,child.name)==areaID then return child.mapID end
    end
    mapID=info and info.parentMapID
    if mapID==0 then return nil end
  end
end
function A.Refresh()
  if A.provider then A.provider:RefreshAllData() end
  if A.RefreshUI then A.RefreshUI() end
  if A.RefreshMapUI then A.RefreshMapUI() end
  if A.UpdateMinimap then A.UpdateMinimap(true) end
  if A.RefreshInstances then A.RefreshInstances() end
end
function A.NewAtPlayer(typeID)
  local mapID,x,y = A.PlayerPosition()
  if not mapID then A.Print("Position unavailable. Leave combat and stand outdoors in a zone."); return end
  local n,err = A.AddObservation(mapID,x,y,typeID,A.Now(),A.build)
  if not n then A.Print(err); return end
  A.selected = n
  A.selectedArea=A.ResolveArea(mapID,(A.MapInfo(mapID) or {}).name)
  A.filters.areaID=0
  if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
  A.Print("Your find was added at your position. Coordinates are approximate.")
  A.Refresh()
  if A.ShowUI then A.ShowUI() end
end
function A.MakeOwn(n)
  if not n then return nil end
  if n.rare then A.Print("Rare NPC locations are historical references. Chest journal actions do not apply.");return nil end
  if n.own then return n end
  local mapID,x,y = A.PlayerPosition()
  if not mapID then A.Print("Player position unavailable."); return nil end
  local info=A.MapInfo(mapID)
  local area=A.ResolveArea(mapID,info and info.name)
  if area~=A.selectedArea or (x-n.x)^2+(y-n.y)^2>0.0001 then
    A.Print("Move to the chest before recording a find (within about 1% of the zone map).")
    return nil
  end
  local own=A.AddObservation(mapID,x,y,n.typeID,A.Now(),A.build)
  own.referenceID=n.id
  own.legacyRespawn=n.legacyRespawn
  A.selected=own
  return own
end
function A.Waypoint(n, contextMapID, routeStep)
  if not n then return end
  local mapID=n.mapID or contextMapID or A.displayMapID
  if not A.ValidPosition(mapID,n.x,n.y) then return end
  if A.StartNavigation then A.StartNavigation(n,mapID,routeStep) end
  local canSet = C_Map and A.Safe(C_Map.CanSetUserWaypointOnMap,mapID)
  if canSet ~= false and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local point=A.Safe(UiMapPoint.CreateFromCoordinates,mapID,n.x,n.y)
    local ok=point and pcall(C_Map.SetUserWaypoint,point)
    if ok then
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
      if not routeStep then A.Print("Waypoint set.")end; return
    end
  end
  A.Print(string.format("Go to %s: %.1f, %.1f. The Chest Atlas arrow points the way when position is available.",A.TypeName(n.typeID),n.x*100,n.y*100))
end

-- Instance ID for 5-player dungeons and raids; battlegrounds and the open world return nil.
function A.CurrentInstance()
  local inside,kind=A.Safe(IsInInstance)
  if not inside or (kind~="party" and kind~="raid") then return nil end
  local id=select(8,A.Safe(GetInstanceInfo))
  return type(id)=="number" and id>0 and id or nil
end
-- The loot API gives an object GUID but no name. Remember the last named world object
-- (cast target or mouseover tooltip) and the last gathering cast, for discoveries.
local recent={}
local gathering={Herbalism=true,["Herb Gathering"]=true,Mining=true,Fishing=true,Skinning=true,Cultivation=true,Gathering=true,Disenchant=true}
function A.NoteObjectName(name)
  if type(name)=="string" and name~="" and not (issecretvalue and issecretvalue(name)) then recent.name,recent.nameTime=name,GetTime() end
end
function A.NoteCast(spellID)
  local getName=C_Spell and C_Spell.GetSpellName or GetSpellInfo
  local name=getName and A.Safe(getName,spellID)
  if type(name)=="string" and gathering[name] then recent.gatherTime=GetTime() end
end
local lootSerial, activeLoot = 0, nil
function A.CaptureLoot()
  local instanceID=A.CurrentInstance()
  local mapID,x,y
  if not instanceID then mapID,x,y=A.PlayerPosition();if not mapID then return end end
  local num=A.Safe(GetNumLootItems)
  if type(num)~="number" or num<1 then return end
  if not activeLoot then
    lootSerial=lootSerial+1
    local now=GetTime()
    activeLoot={time=A.Now(),mapID=mapID,x=x,y=y,instanceID=instanceID,key=A.sessionID..":"..lootSerial,items={},bySlot={},
      objectName=recent.nameTime and now-recent.nameTime<=20 and recent.name or nil,
      gathering=recent.gatherTime~=nil and now-recent.gatherTime<=10}
  end
  for slot=1,num do
    local link=A.Safe(GetLootSlotLink,slot)
    local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
    local _,_,quantity=A.Safe(GetLootSlotInfo,slot)
    if id and type(quantity)=="number" and quantity>0 then
      activeLoot.bySlot[slot]={id=id,count=quantity}
    end
    -- Read the source for every slot, so coin-only chests are still attributed.
    if GetLootSourceInfo then
      local ok,sources=pcall(function() return {GetLootSourceInfo(slot)} end)
      if ok then
        for i=1,#sources,2 do
          local guid=sources[i]
          if not (issecretvalue and issecretvalue(guid)) and type(guid)=="string" then
            local kind=guid:match("^([^-]+)")
            if kind~="GameObject" then activeLoot.sourceRejected=true end
            if activeLoot.sourceGUID and activeLoot.sourceGUID~=guid then activeLoot.sourceRejected=true end
            activeLoot.sourceGUID=guid
            local objectID=tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
            if objectID then
              if activeLoot.typeID and activeLoot.typeID~=objectID then activeLoot.sourceRejected=true end
              activeLoot.typeID=objectID
            end
          end
        end
      end
    end
  end
  local totals={}
  for _,item in pairs(activeLoot.bySlot) do totals[item.id]=(totals[item.id] or 0)+item.count end
  activeLoot.items={}
  for id,count in pairs(totals) do activeLoot.items[#activeLoot.items+1]={id=id,count=count} end
  table.sort(activeLoot.items,function(a,b)return a.id<b.id end)
  A.lastLoot=activeLoot
end
function A.AutoLog(snapshot)
  if not (snapshot and A.journal and A.settings and A.settings.autoJournal) then return end
  local discovery
  if snapshot.typeID and not snapshot.sourceRejected and not snapshot.gathering and A.IsNewObject(snapshot.typeID) then
    A.RegisterDiscovered(snapshot.typeID,snapshot.objectName,snapshot.instanceID);discovery=true
    A.Print("New object, not in Classic data: "..A.TypeName(snapshot.typeID).." #"..snapshot.typeID..". Saved as your discovery.")
  end
  if snapshot.instanceID then
    local e,result=A.RecordInstanceLoot(snapshot,A.Now())
    if e and not result.same and not discovery then
      A.Print(A.TypeName(snapshot.typeID).." logged in "..A.InstanceName(snapshot.instanceID)..(e.loots>1 and (" • "..e.loots.." loots") or "").." • /ca dungeons")
    end
    if e and A.RefreshInstances then A.RefreshInstances() end
    return
  end
  local info=A.MapInfo(snapshot.mapID)
  local area=A.ResolveArea(snapshot.mapID,info and info.name)
  local n,result=A.AutoRecord(snapshot,area,A.Now())
  if not n or result.same then return end
  local text=A.TypeName(n.typeID)..(result.new and " added to your journal" or " logged")..
    (result.items>0 and (" • "..result.items.." item"..(result.items==1 and "" or "s")) or "")..
    (result.reloot and (" • back after "..A.Ago(result.reloot)) or "")
  A.Print(text..". /ca auto turns this off.")
  local route=A.chestRoute
  local stop=route and route.nodes[route.index]
  if stop and (stop==n or stop.id==n.referenceID or (stop.referenceID and stop.referenceID==n.referenceID)) then
    A.AdvanceChestRoute(false)
  end
  A.Refresh()
end

local frame=CreateFrame("Frame")
A.events=frame
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","LOOT_READY","LOOT_OPENED","LOOT_CLOSED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED"}) do pcall(frame.RegisterEvent,frame,event) end
if GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnShow",function(tip)
    -- World objects use the default anchor on UIParent and carry no unit.
    local owner=tip.GetOwner and tip:GetOwner()
    local unit=tip.GetUnit and select(2,tip:GetUnit())
    local line=_G.GameTooltipTextLeft1
    if owner==UIParent and not unit and line and line.GetText then A.NoteObjectName(A.Safe(line.GetText,line)) end
  end)
end
frame:SetScript("OnEvent",function(_,event,...)
  if event=="ADDON_LOADED" and (...)==addonName then
    ChestAtlasDB=A.Init(ChestAtlasDB)
    local version,build,_,interface=GetBuildInfo()
    A.build=(version or "?").."."..(build or "?")
    A.isForever=(version and version:match("^1%.60%.")) or interface==16001 or interface==160001
    local region=GetCurrentRegion and GetCurrentRegion() or 0
    A.UseJournal(tostring(region)..":"..(GetRealmName() or "Unknown")..":"..(A.isForever and "Forever" or "Other"))
    A.sessionID=tostring(A.Now())..":"..tostring(GetTime())
  elseif event=="PLAYER_LOGIN" then
    if A.SetupRareScanner then A.SetupRareScanner()end
    A.AttachMap()
    if A.InitMinimap then A.InitMinimap() end
    A.Print("v"..A.version.." • /ca opens the atlas. Click a chest: loot / Go here. Right-click: waypoint + arrow.")
    if not A.isForever then A.Print("This client is not recognized as Forever. Its journal is kept separate.") end
  elseif event=="LOOT_READY" or event=="LOOT_OPENED" then A.CaptureLoot()
  elseif event=="LOOT_CLOSED" then
    local snapshot=activeLoot;activeLoot=nil
    if snapshot then local ok,err=pcall(A.AutoLog,snapshot);if not ok then A.Print("Auto-log failed: "..tostring(err)) end end
  elseif event=="UNIT_SPELLCAST_SENT" then
    local unit,target=...
    if unit=="player" then A.NoteObjectName(target) end
  elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
    local unit,_,spellID=...
    if unit=="player" then A.NoteCast(spellID) end
  elseif (event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT") and A.RefreshItemWidgets then A.RefreshItemWidgets(...)
  elseif event=="PLAYER_ENTERING_WORLD" and A.db then
    if A.SetupRareScanner then A.SetupRareScanner()end
    A.Refresh()
    if A.AnnounceInstance then A.AnnounceInstance() end
  elseif event=="ZONE_CHANGED_NEW_AREA" and A.db and A.AnnounceInstance then A.AnnounceInstance()
  end
end)

-- Pin templates use the same MapCanvas mechanism as Blizzard's own providers.
ChestAtlasPinMixin={}
function A.UpdateShimmer(pin,dt)
  pin.shimmerTime=(pin.shimmerTime or 0)+dt
  pin.shimmerTick=(pin.shimmerTick or 0)+dt
  if pin.shimmerTick<0.05 then return end
  pin.shimmerTick=0
  local t=(pin.shimmerTime+(pin.shimmerPhase or 0))%3.6
  local pulse=t<1 and math.sin(t*math.pi) or 0
  pin.Sparkle:SetAlpha(pulse*0.95)
  pin.Glow:SetAlpha(0.08+pulse*0.16)
  if pulse>0 then
    local size=pin.iconSize or A.settings.iconSize
    pin.Sparkle:ClearAllPoints()
    pin.Sparkle:SetPoint("CENTER",pin,"CENTER",size*(t-0.5)*0.6,size*(0.05+t*0.18))
    local sparkleSize=(8+8*pulse)*(pin.iconScale or 1)
    pin.Sparkle:SetSize(sparkleSize,sparkleSize)
  end
end
function ChestAtlasPinMixin:OnLoad()
  -- Default pins are below fog-of-war and exploration overlays on WorldMap.
  self:UseFrameLevelType("PIN_FRAME_LEVEL_CHESTATLAS")
  self:SetSize(13,13)
  self:RegisterForClicks("LeftButtonUp","RightButtonUp")
  self:SetScript("OnUpdate",A.UpdateShimmer)
end
function ChestAtlasPinMixin:OnAcquired(node,areaID,group,iconSize)
  self.node,self.areaID=node,areaID
  self.group=group or {nodes={node},x=node.x,y=node.y,own=node.own}
  -- Explicit sizes come from the minimap; scale only chest pins on the world map.
  self.iconScale=(iconSize or node.rare) and 1 or 0.5
  self.iconSize=iconSize or A.settings.iconSize*self.iconScale
  self:SetSize(self.iconSize,self.iconSize)
  A.ApplyLocationIcon(self.Icon,node)
  self.Icon:SetVertexColor(1,1,1)
  A.ApplyLocationIcon(self.Glow,node)
  self.Glow:SetSize(self.iconSize+6*self.iconScale,self.iconSize+6*self.iconScale)
  self.Glow:SetVertexColor(1,0.83,0.38);self.Glow:SetAlpha(0.08)
  self.Sparkle:SetTexture(A.sparklePath);self.Sparkle:SetAlpha(0)
  self.shimmerTime,self.shimmerTick,self.shimmerPhase=0,0,(node.x*17+node.y*31)%3.6
  self.Label:SetText(A.TypeName(node.typeID))
  self.Label:SetTextColor(1,0.88,0.5)
  if node.rare then self.Label:SetTextColor(0.8,0.85,1);self.Glow:SetVertexColor(0.6,0.7,1)end
  self.Label:SetShown(A.settings.labels)
  self.Count:SetText(#self.group.nodes>1 and tostring(#self.group.nodes) or "")
  local favorite=false
  for _,n in ipairs(self.group.nodes) do favorite=favorite or A.IsFavorite(n) end
  self.Star:SetText(favorite and "*" or "")
  self.Own:SetText(self.group.own and "+" or "")
  if not node.rare then
    local status,_,colour=A.LocationStatus(node)
    self.Own:SetText(status=="looted" and "L" or status=="seen" and "S" or "")
    self.Own:SetTextColor(unpack(colour));self.Glow:SetVertexColor(unpack(colour))
  end
  self:SetAlpha(1)
  self:SetPosition(self.group.x,self.group.y)
end
function ChestAtlasPinMixin:OnMouseEnter()
  self.Label:Show()
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
  GameTooltip:AddLine(A.TypeName(self.node.typeID),1,0.84,0.4)
  GameTooltip:AddLine(string.format("%.1f, %.1f • ",self.node.x*100,self.node.y*100)..A.DistanceText(self.node,self.mapID or self:GetMap():GetMapID()),1,1,1)
  local _,status,colour=A.LocationStatus(self.node)
  GameTooltip:AddLine(status,colour[1],colour[2],colour[3],true)
  GameTooltip:AddLine("Live availability unknown",0.64,0.72,0.80)
  if #self.group.nodes>1 then GameTooltip:AddLine(#self.group.nodes.." nearby locations. Click to select one.",0.7,0.9,1,true) end
  GameTooltip:AddLine("Click: details / loot • Right-click: navigate",0.6,0.8,1,true)
  GameTooltip:Show()
end
function ChestAtlasPinMixin:OnMouseLeave() self.Label:SetShown(A.settings.labels);GameTooltip:Hide() end
function ChestAtlasPinMixin:ShouldMouseButtonBePassthrough() return false end
function ChestAtlasPinMixin:OnMouseClickAction(button)
  if button=="RightButton" then A.Waypoint(self.node,self:GetMap():GetMapID())
  else A.selected,A.selectedArea=self.node,self.areaID
    if A.ShowMapDetail then A.ShowMapDetail(self.group.nodes,self.areaID,self:GetMap():GetMapID()) else A.ShowUI() end
  end
end
-- Native suppression is reversible and also catches pins created after enabling focus.
ChestAtlasFocusMixin=CreateFromMixins(MapCanvasPinMixin or {})
function ChestAtlasFocusMixin:OnLoad()
  self:SetSize(1,1);self:SetAlpha(0);self.tracked={}
  local elapsed=0
  self:SetScript("OnUpdate",function(pin,dt)
    elapsed=elapsed+dt
    if elapsed>=0.2 then elapsed=0;local map=pin:GetMap();if map then map:SetPinSuppressionDirty() end end
  end)
end
function ChestAtlasFocusMixin:OnAcquired()self:SetPosition(0,0);self:SetAlpha(0)end
function ChestAtlasFocusMixin:IsPinSuppressor()return true end
function ChestAtlasFocusMixin:ShouldSuppressPin(pin)
  local name=pin.pinTemplate or ""
  if not A.settings.focus or name:find("ChestAtlas",1,true) then return false end
  if A.CompanionActive and A.CompanionActive() and (name=="RSEntityPinTemplate" or name=="RSGroupPinTemplate" or name=="RSGuideTemplate" or name=="RSOverlayTemplate") then return false end
  -- Keep map artwork, area shading and the player's optional position frame.
  if name:find("Fog") or name:find("Exploration") or name:find("Blob") or name:find("Overlay") or name:find("MapHighlight") then return false end
  if A.settings.keepPlayer and name=="GroupMembersPinTemplate" then return false end
  return true
end
function ChestAtlasFocusMixin:TrackSuppressedPin(pin)self.tracked[#self.tracked+1]=pin end
function ChestAtlasFocusMixin:ResetSuppression()
  for _,pin in ipairs(self.tracked or {}) do if pin:GetPinSuppressor()==self then pin:ClearSuppression() end end
  self.tracked={}
end
function ChestAtlasFocusMixin:FinalizeSuppression()end
function ChestAtlasFocusMixin:OnReleased()self:ResetSuppression();MapCanvasPinMixin.OnReleased(self)end
function A.AttachMap()
  if A.provider or not WorldMapFrame or not WorldMapFrame.AddDataProvider or not MapCanvasDataProviderMixin then return end
  local levels=WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
  if levels then
    if not levels:InsertFrameLevelAbove("PIN_FRAME_LEVEL_CHESTATLAS","PIN_FRAME_LEVEL_VIGNETTE") then
      levels:AddFrameLevel("PIN_FRAME_LEVEL_CHESTATLAS")
    end
  end
  local provider=CreateFromMixins(MapCanvasDataProviderMixin)
  function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("ChestAtlasFocusTemplate")
    self:GetMap():RemoveAllPinsByTemplate("ChestAtlasPinTemplate")
  end
  function provider:RefreshAllData()
    local ok,err=pcall(function()
      self:RemoveAllData()
      if not A.journal then return end
      local map=self:GetMap()
      local mapID=map:GetMapID()
      local info=A.MapInfo(mapID)
      local nodes,area=A.NodesForMap(mapID,info and info.name)
      A.pinMapID,A.expectedPins=mapID,#nodes
      if A.settings.focus then map:AcquirePin("ChestAtlasFocusTemplate") end
      local canvas=map.GetCanvas and map:GetCanvas()
      local width=canvas and canvas:GetWidth() or 1000
      local height=canvas and canvas:GetHeight() or 668
      local groups=A.GroupNodes(nodes,width,height,A.settings.cluster and A.WorldMapIconSize()*0.85 or 0)
      if A.settings.showPins then
        for _,g in ipairs(groups) do map:AcquirePin("ChestAtlasPinTemplate",g.nodes[1],area,g) end
      end
      A.drawnPins=map.GetNumActivePinsByTemplate and map:GetNumActivePinsByTemplate("ChestAtlasPinTemplate") or (A.settings.showPins and #groups or 0)
      A.pinLevel=levels and levels:GetValidFrameLevel("PIN_FRAME_LEVEL_CHESTATLAS")
      A.fogLevel=levels and levels:GetValidFrameLevel("PIN_FRAME_LEVEL_FOG_OF_WAR")
    end)
    if ok then A.pinError=nil
    else
      A.drawnPins=0
      if A.pinError~=tostring(err) then A.Print("Map markers failed: "..tostring(err)..". Use /ca status for details.") end
      A.pinError=tostring(err)
    end
    if A.RefreshMapUI then A.RefreshMapUI() end
  end
  if WorldMapFrame.SetPinTemplateType then WorldMapFrame:SetPinTemplateType("ChestAtlasPinTemplate","BUTTON") end
  if WorldMapFrame.SetPinTemplateType then WorldMapFrame:SetPinTemplateType("ChestAtlasFocusTemplate","FRAME") end
  WorldMapFrame:AddDataProvider(provider)
  A.provider=provider
  if WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow",function()provider:RefreshAllData()end)
  end
  provider:RefreshAllData()
end

SLASH_CHESTATLAS1="/ca"
SLASH_CHESTATLAS2="/chestatlas"
SlashCmdList.CHESTATLAS=function(message)
  local command,arg=(message or ""):match("^(%S*)%s*(.-)$")
  command=command:lower()
  if command=="add" then A.NewAtPlayer(tonumber(arg) or A.filters.typeID)
  elseif command=="backup" then A.ShowBackup(false)
  elseif command=="import" then A.ShowBackup(true)
  elseif command=="bind" then
    local mapID=A.PlayerPosition()
    if mapID and A.Bind(tonumber(arg),mapID) then A.Print("Reference zone bound to the current map."); A.Refresh()
    else A.Print("Use /ca bind <Vanilla-areaID> while in the matching zone. See the zone list.") end
  elseif command=="status" then
    local mapID=A.PlayerPosition(); local info=mapID and A.MapInfo(mapID)
    local area=mapID and A.ResolveArea(mapID,info and info.name)
    local count=0; for _ in pairs(A.journal.nodes) do count=count+1 end
    A.Print("v"..A.version.." | client "..A.build.." | map "..tostring(mapID).." | reference zone "..tostring(area).." | personal locations "..count.." | map provider "..tostring(A.provider~=nil))
    A.Print("Map markers: "..tostring(A.drawnPins or 0).." icons from "..tostring(A.expectedPins or 0).." locations | displayed map "..tostring(A.pinMapID).." | frame level "..tostring(A.pinLevel).." above map overlay "..tostring(A.fogLevel).." | error "..(A.pinError or "none"))
    A.Print("Minimap: "..tostring(A.minimapPinCount or 0).." nearby icons | "..(A.minimapStatus or "Waiting").." | individual spawns "..tostring(not A.settings.cluster))
  elseif command=="dungeons" or command=="dungeon" or command=="instances" or command=="raid" then A.ShowInstances()
  elseif command=="auto" then
    A.settings.autoJournal=not A.settings.autoJournal;A.Refresh()
    A.Print("Auto-log looted chests: "..(A.settings.autoJournal and "on" or "off")..".")
  elseif command=="focus" then A.settings.focus=not A.settings.focus;A.Refresh()
  elseif command=="map" then WorldMapFrame:Show();A.Refresh()
  elseif command=="route" then A.StartChestRoute()
  elseif command=="next" then A.AdvanceChestRoute(false)
  elseif command=="skip" then A.AdvanceChestRoute(true)
  elseif command=="stop" then if A.StopNavigation then A.StopNavigation() end
  elseif command=="reset" then A.ResetFilters()
  else A.AttachMap(); A.ShowUI() end
end
