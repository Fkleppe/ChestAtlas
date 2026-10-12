local _, A = ...
local methods={}
function methods:SetScript(name,fn)self.scripts[name]=fn end
function methods:HookScript(name,fn)
  local previous=self.scripts[name]
  self.scripts[name]=function(...)if previous then previous(...)end;fn(...)end
end
function methods:RegisterEvent(name)self.events[name]=true end
function methods:Show()self.visible=true;if self.scripts.OnShow then self.scripts.OnShow(self)end end
function methods:Hide()self.visible=false end
function methods:IsShown()return self.visible end
function methods:SetPoint(...)self.anchor={...}end
function methods:ClearAllPoints()self.anchor=nil end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:SetWordWrap(v)self.wordWrap=v end
function methods:SetScale(v)self.scale=v end
function methods:GetFontString()
  if not self.fontString then self.fontString=self:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");self.fontString:SetText(self.text or "")end
  return self.fontString
end
function methods:SetFontString(f)self.fontString=f end
function methods:GetHighlightTexture()
  if not self.highlightTexture then self.highlightTexture=self:CreateTexture(nil,"HIGHLIGHT")end
  return self.highlightTexture
end
function methods:GetWidth()return self.width or 1920 end
function methods:GetHeight()return self.height or 1080 end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetText(text)self.text=text;if self.fontString then self.fontString:SetText(text)end;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self)end end
function methods:GetText()return self.text or "" end
function methods:SetEnabled(flag)self.enabled=flag end
function methods:CreateFontString(name,layer,font)local f=CreateFrame("FontString",name,self);f.font=font;return f end
function methods:CreateTexture(name,layer)return CreateFrame("Texture",name,self)end
function methods:SetChecked(v)self.checked=v end
function methods:GetChecked()return self.checked end
function methods:SetShown(v)if v then self:Show() else self:Hide() end end
function methods:SetTexture(value)self.texture=value;return true end
function methods:SetAtlas(value)self.atlas=value end
function methods:SetAlpha(value)self.alpha=value end
function methods:SetTextColor(...)self.textColor={...}end
function methods:SetBackdropColor(...)self.backgroundColor={...}end
function methods:SetVertexColor(...)self.vertexColor={...}end
function methods:SetTexCoord(...)self.texCoords={...}end
function methods:SetRotation(v)self.rotation=v end
function methods:GetFrameLevel()return self.frameLevel or 0 end
function methods:AddMessage(text)self.messages[#self.messages+1]=text end
function methods:AddLine(text)self.messages[#self.messages+1]=text end
function methods:Clear()self.messages={}end
setmetatable(methods,{__index=function(_,name) if name:match('^Set') or name:match('^Enable') or name:match('^Disable') or name:match('^Register') or name:match('^Scroll') or name:match('^Clear') or name:match('^Start') or name:match('^Stop') or name:match('^Highlight') then return function()end end end})
MockFrames={}
function CreateFrame(kind,name,parent,template)
  local f=setmetatable({scripts={},events={},messages={},visible=true,kind=kind,parent=parent,name=name,template=template},{__index=methods})
  MockFrames[#MockFrames+1]=f
  if name then _G[name]=f end
  return f
end
UIParent=CreateFrame("Frame");UISpecialFrames={};SlashCmdList={}
GameFontHighlightSmall={};ChatFontNormal={};DEFAULT_CHAT_FRAME=CreateFrame("Frame");GameTooltip=CreateFrame("Frame")
function GetBuildInfo()return "1.60.1","70170","Oct 2",16001 end
function GetCurrentRegion()return 3 end
function GetRealmName()return "MockRealm"end
function GetServerTime()return 2000 end
function GetTime()return 100 end
function InCombatLockdown()return false end
function issecretvalue()return false end
function CreateFromMixins(...)
  local result={};for i=1,select('#',...)do for k,v in pairs(select(i,...))do result[k]=v end end;return result
end
MapCanvasDataProviderMixin={}
function MapCanvasDataProviderMixin:GetMap()return self.owningMap end
C_Map={}
function C_Map.GetBestMapForUnit()return 37 end
function C_Map.GetPlayerMapPosition()return {GetXY=function()return 0.524,0.519 end}end
function C_Map.GetMapInfo(id)if id==37 then return {mapID=37,name="Elwynn Forest",parentMapID=0}else return {name="Unknown",parentMapID=0}end end
function C_Map.GetMapChildrenInfo()return {}end
function C_Map.GetAreaInfo()return nil end
function C_Map.SetUserWaypoint(point)MockWaypoint=point end
UiMapPoint={CreateFromCoordinates=function(map,x,y)return {map=map,x=x,y=y}end}
WorldMapFrame=CreateFrame("Frame")
function WorldMapFrame:GetMapID()return self.mapID or 37 end
function WorldMapFrame:SetMapID(id)self.mapID=id end
function WorldMapFrame:RemoveAllPinsByTemplate()self.pins={}end
function WorldMapFrame:AcquirePin(template,node,area)self.pins[#self.pins+1]={node=node,area=area}end
function WorldMapFrame:AddDataProvider(provider)provider.owningMap=self end
MockLootGUID="GameObject-0-1-1-1-2843-000000001"
function GetNumLootItems()return 1 end
function GetLootSlotLink()return "|Hitem:117|h[Tough Jerky]|h"end
function GetLootSlotInfo()return "texture","Tough Jerky",2 end
function GetLootSourceInfo()return MockLootGUID,2 end
