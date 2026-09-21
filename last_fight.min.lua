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
local floor,min=math.floor,math.min
local B
local FC={0xffd23f,0xff4f6d,0xffe98a,0xff9fb0,0x9a7e20,0x99303f}
local F,hud,hearts,tag,W,NM={},{},{},{},{},{"You","AI"}

local st,di,acc,last,pa,pu,ct,cn=1,1,0,0,false,false,0,-1
local ledt,kw,sub,sn,L=0,1,nil,-1
local function spawn(f,x)
f.x,f.y=x,PY-60
f.vx=0;f.vy=0;f.air=true
f.dmg=0;f.atk=0;f.stun=0;f.dead=0;f.bcd=0;f.bt=0
f.blk=false;f.hit=true;f.dj=true
end

local function hudup(c)
for i=1,2 do
hud[i]:set_text(NM[i].." "..F[i].dmg.."%")
for k=1,3 do hearts[i][k]:hidden(c or k>F[i].stk)end
end
end

local function hint(t)
W.hint:set_text(t);W.hint:hidden(t=="")
end


local function typ(w,tx,t)
local n=min(#tx+1,t//140)
if n~=sn and n>=0 then sn=n;w:set_text(string.sub(tx,1,n))end
return n>#tx
end


local Z=1
local function wb(w,x,y,ww,hh)
w:set_pos(floor(150+(x-150)*Z),floor(PY+(y-PY)*Z));w:set_size(floor(ww*Z),floor(hh*Z))
end

local function draw(f)
local x,y=f.x,f.y
if f.dead>0 then x,y=-50,-50 end
if f.cut==2 then wb(f.wb,139,PY-10,22,10);wb(f.wh,x-5,y-5,10,10)
else wb(f.wb,x-7,y-22,14,22);wb(f.wh,x-5,y-32,10,10)end
local act=f.dead==0 and f.atk>=5 and f.atk<=9
if act then wb(f.wa,x+(f.face>0 and 7 or-25),y-22,18,12)end
if act~=f.sa then f.sa=act;f.wa:hidden(not act)end
if f.blk~=f.sb then f.sb=f.blk;f.wb:set_color(FC[f.i+(f.blk and 4 or 0)])end
end


local function frame()
wb(W.plat,PX1,PY,PX2-PX1,10);wb(W.dirt,PX1+4,PY+10,PX2-PX1-8,12)
draw(F[1]);draw(F[2])
end


local function theme(d)
d=d or di


local TH="\x2a\x6f\xd6\x3b\x82\xe2\x56\xa0\xee\x7c\xc0\xf8\x34\x67\xa8\x28\xff\xff\xff\x00\x00\x00\xff\xe1\x4a\x1e\xb6\x06\x3f\xae\x3f\x7a\x4a\x1e\x00\x00\x00\x00\z
\x14\x10\x2a\x2a\x1a\x48\x4b\x2a\x5a\x7a\x3a\x55\x12\x0e\x1e\x28\x3a\x38\x48\xd0\xd0\xe0\xd8\xda\xe6\x18\xba\x08\x5c\x6b\x34\x35\x25\x18\x00\x00\x00\x00\z
\x05\x00\x05\x18\x00\x06\x38\x00\x0a\x70\x00\x0e\x00\x00\x00\x00\x2a\x00\x00\xff\x4a\x20\x00\x00\x00\x00\x00\x00\x15\x08\x08\x05\x00\x00\xff\x20\x20\x02"
local s1,s2,s3,s4,hc,hr,cc,sc,oc,os,ox,oy,pc,dc,bc,bw=string.unpack(">I3I3I3I3I3BI3I3I3BBBI3I3I3B",TH,d*38-37)
local sky={s1,s2,s3,s4}
for k=1,4 do W.sky[k]:set_color(sky[k]);W.hill[k]:style({bg_color=hc,radius=hr})end
for k=1,6 do W.cl[k]:set_color(cc)end
for k=1,10 do W.star[k]:hidden(sc==0);W.star[k]:set_color(sc)end
W.orb:hidden(oc==0)
if oc>0 then W.orb:set_size(os,os);W.orb:set_pos(ox,oy);W.orb:style({bg_color=oc,radius=os//2})end
W.plat:set_color(pc);W.plat:set_border(bc,bw)
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
f.stk,f.y,f.air,f.face,f.sa,f.sb,f.cut=3,PY,false,3-2*i,nil,nil,nil
f.wa:set_size(18,12)
end
f.wa:set_color(c and i==2 and 0xff2020 or FC[i])
hud[i]:hidden(g);tag[i]:hidden(g)
end
W.over:hidden(h);W.title:hidden(h);W.keys:hidden(h);W.acts:hidden(h);W.dif:hidden(h)
W.over:style({bg_color=c and 0xffffff or 0,bg_opa=c and 230 or 130});W.msg:set_color(c and kw==2 and 0xff2020 or 0xffffff)
W.sub:set_text("");W.pool:hidden(true)
if m~=2 then W.msg:set_text("")end
hint(m==1 and"Left / Right  difficulty        A  start"or"")

local a,s,cd,bp,tm=F[2],string.byte("\x0c\x5a\x00\x05\x14\x2d\x1e\x28\x19\x26\x41\x64",di*4-3,di*4)
a.spd,a.cd,a.bp,a.hop,a.tm,a.rec=s/20,cd,bp,di==3,tm,di>1
st,ct,cn=m,now,-1
hudup(c)
frame()
end






local function cut(now)
local t,p,a,k=now-ct,F[3-kw],F[kw],kw==1
local u=1-min(1,t/1500)
Z=2.2-1.2*u*u
if t<6500 then
p.x,p.y,a.y=150+t//100%2,PY,PY
if t>=2500 then
local x=math.max(176,236-(t-2500)*0.02)
a.x=k and 300-x or x
end
if t>=5500 then a.wa:hidden(false);wb(a.wa,k and a.x+6-(t-5500)*0.014 or a.x-24,PY-22,18,12)end
elseif t<6700 then
if k then a.x=132 end
wb(a.wa,141,PY-22,18,12)
W.over:hidden(k)
elseif not p.cut then
p.cut=kw
W.over:hidden(true);a.wa:hidden(true);W.pool:hidden(k)
p.x,p.y,p.vx,p.vy=150,k and PY or PY-27,k and 4 or-1.6,k and-7 or-5
else
while acc>=STEP do
acc=acc-STEP
if p.y<300 then
p.vy=p.vy+G;p.x,p.y=p.x+p.vx,p.y+p.vy
if p.vy>0 and p.y>PY-5 and p.x>PX1 and p.x<PX2 then p.y,p.vy,p.vx=PY-5,-p.vy*0.4,p.vx*0.7 end
end
end
if p.cut==1 and p.x>240 then p.cut=3;theme(1)end
local pw=min(60,(t-6700)//60+4)
wb(W.pool,150-pw/2,PY-4,pw,4)
if t>=7800 and typ(W.msg,k and"Humanity is safe at last."or"It's our time now",t-7800)and t>=11500 then st=5;hint(RM)end
end
frame()
end

local function ainp(f,o)
local n,dx,rnd=f.inp,o.x-f.x,badge.sys.random
local ad,live=math.abs(dx),o.dead==0
n.l,n.r,n.atk,n.up=false,false,false,false
if live and ad>26 then
if dx<0 then n.l=true else n.r=true end
elseif not f.air then
f.face=dx<0 and-1 or 1
end
f.t=f.t-1
if live and(f.t<=0 and(ad<30 and rnd(100)<f.tm or f.tm<50 and ad<70 and rnd(100)<1)
or f.hop and o.atk==10 and ad<36)then n.atk=true;f.t=f.cd end
if f.bt>0 then f.bt=f.bt-1 end
if o.atk==1 and ad<44 and rnd(100)<f.bp then f.bt=14 end
n.blk=f.bt>0
if f.air then
local l,r=f.x<PX1,f.x>PX2
if l or r then n.r,n.l=l,r end
n.up=f.rec and f.dj and(l or r)
if f.hop and f.dj and f.vy>0 and rnd(100)<4 then n.up=true end
elseif f.hop and f.bt==0 and rnd(100)<2 then
n.up=true
end
end

local function step(f,o)
local n=f.inp
if f.dead>0 then
f.dead=f.dead-1
if f.dead==0 then spawn(f,160);W.msg:set_text("")end
return
end
if f.stun>0 then f.stun=f.stun-1 end
if f.bcd>0 then f.bcd=f.bcd-1 end
local free=f.stun==0 and f.atk==0
local canb=n.blk and free and not f.air
if f.blk and not canb then f.blk=false;f.bcd=10 end
if not f.blk and canb and f.bcd==0 then f.blk=true end
if free and not f.blk then
if n.l then f.vx=-WALK*f.spd;f.face=-1
elseif n.r then f.vx=WALK*f.spd;f.face=1
elseif not f.air then f.vx=0 end
if n.atk then f.atk=1;f.hit=false;if not f.air then f.vx=0 end end
if n.up and(not f.air or f.dj)then f.dj,f.air,f.vy=not f.air,true,-7 end
elseif not f.air then
f.vx=f.vx*0.6
end
if f.atk>0 then f.atk=f.atk+1;if f.atk>17 then f.atk=0 end end
f.vy=min(f.vy+G,9)
f.x,f.y=f.x+f.vx,f.y+f.vy
local on=f.x>PX1-6 and f.x<PX2+6
if f.vy>0 and f.y-f.vy<=PY and f.y>=PY and on then
f.y,f.vy,f.air,f.dj=PY,0,false,true
elseif not f.air and not on then
f.air=true
end
if f.atk>=5 and f.atk<=9 and not f.hit and o.dead==0
and math.abs(f.x+f.face*16-o.x)<16 and math.abs(f.y-o.y)<22 then
f.hit=true
local d=o.x>=f.x and 1 or-1
if o.blk and d*o.face<0 then
o.vx=d*2
else
o.dmg=o.dmg+10
o.vx,o.vy=d*(3+o.dmg*0.06),-(2+o.dmg*0.03)
o.stun,o.atk,o.blk,o.air=8+floor(o.dmg/8),0,false,true
o.flash=last+100
hudup()
end
end
if f.y>260 or f.x<-40 or f.x>360 then
f.stk=f.stk-1
hudup()
if f.stk==0 then
kw,sn=o.i,-1
if di<3 then
st,ct,sub=5,last,({"You beat AI from 2022...\nGo stop the agents\nfrom taking action","Sigh, humanity never\nstood a chance...",
"You beat modern AI, but the\nbubble hasn't popped just yet.","It was fun while it lasted"})[di*2+kw-2]
W.msg:set_text(kw==1 and"YOU WIN!"or"AI WINS")
else
o.x,o.dead,o.atk,f.atk,sub=kw==1 and 64 or 236,0,0,0,nil
place(4,last)
end
else
f.dead=50;f.atk=0;f.blk=false
W.msg:set_text(NM[f.i].." fell!")
end
end
end

local function leds(now)
local r,g,b=0,0,0
if st==3 then
for k=1,6 do
local f=F[k%5<2 and 1 or 2]
local t=min(f.dmg,100)/50
r,g,b=floor(150*min(1,t)),floor(150*min(1,2-t)),0
if now<f.flash then r,g,b=200,200,200 end
L.set(k,r,g,b)
end
else
if st==1 then
r,g,b=string.byte("\x00\x5a\x1e\x6e\x5a\x00\x78\x00\x14",di*3-2,di*3)
elseif st==2 then
r=200-50*cn
g,b=r,r
if cn==0 then r,g,b=0,150,0 end
elseif st==4 then
local t=now-ct
r=t//400%2==0 and 200 or 30
g=kw%2*r
if kw==2 and t>=6500 and t<6700 then r,g,b=255,255,255 end
else
local c=FC[kw]
r,g,b=c>>16,c>>8&255,c&255
end
L.set_all(r,g,b)
end
L.show()
end

local R
local function box(w,h,x,y,c,r)
local b=badge.ui.box(R,w,h)
b:set_pos(x,y)
b:style({bg_color=c,radius=r})
return b
end

function on_enter(root)
B,R,L=badge.input.BUTTON,root,badge.led
W.sky,W.hill,W.cl,W.star={},{},{},{}
for k=1,4 do W.sky[k]=box(320,60,0,k*60-60,0,0)end
for k=1,4 do
local x,w,h=string.unpack(">hBB","\xff\xec\x78\x46\x00\x50\x8c\x32\x00\xbe\x96\x50\x01\x2c\x3c\x28",k*4-3)
W.hill[k]=box(w,h,x,240-h,0,0)
end
for k=1,10 do W.star[k]=box(3,3,(k*61)%310+4,(k*37)%90+6,0,1)end
W.orb=box(10,10,0,0,0,0)
for k=1,3 do
local y=string.byte("\x28\x16\x3e",k)
W.cl[k]=box(56,14,k*100-80,y,0,7)
W.cl[k+3]=box(26,14,k*100-64,y-8,0,7)
end
W.dirt=box(PX2-PX1-8,12,PX1+4,PY+10,0,3)
W.plat=box(PX2-PX1,10,PX1,PY,0,0)
for i=1,2 do
local f={i=i,flash=0,inp={},t=0,spd=1}
f.wb=box(14,22,0,-50,FC[i],2)
f.wh=box(10,10,0,-50,FC[i+2],3)
f.wa=box(18,12,0,-50,FC[i],2)
hud[i]=badge.ui.label(R,"")
hud[i]:style({text_font=20})
hud[i]:set_pos(i==1 and 8 or 240,6)
hearts[i]={}
for k=1,3 do
hearts[i][k]=box(10,10,(i==1 and 10 or 260)+(k-1)*18,34,0xff3355,5)
end
tag[i]=badge.ui.label(R,i==1 and"YOU"or"AI")
tag[i]:style({text_font=14,text_color=0xffffff})
tag[i]:set_pos(i*100-4,PY-54)
F[i]=f
end
W.pool=box(4,4,-10,-10,0xd01020,2)
W.over=box(320,240,0,0,0x000000,0)
for k,tx,fo,ax,al,dx,dy in("title|HUMANITY'S\nLAST FIGHT|24|center|top_mid|0|6;keys|Left / Right\nUp\nA\nB|16|right|right_mid|-170|-6;"
.."acts|move\njump  (twice)\nattack\nblock|16|left|left_mid|168|-6;dif||20|center|center|0|66;hint||14|center|bottom_mid|0|-8;"
.."msg||24|center|center|0|-64;sub||16|center|center|0|-14"):gmatch("(%a+)|([^|]*)|(%d+)|(%a+)|([%a_]+)|(-?%d+)|(-?%d+)")do
local l=badge.ui.label(R,tx)
l:style({text_font=tonumber(fo),text_align=ax});l:align(al,tonumber(dx),tonumber(dy))
W[k]=l
end
W.title:style({text_color=0xffd23f})
place(1)
end

function on_tick()
local now=badge.sys.ms()
if last==0 then last=now end
acc=min(acc+now-last,STEP*3)
last=now
if st==2 then
local n=3-(now-ct)//1000
if n<1 then n=0 end
if n~=cn then cn=n;W.msg:set_text(n>0 and tostring(n)or"FIGHT!")end
if now-ct>=3600 then
st,acc=3,0
W.msg:set_text("")
tag[1]:hidden(true);tag[2]:hidden(true)
end
elseif st==3 then
while acc>=STEP and st==3 do
acc=acc-STEP
local n=F[1].inp
n.l,n.r=badge.input.is_down(B.LEFT),badge.input.is_down(B.RIGHT)
n.blk,n.atk,n.up,pa,pu=badge.input.is_down(B.B),pa,pu,false,false
ainp(F[2],F[1])
step(F[1],F[2]);step(F[2],F[1])
end
frame()
elseif st==4 then
cut(now)
elseif st==5 and sub then
if typ(W.sub,sub,now-ct-800)then sub=nil;hint(RM)end
end
if now>=ledt then ledt=now+50;leds(now)end
end

function on_button(b,kind)
if kind~=badge.input.KIND.PRESSED then return end
if b==B.A and(st==1 or st==5)then place(2,badge.sys.ms())
elseif b==B.START and st~=1 or b==B.B and st==5 then place(1)
elseif st==1 then
if b==B.LEFT or b==B.RIGHT then di=(di+(b==B.LEFT and 1 or 0))%3+1;theme()end
elseif st==3 then
if b==B.A then pa=true elseif b==B.UP then pu=true end
end
end

function on_exit()
L.clear()
L.show()
end
