local _,A=...
local W={};A.Widgets=W
W.gold={0.90,0.73,0.39}
function W.Surface(p,light)
  p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
  p:SetBackdropColor(light and 0.065 or 0.025,light and 0.09 or 0.039,light and 0.12 or 0.058,0.98)
  p:SetBackdropBorderColor(0.25,0.28,0.31,1)
end
function W.Rule(parent,x,y,width)
  local t=parent:CreateTexture(nil,"BACKGROUND");t:SetTexture("Interface\\Buttons\\WHITE8X8")
  t:SetVertexColor(0.72,0.55,0.27,0.35);t:SetPoint("TOPLEFT",x,-y);t:SetSize(width,1);return t
end
function W.Text(parent,text,x,y,width,font)
  local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
  f:SetPoint("TOPLEFT",x,-y);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetText(text);return f
end
function W.Line(parent,text,x,y,width,font)
  local f=W.Text(parent,text,x,y,width,font)
  f:SetWordWrap(false);f:SetHeight(font=="GameFontNormalLarge" and 24 or 16);return f
end
function W.Button(parent,text,x,y,width,fn)
  local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
  b:SetPoint("TOPLEFT",x,-y);b:SetSize(width,26);W.Surface(b,true)
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD")
  b:GetHighlightTexture():SetVertexColor(0.35,0.27,0.12,0.24)
  local caption=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");caption:SetPoint("CENTER");caption:SetTextColor(unpack(W.gold))
  b:SetFontString(caption);b:SetText(text);b:SetScript("OnClick",fn)
  local f=b:GetFontString()
  if f then f:SetWidth(width-16);f:SetHeight(16);f:SetWordWrap(false) end
  local enable=b.SetEnabled
  b.SetEnabled=function(self,enabled)
    enable(self,enabled)
    if enabled then caption:SetTextColor(unpack(W.gold));self:SetAlpha(1)
    else caption:SetTextColor(0.40,0.47,0.53);self:SetAlpha(0.65)end
  end
  b:SetScript("OnEnter",function(self)
    local text=self:GetText()
    if text and #text>2 then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(text,1,0.82,0,true);GameTooltip:Show()end
  end)
  b:SetScript("OnLeave",function()GameTooltip:Hide()end)
  return b
end
function W.Edit(parent,x,y,width,text)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetPoint("TOPLEFT",x,-y);e:SetSize(width,24);e:SetAutoFocus(false);e:SetText(text or "")
  e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
  e:SetScript("OnEnterPressed",function(self)self:ClearFocus()end);return e
end
function W.Panel(name,parent,width,height)
  local p=CreateFrame("Frame",name,parent,"BackdropTemplate")
  p:SetSize(width,height);p:SetFrameStrata("DIALOG");p:SetClampedToScreen(true)
  W.Surface(p);W.Rule(p,16,8,width-32);p:EnableMouse(true)
  local close=CreateFrame("Button",nil,p,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3)
  p:SetMovable(true);p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart",function(self)self:StartMoving()end)
  p:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
  if name and UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end
  return p
end
function W.Check(parent,text,x,y,width,fn)
  local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
  b:SetPoint("TOPLEFT",x,-y);b:SetSize(24,24)
  b.caption=W.Line(b,text,26,5,width)
  b:SetScript("OnClick",function(self)fn(self:GetChecked()==true)end);return b
end
local picker
function A.OpenPicker(anchor,title,entries,current,callback)
  if not picker then
    picker=W.Panel("ChestAtlasPicker",UIParent,360,410);picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker.title=W.Line(picker,"",16,16,295,"GameFontNormal")
    picker.search=W.Edit(picker,20,46,314,"");picker.search:SetMaxLetters(80)
    picker.rows={}
    for i=1,10 do
      local b=W.Button(picker,"",16,80+(i-1)*27,328,function(self)
        if self.entry then local entry=self.entry;picker:Hide();picker.callback(entry.value) end
      end);picker.rows[i]=b
    end
    picker.pageText=W.Text(picker,"",134,372,100)
    W.Button(picker,"<",16,365,80,function()picker.page=math.max(1,picker.page-1);picker:Refresh()end)
    W.Button(picker,">",264,365,80,function()picker.page=picker.page+1;picker:Refresh()end)
    function picker:Refresh()
      local q=self.search:GetText():lower();local matches={}
      for _,e in ipairs(self.entries or {}) do if e.text:lower():find(q,1,true) then matches[#matches+1]=e end end
      local pages=math.max(1,math.ceil(#matches/10));self.page=math.min(self.page,pages)
      self.pageText:SetText(self.page.." / "..pages)
      for i,b in ipairs(self.rows) do
        local e=matches[(self.page-1)*10+i];b.entry=e
        if e then b:SetText((e.value==self.current and "• " or "")..e.text);b:Show() else b:Hide() end
      end
    end
    picker.search:SetScript("OnTextChanged",function()picker.page=1;picker:Refresh()end)
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
local colors={[0]={0.6,0.6,0.6},[1]={1,1,1},[2]={0.3,1,0.3},[3]={0.3,0.65,1},[4]={0.75,0.45,1}}
function A.Money(copper)
  return string.format("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end
function A.ShortMoney(copper)
  if copper>=10000 then return string.format("%dg %ds",math.floor(copper/10000),math.floor(copper/100)%100) end
  if copper>=100 then return string.format("%ds %dc",math.floor(copper/100),copper%100) end
  return string.format("%dc",copper)
end
function W.Tabs(parent,x,y,width,height)
  local t=CreateFrame("Frame",nil,parent);t:SetPoint("TOPLEFT",x,-y);t:SetSize(width,height)
  t.buttons={};t.pages={}
  function t:SetTab(key)
    if not self.pages[key]then return end
    self.active=key
    for name,p in pairs(self.pages)do
      p:SetShown(name==key)
      self.buttons[name]:SetBackdropBorderColor(unpack(name==key and W.gold or {0.25,0.28,0.31}))
    end
  end
  for i,entry in ipairs({{"loot","Loot"},{"journal","Journal"},{"sources","Sources"}})do
    local key=entry[1]
    t.buttons[key]=W.Button(t,entry[2],(i-1)*(width+6)/3,0,(width-12)/3,function()t:SetTab(key)end)
    local p=CreateFrame("Frame",nil,t);p:SetPoint("TOPLEFT",0,-38);p:SetSize(width,height-38)
    t.pages[key]=p;t[key]=p
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
function W.ItemColor(text,item)
  local c=colors[item and item.quality] or {0.75,0.8,0.85};text:SetTextColor(c[1],c[2],c[3])
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
  GameTooltip:Show()
end
function W.BestCard(parent,x,y,width)
  local c=CreateFrame("Button",nil,parent,"BackdropTemplate");c:SetPoint("TOPLEFT",x,-y);c:SetSize(width,74);W.Surface(c,true)
  c.icon=c:CreateTexture(nil,"ARTWORK");c.icon:SetSize(40,40);c.icon:SetPoint("TOPLEFT",12,-19)
  c.tag=W.Line(c,"MOST VALUABLE • VENDOR",64,2,width-76);c.tag:SetTextColor(unpack(W.gold))
  c.name=W.Line(c,"",64,20,width-76,"GameFontNormal")
  c.meta=W.Line(c,"",64,38,width-76);c.meta:SetTextColor(0.64,0.72,0.79)
  c.cash=W.Line(c,"",64,55,width-76);c.cash:SetTextColor(unpack(W.gold))
  c:SetScript("OnEnter",W.ItemTooltip);c:SetScript("OnLeave",function()GameTooltip:Hide()end)
  c:SetScript("OnClick",function(self)
    if self.item and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.item.link) end
  end)
  function c:SetNode(n,source)
    local best=A.BestLoot(n,source);self.item,self.valueSummary,self.node,self.lootMode=best.item,best,n,source
    self.icon:SetTexture(best.item and best.item.icon or 134400)
    W.ItemColor(self.name,best.item)
    local unknownVariant=n and A.IsGenericType(n.typeID) and best.total==0
    self.name:SetText(best.item and best.item.name or (not n and "Select a location" or unknownVariant and "Exact chest variant unknown" or best.total==0 and "No known loot for this type" or "Item prices not available yet"))
    self.meta:SetText(best.item and (A.Money(best.item.price).." each • priced "..best.known.."/"..best.total) or unknownVariant and "Loot table unavailable • record a find to confirm" or (best.total>0 and ("0/"..best.total.." prices available • AH unknown") or "Possible loot • AH value unknown"))
    self.cash:SetText(n and not n.rare and A.CashText(n) or "")
  end
  c.chance=W.Line(c,"",64,55,width-76);c.chance:SetTextColor(0.64,0.72,0.79)
  c.cash:ClearAllPoints();c.cash:SetPoint("TOPLEFT",64,-74)
  local setNode=c.SetNode
  function c:SetNode(n,source)
    setNode(self,n,source)
    self.chance:SetText(self.item and A.ChanceText(n,self.item.id,source) or "")
    self.tag:SetText(n and A.IsGenericType(n.typeID) and "TOP VENDOR • POSSIBLE VARIANT" or "TOP VENDOR • POSSIBLE DROP")
  end
  c:SetHeight(94);c:SetNode(nil);return c
end
function W.Loot(parent,x,y,width,rowCount)
  local rowTop,rowHeight,pagerGap,pagerHeight=220,40,8,26
  local bottom=rowTop+rowCount*rowHeight+pagerGap
  local b=CreateFrame("Frame",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(width,bottom+pagerHeight)
  b.layout={rowTop=rowTop,rowHeight=rowHeight,rowCount=rowCount,pagerTop=bottom,height=bottom+pagerHeight}
  b.page,b.mode,b.quality=1,"legacy",nil;b.rows={}
  local sorts={valueDesc="Value ↓",valueAsc="Value ↑",chanceDesc="Drop chance ↓",chanceAsc="Drop chance ↑"}
  if not sorts[A.settings and A.settings.lootSort] then A.settings.lootSort="valueDesc" end
  b.best=W.BestCard(b,0,0,width)
  b.source=W.Button(b,"Possible loot",0,102,width*0.38,function(self)
    A.OpenPicker(self,"Loot source",{{value="legacy",text="Classic full table (Vanilla fallback if absent)"},{value="pf",text="Vanilla pfQuest list (incomplete groups)"},{value="own",text="Your recorded loot"}},b.mode,function(mode)b.mode=mode;b.page=1;b:Refresh()end)
  end)
  b.filter=W.Button(b,"All qualities",width*0.4,102,width*0.27,function(self)
    local entries={{value=-1,text="All qualities"}}
    for q=0,4 do entries[#entries+1]={value=q,text=qualityNames[q]} end
    A.OpenPicker(self,"Item quality",entries,b.quality or -1,function(q)b.quality=q>=0 and q or nil;b.page=1;b:Refresh()end)
  end)
  b.sort=W.Button(b,"",width*0.69,102,width*0.31,function(self)
    A.OpenPicker(self,"Sort loot",{{value="valueDesc",text="Value: highest first"},{value="valueAsc",text="Value: lowest first"},{value="chanceDesc",text="Drop chance: highest first"},{value="chanceAsc",text="Drop chance: lowest first"}},A.settings.lootSort,function(sort)A.settings.lootSort=sort;b.page=1;b:Refresh()end)
  end)
  b.frequent=W.Button(b,"All drops",0,136,width,function(self)
    b.frequentOnly=not b.frequentOnly;b.page=1;b:Refresh()
  end)
  b.frequent:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine("Frequent drops: Classic estimate at least 1%.",1,0.84,0.4,true)
    GameTooltip:AddLine("Unknown probabilities are excluded. This is not a measured Forever drop rate.",0.7,0.78,0.85,true);GameTooltip:Show()
  end)
  b.search=W.Edit(b,5,168,width-10,"");b.search:SetMaxLetters(80)
  b.searchHint=W.Line(b.search,"Search items / item ID",5,5,width-24);b.searchHint:SetTextColor(0.55,0.6,0.65)
  b.search:SetScript("OnTextChanged",function()b.page=1;b:Refresh()end)
  b.summary=W.Line(b,"",2,200,width-4);b.summary:SetTextColor(0.66,0.74,0.81)
  for i=1,rowCount do
    local row=CreateFrame("Button",nil,b);row:SetPoint("TOPLEFT",0,-(rowTop+(i-1)*rowHeight));row:SetSize(width,rowHeight-2)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
    row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",1,0);row.icon:SetSize(28,28)
    row.name=W.Line(row,"",36,3,width-38);row.meta=W.Line(row,"",36,21,width-38);row.meta:SetTextColor(0.66,0.74,0.81)
    row:SetScript("OnEnter",W.ItemTooltip)
    row:SetScript("OnLeave",function()GameTooltip:Hide()end)
    row:SetScript("OnClick",function(self)
      if self.item and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.item.link) end
    end)
    b.rows[i]=row
  end
  b.prev=W.Button(b,"<",0,bottom,60,function()b.page=math.max(1,b.page-1);b:Refresh()end)
  b.pageText=W.Line(b,"",70,bottom+6,width-140)
  b.next=W.Button(b,">",width-60,bottom,60,function()b.page=b.page+1;b:Refresh()end)
  function b:SetNode(n)
    if self.node~=n then self.page=1 end
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
    self.searchHint:SetShown(q=="")
    self.source:SetText(self.mode=="own" and "Recorded loot" or generic and "Possible family loot" or A.LootSource(n,self.mode)=="cm" and "Classic loot" or "Vanilla loot")
    self.sort:SetText(sorts[A.settings.lootSort])
    self.frequent:SetEnabled(self.mode~="own" and not generic and A.LootSource(n,self.mode)=="cm")
    self.frequent:SetText(generic and self.mode~="own" and "Exact variant unknown • chances unavailable" or self.frequentOnly and self.mode~="own" and "Frequent drops • Classic ≥1%" or "All drops • include rare possibilities")
    self.filter:SetText(self.quality and qualityNames[self.quality] or "All qualities")
    local pages=math.max(1,math.ceil(#list/rowCount));self.page=math.min(self.page,pages)
    local missing=n and #A.ReferenceLoot(n,self.mode)==0
    self.summary:SetText(#list==0 and (n and (self.mode=="own" and "No recorded loot matches this search." or missing and "No historical item loot documented." or "No items match these filters.") or "Select a chest to view loot.") or (generic and self.mode~="own" and (#list.." possible items • "..(A.GenericLootPool(n,self.mode).scope=="zone" and "zone variants" or "family variants")) or (#list.." items • "..sorts[A.settings.lootSort].." • unknowns last")))
    self.pageText:SetText(self.page.." / "..pages)
    self.prev:SetEnabled(self.page>1);self.next:SetEnabled(self.page<pages)
    for i,row in ipairs(self.rows) do
      local item=list[(self.page-1)*rowCount+i];row.item,row.node,row.lootMode=item,n,self.mode
      if item then
        row.icon:SetTexture(item.icon or 134400);row.name:SetText(item.name)
        W.ItemColor(row.name,item)
        local meta=item.price~=nil and ("Vendor "..A.ShortMoney(item.price)) or "Vendor unknown"
        if self.mode=="own" then local e=n.contents[item.id];meta=e.count.." seen • "..meta
        else meta=meta.." • "..A.ChanceText(n,item.id,self.mode)end
        row.meta:SetText(meta);row:Show()
      else row:Hide() end
    end
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
      if A.UpdateNavigation then A.UpdateNavigation()end
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
