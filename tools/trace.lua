-- Visual-equivalence trace harness for badge apps (desktop Lua 5.5, the badge's version; no hardware).
-- usage: lua tools/trace.lua last_fight.lua /tmp/out.trace
-- Simulates the badge API with a seeded RNG, drives menu / all difficulties / idle losses / an aggressive
-- player / rematches, and records every per-tick widget state change and LED frame. Run it before and
-- after a change and `cmp` the two traces: identical traces mean the game looks identical.
local app, outp = arg[1], arg[2]
local out, nw, pend, W = {}, 0, {}, {}
local ms, walk, holdB = 0, false, false
local function ser(v)
  if type(v) == "table" then local ks = {} for k in pairs(v) do ks[#ks+1] = k end table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    local p = {} for _, k in ipairs(ks) do p[#p+1] = tostring(k) .. "=" .. ser(v[k]) end return "{" .. table.concat(p, ",") .. "}" end
  if type(v) == "number" then if v ~= math.floor(v) then error("non-integer " .. v .. " at ms " .. ms) end return string.format("%d", v) end
  return tostring(v)
end
local function setp(w, prop, val)
  if w.st[prop] ~= val then w.st[prop] = val; pend[w.id .. " " .. prop] = val end
end
local function widget(kind, root, a, b)
  nw = nw + 1
  local w = {kind = kind, id = nw, st = {}}
  W[nw] = w
  setp(w, "kind", kind)
  if kind == "label" then setp(w, "text", a) else setp(w, "size", ser({a, b})) end
  return setmetatable(w, {__index = function(_, k) return function(self, ...)
    local args = {...}
    if k == "set_pos" then setp(self, "pos", ser(args))
    elseif k == "set_size" then setp(self, "size", ser(args))
    elseif k == "set_text" then setp(self, "text", args[1])
    elseif k == "hidden" then setp(self, "hidden", tostring(args[1]))
    elseif k == "set_color" then setp(self, self.kind == "label" and "s.text_color" or "s.bg_color", ser(args[1]))
    elseif k == "set_border" then setp(self, "s.border_color", ser(args[1])); setp(self, "s.border_width", ser(args[2]))
    elseif k == "style" then for kk, vv in pairs(args[1]) do setp(self, "s." .. kk, ser(vv)) end
      if args[1].bg_color and not args[1].bg_opa and self.st["s.bg_opa"] == nil then setp(self, "s.bg_opa", "255") end
    elseif k == "align" then setp(self, "align", ser(args))
    else setp(self, k, ser(args)) end
    return self end end})
end
local led = {}
badge = {
  input = {BUTTON = {LEFT = 1, RIGHT = 2, UP = 3, DOWN = 4, A = 5, B = 6, START = 7}, KIND = {PRESSED = 1},
    is_down = function(b)
      if b == 6 then return holdB end
      if not walk then return false end
      local px, ax
      for _, w in ipairs(W) do
        if w.kind == "box" and w.st.size == "{1=14,2=22}" and w.st.pos then
          local x = tonumber(w.st.pos:match("{1=(%-?%d+)"))
          if w.st["s.bg_color"] == "16765503" or w.st["s.bg_color"] == "10124832" then px = x elseif w.st["s.bg_color"] == "16732013" or w.st["s.bg_color"] == "10039359" then ax = x end
        end
      end
      if not px or not ax or px < -40 then return false end
      if b == 2 then return px < ax - 22 and px < 250 end
      if b == 1 then return px > ax + 22 and px > 70 end
      return false
    end},
  sys = {stats = function() return {lua_used = 0, lua_peak = 0, free_heap = 0} end, log = function() end,
    ms = function() return ms end, random = function(n) return math.random(0, n - 1) end},
  led = {clear = function() for i = 1, 6 do led[i] = "0,0,0" end end, show = function() pend["LED"] = table.concat(led, " ") end,
    set = function(i, r, g, b) led[i] = ser(r) .. "," .. ser(g) .. "," .. ser(b) end,
    set_all = function(r, g, b) for i = 1, 6 do led[i] = ser(r) .. "," .. ser(g) .. "," .. ser(b) end end},
  ui = {label = function(r, t) return widget("label", r, t) end, box = function(r, w, h) return widget("box", r, w, h) end},
}
local seen = {}
local function flush(tag)
  local ks = {} for k in pairs(pend) do ks[#ks+1] = k end table.sort(ks)
  for _, k in ipairs(ks) do out[#out+1] = string.format("%6d %s %s = %s", ms, tag or "", k, pend[k]) end
  for _, w in ipairs(W) do if w.st.text and w.st.text ~= "" then seen[(w.st.text:gsub("\n", "/"))] = true end end
  pend = {}
end
local chunk = assert(loadfile(app))
math.randomseed(7)
chunk()
on_enter({})
flush("enter")
local function tick(n) for _ = 1, n do ms = ms + 20; on_tick(); flush() end end
local function press(b) on_button(badge.input.BUTTON[b], 1); flush("btn:" .. b) end
-- scenario 1: cycle difficulties both ways
press("RIGHT"); tick(3); press("RIGHT"); tick(3); press("LEFT"); tick(3); press("LEFT"); tick(3)
-- scenario 2: each difficulty, player idles until the AI wins (ko or cutscene), then rematch once, then menu
for d = 1, 3 do
  press("A"); tick(40 * 60)      -- 60 s: enough for count + fight + cutscene/typewriter
  press("A"); tick(400)          -- rematch, 8 s
  press("START"); tick(5)        -- back to menu mid-fight
  press("RIGHT"); tick(2)        -- advance difficulty (RIGHT = di+1)
end
-- scenario 3: aggressive player on each difficulty: walk right, spam A, occasional UP, some blocking
for d = 1, 3 do
  press("A"); tick(190)
  walk = true
  for i = 1, 3500 do
    if i % 9 == 0 then press("A") end
    if i % 61 == 0 then press("UP") end
    if i % 97 == 0 then press("UP"); tick(1); press("UP") end
    holdB = (i % 40) < 6
    tick(1)
  end
  walk, holdB = false, false
  tick(600)                       -- let any cutscene / end text finish
  press("B"); tick(3)             -- menu from ko (or nothing)
  press("START"); tick(3)
  press("RIGHT"); tick(2)
end
on_exit(); flush("exit")
local f = assert(io.open(outp, "w")); f:write(table.concat(out, "\n"), "\n"); f:close()
local ks = {} for k in pairs(seen) do ks[#ks+1] = k end table.sort(ks)
print(#out .. " state changes, widgets=" .. nw .. "\ntexts seen:\n  " .. table.concat(ks, "\n  "))
