local _, A = ...
local nativeCreateFrame=CreateFrame
function Mixin(target,...)
  for i=1,select('#',...)do for k,v in pairs(select(i,...))do target[k]=v end end
  return target
end
function CreateFrame(kind,name,parent,template)
  local frame=nativeCreateFrame(kind,name,parent,template)
  frame.kind=kind
  function frame:IsMouseClickEnabled()return true end
  function frame:IsMouseMotionEnabled()return true end
  function frame:IsObjectType(t)return self.kind:lower()==t:lower()end
  function frame:GetScript(script)return self.scripts[script]end
  function frame:GetScale()return 1 end
  function frame:SetPoint(...)self.anchor={...}end
  function frame:SetPassThroughButtons(...)self.passThrough={...}end
  function frame:SetFrameLevel(level)self.frameLevel=level end
  function frame:AddLine(text)self.messages[#self.messages+1]=text end
  if template=="ChestAtlasPinTemplate" then
    Mixin(frame,MapCanvasPinMixin,ChestAtlasPinMixin)
    frame.Icon=nativeCreateFrame('Texture')
    frame.Glow=nativeCreateFrame('Texture');frame.Sparkle=nativeCreateFrame('Texture')
    frame.Label=nativeCreateFrame('FontString')
    frame.Count=nativeCreateFrame('FontString');frame.Star=nativeCreateFrame('FontString');frame.Own=nativeCreateFrame('FontString')
  elseif template=="ChestAtlasFocusTemplate" then
    Mixin(frame,MapCanvasPinMixin,ChestAtlasFocusMixin)
  end
  return frame
end
function Pool_HideAndClearAnchors(_,pin)pin:Hide();pin:ClearAllPoints()end
function CreateFramePool(kind,parent,template,reset)
  local pool={active={},inactive={}}
  function pool:Acquire()
    local pin=table.remove(self.inactive)
    local isNew=not pin
    pin=pin or CreateFrame(kind,nil,parent,template)
    self.active[#self.active+1]=pin
    return pin,isNew
  end
  function pool:ReleaseAll()
    for _,pin in ipairs(self.active)do reset(self,pin);self.inactive[#self.inactive+1]=pin end
    self.active={}
  end
  function pool:GetNumActive()return #self.active end
  function pool:EnumerateActive()
    local i=0;return function()i=i+1;return self.active[i]end
  end
  return pool
end
WorldMapFrame=CreateFrame('Frame')
Mixin(WorldMapFrame,MapCanvasMixin)
WorldMapFrame.pinPools={};WorldMapFrame.pinTemplateTypes={}
WorldMapFrame.dataProviders={};WorldMapFrame.pinSuppressors={}
WorldMapFrame.mapID=37;WorldMapFrame.globalPinScale=1
WorldMapFrame.ScrollContainer={Child=CreateFrame('Frame'),MarkCanvasDirty=function()end}
WorldMapFrame.pinFrameLevelsManager=CreateFromMixins(MapCanvasPinFrameLevelsManagerMixin)
WorldMapFrame.pinFrameLevelsManager:Initialize()
-- Execute the client's registration order, including layers that can occlude pins.
for name in nativeWorldMapSource:gmatch('pinFrameLevelsManager:AddFrameLevel%("([^"]+)"') do
  WorldMapFrame.pinFrameLevelsManager:AddFrameLevel(name)
end
function WorldMapFrame:ProcessGlobalPinMouseActionHandlers()return false end
function WorldMapFrame:SetMapID(id)self.mapID=id end
function secureexecuterange(t,fn,...)
  for k,v in pairs(t) do fn(k,v,...) end
end
function tContains(t,value)for _,v in ipairs(t)do if v==value then return true end end;return false end
function tDeleteItem(t,value)for i,v in ipairs(t)do if v==value then table.remove(t,i);return end end end
nop=function()end
function C_Map.GetMapInfo(id)
  return {mapID=id,name=id==37 and 'Elwynn Forest' or id==57 and 'Teldrassil' or 'Unknown',parentMapID=0}
end
