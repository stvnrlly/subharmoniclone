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
-- TODO: add waveform mix controls
-- TODO: add pulsewidth for square wave
-- TODO: add batch command (like all_) for osc groups
engine.name='Moogshine'
moogshine_setup = include 'lib/moogshine'

-- ___ engine commands ___
-- amp	 	sf
-- amp_slew	 	sf
-- attack	 	sf
-- cutoff	 	sf
-- cutoff_env	 	sf
-- free_all_notes	 	
-- freq	 	sf
-- freq_slew	 	sf
-- noise_amp	 	sf
-- noise_slew	 	sf
-- pan	 	sf
-- pan_slew	 	sf
-- release	 	sf
-- resonance	 	sf
-- sub_div	 	sf
-- trig	 	sf

-- load libraries
s = require 'sequins'
MusicUtil = require 'musicutil'
util = require 'util'
lattice = require 'lattice'
UI = require 'ui'

-- set up globals
scale_names = {}
notes = {}
alt = 0
alt_1 = 0
alt_2 = 0
local g = grid.connect()
local g_page_1 = 1
local g_page_2 = 1

-- ui elements
screen.aa(1)
pages = UI.Pages.new(1,3)
p1_loc = 1
p2_loc = 1
osc_dials = {}
r_dials = {}
s1_sliders = {}
s2_sliders = {}

------------
-- 
-- UTILITIES
-- 
-- 

function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 32)
  local num_to_add = 32 - #notes
  for i = 1, num_to_add do
    table.insert(notes, notes[32 - num_to_add])
  end
end

function shrink(str)
  local out = ''
  for w in str:gmatch("([^%s]+)") do 
    out = out .. string.sub(w,1,1)
  end
  return out
end

function amp2grid(i)
  return util.round(util.linlin(0,2,1,16,i),1)
end

function grid2amp(i)
  return util.linlin(1,16,0,2,i)
end

--------------------- 
-- 
-- ENGINE INTERACTION
-- 
-- 

function play(r)
  -- when a rhythm triggers, it advances the connected sequences
  -- when the sequence advances, it triggers envelopes for connected oscillators
  -- osc pitch = notes[osc note value + seq value]
  -- sub pitch = osc frequency / (sub div value + seq value)
  grid_redraw()
  if params:get(r.."_s1") == 1 then
    -- collect s1 info
    if params:get("s1_dir") == 1 then
      if params:get("s1_length") == s1.ix then
        s1:select(1)
        m1:select(1)
      end
    elseif params:get("s1_dir") == 2 then
      if s1.ix == 1 then
        s1:select(params:get("s1_length"))
        m1:select(params:get("s1_length"))
      end
    end
    local p1 = s1()
    local pp1 = m1()
    if pages.index == 2 then
      redraw()
    end
    local n1 = params:get("o1_mod")
    -- determine note 1
    n1 = params:get("s1_o1") == 1 and notes[n1 + p1] or notes[n1]
    local f1 = MusicUtil.note_num_to_freq(n1)
    -- determine note 2
    local d2 = params:get("s1_o2") == 1 and params:get("o2_mod") + p1 or params:get("o2_mod")
    local f2 = f1 / d2
    -- determine note 3
    local d3 = params:get("s1_o3") == 1 and params:get("o3_mod") + p1 or params:get("o3_mod")
    local f3 = f1 / d3
    -- play notes
    if pp1 == 0 then
      engine.trig(1,f1)
      engine.trig(2,f2)
      engine.trig(3,f3)
    end
  end
  if params:get(r.."_s2") == 1 then
    -- collect s2 info
    if params:get("s2_length") == s2.ix then
      s2:select(1)
      m2:select(1)
    end
    local p2 = s2()
    local pp2 = m2()
    if pages.index == 2 then
      redraw()
    end
    local n2 = params:get("o4_mod")
    -- determine note 1
    n2 = params:get("s2_o4") == 1 and notes[n2 + p2] or notes[n2]
    local f4 = MusicUtil.note_num_to_freq(n2)
    -- determine note 2
    local d5 = params:get("s2_o5") == 1 and params:get("o5_mod") + p2 or params:get("o5_mod")
    local f5 = f4 / d5
    -- determine note 3
    local d6 = params:get("s2_o6") == 1 and params:get("o6_mod") + p2 or params:get("o6_mod")
    local f6 = f4 / d6
    -- play notes
    if pp2 == 0 then
      engine.trig(4,f4)
      engine.trig(5,f5)
      engine.trig(6,f6)
    end
  end
end

---------- 
-- 
-- SOFTCUT
-- 
-- 

-- softcut code borrowed from https://github.com/ambalek/fall/ 
local function softcut_delay(ch, time, feedback, rate, level)
  softcut.level(ch, level)
  softcut.level_slew_time(ch, 0)
  softcut.level_input_cut(ch, 1, 1.0)
  softcut.level_input_cut(ch, 2, 1.0)
  softcut.pan(ch, 0.0)
  softcut.play(ch, 1)
  softcut.rate(ch, rate)
  softcut.rate_slew_time(ch, 0)
  softcut.loop_start(ch, 0)
  softcut.loop_end(ch, time)
  softcut.loop(ch, 1)
  softcut.fade_time(ch, 0.1)
  softcut.rec(ch, 1)
  softcut.rec_level(ch, 1)
  softcut.pre_level(ch, feedback)
  softcut.position(ch, 0)
  softcut.enable(ch, 1)
  softcut.pre_filter_dry(ch, 0)
  softcut.pre_filter_hp(ch, 1.0)
  softcut.pre_filter_fc(ch, 300)
  softcut.pre_filter_rq(ch, 4.0)
end

local function apply_delays()
  -- TODO: stereo delay with panning
  -- TODO: softcut filtering
  softcut_delay(1,
    params:get("long_delay_time"), params:get("long_delay_feedback"), 1.0, params:get("long_delay_level")
  )
  softcut_delay(2,
    params:get("short_delay_time"), params:get("short_delay_feedback"), 1.0, params:get("short_delay_level")
  )
end

local function softcut_setup()
  softcut.reset()
  for i = 1, 2 do
    softcut.position(i, 0)
    softcut.rate(0, 1)
  end
  softcut.buffer_clear()
  audio.level_cut(1.0)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  apply_delays()
end

------------------- 
-- 
-- LFO & MODULATION
-- 
-- 

lfo = include("lib/hnds")

local lfo_types = {"sine", "square", "s+h"}
local show_lfo_info = {false, false, false, false}
local lfo_index = nil

local lfo_targets = {
  "none",
  "o1_mod", "o2_mod", "o3_mod", "o4_mod", "o5_mod", "o6_mod",
  "rhythm_1", "rhythm_2", "rhythm_3", "rhythm_4", 
  "all_amp", "all_cutoff", "all_attack", "all_release", "all_pan", "all_noise_amp",
  "s1_length", "s2_length",
  "short_delay_time", "short_delay_level", "short_delay_feedback", 
  "long_delay_time", "long_delay_level", "long_delay_feedback", 
  -- more added via loop below
}

for i = 1,6 do
  table.insert(lfo_targets, i.."_amp")
  table.insert(lfo_targets, i.."_cutoff")
  table.insert(lfo_targets, i.."_attack")
  table.insert(lfo_targets, i.."_release")
  table.insert(lfo_targets, i.."_pan")
  table.insert(lfo_targets, i.."_noise_amp")
end

function lfo.process()
  for i = 1, 4 do
    local target = lfo_targets[params:get(i .. "lfo_target")]
    
    -- TODO: can scale be util linlin instead?
    if params:get(i .. "lfo") == 2 then
      if string.find(target,"o%d_") ~= nil or string.find(target, "rhythm_") ~= nil or string.find(target, "%d_length") ~= nil then
        params:set(target, math.floor(lfo.scale(lfo[i].slope, -1, 1, 1, 16))) 
      elseif string.find(target, "%d_amp") ~= nil or target == "all_amp" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 2.0)
      elseif string.find(target, "_cutoff") ~= nil then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 24000.0)
      elseif string.find(target, "_attack") ~= nil or string.find(target, "_release") ~= nil then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 10.0)
      elseif string.find(target, "_pan") ~= nil then
        params:set(target, lfo[i].slope)
      elseif string.find(target, "_noise_amp") ~= nil then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 2.0)
      elseif target == "short_delay_time" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 1.0, 5.0)
      elseif target == "short_delay_level" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 1.0)
      elseif target == "short_delay_feedback" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 1.0)
      elseif target == "long_delay_time" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 1.0, 50.0)
      elseif target == "long_delay_level" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 1.0)
      elseif target == "long_delay_feedback" then
        params:set(target, lfo.scale(lfo[i].slope), -1, 1, 0.0, 1.0)
      end
      redraw()
      grid_redraw()
    end
  end
end

---------------
-- 
-- SETUP & INIT
-- 
-- 

function init()
  -- TODO: add modulations params w/ lfo & s+h
  -- TODO: consistently use 0 or 1 as minimum
  -- TODO: put sequences into tables for better iteration
  -- TODO: logic options for rhythms
  params:add_separator("SUBHARMONICLONE")
  
  -- TODO: implement start/stop stuff w/ key combo
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
  -- TODO: save these for PSET callback: https://monome.org/docs/norns/reference/params#pset-saveload-callback
  -- TODO: seq values can be negative, 
  -- TODO: allow cross-patching sequences to oscillators
  -- TODO: notes can come from midi instead
  -- TODO: adapt sequence size based on number of notes in scale
  -- TODO: allow accenting
  s1 = s{8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8}
  s2 = s{1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4}
  -- TODO: better visual indicator of muting
  m1 = s{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  m2 = s{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  
  params:add_separator("sequence 1")
  params:add_number("s1_length", "seq 1 length", 1, 16, 8)
  params:add_option("s1_dir","seq 1 direction", {"forward","backward"}, 1)
  params:set_action("s1_dir",function(x) if x == 1 then s1:step(1) m1:step(1) elseif x == 2 then s1:step(-1) m1:step(-1) end end)
  params:add_binary("s1_o1", "→ osc 1", "toggle")
  params:add_binary("s1_o2", "→ sub 1-1", "toggle")
  params:add_binary("s1_o3", "→ sub 1-2", "toggle")
  
  params:add_separator("sequence 2")
  params:add_number("s2_length", "seq 2 length", 1, 16, 8)
  params:add_option("s2_dir","seq 2 direction", {"forward","backward"}, 1)
  params:set_action("s2_dir",function(x) if x == 1 then s2:step(1) m2:step(1) elseif x == 2 then s2:step(-1) m2:step(-1) end end)
  params:add_binary("s2_o4", "→ osc 2", "toggle")
  params:add_binary("s2_o5", "→ sub 2-1", "toggle")
  params:add_binary("s2_o6", "→ sub 2-2", "toggle")
  
  params:add_separator("notes & divisions")
  for i = 1,6 do
    -- TODO: when scale length changes, should squish notes down to max
    if (i == 1 or i == 4) then
      params:add{type = "number", id = "o"..i.."_mod", name = "osc note",
        min = 1, max = 16, default = 1, formatter = function(param) return MusicUtil.note_num_to_name(notes[param:get()], true) end}
    end
    if (i == 2 or i == 5) then
      params:add_number("o"..i.."_mod", "sub 1 div", 1, 16, 1, function(param) return ("1/"..param:get()) end, false)
    elseif (i ==3 or i == 6) then
      params:add_number("o"..i.."_mod", "sub 2 div", 1, 16, 1, function(param) return ("1/"..param:get()) end, false)
    end
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
  
  params:add_separator("time and delays")
  params:add_taper("short_delay_time", "short delay", 1, 5, 1, 0.01, "sec")
  params:set_action("short_delay_time", function(value) softcut.loop_end(2, value) end)
  params:add_taper("short_delay_level", "short delay gain", 0, 1, 0, 0.01, "")
  params:set_action("short_delay_level", function(value) softcut.level(2, value) end)
  params:add_taper("short_delay_feedback", "short delay feedback", 0, 1, 0.5, 0.01)
  params:set_action("short_delay_feedback", function()
    apply_delays()
  end)
  params:add_taper("long_delay_time", "long delay", 1, 50, 10, 0.1, "sec")
  params:set_action("long_delay_time", function(value) softcut.loop_end(1, value) end)
  params:add_taper("long_delay_level", "long delay gain", 0, 1, 0, 0.01, "")
  params:set_action("long_delay_level", function(value) softcut.level(1, value) end)
  params:add_taper("long_delay_feedback", "long delay feedback", 0, 1, 0.5, 0.01)
  params:set_action("long_delay_feedback", function()
    apply_delays()
  end)
  
  -- for lib/hnds
  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  lfo.init()

  -- do lattice stuff
  -- https://monome.org/docs/norns/reference/lib/lattice
  sub_lattice = lattice:new{
    auto = true,
    meter = 4,
    ppqn = 96
  }
  
  rhythm_1 = sub_lattice:new_pattern{
    action = function() play("r1") end,
    division = params:get("rhythm_1")
  }
  params:set_action("rhythm_1",function(x) rhythm_1:set_division(x) end)
  
  rhythm_2 = sub_lattice:new_pattern{
    action = function() play("r2") end,
    division = params:get("rhythm_2")
  }
  params:set_action("rhythm_2",function(x) rhythm_2:set_division(x) end)
  
  rhythm_3 = sub_lattice:new_pattern{
    action = function() play("r3") end,
    division = params:get("rhythm_3")
  }
  params:set_action("rhythm_3",function(x) rhythm_3:set_division(x) end)
  
  rhythm_4 = sub_lattice:new_pattern{
    action = function() play("r4") end,
    division = params:get("rhythm_4")
  }
  params:set_action("rhythm_4",function(x) rhythm_4:set_division(x) end)
  
  -- load the engine params
  moogshine_setup.add_params()
  
  -- engine preferences
  params:set('all_amp',0.2)
  params:set('all_release',1.5)
  params:set('all_cutoff_env',0)
  -- run this here in order to load notes for the selected scale
  -- TODO: maybe this is better as a param action?
  params:default()
  
  -- fill in ui elements
  -- UI.Dial.new (x, y, size, value, min_value, max_value, rounding, start_value, markers, units, title)
  osc_dials[1] = UI.Dial.new(5,3,20,params:get("o1_mod"),1,16,1,1,{1},'','')
  osc_dials[2] = UI.Dial.new(30,3,20,params:get("o2_mod"),1,16,1,1,{1},'','')
  osc_dials[3] = UI.Dial.new(55,3,20,params:get("o3_mod"),1,16,1,1,{1},'','')
  osc_dials[4] = UI.Dial.new(5,35,20,params:get("o4_mod"),1,16,1,1,{1},'','')
  osc_dials[5] = UI.Dial.new(30,35,20,params:get("o5_mod"),1,16,1,1,{1},'','')
  osc_dials[6] = UI.Dial.new(55,35,20,params:get("o6_mod"),1,16,1,1,{1},'','')
  
  r_dials[1] = UI.Dial.new(80,3,20,params:get("rhythm_1"),1,16,1,1,{1},'','')
  r_dials[2] = UI.Dial.new(105,3,20,params:get("rhythm_2"),1,16,1,1,{1},'','')
  r_dials[3] = UI.Dial.new(80,35,20,params:get("rhythm_3"),1,16,1,1,{1},'','')
  r_dials[4] = UI.Dial.new(105,35,20,params:get("rhythm_4"),1,16,1,1,{1},'','')
  
  -- UI.Slider.new (x, y, width, height, value, min_value, max_value, markers, direction)
  for i = 1,16 do
    s1_sliders[i] = UI.Slider.new(6*i, 5, 5, 25, s1[i], 0, 16, {}, "up")
    s2_sliders[i] = UI.Slider.new(6*i, 38, 5, 25, s2[i], 0, 16, {}, "up")
  end
  
  -- UI.List.new (x, y, index, entries)
  sources = UI.List.new(0,3,1,{'rhythm 1','rhythm 2','rhythm 3','rhythm 4','sequence 1','sequence 2'})
  r_dests = UI.List.new(75,3,1,{'sequence 1','sequence 2'})
  s1_dests = UI.List.new(75,3,1,{'osc 1','osc 2','osc 3'})
  s2_dests = UI.List.new(75,3,1,{'osc 4','osc 5','osc 6'})
  
  sub_lattice:start()
end

----------- 
-- 
-- ENCODERS
-- 
-- 

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
      if p1_loc <= 6 then
        -- oscillator mods
        local new = util.clamp(params:get("o"..p1_loc.."_mod")+d,1,16)
        params:set("o"..p1_loc.."_mod", new)
        osc_dials[p1_loc]:set_value(new)
      else
        -- rhythm mods
        local new = util.clamp(params:get("rhythm_"..p1_loc-6)+d,1,16)
        params:set("rhythm_"..p1_loc-6, new)
        r_dials[p1_loc-6]:set_value(new)
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
        if alt == 1 then
          for i=1,16 do
            if d > 0 then 
              s1_sliders[i]:set_value_delta(math.random(0,d))
            else
              s1_sliders[i]:set_value_delta(math.random(d,0))
            end
            s1[i] = s1_sliders[i].value
          end
        else
          s1_sliders[p2_loc]:set_value_delta(d)
          s1[p2_loc] = s1_sliders[p2_loc].value
        end
      else
        if alt == 1 then
          for i=1,16 do
            if d > 0 then 
              s2_sliders[i]:set_value_delta(math.random(0,d))
            else
              s2_sliders[i]:set_value_delta(math.random(d,0))
            end
            s2[i] = s2_sliders[i].value
          end
        else
          s2_sliders[p2_loc-16]:set_value_delta(d)
          s2[p2_loc-16] = s2_sliders[p2_loc-16].value
        end
      end
    end
  elseif pages.index == 3 then
    -- routing
    if n == 2 then
      -- change highlighted source
      sources:set_index_delta(d,false)
    end
    if n == 3 then
      -- change hightlighted destination
      if sources.index <= 4 then
        r_dests:set_index_delta(d,false)
      elseif sources.index == 5 then
        s1_dests:set_index_delta(d,false)
      else
        s2_dests:set_index_delta(d,false)
      end
    end
  elseif pages.index == 4 then
    -- screen 4: global filter & envelopes
  else
    -- screen 5: modulation
  end
  redraw()
end

------- 
-- 
-- KEYS
-- 
-- 

function key(n,z)
  -- TODO: start/stop (k2 on any screen)
  if n == 1 then
    if z == 1 then
      alt = 1
    else
      alt = 0
    end
  end
  
  if n == 2 and z == 1 then
    if alt == 1 then
    -- TODO: key to drone (k1 + k2 on any screen)
    end
    if pages.index == 2 then
      if p2_loc <= 16 then
        m1[p2_loc] = m1[p2_loc] == 0 and 1 or 0
      else
        m2[p2_loc-16] = m2[p2_loc-16] == 0 and 1 or 0
      end
    end
  end
  
  if n == 3 and z == 1 then
    if pages.index == 3 then
      -- get source and dest
      -- toggle relevant param
      local src = shrink(sources.entries[sources.index])
      if sources.index <= 4 then
        local param = src..'_'..shrink(r_dests.entries[r_dests.index])
        params:set(param, params:get(param) == 0 and 1 or 0)
      elseif sources.index == 5 then
        local param = src..'_'..shrink(s1_dests.entries[s1_dests.index])
        params:set(param, params:get(param) == 0 and 1 or 0)
      else
        local param = src..'_'..shrink(s2_dests.entries[s2_dests.index])
        params:set(param, params:get(param) == 0 and 1 or 0)
      end
    end
  end  
  redraw()
end

---------- 
-- 
-- DISPLAY
-- 
-- 

function redraw()
  screen.clear()
  pages:redraw()
  if pages.index == 1 then
    -- screen 1: notes, subdivisions, & rhythms
    -- TODO: switch from dials to a table for more compact view
    for i = 1,6 do
      if i == p1_loc then
        osc_dials[i].active = true
      else
        osc_dials[i].active = false
      end
      osc_dials[i]:redraw()
      if (i == 1 or i == 4) then
        screen.move(osc_dials[i].x+10,osc_dials[i].y+26)
        screen.text_center(MusicUtil.note_num_to_name(notes[params:get('o'..i..'_mod')]))
        screen.fill()
      else
        screen.move(osc_dials[i].x+10,osc_dials[i].y+26)
        screen.text_center(params:get('o'..i..'_mod')..'/16')
        screen.fill()
      end
    end
    for i = 1,4 do
      if i == (p1_loc-6) then
        r_dials[i].active = true
      else
        r_dials[i].active = false
      end
      r_dials[i]:redraw()
      screen.move(r_dials[i].x+10,r_dials[i].y+26)
      screen.text_center(params:get('rhythm_'..i)..'/16')
      screen.fill()
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
      if m1[i] == 1 then
        screen.move(i*6,29)
        screen.level(4)
        screen.text('m')
      end
      if m2[i] == 1 then
        screen.move(i*6,62)
        screen.level(4)
        screen.text('m')
      end
    end
  elseif pages.index == 3 then
    -- screen 3: routing
    -- left side: rhythms & sequences
    sources:redraw()
    -- right side: destinations
    -- draw lines connecting activated routes
    local src = shrink(sources.entries[sources.index])
    if sources.index <= 4 then
      r_dests:redraw()
      for i = 1,2 do
        if params:get(src..'_'..shrink(r_dests.entries[i])) == 1 then
          screen.move(40,sources.index*(64/6)-5)
          screen.line(r_dests.x-2,i*(64/6)-5)
          screen.stroke()
        end
      end
    elseif sources.index == 5 then
      s1_dests:redraw()
      for i = 1,3 do
        if params:get(src..'_'..shrink(s1_dests.entries[i])) == 1 then
          screen.move(50,sources.index*(64/6)-5)
          screen.line(s1_dests.x-2,i*(64/6)-5)
          screen.stroke()
        end
      end
    else
      s2_dests:redraw()
      for i = 1,3 do
        if params:get(src..'_'..shrink(s2_dests.entries[i])) == 1 then
          screen.move(50,sources.index*(64/6)-5)
          screen.line(s2_dests.x-2,i*(64/6)-5)
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
  grid_redraw()
end

------- 
-- 
-- GRID
-- 
-- 

local held_1 = {}
local held_2 = {}

routing_1 = {{"o1","o2","o3"},{},{"s1","s2"},{},{"r1","r2"},{"r3","r4"}}
routing_2 = {{"o4","o5","o6"},{},{"s1","s2"},{},{"r1","r2"},{"r3","r4"}}

function grid_redraw()
  -- TODO: lightly blink page 1 leds when note plays, maybe by row?
  -- TODO: blink playing page 2 seq value
  -- TODO: a way to switch into rhythm editing mode
  -- TODO: alt key for more sequence options (once implemented)
  -- TODO: mute gesture for page 2 seq
  -- TODO: a way to show all 16 seq values without clamping?
  
  g:all(0)
  
  -- page options for each group
  for i = 1,3 do
    g:led(i,4,4)
    g:led(i,8,4)
  end
  
  -- show selected page
  g:led(g_page_1,4,15)
  g:led(g_page_2,8,15)
  
  if alt_1 == 0 then
    g:led(16,4,4)
  else
    g:led(16,4,15)
  end
  
  if alt_2 == 0 then
    g:led(16,8,4)
  else
    g:led(16,8,15)
  end
  
  if g_page_1 == 1 then
    for i = 1,3 do
      if alt_1 == 0 then
        g:led(params:get('o'..i..'_mod'),i,15)
      else
        g:led(amp2grid(params:get(i..'_amp')),i,15)
      end
    end
  end
  
  if g_page_2 == 1 then
    for i = 4,6 do
      if alt_2 == 0 then
        g:led(params:get('o'..i..'_mod'),i+1,15)
      else
        g:led(amp2grid(params:get(i..'_amp')),i+1,15)
      end
    end
  end
  
  if g_page_1 == 2 then
    for i = 1,16 do
      g:led(i,1,util.clamp(s1[i],0,15))
      g:led(i,2,util.clamp(15-s1[i],0,15))
    end
    g:led(s1.ix,3,15)
    if alt_1 == 1 then
      for i = 1,3 do
        g:led(params:get("s1_length"),i,15)
      end
    end
    g:led(13,4,params:get("s1_dir") == 2 and 15 or 4)
    g:led(14,4,params:get("s1_dir") == 1 and 15 or 4)
  end
    
  if g_page_2 == 2 then
    for i = 1,16 do
      g:led(i,5,util.clamp(s2[i],0,15))
      g:led(i,6,util.clamp(15-s2[i],0,15))
    end
    g:led(s2.ix,7,15)
    if alt_2 == 1 then
      for i = 5,7 do
        g:led(params:get("s2_length"),i,15)
      end
    end
    g:led(13,8,params:get("s2_dir") == 2 and 15 or 4)
    g:led(14,8,params:get("s2_dir") == 1 and 15 or 4)
  end
  
  if g_page_1 == 3 then
    if held_1[1] == nil then
      for x = 1,6 do
        for y = 1,3 do
          if routing_1[x] ~= nil then
            if routing_1[x][y] ~= nil then
              g:led(x,y,4)
            end
          end
        end
      end
    else
      local h1 = routing_1[held_1[1]][held_1[2]]
      local h1s = string.sub(h1,1,1)
      g:led(held_1[1],held_1[2],15)
      if h1s == "o" then
        g:led(3,1,params:get('s1_'..h1) == 0 and 4 or 15)
        g:led(3,2,4)
      elseif h1s == "r" then
        for i = 1,2 do
          g:led(3,i,params:get(h1..'_'..'s'..i) == 0 and 4 or 15)
        end
      elseif string.sub(h1,1,1) == "s" then
        if h1 == "s1" then
          for i = 1,3 do
            g:led(1,i,params:get(h1..'_o'..i) == 0 and 4 or 15)
          end
        end
        for i = 1,2 do
          g:led(5,i,params:get('r'..i..'_'..h1) == 0 and 4 or 15)
        end
        for i = 3,4 do
          g:led(6,(i-2),params:get('r'..i..'_'..h1) == 0 and 4 or 15)
        end
      end
    end
  end
  
  if g_page_2 == 3 then
    if held_2[1] == nil then
      for x = 1,6 do
        for y = 5,7 do
          if routing_2[x] ~= nil then
            if routing_2[x][y-4] ~= nil then
              g:led(x,y,4)
            end
          end
        end
      end
    else
      local h2 = routing_2[held_2[1]][held_2[2]-4]
      local h2s = string.sub(h2,1,1)
      g:led(held_2[1],held_2[2],15)
      if h2s == "o" then
        g:led(3,5,4)
        g:led(3,6,params:get('s2_'..h2) == 0 and 4 or 15)
      elseif h2s == "r" then
        for i = 1,2 do
          g:led(3,i+4,params:get(h2..'_'..'s'..i) == 0 and 4 or 15)
        end
      elseif string.sub(h2,1,1) == "s" then
        if h2 == "s2" then
          for i = 4,6 do
            g:led(1,i+1,params:get(h2..'_o'..i) == 0 and 4 or 15)
          end
        end
        for i = 1,2 do
          g:led(5,i+4,params:get('r'..i..'_'..h2) == 0 and 4 or 15)
        end
        for i = 3,4 do
          g:led(6,(i+2),params:get('r'..i..'_'..h2) == 0 and 4 or 15)
        end
      end
    end
  end
  
  g:refresh()
end

g.key = function(x,y,z)
  
  if z == 1 then
  -- button down
    if x < 4 and y == 4 then g_page_1 = x end
    if x < 4 and y == 8 then g_page_2 = x end
    
    if g_page_1 == 1 then
      if y < 4 then
        if alt_1 == 0 then
          params:set('o'..y..'_mod',x)
        else
          params:set(y..'_amp',grid2amp(x))
        end
      end
    end
    
    if g_page_2 == 1 then
      if y > 4 and y < 8 then
        if alt_2 == 0 then
          params:set('o'..(y-1)..'_mod',x)
        else
          params:set((y-1)..'_amp',grid2amp(x))
        end
      end
    end
    
    if g_page_1 == 2 then
      if y == 1 then
        if alt_1 == 1 then
          for i = 1,16 do
            s1[i] = util.clamp(s1[i] + math.random(0,1),0,16)
            s1_sliders[i]:set_value(s1[i])
          end
        else
          s1[x] = util.clamp(s1[x] + 1,0,16)
        end
      end
      if y == 2 then
        if alt_1 == 1 then
          for i = 1,16 do
            s1[i] = util.clamp(s1[i] - math.random(0,1),0,16)
            s1_sliders[i]:set_value(s1[i])
          end
        else
          s1[x] = util.clamp(s1[x] - 1,0,16)
          s1_sliders[x]:set_value(s1[x])
        end
      end
      if y == 3 then
        if alt_1 == 1 then
          params:set("s1_length",x)
        end
      end
      if x == 13 and y == 4 then
        params:set("s1_dir",2)
      elseif x == 14 and y == 4 then
        params:set("s1_dir",1)
      end
    end
    
    if g_page_2 == 2 then
      if y == 5 then
        if alt_2 == 1 then
          for i = 1,16 do
            s2[i] = util.clamp(s2[i] + math.random(0,1),0,16)
            s2_sliders[i]:set_value(s2[i])
          end
        else
          s2[x] = util.clamp(s2[x] + 1,0,16)
          s2_sliders[x]:set_value(s2[x])
        end
      end
      if y == 6 then
        if alt_2 == 1 then
          for i = 1,16 do
            s2[i] = util.clamp(s2[i] - math.random(0,1),0,16)
            s2_sliders[i]:set_value(s2[i])
          end
        else
          s2[x] = util.clamp(s2[x] - 1,0,16)
          s2_sliders[x]:set_value(s2[x])
        end
      end
      if y == 7 then
        if alt_2 == 1 then
          params:set("s2_length",x)
        end
      end
      if x == 13 and y == 8 then
        params:set("s2_dir",2)
      elseif x == 14 and y == 8 then
        params:set("s2_dir",1)
      end
    end
    
    if g_page_1 == 3 then
      if y < 4 then
        if held_1[1] == nil then
          -- only start connecting if option is valid
          if routing_1[x] ~= nil then
            if routing_1[x][y] ~= nil then
              held_1 = {x,y}
            end
          end
        else
          local c1 = routing_1[held_1[1]][held_1[2]]
          local c2 = routing_1[x][y]
          local param = ""
          
          if held_1[1] < x then
            param = c2.."_"..c1
          else
            param = c1.."_"..c2
          end
          
          if params.lookup[param] ~= nil then
            params:set(param, params:get(param) == 0 and 1 or 0)
          end
        end
      end
    end
    
    if g_page_2 == 3 then
      if y > 4 and y < 8 then
        if held_2[1] == nil then
          -- only start connecting if option is valid
          if routing_2[x] ~= nil then
            if routing_2[x][(y-4)] ~= nil then
              held_2 = {x,y}
            end
          end
        else
          local c1 = routing_2[held_2[1]][held_2[2]-4]
          local c2 = routing_2[x][y-4]
          local param = ""
          
          if held_2[1] < x then
            param = c2.."_"..c1
          else
            param = c1.."_"..c2
          end
          
          if params.lookup[param] ~= nil then
            params:set(param, params:get(param) == 0 and 1 or 0)
          end
        end
      end
    end
    
  end
  
  if z == 0 then
    if held_1[1] == x and held_1[2] == y then
      held_1 = {}
    end
    if held_2[1] == x and held_2[2] == y then
      held_2 = {}
    end
  end
  
  -- grid alt buttons
  if x == 16 and y == 4 then
    alt_1 = z
  end
  if x == 16 and y == 8 then
    alt_2 = z
  end
  
  redraw()
  grid_redraw()
end
