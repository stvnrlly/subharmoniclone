-- subharmoniclone
-- 0.1 // @stvnrlly
-- l.llllllll.co/subharmoniclone
-- 
-- screen 1: frequency, 
--            subdivision, and 
--            rhythms
-- screen 2: sequences
-- screen 3: routing
-- screen 4: [not implemented]
-- screen 5: [not implemented]

-- load engine
-- TODO: replace with PolySub
engine.name='PolyPerc'

-- load libraries
s = require 'sequins'
MusicUtil = require 'musicutil'
util = require 'util'
lattice = require 'lattice'
ui = require 'ui'

-- set up globals
scale_names = {}
notes = {}
playing = false

-- ui elements
pages = ui.Pages.new(1,3)
p1_loc = 1
p2_loc = 1
osc_dials = {}
r_dials = {}
s1_sliders = {}
s2_sliders = {}

function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 32)
  local num_to_add = 32 - #notes
  for i = 1, num_to_add do
    table.insert(notes, notes[32 - num_to_add])
  end
end

function play_note(freq, amp, gain, pw, release, cutoff, pan)
  engine.amp(amp)
  engine.gain(gain)
  engine.pw(pw/100)
  engine.release(release)
  engine.cutoff(cutoff)
  engine.pan(pan)
  engine.hz(freq)
end

function play(r)
  -- when a rhythm triggers, it advances the connected sequences
  -- when the sequence advances, it triggers envelopes for connected oscillators
  -- osc pitch = notes[osc note value + seq value]
  -- sub pitch = osc frequency / (sub div value + seq value)
  if playing then
    -- TODO: is this necessary?
    do return end
  end
  
  playing = true
  if params:get(r.."_s1") == 1 then
    -- collect s1 info
    if params:get("s1_length") == s1.ix then
      s1:select(1)
    end
    local p1 = s1()
    if pages.index == 2 then
      redraw()
    end
    local n1 = params:get("osc_1_note")
    -- determine note 1
    n1 = params:get("s1_o1") == 1 and notes[n1 + p1] or notes[n1]
    local f1 = MusicUtil.note_num_to_freq(n1)
    -- determine note 2
    local d1 = params:get("s1_o1s1") == 1 and params:get("o1_d1") + p1 or params:get("o1_d1")
    local f2 = f1 / d1
    -- determine note 3
    local d2 = params:get("s1_o1s2") == 1 and params:get("o1_d2") + p1 or params:get("o1_d2")
    local f3 = f1 / d2
    -- play notes
    play_note(f1, params:get("o1_amp"), params:get("o1_gain"), params:get("o1_pw"), params:get("o1_release"), params:get("o1_cutoff"), params:get("o1_pan"))
    play_note(f2, params:get("o1s1_amp"), params:get("o1s1_gain"), params:get("o1s1_pw"), params:get("o1s1_release"), params:get("o1s1_cutoff"), params:get("o1s1_pan"))
    play_note(f3, params:get("o1s2_amp"), params:get("o1s2_gain"), params:get("o1s2_pw"), params:get("o1s2_release"), params:get("o1s2_cutoff"), params:get("o1s2_pan"))
  end
  if params:get(r.."_s2") == 1 then
    -- collect s2 info
    if params:get("s2_length") == s2.ix then
      s2:reset()
    end
    redraw()
    local p2 = s2()
    local n2 = params:get("osc_2_note")
    -- determine note 1
    n2 = params:get("s2_o2") == 1 and notes[n2 + p2] or notes[n2]
    local f4 = MusicUtil.note_num_to_freq(n2)
    -- determine note 2
    local d3 = params:get("s2_o2s1") == 1 and params:get("o2_d1") + p2 or params:get("o2_d1")
    local f5 = f4 / d3
    -- determine note 3
    local d4 = params:get("s2_o2s2") == 1 and params:get("o2_d2") + p2 or params:get("o2_d2")
    local f6 = f4 / d4
    -- play notes
    play_note(f4, params:get("o2_amp"), params:get("o2_gain"), params:get("o2_pw"), params:get("o2_release"), params:get("o2_cutoff"), params:get("o2_pan"))
    play_note(f5, params:get("o2s1_amp"), params:get("o2s1_gain"), params:get("o2s1_pw"), params:get("o2s1_release"), params:get("o2s1_cutoff"), params:get("o2s1_pan"))
    play_note(f6, params:get("o2s2_amp"), params:get("o2s2_gain"), params:get("o2s2_pw"), params:get("o2s2_release"), params:get("o2s2_cutoff"), params:get("o2s2_pan"))
  end
  playing = false
end

function init()
  -- TODO: streamline menu some more
  -- TODO: add modulations params w/ lfo & s+h
  -- TODO: add a softcut delay option
  -- TODO: consistently use 0 or 1 as minimum
  -- TODO: do menu param changes need an action to update ui elements?
  params:add_separator("SUBHARMONICLONE")
  
  -- start/stop/reset params
  -- params:add{type = "trigger", id = "stop", name = "stop",
  --   action = function() clock.transport.stop() end
  -- }
  -- params:add{type = "trigger", id = "start", name = "start",
  --   action = function() clock.transport.start() end
  -- }
  -- params:add{type = "trigger", id = "reset", name = "reset",
  --   action = function() clock.transport.reset() end
  -- }
  
  -- rhythm params
  params:add_separator("rhythms")
  for i = 1,4 do
    params:add_number("rhythm_"..i, "rhythm "..i.." div", 1, 16, i, function(param) return ("1/"..param:get()) end, false)
    params:add_binary("r"..i.."_s1", "→ seq 1", "toggle")
    params:add_binary("r"..i.."_s2", "→ seq 2", "toggle")
  end
  
  -- sequence params
  -- TODO: seq values can be negative
  -- TODO: allow cross-patching sequences to oscillators
  -- TODO: consider awake approach: https://github.com/tehn/awake/blob/73d4accfc090aaab58f1586eaf4d9cf54d3cff01/awake.lua#L62-L86
    -- store seq values as params
    -- then load those values into sequins
  -- TODO: option to randomize seq
  -- TODO: options for seq direction
  -- TODO: notes can come from midi instead
  -- TODO: adapt sequence size based on number of notes in scale
  s1 = s{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  s2 = s{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  
  params:add_separator("sequence 1")
  -- TODO: seq length here
  params:add_number("s1_length", "seq 1 length", 1, 16, 8)
  -- params:set_action("s1_length", function(x) build_seq(1, s1_data, x) end)
  params:add_binary("s1_o1", "→ osc 1", "toggle")
  params:add_binary("s1_o1s1", "→ sub 1-1", "toggle")
  params:add_binary("s1_o1s2", "→ sub 1-2", "toggle")
  params:add_binary("s1_o2", "→ osc 2", "toggle")
  params:add_binary("s1_o2s1", "→ sub 2-1", "toggle")
  params:add_binary("s1_o2s2", "→ sub 2-2", "toggle")
  
  params:add_separator("sequence 2")
  -- TODO: seq length here
  params:add_number("s2_length", "seq 2 length", 1, 16, 8)
  params:add_binary("s2_o2", "→ osc 2", "toggle")
  params:add_binary("s2_o2s1", "→ sub 2-1", "toggle")
  params:add_binary("s2_o2s2", "→ sub 2-2", "toggle")
  params:add_binary("s2_o1", "→ osc 1", "toggle")
  params:add_binary("s2_o1s1", "→ sub 1-1", "toggle")
  params:add_binary("s2_o1s2", "→ sub 1-2", "toggle")
  
  -- oscillator params
  -- borrowed from https://github.com/tehn/awake/blob/master/awake.lua#L299-L322=
  cs_AMP = controlspec.new(0,1,'lin',0,0.25,'')
  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  
  -- TODO: global osc params
  params:add_separator("polyperc engine control")
  local oscs = {"o1","o1s1","o1s2","o2","o2s1","o2s2"}
  params:add_control("g_amp", "global level", cs_AMP)
  params:set_action("g_amp", function(x) for _,v in pairs(oscs) do params:set(v.."_amp",x) end end)
  params:add_control("g_gain", "global gain", cs_GAIN)
  params:set_action("g_gain", function(x) for _,v in pairs(oscs) do params:set(v.."_gain",x) end end)
  params:add_control("g_pw", "global pw", cs_PW)
  params:set_action("g_pw", function(x) for _,v in pairs(oscs) do params:set(v.."_pw",x) end end)
  params:add_control("g_release", "global release", cs_REL)
  params:set_action("g_release", function(x) for _,v in pairs(oscs) do params:set(v.."_release",x) end end)
  params:add_control("g_cutoff", "global cutoff", cs_CUT)
  params:set_action("g_cutoff", function(x) for _,v in pairs(oscs) do params:set(v.."_cutoff",x) end end)
  params:add_control("g_pan", "global pan", cs_PAN)
  params:set_action("g_pan", function(x) for _,v in pairs(oscs) do params:set(v.."_pan",x) end end)
  
  for i = 1,2 do
    params:add_separator("oscillator "..i)
    -- TODO: when length changes, should squish down to max 
    params:add{type = "number", id = "osc_"..i.."_note", name = "osc note",
      min = 1, max = 16, default = 1, formatter = function(param) return MusicUtil.note_num_to_name(notes[param:get()], true) end}
    params:add_number("o"..i.."_d1", "sub 1 div", 1, 16, 1, function(param) return ("1/"..param:get()) end, false)
    params:add_number("o"..i.."_d2", "sub 2 div", 1, 16, 1, function(param) return ("1/"..param:get()) end, false)
    params:add_control("o"..i.."_amp", "osc level", cs_AMP)
    params:add_control("o"..i.."s1_amp", "sub 1 level", cs_AMP)
    params:add_control("o"..i.."s2_amp", "sub 2 level", cs_AMP)
    params:add_control("o"..i.."_pan", "osc pan", cs_PAN)
    params:add_control("o"..i.."s1_pan", "sub 1 pan", cs_PAN)
    params:add_control("o"..i.."s2_pan", "sub 2 pan", cs_PAN)
    params:add_group("more options", 12)
    params:add_control("o"..i.."_gain", "osc gain", cs_GAIN)
    params:add_control("o"..i.."s1_gain", "sub 1 gain", cs_GAIN)
    params:add_control("o"..i.."s2_gain", "sub 2 gain", cs_GAIN)
    params:add_control("o"..i.."_pw", "osc pw", cs_PW)
    params:add_control("o"..i.."s1_pw", "sub 1 pw", cs_PW)
    params:add_control("o"..i.."s2_pw", "sub 2 pw", cs_PW)
    params:add_control("o"..i.."_release", "osc release", cs_REL)
    params:add_control("o"..i.."s1_release", "sub 1 release", CS_REL)
    params:add_control("o"..i.."s2_release", "sub 2 release", cs_REL)
    params:add_control("o"..i.."_cutoff", "osc cutoff", cs_CUT)
    params:add_control("o"..i.."s1_cutoff", "sub 1 cutoff", cs_CUT)
    params:add_control("o"..i.."s2_cutoff", "sub 2 cutoff", cs_CUT)
  end
  
  -- scale params
  -- borrowed from https://github.com/tehn/awake/blob/master/awake.lua
  params:add_separator("scale quantization")
  -- TODO: add quantize t/f param
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end
  params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 2,
    action = function() build_scale() end}
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end}

  -- do lattice stuff
  -- https://monome.org/docs/norns/reference/lib/lattice
  sub_lattice = lattice:new{
    auto = true,
    meter = 4,
    ppqn = 96
  }
  
  rhythm_1 = sub_lattice:new_pattern{
    action = function() play("r1") end,
    division = 1/params:get("rhythm_1")
  }
  params:set_action("rhythm_1",function(x) rhythm_1:set_division(1/x) end)
  
  rhythm_2 = sub_lattice:new_pattern{
    action = function() play("r2") end,
    division = 1/params:get("rhythm_2")
  }
  params:set_action("rhythm_2",function(x) rhythm_2:set_division(1/x) end)
  
  rhythm_3 = sub_lattice:new_pattern{
    action = function() play("r3") end,
    division = 1/params:get("rhythm_3")
  }
  params:set_action("rhythm_3",function(x) rhythm_3:set_division(1/x) end)
  
  rhythm_4 = sub_lattice:new_pattern{
    action = function() play("r4") end,
    division = 1/params:get("rhythm_4")
  }
  params:set_action("rhythm_4",function(x) rhythm_4:set_division(1/x) end)
  
  -- run this here in order to load notes
  params:default()
  
  -- fill in ui elements
  -- UI.Dial.new (x, y, size, value, min_value, max_value, rounding, start_value, markers, units, title)
  osc_dials[1] = ui.Dial.new(5,3,20,params:get("osc_1_note"),1,16,1,1,{1},'','freq')
  osc_dials[2] = ui.Dial.new(30,3,20,params:get("o1_d1"),1,16,1,1,{1},'','div 1')
  osc_dials[3] = ui.Dial.new(55,3,20,params:get("o1_d2"),1,16,1,1,{1},'','div 2')
  osc_dials[4] = ui.Dial.new(5,35,20,params:get("osc_2_note"),1,16,1,1,{1},'','freq')
  osc_dials[5] = ui.Dial.new(30,35,20,params:get("o2_d1"),1,16,1,1,{1},'','div 1')
  osc_dials[6] = ui.Dial.new(55,35,20,params:get("o2_d2"),1,16,1,1,{1},'','div 2')
  
  r_dials[1] = ui.Dial.new(80,3,20,params:get("rhythm_1"),1,16,1,1,{1},'','r1')
  r_dials[2] = ui.Dial.new(105,3,20,params:get("rhythm_2"),1,16,1,1,{1},'','r2')
  r_dials[3] = ui.Dial.new(80,35,20,params:get("rhythm_3"),1,16,1,1,{1},'','r3')
  r_dials[4] = ui.Dial.new(105,35,20,params:get("rhythm_4"),1,16,1,1,{1},'','r4')
  
  -- UI.Slider.new (x, y, width, height, value, min_value, max_value, markers, direction)
  for i = 1,16 do
    s1_sliders[i] = ui.Slider.new(6*i, 5, 5, 25, 0, 0, 16, {}, "up")
    s2_sliders[i] = ui.Slider.new(6*i, 38, 5, 25, 0, 0, 16, {}, "up")
  end
  
  -- UI.List.new (x, y, index, entries)
  sources = ui.List.new(0,3,1,{'r1','r2','r3','r4','s1','s2'})
  r_dests = ui.List.new(50,3,1,{'s1','s2'})
  s_dests = ui.List.new(50,3,1,{'o1','o1s1','o1s2','o2','o2s1','o2s2'})
  
  sub_lattice:start()
end


function enc(n,d)
  if n == 1 then
    -- change the page with e1
    pages:set_index_delta(d,false)
  end
  if pages.index == 1 then
    -- screen 1: notes, subdivisions, & rhythms
    if n == 2 then
      p1_loc = util.clamp(p1_loc+d,1,10)
    end
    if n == 3 then
      if p1_loc == 1 then
        local new = util.clamp(params:get("osc_1_note")+d,1,16)
        params:set("osc_1_note", new)
        osc_dials[1]:set_value(new)
      elseif p1_loc == 2 then
        local new = util.clamp(params:get("o1_d1")+d,1,16)
        params:set("o1_d1", new)
        osc_dials[2]:set_value(new)
      elseif p1_loc == 3 then
        local new = util.clamp(params:get("o1_d2")+d,1,16)
        params:set("o1_d2", new)
        osc_dials[3]:set_value(new)
      elseif p1_loc == 4 then
        local new = util.clamp(params:get("osc_2_note")+d,1,16)
        params:set("osc_2_note", new)
        osc_dials[4]:set_value(new)
      elseif p1_loc == 5 then
        local new = util.clamp(params:get("o2_d1")+d,1,16)
        params:set("o2_d1", new)
        osc_dials[5]:set_value(new)
      elseif p1_loc == 6 then
        local new = util.clamp(params:get("o2_d2")+d,1,16)
        params:set("o2_d2", new)
        osc_dials[6]:set_value(new)
      elseif p1_loc == 7 then
        local new = util.clamp(params:get("rhythm_1")+d,1,16)
        params:set("rhythm_1", new)
        r_dials[1]:set_value(new)
      elseif p1_loc == 8 then
        local new = util.clamp(params:get("rhythm_2")+d,1,16)
        params:set("rhythm_2", new)
        r_dials[2]:set_value(new)
      elseif p1_loc == 9 then
        local new = util.clamp(params:get("rhythm_3")+d,1,16)
        params:set("rhythm_3", new)
        r_dials[3]:set_value(new)
      elseif p1_loc == 10 then
        local new = util.clamp(params:get("rhythm_4")+d,1,16)
        params:set("rhythm_4", new)
        r_dials[4]:set_value(new)
      end
    end
  elseif pages.index == 2 then
    -- screen 2: sequences
    if n == 2 then
      -- move across sequence values
      p2_loc = util.clamp(p2_loc+d,1,32)
    end
    if n == 3 then
      -- change the highlighted seq value
      -- e.g. s1[location] = value
      if p2_loc <= 16 then
        s1_sliders[p2_loc]:set_value_delta(d)
        s1[p2_loc] = s1_sliders[p2_loc].value
      else
        s2_sliders[p2_loc-16]:set_value_delta(d)
        s2[p2_loc-16] = s2_sliders[p2_loc-16].value
      end
    end
  elseif pages.index == 3 then
    -- routing
    if n == 2 then
      -- change highlighted source
      -- TODO: reset dest index, too?
      sources:set_index_delta(d,false)
    end
    if n == 3 then
      -- change hightlighted destination
      if sources.index <= 4 then
        r_dests:set_index_delta(d,false)
      else
        s_dests:set_index_delta(d,false)
      end
    end
  elseif pages.index == 4 then
    -- screen 4: filter & envelopes
  else
    -- screen 5: modulation
  end
  redraw()
end

function key(n,z)
  -- TODO: key to drone (k1 + k2 on any screen)
  -- TODO: start/stop (k2 on any screen)
  
  if n == 3 and z == 1 then
    if pages.index == 3 then
      -- get source and dest
      -- toggle relevant param
      local source = sources.index
      if source <= 4 then
        local param = sources.entries[source]..'_'..r_dests.entries[r_dests.index]
        params:set(param, params:get(param) == 0 and 1 or 0)
      else
        local param = sources.entries[source]..'_'..s_dests.entries[s_dests.index]
        params:set(param, params:get(param) == 0 and 1 or 0)
      end
    end
  end  
  redraw()
end

pages:set_index(3)

function redraw()
  screen.clear()
  if pages.index == 1 then
    -- screen 1: notes, subdivisions, & rhythms
    for i = 1,6 do
      osc_dials[i].active = false
      osc_dials[i]:redraw()
    end
    for i = 1,4 do
      r_dials[i].active = false
      r_dials[i]:redraw()
    end
    if p1_loc <= 6 then
      osc_dials[p1_loc].active = true
      osc_dials[p1_loc]:redraw()
    else
      r_dials[p1_loc-6].active = true
      r_dials[p1_loc-6]:redraw()
    end
  elseif pages.index == 2 then
    screen.move(s1_sliders[s1.ix].x,s1_sliders[s1.ix].y)
    screen.text('-')
    screen.move(s2_sliders[s2.ix].x,s2_sliders[s2.ix].y)
    screen.text('-')
    if p2_loc <= 16 then
      screen.move(s1_sliders[p2_loc].x,s1_sliders[p2_loc].y)
      screen.text('~')
    else
      screen.move(s2_sliders[p2_loc-16].x,s2_sliders[p2_loc-16].y)
      screen.text('~')
    end
    for i = 1,16 do
      s1_sliders[i]:redraw()
      s2_sliders[i]:redraw()
    end
  elseif pages.index == 3 then
    -- screen 3: routing
    -- left side: rhythms & sequences
    sources:redraw()
    -- right side: destinations
    -- draw lines connecting activated routes
    if sources.index <= 4 then
      r_dests:redraw()
      for i = 1,2 do
        if params:get(sources.entries[sources.index]..'_'..r_dests.entries[i]) == 1 then
          screen.move(10,sources.index*(64/6)-5)
          screen.line(r_dests.x-2,i*(64/6)-5)
          screen.stroke()
        end
      end
    else
      s_dests:redraw()
      for i = 1,6 do
        if params:get(sources.entries[sources.index]..'_'..s_dests.entries[i]) == 1 then
          screen.move(10,sources.index*(64/6)-5)
          screen.line(s_dests.x-2,i*(64/6)-5)
          screen.stroke()
        end
      end
    end
  elseif pages.index == 4 then
    -- screen 4: filter & envelopes
  else
    -- screen 5: modulation
  end
  screen.update()
end
