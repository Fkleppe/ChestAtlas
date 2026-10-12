from pathlib import Path
import sys,runpy,re,json,math
from PIL import Image,ImageDraw,ImageFont
WORK=Path(__file__).resolve().parent
state=runpy.run_path(str(WORK/'test_mapcanvas.py'))
lua,A=state['lua'],state['A']
# Exercise long and empty content as well as the screenshot's six-row loot card.
lua.execute('''
function InCombatLockdown()return false end
C_Item={GetItemInfo=function(id)return A.ItemName(id),"item:"..id,id%5,50,45,"Armor","Leather",1,"CHEST",134400,id*7 end}
A.RefreshItemWidgets(117,true)
LibStub=function()return {GetAddon=function()return {db={profile={}}}end}end
SlashCmdList.ACECONSOLE_RS=function()end
A.settings.cluster=false;A.filters.source="all";A.filters.query="";A.filters.areaID=0;A.filters.typeID=0;A.filters.favoritesOnly=false
local n=A.Data.nodes[141][1]
A.ShowMapDetail({n},141,57)
A.ShowMapSettings()
A.ShowUI();A.selected=n;A.selectedArea=141;A.displayMapID=57;WorldMapFrame:SetMapID(57);A.Refresh()
A.StartNavigation(n,57);A.ShowBackup(false)
A.OpenPicker(A.toolbar.chests,"Choose a chest type",A.TypeEntries(),0,function()end)
local rich
for _,ns in pairs(A.Data.nodes)do for _,p in ipairs(ns)do if p.typeID==153454 then rich=p;break end end;if rich then break end end
A.ShowMapDetail({rich},rich.id:match("legacy:(%d+):") and tonumber(rich.id:match("legacy:(%d+):")),57)
A.mapDetail.loot.page=2;A.mapDetail.loot:Refresh()
assert(A.mapDetail.loot.prev.enabled and A.mapDetail.loot.next.enabled)
A.mapDetail.loot.search:SetText("zzzz_no_item");assert(not A.mapDetail.loot.prev.enabled and not A.mapDetail.loot.next.enabled)
A.mapDetail.loot.search:SetText("");A.mapDetail.loot.page=2;A.mapDetail.loot:Refresh()
''')
fontpath=Path(r'C:\Windows\Fonts\arial.ttf')
def font_for(f):
    return ImageFont.truetype(str(fontpath),18 if f.font=='GameFontNormalLarge' else 14 if f.font=='GameFontNormal' else 12)
def textplain(t):return re.sub(r'\|c[0-9a-fA-F]{8}|\|r','',t if isinstance(t,str) else '')
def textlines(f,width):
    text=textplain(f.text);font=font_for(f);out=[]
    for paragraph in text.split('\n'):
        if f.wordWrap is False:
            while paragraph and font.getlength(paragraph)>width:paragraph=paragraph[:-1]
            out.append(paragraph);continue
        line=''
        for word in paragraph.split(' '):
            candidate=(line+' '+word).strip()
            if line and font.getlength(candidate)>width:out.append(line);line=word
            else:line=candidate
        out.append(line)
    return out
def frames_for(root):
    output=[]
    for _,f in lua.globals().MockFrames.items():
        p=f
        while p is not None:
            if p==root:output.append(f);break
            # Lupa wrapper equality is not Lua object identity.
            if lua.eval('function(a,b)return a==b end')(p,root):output.append(f);break
            p=p.parent
    return output
def eq(a,b):return lua.eval('function(a,b)return a==b end')(a,b)
def size(f):
    w=float(f.width or (f.parent.width if f.parent else 0) or 0)
    if f.height is not None:h=float(f.height)
    elif f.kind=='FontString':h=max(1,len(textlines(f,w)))*14
    else:h=0
    return w,h
factors={'TOPLEFT':(0,0),'TOP':(.5,0),'TOPRIGHT':(1,0),'LEFT':(0,.5),'CENTER':(.5,.5),'RIGHT':(1,.5),'BOTTOMLEFT':(0,1),'BOTTOM':(.5,1),'BOTTOMRIGHT':(1,1)}
def rect(f,root,depth=0):
    w,h=size(f)
    if eq(f,root):return 0,0,w,h
    if depth>30 or f.anchor is None:return None
    a=f.anchor;anchor=a[1]
    if a[2] is None:relative=f.parent;relativepoint=anchor;dx=dy=0
    elif isinstance(a[2],(int,float)):relative=f.parent;relativepoint=anchor;dx=float(a[2]);dy=float(a[3] or 0)
    else:relative=a[2];relativepoint=a[3];dx=float(a[4] or 0);dy=float(a[5] or 0)
    if relative is None:return None
    r=rect(relative,root,depth+1)
    if r is None:return None
    x,y,rw,rh=r;fx,fy=factors[anchor];rx,ry=factors[relativepoint]
    return x+rw*rx+dx-w*fx,y+rh*ry-dy-h*fy,w,h
roots=[lua.globals()[n] for n in ['ChestAtlasMapDetail','ChestAtlasWindow','ChestAtlasMapSettings','ChestAtlasPicker','ChestAtlasBackup','ChestAtlasNavigation','ChestAtlasMapToolbar']]
checks=[]
for root in roots:
    rw,rh=size(root);fs=frames_for(root);boxes=[]
    for f in fs:
        if eq(f,root):continue
        # Hidden item/picker rows are absent from the visible flow.
        p=f;hidden=False
        while p is not None and not eq(p,root):
            if p.visible is False:hidden=True
            p=p.parent
        if hidden:continue
        if f.kind=='FontString' and not textplain(f.text):continue
        r=rect(f,root)
        if not r:continue
        x,y,w,h=r
        if f.kind in ('Button','CheckButton','EditBox','FontString','Frame') and w and h:
            assert x>=-1 and y>=-1 and x+w<=rw+1 and y+h<=rh+1,(root.name,f.kind,f.text,r,(rw,rh))
            if f.parent is not None and f.parent.kind!='CheckButton':
                local=rect(f,f.parent)
                if local is not None:
                    lx,ly,lw,lh=local;pw,ph=size(f.parent)
                    assert lx>=-1 and ly>=-1 and lx+lw<=pw+1 and ly+lh<=ph+1,(root.name,'outside parent',f.kind,textplain(f.text),local,(pw,ph))
            boxes.append((f,r))
    # Independent sibling geometry detects the original loot-board/footer overlap.
    for i,(a,ra) in enumerate(boxes):
        for b,rb in boxes[i+1:]:
            if not eq(a.parent,b.parent) or a.kind=='CheckButton' or b.kind=='CheckButton':continue
            if a.kind=='FontString' and b.kind=='FontString':continue
            ax,ay,aw,ah=ra;bx,by,bw,bh=rb
            overlap=min(ax+aw,bx+bw)-max(ax,bx)>1 and min(ay+ah,by+bh)-max(ay,by)>1
            assert not overlap,(root.name,'sibling overlap',a.kind,a.text,ra,b.kind,b.text,rb)
    # Native button text is explicitly bounded to its available width.
    for f,r in boxes:
        if f.kind=='Button' and f.fontString is not None:
            assert f.fontString.width==f.width-16 and f.fontString.wordWrap is False
    checks.append({'panel':root.name,'elementsChecked':len(boxes),'width':rw,'height':rh})
    im=Image.new('RGB',(int(rw),int(rh)),(9,18,25));draw=ImageDraw.Draw(im)
    for f,(x,y,w,h) in boxes:
        if f.kind in ('Button','EditBox','Frame'):
            color=f.backgroundColor
            fill=tuple(round(float(color[i])*255) for i in range(1,4)) if color else (15,22,30)
            draw.rectangle((x,y,x+w-1,y+h-1),fill=fill,outline=(65,71,79))
            if f.text and f.fontString is None:draw.text((x+8,y+6),textplain(f.text),font=font_for(f),fill=(230,186,99))
        elif f.kind=='FontString':
            for line_no,line in enumerate(textlines(f,w)):
                color=f.textColor
                fill=tuple(round(float(color[i])*255) for i in range(1,4)) if color else (235,237,239)
                if line_no*14+14<=h:draw.text((x,y+line_no*14),line,font=font_for(f),fill=fill)
    im.save(WORK/(root.name+'-layout.png'))
(WORK/'layout-audit.json').write_text(json.dumps({'status':'PASS','panels':checks,'rendering':'Diagnostic render of actual Lua frame geometry, approximate Arial text metrics; not a WoW screenshot'},indent=2))
print(json.dumps(checks))
# Prove that the old incorrect loot height is caught by the same containment check.
board=A.mapDetail.loot
actual=rect(board.next,board);oldheight=97+6*30
assert actual[1]+actual[3]>oldheight,'Regression fixture no longer represents the reported failure'
print('PASS regression: previous loot height would put its page controls outside the panel')
for width,height in [(1280,720),(1920,1080),(2560,1440)]:
    lua.globals().UIParent.SetSize(lua.globals().UIParent,width,height)
    # Fresh UI construction uses the same screen-fit formulas from source.
    for root in roots:
        w,h=size(root)
        if root.name=='ChestAtlasWindow':scale=min(1,width/1000,height/970)
        elif root.name=='ChestAtlasMapDetail':scale=min(1,height/860)
        elif root.name=='ChestAtlasMapSettings':scale=min(1,height/595)
        elif root.name=='ChestAtlasBackup':scale=min(1,width/820,height/570)
        else:scale=1
        assert w*scale<=width and h*scale<=height,(root.name,width,height)
print('PASS screen fit: 1280x720, 1920x1080 and 2560x1440')
seen=set()
for area,nodes in A.RareData.nodes.items():
    for _,n in nodes.items():
        if n.npcID in seen:continue
        seen.add(n.npcID)
        A.ShowMapDetail(lua.table_from([n]),area,57)
        field=A.mapDetail.info
        assert len(textlines(field,float(field.width)))*14<=field.height,('rare details too tall',n.npcID,field.text)
        assert A.mapDetail.loot.layout.height+A.mapDetail.loot.anchor[3]*-1<=A.mapDetail.height
assert len(seen)==334
print('PASS all 334 rare NPC detail summaries fit their reserved text area')
# Exercise every newly included container/hint rather than only ordinary loot cards.
seen_types=set()
for area,nodes in A.Data.nodes.items():
    for _,n in nodes.items():
        if n.typeID in seen_types:continue
        seen_types.add(n.typeID)
        A.ShowMapDetail(lua.table_from([n]),area,57)
        field=A.mapDetail.info
        assert len(textlines(field,float(field.width)))*14<=field.height,('container details too tall',n.typeID,field.text)
        assert A.mapDetail.loot.layout.height+A.mapDetail.loot.anchor[3]*-1<=A.mapDetail.height
print(f'PASS all {len(seen_types)} represented container detail summaries fit; quest/locked/event/collectible hints included')
