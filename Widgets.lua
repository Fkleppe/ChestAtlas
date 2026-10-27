local _,A=...
local W={};A.Widgets=W
W.gold={0.90,0.73,0.39}
W.muted={0.68,0.70,0.73}
W.dim={0.50,0.52,0.55}
W.rowHeight=20
-- Native Blizzard templates when the client has them; plain flat frames otherwise.
local templates,atlases={}, {}
function W.HasTemplate(name)
  if templates[name]==nil then
    local get=C_XMLUtil and C_XMLUtil.GetTemplateInfo
    templates[name]=(get and A.Safe(get,name)~=nil) and true or false
  end
  return templates[name]
end
function W.HasAtlas(name)
  if atlases[name]==nil then
    local get=C_Texture and C_Texture.GetAtlasInfo
    atlases[name]=(get and A.Safe(get,name)~=nil) and true or false
  end
  return atlases[name]
end
local flat={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1,insets={left=1,right=1,top=1,bottom=1}}
-- light: a subtle card on a panel; otherwise a dark floating surface (toolbar, arrow).
function W.Surface(p,light)
  if not p.SetBackdrop then return end
  p:SetBackdrop(flat)
  if light then p:SetBackdropColor(1,1,1,0.035);p:SetBackdropBorderColor(1,1,1,0.10)
  else p:SetBackdropColor(0.055,0.055,0.065,0.94);p:SetBackdropBorderColor(0.32,0.32,0.34,1) end
end
function W.Rule(parent,x,y,width)
  local t=parent:CreateTexture(nil,"ARTWORK");t:SetColorTexture(1,1,1,0.12)
  t:SetPoint("TOPLEFT",x,-y);t:SetSize(width,1);return t
end
function W.Text(parent,text,x,y,width,font)
  local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
  f:SetPoint("TOPLEFT",x,-y);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetText(text);return f
end
function W.Line(parent,text,x,y,width,font)
  local f=W.Text(parent,text,x,y,width,font)
  f:SetWordWrap(false);f:SetHeight(font=="GameFontNormalLarge" and 24 or 16);return f
end
-- Section header: gold caption with a hairline underneath (Settings panel style).
function W.Header(parent,text,x,y,width)
  local f=W.Line(parent,text,x,y,width,"GameFontNormal")
  f.rule=W.Rule(parent,x,y+19,width);return f
end
local function truncatedTip(self)
  local fs=self.GetFontString and self:GetFontString()
  if fs and fs.IsTruncated and fs:IsTruncated() then
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self:GetText(),1,0.82,0,true);GameTooltip:Show()
  end
end
local function hideTip()GameTooltip:Hide()end
-- Flat fallback button, also used for segmented tabs when native tab art is missing.
function W.FlatButton(parent,text,x,y,width,fn,height)
  local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
  b:SetPoint("TOPLEFT",x,-y);b:SetSize(width,height or 22);W.Surface(b,true)
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD")
  b:GetHighlightTexture():SetVertexColor(1,1,1,0.08)
  local caption=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");caption:SetPoint("CENTER");caption:SetTextColor(unpack(W.gold))
  b:SetFontString(caption);b:SetText(text);b:SetScript("OnClick",fn)
  local f=b:GetFontString()
  if f then f:SetWidth(width-16);f:SetHeight(16);f:SetWordWrap(false) end
  local enable=b.SetEnabled
  b.SetEnabled=function(self,enabled)
    enable(self,enabled)
    if enabled then caption:SetTextColor(unpack(W.gold));self:SetAlpha(1)
    else caption:SetTextColor(0.45,0.47,0.50);self:SetAlpha(0.65)end
  end
  b:SetScript("OnEnter",truncatedTip);b:SetScript("OnLeave",hideTip)
  return b
end
-- Standard red Blizzard push button (UIPanelButtonTemplate).
function W.Button(parent,text,x,y,width,fn,height)
  if not W.HasTemplate("UIPanelButtonTemplate") then return W.FlatButton(parent,text,x,y,width,fn,height) end
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT",x,-y);b:SetSize(width,height or 22)
  if GameFontNormalSmall then b:SetNormalFontObject(GameFontNormalSmall) end
  if GameFontHighlightSmall then b:SetHighlightFontObject(GameFontHighlightSmall) end
  if GameFontDisableSmall then b:SetDisabledFontObject(GameFontDisableSmall) end
  b:SetText(text);b:SetScript("OnClick",fn)
  local f=b:GetFontString()
  if f then f:SetWidth(width-16);f:SetHeight(16);f:SetWordWrap(false) end
  b:HookScript("OnEnter",truncatedTip);b:HookScript("OnLeave",hideTip)
  return b
end
-- Dropdown-style selector (silver filter button with an arrow); opens A.OpenPicker.
function W.Select(parent,text,x,y,width,fn)
  if not W.HasTemplate("UIMenuButtonStretchTemplate") then return W.Button(parent,text,x,y,width,fn) end
  local b=CreateFrame("Button",nil,parent,"UIMenuButtonStretchTemplate")
  b:SetPoint("TOPLEFT",x,-y);b:SetSize(width,22)
  b.Icon=b:CreateTexture(nil,"ARTWORK");b.Icon:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  b.Icon:SetSize(10,12);b.Icon:SetPoint("RIGHT",-6,0)
  b:SetText(text);b:SetScript("OnClick",fn)
  local f=b:GetFontString()
  if f then
    f:ClearAllPoints();f:SetPoint("LEFT",8,0);f:SetWidth(width-28);f:SetHeight(16)
    f:SetJustifyH("LEFT");f:SetWordWrap(false)
  end
  b:HookScript("OnEnter",truncatedTip);b:HookScript("OnLeave",hideTip)
  return b
end
-- Spellbook-style page arrows.
function W.ArrowButton(parent,dir,x,y,fn)
  local b=CreateFrame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(26,26)
  local base=dir=="prev" and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
  b:SetNormalTexture(base.."Up");b:SetPushedTexture(base.."Down");b:SetDisabledTexture(base.."Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
  b:SetScript("OnClick",fn);return b
end
function W.Edit(parent,x,y,width,text)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetPoint("TOPLEFT",x,-y);e:SetSize(width,24);e:SetAutoFocus(false);e:SetText(text or "")
  e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
  e:SetScript("OnEnterPressed",function(self)self:ClearFocus()end);return e
end
-- Search field: SearchBoxTemplate (magnifier, grey hint, clear button) or a hinted input box.
function W.Search(parent,x,y,width,hint)
  local native=W.HasTemplate("SearchBoxTemplate")
  local e=CreateFrame("EditBox",nil,parent,native and "SearchBoxTemplate" or "InputBoxTemplate")
  e:SetPoint("TOPLEFT",x+6,-y);e:SetSize(width-6,22);e:SetAutoFocus(false);e:SetMaxLetters(80)
  if native and e.Instructions then e.Instructions:SetText(hint)
  else
    e.hint=W.Line(e,hint,4,3,width-20);e.hint:SetTextColor(unpack(W.dim))
    e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    e:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    e:HookScript("OnTextChanged",function(self)self.hint:SetShown(self:GetText()=="")end)
  end
  return e
end
-- Text-change handler that keeps the template's own OnTextChanged behaviour.
function W.OnText(edit,fn)edit:HookScript("OnTextChanged",fn)end
-- Checkbox with a clickable label; tip is an optional tooltip line.
function W.Check(parent,text,x,y,width,fn,tip)
  local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
  b:SetPoint("TOPLEFT",x,-y);b:SetSize(24,24)
  b.caption=W.Line(b,text,26,4,width)
  if b.SetHitRectInsets then b:SetHitRectInsets(0,-width,0,0) end
  b:SetScript("OnClick",function(self)fn(self:GetChecked()==true)end)
  local enable=b.SetEnabled
  b.SetEnabled=function(self,enabled)
    enable(self,enabled)
    if enabled then self.caption:SetTextColor(1,1,1) else self.caption:SetTextColor(unpack(W.dim)) end
  end
  if tip then
    b:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self.caption:GetText(),1,0.82,0)
      GameTooltip:AddLine(tip,1,1,1,true);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",hideTip)
  end
  return b
end
-- Recessed content area (InsetFrameTemplate marble), drawn below its parent's other children.
function W.Inset(parent,x,y,width,height)
  local native=W.HasTemplate("InsetFrameTemplate")
  local f=CreateFrame("Frame",nil,parent,native and "InsetFrameTemplate" or "BackdropTemplate")
  f:SetPoint("TOPLEFT",x,-y);f:SetSize(width,height)
  if not native then W.Surface(f,true);f:SetFrameLevel(parent:GetFrameLevel()) end
  return f
end
function W.SetTitle(p,text)
  if p.SetTitle and p.TitleContainer then p:SetTitle(text)
  elseif p.fallbackTitle then p.fallbackTitle:SetText(text) end
end
-- Movable window: ButtonFrameTemplate (title bar, close button, Blizzard border) without
-- portrait; content is placed by the caller below the 24px title bar.
function W.Panel(name,parent,width,height,title)
  local native=W.HasTemplate("ButtonFrameTemplate")
  local p=CreateFrame("Frame",name,parent,native and "ButtonFrameTemplate" or "BackdropTemplate")
  p:SetSize(width,height);p:SetFrameStrata("DIALOG");p:SetClampedToScreen(true);p:EnableMouse(true)
  if p.SetToplevel then p:SetToplevel(true) end
  if native and p.TitleContainer then
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait,p) end
    if p.Inset then p.Inset:Hide() end
  else
    W.Surface(p)
    p.fallbackTitle=W.Line(p,"",14,5,width-56,"GameFontNormal");p.fallbackTitle:SetJustifyH("CENTER")
    W.Rule(p,1,24,width-2)
    local close=CreateFrame("Button",nil,p,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-1,-1);p.CloseButton=close
  end
  p:SetMovable(true);p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart",function(self)self:StartMoving()end)
  p:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
  if name and UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end
  W.SetTitle(p,title or "Chest Atlas")
  return p
end
-- Scrolling text block (long source notes); s:SetText keeps the scroll position.
function W.ScrollText(parent,x,y,width,height)
  local native=W.HasTemplate("UIPanelScrollFrameTemplate")
  local s=CreateFrame("ScrollFrame",nil,parent,native and "UIPanelScrollFrameTemplate" or nil)
  s:SetPoint("TOPLEFT",x,-y);s:SetSize(width-24,height);s:EnableMouseWheel(true)
  if native then s.scrollBarHideable=true
  else
    s:SetScript("OnMouseWheel",function(self,delta)
      local range=self:GetVerticalScrollRange() or 0
      self:SetVerticalScroll(math.max(0,math.min(range,(self:GetVerticalScroll() or 0)-delta*40)))
    end)
  end
  local child=CreateFrame("Frame",nil,s);child:SetSize(width-24,height);s:SetScrollChild(child)
  s.text=W.Text(child,"",0,0,width-30);s.text:SetJustifyV("TOP")
  function s:SetText(text)
    self.text:SetText(text or "")
    local h=self.text.GetStringHeight and self.text:GetStringHeight()
    child:SetHeight(math.max(height,(type(h)=="number" and h or 0)+6))
  end
  return s
end
local picker
local PICK_ROWS,PICK_ROW=12,20
function A.OpenPicker(anchor,title,entries,current,callback)
  if not picker then
    picker=CreateFrame("Frame","ChestAtlasPicker",UIParent,"BackdropTemplate")
    picker:SetSize(340,98+PICK_ROWS*PICK_ROW);picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetClampedToScreen(true);picker:EnableMouse(true);picker:EnableMouseWheel(true)
    if picker.SetToplevel then picker:SetToplevel(true) end
    -- Tooltip-style border, like Blizzard's dropdown lists.
    picker:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    picker:SetBackdropColor(0.035,0.035,0.045,0.97);picker:SetBackdropBorderColor(0.62,0.62,0.66,1)
    picker.title=W.Line(picker,"",12,10,290,"GameFontNormal")
    local close=CreateFrame("Button",nil,picker,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3);close:SetSize(22,22)
    picker.search=W.Search(picker,10,32,320,"Filter this list")
    picker.rows={}
    for i=1,PICK_ROWS do
      local b=CreateFrame("Button",nil,picker)
      b:SetPoint("TOPLEFT",8,-(62+(i-1)*PICK_ROW));b:SetSize(324,PICK_ROW)
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
      b.check=b:CreateTexture(nil,"ARTWORK");b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      b.check:SetSize(16,16);b.check:SetPoint("LEFT",2,0)
      b.text=W.Line(b,"",22,2,296)
      b:SetScript("OnClick",function(self)
        if self.entry then local entry=self.entry;picker:Hide();picker.callback(entry.value) end
      end)
      b:SetScript("OnEnter",function(self)
        if self.entry and self.text:IsTruncated() then
          GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self.entry.text,1,1,1,true);GameTooltip:Show()
        end
      end)
      b:SetScript("OnLeave",hideTip)
      picker.rows[i]=b
    end
    local pagerY=68+PICK_ROWS*PICK_ROW
    picker.prev=W.ArrowButton(picker,"prev",10,pagerY,function()picker.page=math.max(1,picker.page-1);picker:Refresh()end)
    picker.pageText=W.Line(picker,"",50,pagerY+5,240);picker.pageText:SetJustifyH("CENTER");picker.pageText:SetTextColor(unpack(W.muted))
    picker.next=W.ArrowButton(picker,"next",304,pagerY,function()picker.page=picker.page+1;picker:Refresh()end)
    picker:SetScript("OnMouseWheel",function(self,delta)
      self.page=math.max(1,self.page-(delta>0 and 1 or -1));self:Refresh()
    end)
    function picker:Refresh()
      local q=self.search:GetText():lower();local matches={}
      for _,e in ipairs(self.entries or {}) do if e.text:lower():find(q,1,true) then matches[#matches+1]=e end end
      local pages=math.max(1,math.ceil(#matches/PICK_ROWS));self.page=math.min(self.page,pages)
      self.pageText:SetText(#matches==0 and "No matches" or (self.page.." / "..pages.."  •  "..#matches.." options"))
      self.prev:SetEnabled(self.page>1);self.next:SetEnabled(self.page<pages)
      for i,b in ipairs(self.rows) do
        local e=matches[(self.page-1)*PICK_ROWS+i];b.entry=e
        if e then
          local active=e.value==self.current
          b.text:SetText(e.text);b.check:SetShown(active)
          if active then b.text:SetTextColor(1,0.82,0) else b.text:SetTextColor(1,1,1) end
          b:Show()
        else b:Hide() end
      end
    end
    W.OnText(picker.search,function()picker.page=1;picker:Refresh()end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ChestAtlasPicker" end
  end
  picker.entries,picker.current,picker.callback,picker.page=entries,current,callback,1
  picker.title:SetText(title);picker:ClearAllPoints();picker:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-3)
  picker.search:SetText("");picker:Show();picker:Refresh();picker.search:SetFocus()
end
local boards,requested,queue,queued,failed={},{},{},{},{}
local queueHead,revision,refreshDelay=1,0,0
local valueCache={}
local watched={}
local qualityNames={[0]="Poor",[1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic"}
local qualityFallback={[0]={0.62,0.62,0.62},[1]={1,1,1},[2]={0.12,1,0},[3]={0,0.44,0.87},[4]={0.64,0.21,0.93},[5]={1,0.5,0}}
function A.Money(copper)
  return string.format("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end
function A.ShortMoney(copper)
  if copper>=10000 then return string.format("%dg %ds",math.floor(copper/10000),math.floor(copper/100)%100) end
  if copper>=100 then return string.format("%ds %dc",math.floor(copper/100),copper%100) end
  return string.format("%dc",copper)
end
-- Same amounts as A.ShortMoney with Blizzard's coin colours on the unit letters.
local GOLD,SILVER,COPPER="|cffffd100g|r","|cffc7c7cfs|r","|cffeda55fc|r"
function W.Coins(copper)
  if type(copper)~="number" then return nil end
  local g,s,c=math.floor(copper/10000),math.floor(copper/100)%100,math.floor(copper%100)
  if g>0 then return g..GOLD..(s>0 and (" "..s..SILVER) or "") end
  if s>0 then return s..SILVER..(c>0 and (" "..c..COPPER) or "") end
  return c..COPPER
end
-- Top tabs (PanelTopTabButtonTemplate) over an inset; pages sit inside the inset.
local TAB_TOP=30
function W.Tabs(parent,x,y,width,height)
  local t=CreateFrame("Frame",nil,parent);t:SetPoint("TOPLEFT",x,-y);t:SetSize(width,height)
  t.buttons={};t.pages={};t.index={}
  t.pageWidth,t.pageHeight=width-16,height-TAB_TOP-16
  local native=W.HasTemplate("PanelTopTabButtonTemplate") and PanelTemplates_SetNumTabs and PanelTemplates_SetTab and PanelTemplates_TabResize
  t.inset=W.Inset(t,0,TAB_TOP-2,width,height-TAB_TOP+2)
  local entries={{"loot","Loot"},{"journal","Journal"},{"sources","Sources"}}
  for i,entry in ipairs(entries)do
    local key=entry[1]
    local b
    if native then
      b=CreateFrame("Button",nil,t,"PanelTopTabButtonTemplate")
      b:SetID(i);b:SetText(entry[2])
      if i==1 then b:SetPoint("BOTTOMLEFT",t,"TOPLEFT",6,-TAB_TOP) end
      t.Tabs=t.Tabs or {}
      local known=false;for _,tab in ipairs(t.Tabs) do known=known or tab==b end
      if not known then t.Tabs[#t.Tabs+1]=b end
      b:SetScript("OnClick",function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        t:SetTab(key)
      end)
    else
      b=W.FlatButton(t,entry[2],(i-1)*84,2,80,function()t:SetTab(key)end,24)
    end
    t.buttons[key]=b;t.index[key]=i
    local p=CreateFrame("Frame",nil,t);p:SetPoint("TOPLEFT",8,-(TAB_TOP+8));p:SetSize(t.pageWidth,t.pageHeight)
    t.pages[key]=p;t[key]=p
  end
  if native then
    pcall(PanelTemplates_SetNumTabs,t,#entries)
    for _,entry in ipairs(entries) do pcall(PanelTemplates_TabResize,t.buttons[entry[1]],0) end
  end
  function t:SetTab(key)
    if not self.pages[key]then return end
    self.active=key
    for name,p in pairs(self.pages)do p:SetShown(name==key) end
    if native then pcall(PanelTemplates_SetTab,self,self.index[key])
    else
      for name,b in pairs(self.buttons)do
        b:SetBackdropBorderColor(unpack(name==key and W.gold or {1,1,1,0.10}))
        local f=b:GetFontString();if f then if name==key then f:SetTextColor(1,1,1) else f:SetTextColor(unpack(W.gold)) end end
      end
    end
  end
  t:SetTab("loot");return t
end
function W.SourceText(n,area)
  if not n then return "Select a location to inspect its sources." end
  local own=A.Observation(n)
  return A.LocationSource(n).."\n"..(n.rare and ("NPC #"..n.npcID) or A.IsGenericType(n.typeID) and "Exact object variant unknown" or ("Object #"..n.typeID))..
    "\n\n"..W.DetailText(n,area).."\n\n"..(n.rare and "" or A.LootSourceLabel(n).."\n"..A.CashText(n,true).."\n\n")..
    (A.IsGenericType(n.typeID) and (A.GenericLootDetails(n).."\n\n") or "")..
    (not n.rare and not A.IsGenericType(n.typeID) and #A.ReferenceLoot(n)==0 and "No historical item-drop list is documented for this object. Scripted or quest rewards may work separately.\n\n" or "")..
    (own and "Personal observation: "..A.LocationStatusText(n).."\n\n" or "")..
    "Classic loot and probabilities are historical references at 1x rates. Forever drops, spawn timing and live availability are unconfirmed.\n\nVendor value is for one item; it is not AH value or expected profit. Routes connect possible locations in a visit order, without terrain or enemy checks."
end
function A.CashText(n,verbose)
  local cash=A.CashRange(n)
  if not cash then return n and A.IsGenericType(n.typeID) and "Coins unknown • variant unknown" or "Coins: unknown" end
  local amount=A.ShortMoney(cash.minCopper)
  if cash.maxCopper~=cash.minCopper then amount=amount.."–"..A.ShortMoney(cash.maxCopper) end
  return "Classic coins: "..amount..(verbose and " • 1x reference; Forever unknown" or "")
end
function A.ChanceText(n,itemID,source)
  local chance,why=A.DropChance(n,itemID,source)
  if n and A.IsGenericType(n.typeID) then return "Variant unknown",why end
  if chance==nil then return "Chance unknown",why end
  local value=chance==0 and "0%" or chance<0.0001 and "<0.0001%" or chance<0.01 and string.format("%.4f%%",chance) or string.format("%.2f%%",chance)
  return "Classic est. "..value,"Static 1x Classic estimate; Forever rates and eligibility are unverified."
end
-- Compact chance for the loot table column; the tooltip keeps the full A.ChanceText.
local function chanceCell(n,itemID,source)
  if n and A.IsGenericType(n.typeID) then return nil end
  local chance=A.DropChance(n,itemID,source)
  if chance==nil then return nil end
  if chance==0 then return "0%" end
  if chance<0.01 then return "<0.01%" end
  return string.format(chance<10 and "%.2f%%" or "%.1f%%",chance)
end
function A.LootOrder(a,b,sort)
  local field=(sort=="chanceDesc" or sort=="chanceAsc") and "chance" or "price"
  local x,y=a[field],b[field]
  if (x~=nil)~=(y~=nil) then return x~=nil end
  if x~=y then
    if x==nil then return A.ValueOrder(a,b)end
    if sort=="valueAsc" or sort=="chanceAsc" then return x<y end
    return x>y
  end
  return A.ValueOrder(a,b)
end
local function requestItem(item)
  watched[item.id]=true
  if item.price~=nil or requested[item.id] or queued[item.id] or failed[item.id] then return end
  if C_Item and C_Item.RequestLoadItemDataByID then
    queued[item.id]=true;queue[#queue+1]=item.id
  else failed[item.id]=true end
end
function A.BestLoot(n,source)
  if not n then return {total=0,known=0} end
  local ids=A.ReferenceLoot(n,source);local personal=#ids==0 and n.own
  if personal then ids={};for id in pairs(n.contents or {}) do ids[#ids+1]=id end end
  local key=A.LootContextKey(n)..":"..(source=="pf" and "pf" or "legacy")..":"..A.LootSource(n,source)
  local cached=valueCache[key]
  if not personal and cached and cached.revision==revision then return cached end
  local result={total=0,known=0,revision=revision}
  for _,id in ipairs(ids) do
    local item=A.ItemDetails(id);result.total=result.total+1;requestItem(item)
    if item.price~=nil then
      result.known=result.known+1
      if not result.item or A.ValueOrder(item,result.item) then result.item=item end
    end
  end
  if not personal then valueCache[key]=result end;return result
end
local function qualityColor(q)
  if q==nil then return 0.75,0.8,0.85 end
  if C_Item and C_Item.GetItemQualityColor then
    local r,g,b=A.Safe(C_Item.GetItemQualityColor,q)
    if type(r)=="number" and type(g)=="number" and type(b)=="number" then return r,g,b end
  end
  local c=qualityFallback[q] or qualityFallback[1];return c[1],c[2],c[3]
end
function W.ItemColor(text,item)
  text:SetTextColor(qualityColor(item and item.quality))
end
function W.ItemTooltip(row)
  if not row.item then return end
  GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..row.item.id)
  if row.item.price~=nil then GameTooltip:AddLine("Vendor value per item: "..A.Money(row.item.price),0.9,0.75,0.45,true) end
  if row.node then
    if not row.node.rare then GameTooltip:AddLine(A.CashText(row.node,true),1,0.82,0.4,true)end
    if row.lootMode~="own" then
      local text,why=A.ChanceText(row.node,row.item.id,row.lootMode)
      GameTooltip:AddLine(text,0.75,0.85,1,true)
      if why then GameTooltip:AddLine(why,0.7,0.75,0.8,true)end
      GameTooltip:AddLine(A.LootSourceLabel(row.node,row.lootMode),0.7,0.75,0.8,true)
    end
  end
  if row.valueSummary then
    GameTooltip:AddLine("Highest known vendor value in the possible loot table.",0.8,0.85,0.9,true)
    GameTooltip:AddLine(row.valueSummary.known.." / "..row.valueSummary.total.." item prices available. AH value is unknown.",0.65,0.7,0.75,true)
    GameTooltip:AddLine("Historical loot association; this drop is not guaranteed.",0.65,0.7,0.75,true)
  end
  if IsShiftKeyDown and ChatEdit_InsertLink then GameTooltip:AddLine("Shift-click to link in chat.",0.5,0.52,0.55,true) end
  GameTooltip:Show()
end
local function iconCrop(t)t:SetTexCoord(0.07,0.93,0.07,0.93)end
-- Highlighted "most valuable item" card at the top of the loot tab.
W.bestCardHeight=66
function W.BestCard(parent,x,y,width)
  local c=CreateFrame("Button",nil,parent,"BackdropTemplate");c:SetPoint("TOPLEFT",x,-y);c:SetSize(width,W.bestCardHeight);W.Surface(c,true)
  c:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD");c:GetHighlightTexture():SetVertexColor(1,1,1,0.04)
  c.iconBorder=c:CreateTexture(nil,"BORDER");c.iconBorder:SetColorTexture(0,0,0,0.8);c.iconBorder:SetSize(40,40);c.iconBorder:SetPoint("TOPLEFT",9,-13)
  c.icon=c:CreateTexture(nil,"ARTWORK");c.icon:SetSize(38,38);c.icon:SetPoint("TOPLEFT",10,-14);iconCrop(c.icon)
  c.tag=W.Line(c,"",58,5,width-66);c.tag:SetHeight(14);c.tag:SetTextColor(unpack(W.dim))
  c.name=W.Line(c,"",58,19,width-66,"GameFontNormal")
  c.meta=W.Line(c,"",58,35,width-66);c.meta:SetHeight(14);c.meta:SetTextColor(unpack(W.muted))
  c.cash=W.Line(c,"",58,49,width-66);c.cash:SetHeight(14);c.cash:SetTextColor(unpack(W.gold))
  c:SetScript("OnEnter",W.ItemTooltip);c:SetScript("OnLeave",hideTip)
  c:SetScript("OnClick",function(self)
    if self.item and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.item.link) end
  end)
  function c:SetNode(n,source)
    local best=A.BestLoot(n,source);self.item,self.valueSummary,self.node,self.lootMode=best.item,best,n,source
    self.icon:SetTexture(best.item and best.item.icon or 134400)
    W.ItemColor(self.name,best.item)
    local unknownVariant=n and A.IsGenericType(n.typeID) and best.total==0
    self.tag:SetText(n and A.IsGenericType(n.typeID) and "Top vendor value • possible variant" or "Top vendor value • possible drop")
    self.name:SetText(best.item and best.item.name or (not n and "Select a location" or unknownVariant and "Exact chest variant unknown" or best.total==0 and "No known loot for this type" or "Item prices not available yet"))
    self.meta:SetText(best.item and (W.Coins(best.item.price).." each  •  "..A.ChanceText(n,best.item.id,source)) or unknownVariant and "Loot table unavailable • record a find to confirm" or (best.total>0 and ("0/"..best.total.." prices available • AH unknown") or "Possible loot • AH value unknown"))
    self.cash:SetText(n and not n.rare and A.CashText(n) or "")
  end
  c:SetNode(nil);return c
end
local sortLabels={valueDesc="vendor value, high to low",valueAsc="vendor value, low to high",chanceDesc="drop chance, high to low",chanceAsc="drop chance, low to high"}
-- Loot table: best-item card, filters, sortable column headers and a scrolling item list.
-- listRows is the number of visible rows; b.layout.height is the full board height.
function W.Loot(parent,x,y,width,listRows)
  local rowH=W.rowHeight
  local card=W.bestCardHeight
  local selectY,searchY,headY=card+8,card+38,card+68
  local listTop=headY+21
  local height=listTop+listRows*rowH+40
  local b=CreateFrame("Frame",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(width,height)
  b.layout={rowTop=listTop,rowHeight=rowH,rowCount=listRows,height=height}
  b.mode,b.quality="legacy",nil;b.rows={}
  if not sortLabels[A.settings and A.settings.lootSort] then A.settings.lootSort="valueDesc" end
  b.best=W.BestCard(b,0,0,width)
  local sourceWidth=math.floor((width-8)*0.58)
  b.source=W.Select(b,"Possible loot",0,selectY,sourceWidth,function(self)
    A.OpenPicker(self,"Loot source",{{value="legacy",text="Classic full table (Vanilla fallback if absent)"},{value="pf",text="Vanilla pfQuest list (incomplete groups)"},{value="own",text="Your recorded loot"}},b.mode,function(mode)b.mode=mode;b:Refresh()end)
  end)
  b.filter=W.Select(b,"All qualities",sourceWidth+8,selectY,width-sourceWidth-8,function(self)
    local entries={{value=-1,text="All qualities"}}
    for q=0,4 do entries[#entries+1]={value=q,text=qualityNames[q]} end
    A.OpenPicker(self,"Item quality",entries,b.quality or -1,function(q)b.quality=q>=0 and q or nil;b:Refresh()end)
  end)
  b.search=W.Search(b,0,searchY,width-112,"Search items or item ID")
  W.OnText(b.search,function()b:Refresh()end)
  b.frequent=W.Check(b,"1%+ only",width-104,searchY-1,76,function(v)b.frequentOnly=v;b:Refresh()end,
    "Frequent drops: Classic estimate of at least 1%. Unknown probabilities are excluded. This is not a measured Forever drop rate.")
  -- Columns: item name fills, chance and vendor value are right-aligned numbers.
  local listWidth=width-22
  local colChance,colValue=70,78
  local nameWidth=listWidth-colChance-colValue
  b.listWidth=listWidth
  local headerTemplate=W.HasTemplate("ColumnDisplayButtonShortTemplate") and "ColumnDisplayButtonShortTemplate" or nil
  local arrowAtlas=W.HasAtlas("auctionhouse-ui-sortarrow")
  local function header(label,hx,hw,right,sortKey)
    local h=CreateFrame("Button",nil,b,headerTemplate);h:SetPoint("TOPLEFT",hx,-headY);h:SetSize(hw,19)
    local fs=h:GetFontString()
    if not fs then fs=h:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");h:SetFontString(fs) end
    h:SetText(label)
    fs:ClearAllPoints()
    if right then fs:SetPoint("RIGHT",-8,0);fs:SetJustifyH("RIGHT") else fs:SetPoint("LEFT",8,0);fs:SetJustifyH("LEFT") end
    if not headerTemplate then
      h.bg=h:CreateTexture(nil,"BACKGROUND");h.bg:SetAllPoints();h.bg:SetColorTexture(1,1,1,0.06)
    end
    h.label=fs
    if arrowAtlas then
      h.arrow=h:CreateTexture(nil,"OVERLAY");h.arrow:SetAtlas("auctionhouse-ui-sortarrow",true)
      if right then h.arrow:SetPoint("RIGHT",fs,"LEFT",-3,0) else h.arrow:SetPoint("LEFT",fs,"RIGHT",3,0) end
      h.arrow:Hide()
    end
    if sortKey then
      h:SetScript("OnClick",function()
        local current=A.settings.lootSort
        A.settings.lootSort=current==sortKey.."Desc" and sortKey.."Asc" or sortKey.."Desc";b:Refresh()
      end)
      h:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Click to sort",1,1,1);GameTooltip:Show()
      end)
      h:SetScript("OnLeave",hideTip)
    else h:EnableMouse(false) end
    h.sortKey=sortKey;return h
  end
  b.headName=header("Item",0,nameWidth+2,false,nil)
  b.headChance=header("Chance",nameWidth,colChance+2,true,"chance")
  b.headValue=header("Vendor",nameWidth+colChance,colValue,true,"value")
  -- Virtual scrolling list: a small pool of rows is re-positioned over the visible part
  -- of a tall scroll child, so long Classic tables (hundreds of items) stay cheap.
  local scrollNative=W.HasTemplate("UIPanelScrollFrameTemplate")
  local s=CreateFrame("ScrollFrame",nil,b,scrollNative and "UIPanelScrollFrameTemplate" or nil)
  s:SetPoint("TOPLEFT",0,-listTop);s:SetSize(listWidth,listRows*rowH);s:EnableMouseWheel(true)
  if scrollNative then
    s.scrollBarHideable=true
    if type(s.ScrollBar)=="table" then s.ScrollBar.scrollStep=rowH*3 end
  else
    s:SetScript("OnMouseWheel",function(self,delta)
      local range=self:GetVerticalScrollRange() or 0
      self:SetVerticalScroll(math.max(0,math.min(range,(self:GetVerticalScroll() or 0)-delta*rowH*3)))
      b:Render()
    end)
  end
  s:HookScript("OnVerticalScroll",function()if b.Render then b:Render() end end)
  local child=CreateFrame("Frame",nil,s);child:SetSize(listWidth,listRows*rowH);s:SetScrollChild(child)
  b.scroll,b.child=s,child
  b.listBg=b:CreateTexture(nil,"BACKGROUND");b.listBg:SetColorTexture(0,0,0,0.25)
  b.listBg:SetPoint("TOPLEFT",0,-listTop);b.listBg:SetSize(listWidth,listRows*rowH)
  b.empty=W.Text(b,"",12,listTop+16,listWidth-24);b.empty:SetJustifyH("CENTER");b.empty:SetTextColor(unpack(W.muted))
  local function createRow(i)
    local row=CreateFrame("Button",nil,child);row:SetSize(listWidth,rowH);row:SetPoint("TOPLEFT",0,-(i-1)*rowH)
    row.stripe=row:CreateTexture(nil,"BACKGROUND");row.stripe:SetAllPoints();row.stripe:SetColorTexture(1,1,1,0.04)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
    row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(16,16);row.icon:SetPoint("LEFT",4,0);iconCrop(row.icon)
    row.name=W.Line(row,"",26,2,nameWidth-30)
    row.chance=W.Line(row,"",nameWidth,2,colChance-8);row.chance:SetJustifyH("RIGHT")
    row.value=W.Line(row,"",nameWidth+colChance,2,colValue-8);row.value:SetJustifyH("RIGHT")
    row:SetScript("OnEnter",W.ItemTooltip)
    row:SetScript("OnLeave",hideTip)
    row:SetScript("OnClick",function(self)
      if self.item and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.item.link) end
    end)
    b.rows[i]=row;return row
  end
  for i=1,listRows+1 do createRow(i) end
  b.list={}
  function b:Render()
    local list=self.list
    local first=math.max(1,math.floor((self.scroll:GetVerticalScroll() or 0)/rowH)+1)
    local n=self.node
    for i,row in ipairs(self.rows) do
      local index=first+i-1
      local item=list[index]
      row.item,row.node,row.lootMode=item,n,self.mode
      if item then
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(index-1)*rowH)
        row.stripe:SetShown(index%2==0)
        row.icon:SetTexture(item.icon or 134400);row.name:SetText(item.name)
        W.ItemColor(row.name,item)
        local price=W.Coins(item.price)
        row.value:SetText(price or "–");if price then row.value:SetTextColor(1,1,1) else row.value:SetTextColor(unpack(W.dim)) end
        local chance
        if self.mode=="own" then local e=n and n.contents and n.contents[item.id];chance=e and e.count and ("x"..e.count)
        else chance=chanceCell(n,item.id,self.mode) end
        row.chance:SetText(chance or "–");if chance then row.chance:SetTextColor(1,1,1) else row.chance:SetTextColor(unpack(W.dim)) end
        row:Show()
        if GameTooltip:IsOwned(row) then W.ItemTooltip(row) end
      else row:Hide() end
    end
  end
  b.summary=W.Line(b,"",2,listTop+listRows*rowH+6,width-4);b.summary:SetTextColor(unpack(W.muted))
  b.disclaimer=W.Line(b,"Classic estimates • Forever loot unconfirmed",2,listTop+listRows*rowH+22,width-4);b.disclaimer:SetTextColor(unpack(W.dim))
  function b:SetNode(n)
    if self.node~=n then self.scrollKey=nil end
    if n and n.rare then self.mode="legacy"end
    self.source:SetEnabled(not (n and n.rare))
    self.node=n;self:Refresh()
  end
  function b:Refresh()
    local n=self.node;local list={};local q=self.search:GetText():lower()
    local generic=n and A.IsGenericType(n.typeID)
    if self.mode=="own" or generic or A.LootSource(n,self.mode)~="cm" then self.frequentOnly=false end
    self.best:SetNode(n,self.mode=="pf" and "pf" or "legacy")
    if n then
      local ids={}
      if self.mode=="own" then for id in pairs(n.contents or {}) do ids[#ids+1]=id end
      else for _,id in ipairs(A.ReferenceLoot(n,self.mode)) do ids[#ids+1]=id end end
      for _,id in ipairs(ids) do
        local item=A.ItemDetails(id)
        if self.mode~="own"then item.chance=A.DropChance(n,id,self.mode)end
        requestItem(item)
        if (not self.frequentOnly or self.mode=="own" or item.chance and item.chance>=1)
          and (q=="" or item.name:lower():find(q,1,true) or tostring(id)==q) and (self.quality==nil or item.quality==nil or item.quality==self.quality) then list[#list+1]=item end
      end
    end
    table.sort(list,function(a,b)return A.LootOrder(a,b,A.settings.lootSort)end)
    self.source:SetText(self.mode=="own" and "Recorded loot" or generic and "Possible family loot" or A.LootSource(n,self.mode)=="cm" and "Classic loot table" or "Vanilla loot list")
    self.filter:SetText(self.quality and qualityNames[self.quality] or "All qualities")
    local canFilter=self.mode~="own" and not generic and A.LootSource(n,self.mode)=="cm"
    self.frequent:SetEnabled(canFilter);self.frequent:SetChecked(self.frequentOnly==true)
    -- Column headers follow the saved sort; the chance column shows counts for your own loot.
    local sort=A.settings.lootSort
    self.headChance:SetText(self.mode=="own" and "Seen" or "Chance")
    for _,h in ipairs({self.headChance,self.headValue}) do
      local active=sort==h.sortKey.."Desc" or sort==h.sortKey.."Asc"
      if active then h.label:SetTextColor(1,0.82,0) else h.label:SetTextColor(1,1,1) end
      if h.arrow then
        h.arrow:SetShown(active)
        if sort==h.sortKey.."Asc" then h.arrow:SetTexCoord(0,1,1,0) else h.arrow:SetTexCoord(0,1,0,1) end
      end
    end
    local missing=n and #A.ReferenceLoot(n,self.mode)==0
    if #list==0 then
      self.empty:SetText(n and (self.mode=="own" and "No recorded loot matches this search." or missing and "No historical item loot documented." or "No items match these filters.") or "Select a chest to view loot.")
      self.summary:SetText(n and A.LootSourceLabel(n,self.mode) or "")
    else
      self.empty:SetText("")
      self.summary:SetText(generic and self.mode~="own" and (#list.." possible items • "..(A.GenericLootPool(n,self.mode).scope=="zone" and "zone variants" or "family variants")) or (#list.." items • sorted by "..sortLabels[sort].." • unknowns last"))
    end
    self.list=list
    child:SetHeight(math.max(1,#list*rowH))
    -- Back to the top only when the chest or filters change, not on item-data refreshes.
    local key=tostring(n)..":"..self.mode..":"..tostring(self.quality)..":"..q..":"..sort..":"..tostring(self.frequentOnly)
    if self.scrollKey~=key then
      self.scrollKey=key
      local bar=self.scroll.ScrollBar
      if type(bar)=="table" and bar.SetValue then bar:SetValue(0) else self.scroll:SetVerticalScroll(0) end
    end
    self:Render()
  end
  boards[#boards+1]=b;b:Refresh();return b
end
function A.RefreshItemWidgets(id,success)
  if type(id)~="number" or not watched[id] then return end
  requested[id]=nil;queued[id]=nil;failed[id]=success==false or nil
  revision=revision+1;if refreshDelay<=0 then refreshDelay=0.15 end
end
-- Batch asynchronous item requests and redraws; never refresh map pins for price events.
local loader=CreateFrame("Frame");A.valueLoader=loader
local tick=0
loader:SetScript("OnUpdate",function(_,dt)
  tick=tick+dt
  if tick>=0.2 then
    tick=0;local count=0
    while queueHead<=#queue and count<6 do
      local id=queue[queueHead];queueHead=queueHead+1
      if queued[id] then
        queued[id]=nil
        if not requested[id] and not failed[id] then
          count=count+1;requested[id]=true
          local getter=C_Item and C_Item.RequestLoadItemDataByID
          local ok=getter and pcall(getter,id)
          if not ok then requested[id]=nil;failed[id]=true end
        end
      end
    end
    if queueHead>#queue then queue={};queueHead=1 end
  end
  if refreshDelay>0 then
    refreshDelay=refreshDelay-dt
    if refreshDelay<=0 then
      for _,b in ipairs(boards) do if b:IsShown() then b:Refresh() end end
      if A.RefreshUI then A.RefreshUI()end
      if A.UpdateNavigation then A.UpdateNavigation(true)end
    end
  end
end)
function W.DetailText(n,area)
  if not n then return "Click a chest or rare icon to view loot and set a waypoint." end
  if n.rare then return "Rare NPCs are handled by RareScanner."end
  local category=A.ContainerCategory(n.typeID)
  local hint=A.ContainerHint(n.typeID)
  if category~="treasure" or hint then
    return string.format("%.1f, %.1f • %s\n",n.x*100,n.y*100,A.ContainerLabel(category))..
      (hint and hint.."\n" or "")..
      (A.IsGenericType(n.typeID) and "Exact loot variant unknown.\n" or "")..
      "Forever spawn and requirements are unconfirmed."
  end
  if A.IsGenericType(n.typeID) then
    return string.format("%.1f, %.1f • %s\n",n.x*100,n.y*100,A.LocationSource(n))..
      "Chest family known; exact loot variant unknown.\n"..A.Timer(n,A.Now()).."\nForever spawn and respawn are unconfirmed."
  end
  local zone=area and (A.Zones or A.Data.zones)[area]
  return string.format("%.1f, %.1f • %s\n",n.x*100,n.y*100,n.own and "Your recorded find" or "Historical spawn location")..
    (zone and ("Zone level "..zone.minLevel.."–"..zone.maxLevel.." (Vanilla)\n") or "")..
    A.Timer(n,A.Now()).."\n"..(n.legacyRespawn and string.format("Historical respawn: %.0f min. Forever unknown.",n.legacyRespawn/60) or "Forever respawn: unknown.")
end
