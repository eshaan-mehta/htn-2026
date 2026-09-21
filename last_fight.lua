--[==[badge-app
slug=last_fight
name=Humanity's Last Fight
icon=HLF
api=2
heap_kb=96
wake_lock=1
]==]
-- Humanity's Last Fight: You vs AI. L/R move  Up jump x2  A attack  B block  Start menu
local PX1, PX2, PY, G, WALK, STEP = 40, 280, 170, 0.4, 3, 20
local floor, RM = math.floor, "A  rematch        B  menu"
local B
local SIDE = {{1, 6, 5}, {2, 3, 4}}
local BC, HC, BB = {0xffd23f, 0xff4f6d}, {0xffe98a, 0xff9fb0}, {0x9a7e20, 0x99303f}
local DIFF = {{"CHATBOT", 0.6, 90, 0, false, false, 5}, {"AGENT", 1, 45, 30, false, false, 40}, {"AGI", 1.25, 38, 65, true, true, 100}}
local DC = {{0, 90, 30}, {110, 90, 0}, {120, 0, 20}}
-- per difficulty: sky bands 1-4, hill color, hill radius, clouds, stars, orb color (false = none), orb w, h, x, y, platform, dirt, platform border
local TH = {
  {0x2a6fd6, 0x3b82e2, 0x56a0ee, 0x7cc0f8, 0x3467a8, 40, 0xffffff, false, 0xffe14a, 30, 30, 182, 6, 0x3fae3f, 0x7a4a1e, 0},
  {0x14102a, 0x2a1a48, 0x4b2a5a, 0x7a3a55, 0x120e1e, 40, 0x3a3848, 0xd0d0e0, 0xd8dae6, 24, 24, 186, 8, 0x5c6b34, 0x352518, 0},
  {0x050005, 0x180006, 0x38000a, 0x70000e, 0x000000, 0, 0x2a0000, 0xff4a20, false, 0, 0, 0, 0, 0x150808, 0x050000, 0xff2020},
}
local HILL, CLY = {{-20, 120, 70}, {80, 140, 50}, {190, 150, 80}, {300, 60, 40}}, {40, 22, 62}
local F, hud, hearts, tag, W = {}, {}, {}, {}, {}
local st, di, acc, last, pa, pu, ct, cn = "menu", 1, 0, 0, false, false, 0, -1
local ledt, kw, sub, sn = 0, 1, nil, -1
-- end-screen lines per difficulty {win, loss}; false = cutscene
local END = {
  {"You beat AI from 2022...\nGo stop the agents\nfrom taking action", "Sigh, humanity never\nstood a chance..."},
  {"You beat modern AI, but the\nbubble hasn't popped just yet.", "It was fun while it lasted"},
  {"", false},
}

local function spawn(f, x)
  f.x, f.y, f.vx, f.vy, f.air = x, PY - 60, 0, 0, true
  f.dmg, f.atk, f.stun, f.dead, f.blk, f.bcd, f.hit, f.dj, f.bt = 0, 0, 0, 0, false, 0, true, true, 0
end

local function hudup()
  for i = 1, 2 do
    hud[i]:set_text((i == 1 and "You " or "AI ") .. F[i].dmg .. "%")
    for k = 1, 3 do hearts[i][k]:hidden(k > F[i].stk) end
  end
end

local function hint(t)
  W.hint:set_text(t); W.hint:hidden(t == "")
end

-- typewriter: reveal tx on w at 140 ms per char, t = ms since start; true when done
local function typ(w, tx, t)
  local n = math.min(#tx + 1, floor(t / 140))
  if n ~= sn and n >= 0 then sn = n; w:set_text(string.sub(tx, 1, n)) end
  return n > #tx
end

-- cutscene camera: world units scaled by Z about the player's spot (150, PY)
local Z = 1
local function wb(w, x, y, ww, hh)
  w:set_pos(floor(150 + (x - 150) * Z), floor(PY + (y - PY) * Z)); w:set_size(floor(ww * Z), floor(hh * Z))
end

local function draw(f)
  local x, y = floor(f.x), floor(f.y)
  if f.dead > 0 then x, y = -50, -50 end
  f.wb:set_pos(x - 7, y - 22)
  f.wh:set_pos(x - 5, y - 32)
  local act = f.dead == 0 and f.atk >= 5 and f.atk <= 9
  if act then f.wa:set_pos(x + (f.face > 0 and 7 or -25), y - 22) end
  if act ~= f.sa then f.sa = act; f.wa:hidden(not act) end
  if f.blk ~= f.sb then f.sb = f.blk; f.wb:style({bg_color = f.blk and BB[f.i] or BC[f.i]}) end
end

-- put both fighters on the platform facing each other; m = menu mode
local function place(m)
  Z = 1
  wb(W.plat, PX1, PY, PX2 - PX1, 10); wb(W.dirt, PX1 + 4, PY + 10, PX2 - PX1 - 8, 12)
  for k = 1, 4 do W.hill[k]:hidden(false) end
  for i = 1, 2 do
    local f = F[i]
    spawn(f, 10 + i * 100)
    f.stk, f.y, f.air, f.face, f.sa, f.sb = 3, PY, false, 3 - 2 * i, nil, nil
    f.wb:set_size(14, 22); f.wh:set_size(10, 10); f.wa:set_size(18, 12); f.wa:style({bg_color = 0xffffff})
    draw(f)
    hud[i]:hidden(m)
    tag[i]:set_pos(floor(f.x) - 14, PY - 54)
    tag[i]:hidden(m)
  end
  W.over:hidden(not m); W.title:hidden(not m); W.keys:hidden(not m); W.acts:hidden(not m); W.dif:hidden(not m)
  W.over:style({bg_color = 0, bg_opa = 130}); W.msg:style({text_color = 0xffffff}); W.sub:set_text("")
  W.pool:hidden(true)
  hudup()
end

-- AGI loss cutscene, t = ms since KO: zoom in, hold, AI walks in, blade up, strike, aftermath, line
local function cut(now)
  local t, p, a = now - ct, F[1], F[2]
  local u = 1 - math.min(1, t / 1500)
  Z = 2.2 - 1.2 * u * u
  if t < 6500 then
    p.x = 150 + floor(t / 100) % 2
    if t >= 2500 then a.x = math.max(176, 236 - (t - 2500) * 0.02) end
    if t >= 5500 then a.wa:hidden(false); wb(a.wa, a.x - 24, PY - 52, 18, 12) end
  elseif t < 6700 then
    wb(a.wa, 141, PY - 36, 18, 12)
    W.over:hidden(false)
  elseif not p.cut then
    p.cut = true
    W.over:hidden(true); a.wa:hidden(true); W.pool:hidden(false)
    p.x, p.y, p.vx, p.vy = 150, PY - 27, -1.6, -5
  else
    while acc >= STEP do
      acc = acc - STEP
      p.vy = p.vy + G; p.x, p.y = p.x + p.vx, p.y + p.vy
      if p.vy > 0 and p.y > PY - 5 and p.x > PX1 and p.x < PX2 then p.y, p.vy, p.vx = PY - 5, -p.vy * 0.4, p.vx * 0.7 end
    end
    local pw = math.min(60, floor((t - 6700) / 60) + 4)
    wb(W.pool, 150 - pw / 2, PY - 4, pw, 4)
    if t >= 7800 and typ(W.msg, "It's our time now", t - 7800) and t >= 11500 then st = "ko"; hint(RM) end
  end
  wb(W.plat, PX1, PY, PX2 - PX1, 10); wb(W.dirt, PX1 + 4, PY + 10, PX2 - PX1 - 8, 12)
  wb(a.wb, a.x - 7, PY - 22, 14, 22); wb(a.wh, a.x - 5, PY - 32, 10, 10)
  if p.cut then wb(p.wb, 139, PY - 10, 22, 10); wb(p.wh, p.x - 5, p.y - 5, 10, 10)
  else wb(p.wb, p.x - 7, PY - 22, 14, 22); wb(p.wh, p.x - 5, PY - 32, 10, 10) end
end

local function theme()
  local t = TH[di]
  for k = 1, 4 do W.sky[k]:style({bg_color = t[k]}); W.hill[k]:style({bg_color = t[5], radius = t[6]}) end
  for k = 1, 6 do W.cl[k]:style({bg_color = t[7]}) end
  for k = 1, 10 do W.star[k]:hidden(not t[8]); W.star[k]:style({bg_color = t[8] or 0}) end
  W.orb:hidden(not t[9])
  if t[9] then W.orb:set_size(t[10], t[11]); W.orb:set_pos(t[12], t[13]); W.orb:style({bg_color = t[9], radius = floor(t[11] / 2)}) end
  W.plat:style({bg_color = t[14]}); W.plat:set_border(t[16], di == 3 and 2 or 0)
  W.dirt:style({bg_color = t[15]})
  W.dif:set_text("Difficulty:   <  " .. DIFF[di][1] .. "  >")
end

local function menu()
  st = "menu"
  W.msg:set_text("")
  hint("Left / Right  difficulty        A  start")
  place(true)
end

local function start(now)
  local d = DIFF[di]
  place(false)
  F[2].spd, F[2].cd, F[2].bp, F[2].pun, F[2].hop, F[2].tm, F[2].rec = d[2], d[3], d[4], d[5], d[6], d[7], di > 1
  st, ct, cn = "count", now, -1
  hint("")
end

local function ainp(f, o)
  local n, dx = f.inp, o.x - f.x
  local ad = math.abs(dx)
  n.l, n.r, n.atk, n.up = false, false, false, false
  if o.dead == 0 and ad > 26 then
    if dx < 0 then n.l = true else n.r = true end
  elseif not f.air then
    f.face = dx < 0 and -1 or 1
  end
  f.t = f.t - 1
  local rdy = o.dead == 0 and f.t <= 0
  if (rdy and ad < 30 and badge.sys.random(100) < f.tm) or (rdy and f.tm < 50 and ad < 70 and badge.sys.random(100) < 1)
    or (f.pun and o.dead == 0 and o.atk == 10 and ad < 36) then n.atk = true; f.t = f.cd end
  if f.bt > 0 then f.bt = f.bt - 1 end
  if o.atk == 1 and ad < 44 and badge.sys.random(100) < f.bp then f.bt = 14 end
  n.blk = f.bt > 0
  if f.air then
    if f.x < PX1 then n.r, n.l = true, false elseif f.x > PX2 then n.l, n.r = true, false end
    n.up = f.rec and f.dj and (f.x < PX1 or f.x > PX2)
    if f.hop and f.dj and f.vy > 0 and badge.sys.random(100) < 4 then n.up = true end
  elseif f.hop and f.bt == 0 and badge.sys.random(100) < 2 then
    n.up = true
  end
end

local function step(f, o)
  local n = f.inp
  if f.dead > 0 then
    f.dead = f.dead - 1
    if f.dead == 0 then spawn(f, 160); W.msg:set_text("") end
    return
  end
  if f.stun > 0 then f.stun = f.stun - 1 end
  if f.bcd > 0 then f.bcd = f.bcd - 1 end
  local free = f.stun == 0 and f.atk == 0
  if f.blk and not (n.blk and free and not f.air) then f.blk = false; f.bcd = 10 end
  if not f.blk and n.blk and free and not f.air and f.bcd == 0 then f.blk = true end
  if free and not f.blk then
    if n.l then f.vx = -WALK * f.spd; f.face = -1
    elseif n.r then f.vx = WALK * f.spd; f.face = 1
    elseif not f.air then f.vx = 0 end
    if n.atk then f.atk = 1; f.hit = false; if not f.air then f.vx = 0 end end
    if n.up and (not f.air or f.dj) then f.dj, f.air, f.vy = not f.air, true, -7 end
  elseif not f.air then
    f.vx = f.vx * 0.6
  end
  if f.atk > 0 then f.atk = f.atk + 1; if f.atk > 17 then f.atk = 0 end end
  f.vy = math.min(f.vy + G, 9)
  f.x, f.y = f.x + f.vx, f.y + f.vy
  local on = f.x > PX1 - 6 and f.x < PX2 + 6
  if f.vy > 0 and f.y - f.vy <= PY and f.y >= PY and on then
    f.y, f.vy, f.air, f.dj = PY, 0, false, true
  elseif not f.air and not on then
    f.air = true
  end
  if f.atk >= 5 and f.atk <= 9 and not f.hit and o.dead == 0
    and math.abs(f.x + f.face * 16 - o.x) < 16 and math.abs(f.y - o.y) < 22 then
    f.hit = true
    local d = o.x >= f.x and 1 or -1
    if o.blk and d * o.face < 0 then
      o.vx = d * 2
    else
      o.dmg = o.dmg + 10
      o.vx, o.vy = d * (3 + o.dmg * 0.06), -(2 + o.dmg * 0.03)
      o.stun, o.atk, o.blk, o.air = 8 + floor(o.dmg / 8), 0, false, true
      o.flash = last + 100
      hudup()
    end
  end
  if f.y > 260 or f.x < -40 or f.x > 360 then
    f.stk = f.stk - 1
    hudup()
    if f.stk == 0 then
      kw, sn = o.i, -1
      local e = END[di][kw]
      if e then
        st, ct, sub = "ko", last, e
        W.msg:set_text(kw == 1 and "YOU WIN!" or "AI WINS")
      else
        st, ct, sub, f.cut, o.x, o.dead = "cut", last, nil, false, 236, 0
        f.wa:hidden(true); o.wa:hidden(true)
        for i = 1, 2 do hud[i]:hidden(true); for k = 1, 3 do hearts[i][k]:hidden(true) end end
        for k = 1, 4 do W.hill[k]:hidden(true) end
        W.msg:set_text(""); W.msg:style({text_color = 0xff2020})
        W.over:style({bg_color = 0xffffff, bg_opa = 230})
        o.wa:style({bg_color = 0xff2020})
      end
    else
      f.dead, f.atk, f.blk = 50, 0, false
      W.msg:set_text((f.i == 1 and "You" or "AI") .. " fell!")
    end
  end
end

local function leds(now)
  badge.led.clear()
  if st == "menu" then
    local c = DC[di]
    badge.led.set_all(c[1], c[2], c[3])
  elseif st == "count" then
    local v = 200 - 50 * cn
    if cn == 0 then badge.led.set_all(0, 150, 0) else badge.led.set_all(v, v, v) end
  elseif st == "cut" then
    local t = now - ct
    if t >= 6500 and t < 6700 then badge.led.set_all(255, 255, 255)
    else badge.led.set_all(floor(t / 400) % 2 == 0 and 200 or 30, 0, 0) end
  elseif st == "ko" then
    local c = BC[kw]
    badge.led.set_all(floor(c / 65536), floor(c / 256) % 256, c % 256)
  else
    for i = 1, 2 do
      local f = F[i]
      local t = math.min(f.dmg, 100) / 50
      local r, g, b = floor(150 * math.min(1, t)), floor(150 * math.min(1, 2 - t)), 0
      if now < f.flash then r, g, b = 200, 200, 200 end
      for k = 1, 3 do badge.led.set(SIDE[i][k], r, g, b) end
    end
  end
  badge.led.show()
end

local function box(root, w, h, x, y, c, r)
  local b = badge.ui.box(root, w, h)
  b:set_pos(x, y)
  b:style({bg_color = c, radius = r})
  return b
end

local function label(root, text, font, alx, al, dx, dy)
  local l = badge.ui.label(root, text)
  l:style({text_font = font, text_align = alx})
  l:align(al, dx, dy)
  return l
end

function on_enter(root)
  B = badge.input.BUTTON
  local s = badge.sys.stats()
  badge.sys.log("lua=" .. s.lua_used .. " peak=" .. s.lua_peak .. " free=" .. s.free_heap)
  W.sky, W.hill, W.cl, W.star = {}, {}, {}, {}
  for k = 1, 4 do W.sky[k] = box(root, 320, 60, 0, k * 60 - 60, 0, 0) end
  for k = 1, 4 do local h = HILL[k]; W.hill[k] = box(root, h[2], h[3], h[1], 240 - h[3], 0, 0) end
  for k = 1, 10 do W.star[k] = box(root, 3, 3, (k * 61) % 310 + 4, (k * 37) % 90 + 6, 0, 1) end
  W.orb = box(root, 10, 10, 0, 0, 0, 0)
  for k = 1, 3 do
    W.cl[k] = box(root, 56, 14, k * 100 - 80, CLY[k], 0, 7)
    W.cl[k + 3] = box(root, 26, 14, k * 100 - 64, CLY[k] - 8, 0, 7)
  end
  W.dirt = box(root, PX2 - PX1 - 8, 12, PX1 + 4, PY + 10, 0, 3)
  W.plat = box(root, PX2 - PX1, 10, PX1, PY, 0, 0)
  for i = 1, 2 do
    local f = {i = i, face = 3 - 2 * i, stk = 3, flash = 0, inp = {}, t = 0, spd = 1, cd = 60, bp = 0, tm = 100}
    f.wb = box(root, 14, 22, 0, -50, BC[i], 2)
    f.wh = box(root, 10, 10, 0, -50, HC[i], 3)
    f.wa = box(root, 18, 12, 0, -50, 0xffffff, 2)
    hud[i] = badge.ui.label(root, "")
    hud[i]:style({text_font = 20})
    hud[i]:set_pos(i == 1 and 8 or 240, 6)
    hearts[i] = {}
    for k = 1, 3 do
      hearts[i][k] = box(root, 10, 10, (i == 1 and 10 or 260) + (k - 1) * 18, 34, 0xff3355, 5)
    end
    tag[i] = badge.ui.label(root, i == 1 and "YOU" or "AI")
    tag[i]:style({text_font = 14, text_color = 0xffffff})
    F[i] = f
  end
  W.pool = box(root, 4, 4, -10, -10, 0xd01020, 2)
  W.over = box(root, 320, 240, 0, 0, 0x000000, 0)
  W.over:style({bg_opa = 130})
  W.title = label(root, "HUMANITY'S\nLAST FIGHT", 24, "center", "top_mid", 0, 6)
  W.title:style({text_color = 0xffd23f})
  W.keys = label(root, "Left / Right\nUp\nA\nB", 16, "right", "right_mid", -170, -6)
  W.acts = label(root, "move\njump  (twice)\nattack\nblock", 16, "left", "left_mid", 168, -6)
  W.dif = label(root, "", 20, "center", "center", 0, 66)
  W.hint = label(root, "", 14, "center", "bottom_mid", 0, -8)
  W.msg = label(root, "", 24, "center", "center", 0, -64)
  W.sub = label(root, "", 16, "center", "center", 0, -14)
  theme()
  menu()
end

function on_tick()
  local now = badge.sys.ms()
  if last == 0 then last = now end
  acc = math.min(acc + now - last, STEP * 3)
  last = now
  if st == "count" then
    local n = 3 - floor((now - ct) / 1000)
    if n < 1 then n = 0 end
    if n ~= cn then cn = n; W.msg:set_text(n > 0 and tostring(n) or "FIGHT!") end
    if now - ct >= 3600 then
      st, acc = "play", 0
      W.msg:set_text("")
      tag[1]:hidden(true); tag[2]:hidden(true)
    end
  elseif st == "play" then
    while acc >= STEP do
      acc = acc - STEP
      local n = F[1].inp
      n.l, n.r = badge.input.is_down(B.LEFT), badge.input.is_down(B.RIGHT)
      n.blk, n.atk, n.up, pa, pu = badge.input.is_down(B.B), pa, pu, false, false
      ainp(F[2], F[1])
      step(F[1], F[2]); step(F[2], F[1])
    end
    draw(F[1]); draw(F[2])
  elseif st == "cut" then
    cut(now)
  elseif st == "ko" and sub then
    if typ(W.sub, sub, now - ct - 800) then sub = nil; hint(RM) end
  end
  if now >= ledt then ledt = now + 50; leds(now) end
end

function on_button(b, kind)
  if kind ~= badge.input.KIND.PRESSED then return end
  local now = badge.sys.ms()
  if st == "menu" then
    if b == B.LEFT or b == B.RIGHT then di = (di + (b == B.LEFT and 1 or 0)) % 3 + 1; theme()
    elseif b == B.A then start(now) end
  elseif st == "ko" then
    if b == B.A then start(now) elseif b == B.B or b == B.START then menu() end
  elseif st == "play" then
    if b == B.A then pa = true elseif b == B.UP then pu = true elseif b == B.START then menu() end
  elseif b == B.START then
    menu()
  end
end

function on_exit()
  badge.led.clear()
  badge.led.show()
end
