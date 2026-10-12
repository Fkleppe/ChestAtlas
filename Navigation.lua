local _,A=...
local nav,elapsed
function A.NavigationVector(px,py,tx,ty,width,height,facing)
  local dx,dy=(tx-px)*width,(ty-py)*height
  return math.atan2(-dx,-dy)-facing,math.sqrt(dx*dx+dy*dy)
end
function A.UpdateNavigation()
  if not nav or not A.navigation then return end
  local goal=A.navigation
  local route=A.chestRoute
  nav.progress:SetText(route and ("CHEST ROUTE • "..route.index.." / "..#route.nodes.." • skipped "..route.skipped) or "CHEST ATLAS • NAVIGATION")
  nav.next:SetShown(route~=nil);nav.skip:SetShown(route~=nil)
  nav.stop:SetText(route and "Stop route" or "Stop arrow")
  nav.title:SetText(A.TypeName(goal.node.typeID))
  nav.coords:SetText(string.format("%.1f, %.1f",goal.node.x*100,goal.node.y*100)..(goal.node.rare and "" or " • "..A.CashText(goal.node)))
  if nav.best then
    local best=A.BestLoot(goal.node);nav.best.item,nav.best.valueSummary=best.item,best
    nav.best.icon:SetTexture(best.item and best.item.icon or 134400)
    nav.best.name:SetText(best.item and best.item.name or (best.total>0 and "Vendor value unknown" or "No known loot"));A.Widgets.ItemColor(nav.best.name,best.item)
    nav.best.meta:SetText(best.item and (A.ShortMoney(best.item.price).." each • "..A.ChanceText(goal.node,best.item.id)) or "Possible loot • vendor value unknown")
  end
  local map,x,y=A.PlayerPosition()
  local facing=A.Safe(GetPlayerFacing)
  local width,height
  if C_Map then width,height=A.Safe(C_Map.GetMapWorldSize,goal.mapID) end
  if map~=goal.mapID or not x or not y or type(facing)~="number" or type(width)~="number" or type(height)~="number" or width<=0 or height<=0 then
    nav.arrow:Hide()
    local info=A.MapInfo(goal.mapID)
    nav.distance:SetText(map and map~=goal.mapID and ("Travel to "..(info and info.name or "the target zone")) or (InCombatLockdown and InCombatLockdown() and "Arrow paused in combat" or "Waiting for player position"))
    return
  end
  local rotation,yards=A.NavigationVector(x,y,goal.node.x,goal.node.y,width,height,facing)
  nav.arrow:SetRotation(rotation);nav.arrow:Show()
  nav.distance:SetText(yards<=10 and "At the target location" or string.format("%.0f m • straight line",yards*0.9144))
  nav.arrow:SetVertexColor(yards<=10 and 0.4 or 1,1,yards<=10 and 0.5 or 1)
end
local function createNavigation()
  nav=CreateFrame("Frame","ChestAtlasNavigation",UIParent,"BackdropTemplate")
  nav:SetSize(320,235);nav:SetPoint("TOP",UIParent,"TOP",0,-100);nav:SetFrameStrata("HIGH")
  local W=A.Widgets;W.Surface(nav);W.Rule(nav,14,120,292)
  nav.progress=W.Line(nav,"",14,10,292);nav.progress:SetTextColor(unpack(W.gold))
  nav:SetMovable(true);nav:EnableMouse(true);nav:RegisterForDrag("LeftButton");nav:SetClampedToScreen(true)
  nav:SetScript("OnDragStart",function(self)self:StartMoving()end)
  nav:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
  nav.arrow=nav:CreateTexture(nil,"ARTWORK");nav.arrow:SetSize(58,58);nav.arrow:SetPoint("TOPLEFT",10,-46);nav.arrow:SetTexture(A.arrowPath)
  local function text(y,font)
    local f=nav:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");f:SetPoint("TOPLEFT",76,-y);f:SetWidth(230);f:SetJustifyH("LEFT");return f
  end
  nav.title=text(36,"GameFontNormal");nav.title:SetHeight(18);nav.title:SetWordWrap(false)
  nav.distance=text(61);nav.distance:SetHeight(30)
  nav.coords=text(99);nav.coords:SetHeight(16);nav.coords:SetWordWrap(false)
  nav.best=CreateFrame("Button",nil,nav);nav.best:SetPoint("TOPLEFT",14,-130);nav.best:SetSize(292,38)
  nav.best.icon=nav.best:CreateTexture(nil,"ARTWORK");nav.best.icon:SetSize(30,30);nav.best.icon:SetPoint("TOPLEFT",0,-2)
  nav.best.name=W.Line(nav.best,"",38,0,254);nav.best.meta=W.Line(nav.best,"",38,20,254);nav.best.meta:SetTextColor(unpack(W.gold))
  nav.best:SetScript("OnEnter",W.ItemTooltip);nav.best:SetScript("OnLeave",function()GameTooltip:Hide()end)
  local details=W.Button(nav,"View loot",14,174,140,function()end)
  details:SetScript("OnClick",function()
    if A.navigation then
      local goal=A.navigation
      WorldMapFrame:Show();WorldMapFrame:SetMapID(goal.mapID)
      A.ShowMapDetail({goal.node},goal.area,goal.mapID);A.Refresh()
    end
  end)
  nav.details=details
  local stop=W.Button(nav,"Stop arrow",166,174,140,function()end)
  nav.stop=stop
  stop:SetScript("OnClick",function()A.StopNavigation()end)
  nav.next=W.Button(nav,"Next stop",14,205,140,function()A.AdvanceChestRoute(false)end)
  nav.skip=W.Button(nav,"Skip stop",166,205,140,function()A.AdvanceChestRoute(true)end)
  elapsed=0
  nav:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>=0.1 then elapsed=0;A.UpdateNavigation()end end)
  A.navFrame=nav
end
function A.StartNavigation(n,mapID,routeStep)
  if not routeStep then A.chestRoute=nil end
  if not nav then createNavigation() end
  local info=A.MapInfo(mapID)
  A.navigation={node=n,mapID=mapID,area=A.ResolveArea(mapID,info and info.name)}
  nav:Show();A.UpdateNavigation()
  if A.RefreshMapUI then A.RefreshMapUI()end
  if A.RefreshUI then A.RefreshUI()end
end
function A.StopNavigation()
  if C_Map and C_Map.GetUserWaypoint and C_Map.ClearUserWaypoint and A.navigation then
    local point=A.Safe(C_Map.GetUserWaypoint)
    local pos=point and point.position
    local x,y
    if pos and pos.GetXY then x,y=A.Safe(pos.GetXY,pos) end
    local goal=A.navigation
    if point and point.uiMapID==goal.mapID and x and y and math.abs(x-goal.node.x)<0.00001 and math.abs(y-goal.node.y)<0.00001 then
      pcall(C_Map.ClearUserWaypoint)
    end
  end
  A.navigation=nil
  A.chestRoute=nil
  if nav then nav:Hide() end
  if A.RefreshMapUI then A.RefreshMapUI()end
  if A.RefreshUI then A.RefreshUI()end
end

-- A visit order using map-world distance, not a terrain path or spawn detector.
-- Keep route state in memory; next/skip never writes to the personal journal.
-- Auto-log advances the route only when the current stop's chest is looted.
function A.BuildChestRoute(nodes,x,y,width,height)
  local remaining,keys={},{}
  for _,n in ipairs(nodes) do
    if not n.rare and A.ValidPosition(1,n.x,n.y) then
      local key=A.FavoriteKey(n)
      local prior=keys[key]
      if not prior then keys[key]=n;remaining[#remaining+1]=n
      elseif n.own then
        for i,p in ipairs(remaining)do if p==prior then remaining[i]=n;break end end
        keys[key]=n
      end
    end
  end
  if #remaining>150 then return nil,"More than 150 stops. Narrow the zone filters or select favorites first." end
  local route={}
  while #remaining>0 do
    local nearest,dist=1,math.huge
    for i,n in ipairs(remaining)do
      local d=((n.x-x)*width)^2+((n.y-y)*height)^2
      if d<dist or d==dist and tostring(n.id)<tostring(remaining[nearest].id) then nearest,dist=i,d end
    end
    local n=table.remove(remaining,nearest);route[#route+1]=n;x,y=n.x,n.y
  end
  return route
end
function A.StartChestRoute(mapID)
  local playerMap,x,y=A.PlayerPosition()
  mapID=mapID or (WorldMapFrame:IsShown() and WorldMapFrame:GetMapID()) or A.displayMapID or playerMap
  if not playerMap or playerMap~=mapID then A.Print("Stand in the route's zone outside combat before starting.");return false end
  local width,height=A.Safe(C_Map.GetMapWorldSize,mapID)
  if type(width)~="number" or type(height)~="number" or width<=0 or height<=0 then A.Print("Map distances unavailable; route not started.");return false end
  local info=A.MapInfo(mapID)
  local nodes,area=A.NodesForMap(mapID,info and info.name)
  local route,err=A.BuildChestRoute(nodes,x,y,width,height)
  if not route or #route==0 then A.Print(err or "No chests match the current filters.");return false end
  A.chestRoute={nodes=route,index=1,skipped=0,mapID=mapID,area=area}
  A.Waypoint(route[1],mapID,true)
  A.Print("Chest route: "..#route.." stops. Looting the stop's chest advances; Next / Skip if it is empty. Straight-line guidance.")
  if A.RefreshMapUI then A.RefreshMapUI()end
  return true
end
function A.AdvanceChestRoute(skip)
  local route=A.chestRoute
  if not route then A.Print("Start a chest route first with /ca route.");return false end
  if skip then route.skipped=route.skipped+1 end
  route.index=route.index+1
  if route.index>#route.nodes then
    local skipped=route.skipped;A.StopNavigation();A.Print("Chest route finished • skipped "..skipped..".")
  else
    A.Waypoint(route.nodes[route.index],route.mapID,true)
    if A.RefreshMapUI then A.RefreshMapUI()end
  end
  return true
end
