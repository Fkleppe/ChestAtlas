local _,A=...
-- Dungeon and raid chests. Forever has no dungeon maps and no player coordinates inside
-- instances, so chests are listed per instance with opening requirements and loot.
local W=A.Widgets
local panel,selectedInstance,selectedChest,announced
local page,ROWS=1,8
function A.InstanceName(id)
  local inst=A.Instances and A.Instances[id]
  return inst and inst.name or A.ForeverInstances and A.ForeverInstances[id] or ("Instance #"..tostring(id))
end
local function owned(id)
  local count=A.Safe(C_Item and C_Item.GetItemCount or GetItemCount,id)
  return type(count)=="number" and count or 0
end
function A.LockpickingSkill()
  if not GetNumSkillLines or not GetSkillLineInfo then return nil end
  for i=1,(A.Safe(GetNumSkillLines) or 0) do
    local name,_,_,rank=A.Safe(GetSkillLineInfo,i)
    if name=="Lockpicking" and type(rank)=="number" then return rank end
  end
end
local function names(ids)
  local out={};for _,id in ipairs(ids or {}) do out[#out+1]=A.ItemName(id) end;return out
end
-- Short text for list rows, long text for the detail panel.
function A.ChestRequirement(c)
  local short,long={},{}
  if c.keys then
    short[#short+1]="Key: "..table.concat(names(c.keys)," / ")
    long[#long+1]="Requires a key: "..table.concat(names(c.keys)," or ").."."
  end
  if c.pickLock then
    local tools=names(c.tools)
    short[#short+1]="Locked • Lockpicking "..c.pickLock
    long[#long+1]="Locked: Rogue Pick Lock with Lockpicking "..c.pickLock..(#tools>0 and (", or "..table.concat(tools,", ")) or "").."."
  end
  if #short==0 then short[1]="No key • anyone can open";long[1]="No key or lockpicking needed: anyone can open it." end
  if c.event then short[#short+1]="after encounter";long[#long+1]="Not there when the instance opens: an encounter or script spawns it." end
  if c.trigger then long[#long+1]=c.trigger end
  return table.concat(short," • "),table.concat(long," ")
end
function A.ChestAccess(c)
  local have={}
  for _,list in ipairs({c.keys or {},c.tools or {}}) do
    for _,id in ipairs(list) do local n=owned(id);if n>0 then have[#have+1]=A.ItemName(id).." x"..n end end
  end
  if c.pickLock then
    local skill=A.LockpickingSkill()
    if skill then have[#have+1]="Lockpicking "..skill..(skill>=c.pickLock and " (enough)" or " (too low)") end
  end
  return #have>0 and ("You have: "..table.concat(have,", ")..".") or nil
end
function A.InstanceChests(iid)
  local list={}
  for _,c in ipairs(A.Instances and A.Instances[iid] and A.Instances[iid].chests or {}) do list[#list+1]=c end
  local found={}
  for id,d in pairs(A.journal and A.journal.discovered or {}) do if d.instance==iid then found[#found+1]=id end end
  table.sort(found)
  for _,id in ipairs(found) do list[#list+1]={typeID=id,discovered=true,spawns=0} end
  return list
end
function A.InstanceEntries()
  local seen,entries={},{}
  local function add(id)
    if seen[id] then return end;seen[id]=true
    local n=#A.InstanceChests(id)
    entries[#entries+1]={value=id,text=A.InstanceName(id).." • "..n.." chest type"..(n==1 and "" or "s")}
  end
  for id in pairs(A.Instances or {}) do add(id) end
  for id in pairs(A.journal and A.journal.instances or {}) do add(id) end
  for _,d in pairs(A.journal and A.journal.discovered or {}) do if d.instance then add(d.instance) end end
  table.sort(entries,function(a,b)return a.text<b.text end)
  return entries
end
function A.AnnounceInstance()
  local iid=A.CurrentInstance and A.CurrentInstance()
  if iid==announced then return end
  announced=iid
  if not iid then return end
  selectedInstance,selectedChest,page=iid,nil,1
  local list,seen,parts=A.InstanceChests(iid),{},{}
  for _,c in ipairs(list) do
    local name=A.TypeName(c.typeID)
    if not seen[name] then
      seen[name]=true
      parts[#parts+1]=name..(c.keys and " (key)" or c.pickLock and " (locked)" or c.event and " (after encounter)" or "")
    end
  end
  if #parts==0 then A.Print(A.InstanceName(iid)..": no chest data. Chests you loot here are logged • /ca dungeons")
  else A.Print(A.InstanceName(iid)..": "..table.concat(parts,", ")..". Keys and loot: /ca dungeons") end
end
local function logText(iid,c)
  local e=A.journal.instances[iid] and A.journal.instances[iid][c.typeID]
  if not e or (e.loots or 0)==0 then return "Not looted by you yet." end
  return "Looted by you "..e.loots.."x • last "..A.Ago(A.Now()-(e.last or A.Now())).." ago."
end
function A.InstanceChestDetail(iid,c)
  if c.discovered then
    return "Found by you in "..A.InstanceName(iid)..". Object #"..c.typeID.." is not in the Classic databases, so it is new or changed in Forever.\n"..logText(iid,c)
  end
  local _,req=A.ChestRequirement(c)
  local parts={req,(c.spawns or 0).." possible spawn point"..(c.spawns==1 and "" or "s").." in Classic data"..(c.sources=="CM" and " (CMaNGOS only)" or "").."."}
  if c.sharesWith and #c.sharesWith>0 then
    local others={};for _,id in ipairs(c.sharesWith) do others[#others+1]=A.TypeName(id).." #"..id end
    parts[#parts+1]="Shares its spawn points with "..table.concat(others,", ")..": each point holds one of them."
  end
  local access=A.ChestAccess(c);if access then parts[#parts+1]=access end
  parts[#parts+1]=logText(iid,c)
  return table.concat(parts,"\n")
end
local function nodeFor(iid,c)
  local log=A.journal.instances[iid] and A.journal.instances[iid][c.typeID]
  return {id="instance:"..iid..":"..c.typeID,typeID=c.typeID,contents=log and log.contents or {},own=c.discovered or nil,instanceID=iid}
end
local function createPanel()
  panel=W.Panel("ChestAtlasInstances",UIParent,760,650);panel:SetPoint("CENTER")
  panel:SetScale(math.min(1,UIParent:GetHeight()/690))
  W.Line(panel,"DUNGEON & RAID CHESTS",16,19,600,"GameFontNormalLarge"):SetTextColor(unpack(W.gold))
  W.Line(panel,"Forever has no dungeon maps, so chests are listed per instance.",16,46,600)
  panel.pick=W.Button(panel,"",16,70,330,function(self)
    A.OpenPicker(self,"Select instance",A.InstanceEntries(),selectedInstance,function(v)selectedInstance,selectedChest,page=v,nil,1;A.RefreshInstances()end)
  end)
  panel.rows={}
  for i=1,ROWS do
    local row=CreateFrame("Button",nil,panel,"BackdropTemplate")
    row:SetPoint("TOPLEFT",16,-(108+(i-1)*52));row:SetSize(330,48);W.Surface(row,true)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD");row:GetHighlightTexture():SetVertexColor(0.30,0.23,0.09,0.2)
    row.selected=row:CreateTexture(nil,"OVERLAY");row.selected:SetTexture("Interface\\Buttons\\WHITE8X8");row.selected:SetVertexColor(unpack(W.gold));row.selected:SetSize(3,46);row.selected:SetPoint("TOPLEFT",1,-1)
    row.icon=row:CreateTexture(nil,"ARTWORK");A.ApplyChestIcon(row.icon);row.icon:SetSize(26,26);row.icon:SetPoint("TOPLEFT",6,-11)
    row.name=W.Line(row,"",40,6,284,"GameFontNormal")
    row.meta=W.Line(row,"",40,26,284);row.meta:SetTextColor(0.60,0.69,0.77)
    row:SetScript("OnClick",function(self)selectedChest=self.chest;A.RefreshInstances()end)
    panel.rows[i]=row
  end
  panel.empty=W.Text(panel,"",20,114,320)
  panel.prev=W.Button(panel,"<",16,528,60,function()page=math.max(1,page-1);A.RefreshInstances()end)
  panel.pageText=W.Line(panel,"",86,534,190);panel.pageText:SetJustifyH("CENTER")
  panel.next=W.Button(panel,">",286,528,60,function()page=page+1;A.RefreshInstances()end)
  panel.footer=W.Text(panel,"Classic spawn points and loot; Forever spawns and drops are unconfirmed. Opening requirements come from the Forever client's lock data. Your loots inside instances are logged automatically.",16,566,330)
  panel.footer:SetTextColor(0.55,0.62,0.68)
  panel.title=W.Line(panel,"",362,70,382,"GameFontNormalLarge")
  panel.detail=W.Text(panel,"",362,98,382);panel.detail:SetHeight(120);panel.detail:SetJustifyV("TOP")
  panel.loot=W.Loot(panel,362,226,382,4)
end
function A.RefreshInstances()
  if not panel or not panel:IsShown() then return end
  local iid=selectedInstance
  panel.pick:SetText(iid and A.InstanceName(iid) or "Select an instance")
  local list=iid and A.InstanceChests(iid) or {}
  local pages=math.max(1,math.ceil(#list/ROWS));page=math.max(1,math.min(page,pages))
  local valid=false;for _,c in ipairs(list) do valid=valid or c==selectedChest end
  if not valid then selectedChest=list[1] end
  for i,row in ipairs(panel.rows) do
    local c=list[(page-1)*ROWS+i];row.chest=c
    if c then
      row.name:SetText(A.TypeName(c.typeID)..((c.spawns or 0)>0 and (" x"..c.spawns) or ""))
      row.meta:SetText(c.discovered and "Your discovery • not in Classic data" or (A.ChestRequirement(c)))
      row.selected:SetShown(c==selectedChest);row:Show()
    else row:Hide() end
  end
  panel.empty:SetText(#list==0 and (iid and "No chest data for this instance. Chests you loot here appear automatically." or "Select an instance.") or "")
  panel.pageText:SetText(page.." / "..pages);panel.prev:SetEnabled(page>1);panel.next:SetEnabled(page<pages)
  local c=selectedChest
  panel.title:SetText(c and A.TypeName(c.typeID) or "")
  panel.detail:SetText(c and A.InstanceChestDetail(iid,c) or "")
  panel.loot:SetNode(c and nodeFor(iid,c) or nil)
end
function A.ShowInstances(iid)
  if not A.journal then return end
  if not panel then createPanel() end
  selectedInstance=iid or (A.CurrentInstance and A.CurrentInstance()) or selectedInstance
  if not selectedInstance then local first=A.InstanceEntries()[1];selectedInstance=first and first.value end
  panel:Show();A.RefreshInstances()
end
