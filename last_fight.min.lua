--[==[badge-app
slug=last_fight
name=Humanity's Last Fight
icon=HLF
api=2
heap_kb=96
wake_lock=1
]==]
local PX1<const> =40
local PX2<const> =280
local PY<const> =170
local G<const> =0.4
local WALK<const> =3
local STEP<const> =20
local RM<const> ="A  rematch        B  menu"
local floor,min,abs,badge=math.floor,math.min,math.abs
local FC={0xffd23f,0xff4f6d,0xffe98a,0xff9fb0,0x9a7e20,0x99303f}
local F,W,NM={},{},{"You","AI"}
local st,di,acc,last,cn,ledt,kw,sn,Z=1,1,0,0,-1,0,1,-1,1
local B,R,L,ct,sub,god
local function spawn(f,x)
f.x=x;f.y=PY-60
f.vx=0;f.vy=0;f.air=true
f.dmg=0;f.atk=0;f.stun=0;f.dead=0;f.bcd=0;f.bt=0
f.blk=false;f.dj=true
end
local function hudup(c)
for i=1,2 do
local f=F[i]
f.hud:set_text(NM[i].." "..f.dmg.."%")
for k=1,3 do f.hearts[k]:hidden(c or k>f.stk)end
end
end
local function typ(w,tx,t)
local l=#tx
local n=min(l+1,t//140)
if n~=sn and n>=0 then sn=n;w:set_text(tx:sub(1,n))end
return n>l
end
local function wb(w,x,y,ww,hh)
local fl,z=floor,Z
w:set_pos(fl(150+(x-150)*z),fl(PY+(y-PY)*z));w:set_size(fl(ww*z),fl(hh*z))
end
local function draw(f)
local x,y=f.x,f.y
if f.dead>0 then x=-50;y=-50 end
local hy=y-32
if f.cut==2 then wb(f.wb,139,PY-10,22,10);hy=y-5
else wb(f.wb,x-7,y-22,14,22)end
wb(f.wh,x-5,hy,10,10)
local atk=f.atk
local act=atk//5==1
if act then wb(f.wa,x+(f.face>0 and 7 or-25),y-22,18,12)end
if act~=f.sa then f.sa=act;f.wa:hidden(not act)end
local b=f.blk
if b~=f.sb then f.sb=b;f.wb:set_color(FC[f.i+(b and 4 or 0)])end
end
local function frame()
wb(W.plat,PX1,PY,PX2-PX1,10);wb(W.dirt,PX1+4,PY+10,PX2-PX1-8,12)
draw(F[1]);draw(F[2])
end
local function theme(d)
d=d or di
local TH<const> ="\x2a\x6f\xd6\x3b\x82\xe2\x56\xa0\xee\x7c\xc0\xf8\x34\x67\xa8\x28\xff\xff\xff\x00\x00\x00\xff\xe1\x4a\x1e\xb6\x06\x3f\xae\x3f\x7a\x4a\x1e\x00\x00\x00\x00\x0c\x5a\x00\x05\z\x14\x10\x2a\x2a\x1a\x48\x4b\x2a\x5a\x7a\x3a\x55\x12\x0e\x1e\x28\x3a\x38\x48\xd0\xd0\xe0\xd8\xda\xe6\x18\xba\x08\x5c\x6b\x34\x35\x25\x18\x00\x00\x00\x00\x14\x2d\x1e\x28\z\x05\x00\x05\x18\x00\x06\x38\x00\x0a\x70\x00\x0e\x00\x00\x00\x00\x2a\x00\x00\xff\x4a\x20\x00\x00\x00\x00\x00\x00\x15\x08\x08\x05\x00\x00\xff\x20\x20\x02\x19\x26\x41\x64"
local s1,s2,s3,s4,hc,hr,cc,sc,oc,os,ox,oy,pc,dc,bc,bw,sp,cd,bp,tm=(">I3I3I3I3I3BI3I3I3BBBI3I3I3BBBBB"):unpack(TH,d*42-41)
local a=F[2]
a.spd=sp/20;a.cd=cd;a.bp=bp;a.tm=tm
local sky={s1,s2,s3,s4}
for k=1,4 do W.sky[k]:set_color(sky[k]);W.hill[k]:style({bg_color=hc,radius=hr})end
for k=1,6 do W.cl[k]:set_color(cc)end
for k=1,10 do local s=W.star[k];s:hidden(sc==0);s:set_color(sc)end
local o,p=W.orb,W.plat
o:hidden(oc==0)
if oc>0 then o:set_size(os,os);o:set_pos(ox,oy);o:style({bg_color=oc,radius=os//2})end
p:set_color(pc);p:set_border(bc,bw)
W.dirt:set_color(dc)
W.dif:set_text("Difficulty:   <  "..({"CHATBOT","AGENT","AGI"})[d].."  >")
end
local function place(m,now)
local c,h,g=m==4,m~=1,m~=2
theme()
Z=1
for k=1,6 do W.cl[k]:hidden(c);if k<5 then W.hill[k]:hidden(c)end end
for i=1,2 do
local f=F[i]
if not c then
spawn(f,10+i*100)
f.stk=3;f.y=PY+0;f.air=false;f.face=3-2*i;f.sa=nil;f.sb=nil;f.cut=nil
f.wa:set_size(18,12)
end
f.wa:set_color(c and i==2 and 0xff2020 or FC[i])
f.hud:hidden(g);f.tag:hidden(g)
end
for n in("over title keys acts dif"):gmatch("%a+")do W[n]:hidden(h)end
local mg=W.msg
W.over:style({bg_color=c and 0xffffff or 0,bg_opa=c and 255 or 130});mg:set_color(c and kw==2 and 0xff2020 or 0xffffff)
W.sub:set_text("");W.pool:hidden(true)
if m~=2 then mg:set_text("")end
W.hint:set_text(m==1 and"Left / Right  difficulty        A  start"or"")
if m==2 and god then local a=F[2];a.dmg=200;a.stk=1;a.bp=0 end
st=m;ct=now;cn=-1
hudup(c)
frame()
end
local function cut(now)
local t,w=now-ct,kw
local p,a,k,h=F[3-w],F[w],w==1,t//100
local wa,over=a.wa,W.over
local u=min(0,t-1500)
Z=2.2-u*u/1875000
if h<65 then
p.x=150+h%2;p.y=PY+0;a.y=PY+0
local x=min(-176,(t-2500)/50-236)
a.x=k and 300+x or-x
if h>=55 then wa:hidden(false);wb(wa,k and 124-min(14,t/10-556)or 152,PY-22,18,12)end
elseif h<67 then
if not p.cut then
p.cut=0
if k then a.x=132 end
wb(wa,141,PY-22,18,12)
over:hidden(k)
end
elseif p.cut==0 then
p.cut=w
over:hidden(true);wa:hidden(true);W.pool:hidden(k)
p.x=150
if k then p.y=PY+0;p.vx=7;p.vy=-13 else p.y=PY-27;p.vx=-1.6;p.vy=-5 end
else
while acc>=STEP do
acc=acc-STEP
if p.y<300 then
local vy=p.vy+G
local y=p.y+vy
p.vy=vy;p.y=y;p.x=p.x+p.vx
if vy>0 and y>PY-5 then p.y=PY-5;p.vy=-vy*0.4;p.vx=p.vx*0.7 end
end
end
if p.cut==1 and p.x>240 then p.cut=3;theme(1)end
local pw=min(60,(t-6460)//60)
wb(W.pool,150-pw/2,PY-4,pw,4)
if h>=78 and typ(W.msg,sub,t-7800)and h>=115 then st=5 end
end
frame()
end
local function ainp(f,o)
local n,dx,rnd,hop=f.inp,o.x-f.x,badge.sys.random,di==3
local ad,live=abs(dx),o.dead==0
n.l=false;n.r=false;n.atk=false;n.up=false
if live and ad>26 then
if dx<0 then n.l=true else n.r=true end
elseif not f.air then
f.face=dx<0 and-1 or 1
end
local ft=f.t-1
f.t=ft
if live and(ft<=0 and(ad<30 and rnd(100)<f.tm or f.tm<50 and ad<70 and rnd(100)<1)
or hop and o.atk==10 and ad<36)then n.atk=true;f.t=f.cd end
local bt=f.bt-1
if o.atk==1 and ad<44 and rnd(100)<f.bp then bt=14 end
f.bt=bt;n.blk=bt>0
if f.air then
local l,r=f.x<PX1,f.x>PX2
if l or r then n.r,n.l=l,r end
n.up=di>1 and f.dj and(l or r)
if hop and f.dj and f.vy>0 and rnd(100)<4 then n.up=true end
elseif hop and bt<=0 and rnd(100)<2 then
n.up=true
end
end
local function step(f,o)
local n,mg,d,s,cd=f.inp,W.msg,f.dead,f.stun,f.bcd
if d>0 then
d=d-1;f.dead=d
if d==0 then spawn(f,160);mg:set_text("")end
return
end
s=s-1;cd=cd-1;f.stun=s;f.bcd=cd
local air=f.air
local free=s<=0 and f.atk==0
local canb=n.blk and free and not air
if canb then
if not f.blk and cd<=0 then f.blk=true end
elseif f.blk then f.blk=false;f.bcd=10 end
if free and not f.blk then
if n.l then f.vx=-WALK*f.spd;f.face=-1
elseif n.r then f.vx=WALK*f.spd;f.face=1
elseif not air then f.vx=0 end
if n.atk then f.atk=1;f.hit=false;if not air then f.vx=0 end end
if n.up and(not air or f.dj)then f.dj=not air;f.air=true;f.vy=-7 end
elseif not air then
f.vx=f.vx*0.6
end
local atk=f.atk
if atk>0 then atk=(atk+1)%18;f.atk=atk end
local vy=min(f.vy+G,9)
local y0=f.y
local x,y=f.x+f.vx,y0+vy
f.vy,f.x,f.y=vy,x,y
local on=x>PX1-6 and x<PX2+6
if vy>0 and y0<=PY and y>=PY and on then
y=PY;f.y=y;f.vy=0;f.air=false;f.dj=true
elseif not f.air and not on then
f.air=true
end
local ox=o.x
local hx,hy=x+f.face*16-ox,y-o.y
if atk//5==1 and not f.hit and o.dead==0 and hx>-16 and hx<16 and hy>-22 and hy<22 then
f.hit=true
local d=ox>=x and 1 or-1
if o.blk and d*o.face<0 then
o.vx=d*2
else
local dm=o.dmg+10
o.dmg=dm
local kb=3+dm*0.06
o.vx,o.vy=d*kb,(kb+1)/-2
o.stun=8+dm//8;o.atk=0;o.blk=false;o.air=true
o.flash=last+100
hudup()
end
end
if f.y>260 or x<-40 or x>360 then
f.stk=f.stk-1
hudup()
if f.stk==0 then
kw,sn=o.i,-1
sub=({"You beat AI from 2022...\nBut agents have taken over now","Damn, I guess humanity\nnever stood a chance.",
"Yay! It was just a bubble after all.\nOr maybe not...","It was fun while it lasted.","Humanity is safe at last.","It's our time now"})[di*2+kw-2]
if di<3 then
st,ct=5,last
mg:set_text(kw==1 and"YOU WIN!"or"AI WINS")
else
o.dead=0;o.atk=0;f.atk=0
place(4,last)
end
else
f.dead=50;f.atk=0;f.blk=false
mg:set_text(NM[f.i].." fell!")
end
end
end
local function leds(now)
local r,g,b=0,0,0
if st==3 then
for k=1,6 do
local f=F[("\1\2\2\2\1\1"):byte(k)]
local t=min(f.dmg,100)*3
if now<f.flash then L.set(k,200,200,200)else L.set(k,min(150,t),min(150,300-t),0)end
end
else
if st==2 then
r=200-50*cn
g,b=r,r
if cn==0 then r=0;g=150;b=0 end
elseif st==4 then
local t=now-ct
r=t//400%2==0 and 200 or 30
g=kw%2*r
if t>=6500 and t<6700 then r=150;g=150;b=150 end
else
local j=st==1 and di or kw+3
r,g,b=("\x00\x5a\x1e\x6e\x5a\x00\x78\x00\x14\xff\xd2\x3f\xff\x4f\x6d"):byte(j*3-2,j*3)
end
L.set_all(r,g,b)
end
L.show()
end
function on_enter(root)
badge=_ENV.badge
B,R,L=badge.input.BUTTON,root,badge.led
local function box(w,h,x,y,c,r)
local b=badge.ui.box(R,w,h)
b:set_pos(x,y)
b:style({bg_color=c,radius=r})
return b
end
W.sky,W.hill,W.cl,W.star={},{},{},{}
for k=1,4 do W.sky[k]=box(320,60,0,k*60-60,0,0)end
for k=1,4 do
local x,w,h=(">hBB"):unpack("\xff\xec\x78\x46\x00\x50\x8c\x32\x00\xbe\x96\x50\x01\x2c\x3c\x28",k*4-3)
W.hill[k]=box(w,h,x,240-h,0,0)
end
for k=1,10 do W.star[k]=box(3,3,(k*61)%310+4,(k*37)%90+6,0,1)end
W.orb=box(10,10,0,0,0,0)
for k=1,3 do
local x,y,cl=k*100,("\x28\x16\x3e"):byte(k),W.cl
cl[k]=box(56,14,x-80,y,0,7)
cl[k+3]=box(26,14,x-64,y-8,0,7)
end
W.dirt=box(PX2-PX1-8,12,PX1+4,PY+10,0,3)
W.plat=box(PX2-PX1,10,PX1,PY,0,0)
local lb=badge.ui.label
for i=1,2 do
local f={i=i,flash=0,inp={},t=0,spd=1}
f.wb=box(14,22,0,-50,FC[i],2)
f.wh=box(10,10,0,-50,FC[i+2],3)
f.wa=box(18,12,0,-50,FC[i],2)
local h=lb(R,"")
h:style({text_font=20});h:set_pos(i==1 and 8 or 240,6)
local hs={}
f.hearts=hs
for k=1,3 do
hs[k]=box(10,10,i*250+k*18-258,34,0xff3355,5)
end
local t=lb(R,NM[i]:upper())
t:style({text_font=14,text_color=0xffffff});t:set_pos(i*100-4,PY-54)
f.hud=h;f.tag=t
F[i]=f
end
W.pool=box(4,4,-10,-10,0xd01020,2)
W.over=box(320,240,0,0,0x000000,0)
for k,tx,fo,ax,al,dx,dy in("title|HUMANITY'S\nLAST FIGHT|24|center|top_mid|0|6;keys|Left / Right\nUp\nA\nB|16|right|right_mid|-170|-6;\zacts|move\njump  (twice)\nattack\nblock|16|left|left_mid|168|-6;dif||20|center|center|0|66;hint||14|center|bottom_mid|0|-8;\zmsg||24|center|center|0|-64;sub||16|center|center|0|-14;"):gmatch("(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-);")do
local l=lb(R,tx)
l:style({text_font=fo+0,text_align=ax});l:align(al,dx+0,dy+0)
W[k]=l
end
W.title:set_color(FC[1])
place(1)
end
function on_tick()
local now=badge.sys.ms()
acc=min(acc+now-last,STEP*3)
last=now
if st==2 then
local e,mg=now-ct,W.msg
local n=3-e//1000
if n~=cn then cn=n;mg:set_text(n>0 and n..""or"FIGHT!")end
if e>=3600 then
st,acc=3,0
mg:set_text("")
F[1].tag:hidden(true);F[2].tag:hidden(true)
end
elseif st==3 then
local isd=badge.input.is_down
local p,q=F[1],F[2]
while acc>=STEP and st==3 do
acc=acc-STEP
local n=p.inp
n.l,n.r=isd(B.LEFT),isd(B.RIGHT)
n.blk=isd(B.B)
ainp(q,p)
step(p,q);step(q,p)
n.atk=false;n.up=false
end
frame()
elseif st==4 then
cut(now)
elseif st==5 and sub then
if typ(W.sub,sub,now-ct-800)then sub=nil;W.hint:set_text(RM)end
end
if now>=ledt then ledt=now+50;leds(now)end
end
function on_button(b,kind)
if b==B.AUX1 then god=not god;return end
if kind~=badge.input.KIND.PRESSED then return end
if b==B.A and(st==1 or st==5)then place(2,badge.sys.ms())
elseif b==B.START and st~=1 or b==B.B and st==5 then place(1)
elseif st==1 then
if b==B.LEFT then di=di+1;b=B.RIGHT end
if b==B.RIGHT then di=di%3+1;theme()end
elseif st==3 then
local n=F[1].inp
if b==B.A then n.atk=true elseif b==B.UP then n.up=true end
end
end
function on_exit()
L.clear()
L.show()
end
