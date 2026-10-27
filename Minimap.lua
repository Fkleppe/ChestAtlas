local _,A=...
local pins,candidates,cachedMap={}, {}, nil
local ready=false
function A.MinimapPoint(dx,dy,radius,width,height,facing,shape,iconSize)
  if not radius or radius<=0 or width<=iconSize+4 or height<=iconSize+4 then return nil end
  local c,s=math.cos(facing or 0),math.sin(facing or 0)
  local rx,ry=dx*c-dy*s,-dx*s-dy*c
  local x,y=rx/radius*width/2,ry/radius*height/2
  local limitX,limitY=width/2-iconSize/2-2,height/2-iconSize/2-2
  if shape=="SQUARE" then
    if math.abs(x)>limitX or math.abs(y)>limitY then return nil end
  elseif (x/limitX)^2+(y/limitY)^2>1 then return nil end
  return x,y
end
local function hidePins()
  for _,pin in ipairs(pins) do pin:Hide();pin.sx=nil end
  A.minimapPinCount=0
end
local function createPin()
  local pin=CreateFrame("Button",nil,Minimap)
  pin:SetFrameStrata("HIGH");pin:SetFrameLevel(Minimap:GetFrameLevel()+20)
  pin:RegisterForClicks("LeftButtonUp","RightButtonUp")
  pin.Icon=pin:CreateTexture(nil,"ARTWORK");pin.Icon:SetAllPoints()
  local function text(key,point,x,y,color)
    local f=pin:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    f:SetPoint(point,x,y);f:SetShadowOffset(1,-1);f:SetShadowColor(0,0,0,1)
    if color then f:SetTextColor(color[1],color[2],color[3]) end
    pin[key]=f;return f
  end
  local label=text("Label","TOP",0,-20);label:SetWidth(125)
  text("Count","BOTTOMRIGHT",3,-2);text("Star","TOPRIGHT",3,4);text("Own","TOPLEFT",-3,3,{0.3,1,0.5})
  function pin:SetPosition(x,y)self.normalizedX,self.normalizedY=x,y end
  pin:SetScript("OnEnter",ChestAtlasPinMixin.OnMouseEnter)
  pin:SetScript("OnLeave",ChestAtlasPinMixin.OnMouseLeave)
  pin:SetScript("OnClick",function(self,button)
    if button=="RightButton" then A.Waypoint(self.node,self.mapID)
    else
      A.filters.areaID=0;A.displayMapID=self.mapID
      WorldMapFrame:Show();WorldMapFrame:SetMapID(self.mapID)
      A.ShowMapDetail(self.group.nodes,self.areaID,self.mapID);A.Refresh()
    end
  end)
  pins[#pins+1]=pin;return pin
end
function A.UpdateMinimap(force)
  if not ready then return end
  if not A.journal or not A.settings.minimap or not Minimap:IsShown() then hidePins();return end
  local map,x,y=A.PlayerPosition()
  local radius=C_Minimap and A.Safe(C_Minimap.GetViewRadius)
  local width,height
  if map and C_Map then width,height=A.Safe(C_Map.GetMapWorldSize,map) end
  if not map or type(radius)~="number" or radius<=0 or type(width)~="number" or type(height)~="number" or width<=0 or height<=0 then
    cachedMap=nil;hidePins();A.minimapStatus="Position or view radius unavailable";return
  end
  local angle=0
  local rotate=A.Safe((C_CVar and C_CVar.GetCVar) or GetCVar,"rotateMinimap")=="1"
  if C_Minimap and A.Safe(C_Minimap.IsRotateMinimapIgnored) then rotate=false end
  if rotate then angle=A.Safe(GetPlayerFacing);if type(angle)~="number" then hidePins();A.minimapStatus="Direction unavailable";return end end
  if force or cachedMap~=map then
    local info=A.MapInfo(map)
    candidates,A.minimapArea=A.NodesForMap(map,info and info.name,true)
    cachedMap=map
  end
  local w,h=Minimap:GetWidth(),Minimap:GetHeight()
  local size=math.max(16,A.settings.iconSize-6)
  local shape=A.Safe(GetMinimapShape) or "ROUND"
  local visible=A.minimapVisible or {}
  A.minimapVisible=visible
  for i=#visible,1,-1 do visible[i]=nil end
  for _,n in ipairs(candidates) do
    local sx,sy=A.MinimapPoint((n.x-x)*width,(n.y-y)*height,radius,w,h,angle,shape,size)
    if sx then visible[#visible+1]=n end
  end
  local groups=A.GroupNodes(visible,width*w/(radius*2),height*h/(radius*2),A.settings.cluster and size*0.85 or 0)
  local count=0
  for _,g in ipairs(groups) do
    local sx,sy=A.MinimapPoint((g.x-x)*width,(g.y-y)*height,radius,w,h,angle,shape,size)
    if sx then
      count=count+1
      local pin=pins[count] or createPin()
      -- Same nodes as last time (in order)? Then the pin's look is still right.
      local same=not force and pin.node==g.nodes[1] and pin.mapID==map and pin.shownNodes and #pin.shownNodes==#g.nodes
      if same then for i,n in ipairs(g.nodes) do if pin.shownNodes[i]~=n then same=false;break end end end
      if not same then
        ChestAtlasPinMixin.OnAcquired(pin,g.nodes[1],A.minimapArea,g,size)
        pin.shownNodes=pin.shownNodes or {}
        for i=#pin.shownNodes,1,-1 do pin.shownNodes[i]=nil end
        for i,n in ipairs(g.nodes) do pin.shownNodes[i]=n end
      end
      pin.group,pin.mapID=g,map
      if pin.sx~=sx or pin.sy~=sy or not pin:IsShown() then
        pin:ClearAllPoints();pin:SetPoint("CENTER",Minimap,"CENTER",sx,sy);pin.sx,pin.sy=sx,sy
      end
      pin:Show()
    end
  end
  for i=count+1,#pins do pins[i]:Hide();pins[i].sx=nil end
  A.minimapPinCount,A.minimapStatus=count,"Ready"
end
function A.InitMinimap()
  if ready or not Minimap then return end
  ready=true;A.minimapPins=pins
  local updater=CreateFrame("Frame",nil,UIParent);updater:Show();local elapsed=0
  updater:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=0.1 then elapsed=0;A.UpdateMinimap(false) end
  end)
  A.minimapUpdater=updater;A.UpdateMinimap(true)
end
