-- Tamagotchi Virtual Pet for CC:Tweaked (aligned action buttons, all art, petting secret, respawn after death)
local SAVE_FILE = "/pet_save.dat"
local TICK_TIME = 5
local ANIM_TIME = 0.5
local monitor

-- [Full petSprites as before: blob, cat, dog, dino, ghost, duck]
-- (Unchanged; copy-paste from prior script above if omitted in preview)
local petSprites = {
  blob = {
    name = "Blob",
    moods = {
      happy = {
        {
          "  .----.  ",
          " ( o  o ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        },
        {
          "  .----.  ",
          " ( ^  ^ ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        }
      },
      sad = {
        {
          "  .----.  ",
          " ( -  - ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        },
        {
          "  .----.  ",
          " ( .  . ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        }
      },
      sick = {
        {
          "  .----.  ",
          " ( x  x ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        },
        {
          "  .----.  ",
          " ( +  + ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        }
      },
      default = {
        {
          "  .----.  ",
          " ( o  o ) ",
          "  \\_/\\_/  ",
          "   ----   ",
        }
      }
    }
  },
  cat = {
    name = "Cat",
    moods = {
      happy = {
        {
          " /\\_/\\   ",
          "( o.o )  ",
          " > ^ <   ",
        },
        {
          " /\\_/\   ",
          "( ^.^ )  ",
          " >   <   ",
        }
      },
      sad = {
        {
          " /\\_/\\   ",
          "( -.- )  ",
          " >   <   ",
        },
        {
          " /\\_/\\   ",
          "( ._. )  ",
          " >   <   ",
        }
      },
      sick = {
        {
          " /\\_/\\   ",
          "( x.x )  ",
          " >   <   ",
        },
        {
          " /\\_/\\   ",
          "( +.+ )  ",
          " >   <   ",
        }
      },
      default = {
        {
          " /\\_/\\   ",
          "( o.o )  ",
          " > ^ <   ",
        }
      }
    }
  },
  dog = {
    name = "Dog",
    moods = {
      happy = {
        {
          " /^ ^\\  ",
          "( o.o ) ",
          "  |U|   ",
        },
        {
          " /^ ^\\  ",
          "( ^.^ ) ",
          "  |U|   ",
        }
      },
      sad = {
        {
          " /^ ^\\  ",
          "( -.- ) ",
          "  |U|   ",
        },
        {
          " /^ ^\\  ",
          "( ._. ) ",
          "  |U|   ",
        }
      },
      sick = {
        {
          " /^ ^\\  ",
          "( x.x ) ",
          "  |U|   ",
        },
        {
          " /^ ^\\  ",
          "( +.+ ) ",
          "  |U|   ",
        }
      },
      default = {
        {
          " /^ ^\\  ",
          "( o.o ) ",
          "  |U|   ",
        }
      }
    }
  },
  dino = {
    name = "Dino",
    moods = {
      happy = {
        {
          "  __     ",
          " (oo)    ",
          "/|  |\\   ",
          " V  V    ",
        },
        {
          "  __     ",
          " (^^)    ",
          "/|  |\\   ",
          " V  V    ",
        }
      },
      sad = {
        {
          "  __     ",
          " (-- )   ",
          "/|  |\\   ",
          " V  V    ",
        },
        {
          "  __     ",
          " ( ..)   ",
          "/|  |\\   ",
          " V  V    ",
        }
      },
      sick = {
        {
          "  __     ",
          " (xx)    ",
          "/|  |\\   ",
          " V  V    ",
        },
        {
          "  __     ",
          " (++ )   ",
          "/|  |\\   ",
          " V  V    ",
        }
      },
      default = {
        {
          "  __     ",
          " (oo)    ",
          "/|  |\\   ",
          " V  V    ",
        }
      }
    }
  },
  ghost = {
    name = "Ghost",
    moods = {
      happy = {
        {
          " .-.     ",
          "(o o)    ",
          " | |     ",
          "/   \\    ",
        },
        {
          " .-.     ",
          "(^ ^)    ",
          " | |     ",
          "/   \\    ",
        }
      },
      sad = {
        {
          " .-.     ",
          "(- -)    ",
          " | |     ",
          "/   \\    ",
        },
        {
          " .-.     ",
          "(._.)    ",
          " | |     ",
          "/   \\    ",
        }
      },
      sick = {
        {
          " .-.     ",
          "(x x)    ",
          " | |     ",
          "/   \\    ",
        },
        {
          " .-.     ",
          "(+ +)    ",
          " | |     ",
          "/   \\    ",
        }
      },
      default = {
        {
          " .-.     ",
          "(o o)    ",
          " | |     ",
          "/   \\    ",
        }
      }
    }
  },
  duck = {
    name = "Duck",
    moods = {
      happy = {
        {
          "  _      ",
          " ( v >   ",
          " /_/_    ",
        },
        {
          "  _      ",
          " ( ^ >   ",
          " /_/_    ",
        }
      },
      sad = {
        {
          "  _      ",
          " ( - >   ",
          " /_/_    ",
        },
        {
          "  _      ",
          " ( . >   ",
          " /_/_    ",
        }
      },
      sick = {
        {
          "  _      ",
          " ( x >   ",
          " /_/_    ",
        },
        {
          "  _      ",
          " ( + >   ",
          " /_/_    ",
        }
      },
      default = {
        {
          "  _      ",
          " ( v >   ",
          " /_/_    ",
        }
      }
    }
  }
}

local petTypes = {}
for k in pairs(petSprites) do table.insert(petTypes, k) end

local themes = {
  {bg=colors.lightBlue, fg=colors.black, bar=colors.blue},
  {bg=colors.lime, fg=colors.black, bar=colors.green},
  {bg=colors.orange, fg=colors.white, bar=colors.red},
  {bg=colors.gray, fg=colors.white, bar=colors.lightGray},
  {bg=colors.white, fg=colors.gray, bar=colors.purple},
  {bg=colors.black, fg=colors.white, bar=colors.cyan}
}
local maxStat, minStat = 100, 0

local function getMonitor()
  local side = "top"
  if not peripheral.isPresent(side) then error("No monitor detected on top!") end
  local m = peripheral.wrap(side)
  if not m or not m.setTextScale then error("No monitor peripheral found on top!") end
  return m
end

local function saveState(state)
  local fh = fs.open(SAVE_FILE,"w")
  fh.write(textutils.serialize(state))
  fh.close()
end

local function loadState()
  if not fs.exists(SAVE_FILE) then return nil end
  local fh = fs.open(SAVE_FILE,"r")
  local data = fh.readAll()
  fh.close()
  return textutils.unserialize(data)
end

local function randomStat(min,max) return math.random(min,max) end

local function newPetState(typeKey)
  local t = os.epoch("utc")
  local stats = {hunger=randomStat(60,90),happiness=randomStat(60,90),cleanliness=randomStat(60,90),health=randomStat(60,90),age=0}
  return {petType=typeKey, stats=stats, birth=t, lastTick=t, theme=1, alive=true, anim=1, mood="happy", happyFlash=0, artBox={}}
end

local statDecay = {hunger=6, happiness=5, cleanliness=5, health=2}
local actionDefs = {
  feed={hunger=30,happiness=2,cleanliness=-5},
  play={happiness=30,hunger=-10,cleanliness=-7},
  clean={cleanliness=40,happiness=3},
  heal={health=35,happiness=3,cleanliness=-3},
  pet={happiness=20}
}

local function clear(m, theme) m.setBackgroundColor(theme.bg) m.clear() end

local w, h
local function centerX(str) return math.floor((w-#str)/2)+1 end

local function drawPetName(name, theme)
  monitor.setCursorPos(centerX(name), 2)
  monitor.setTextColor(theme.fg)
  monitor.write(name)
end

local function drawPetCenteredY(petType, mood, frame, theme)
  local pet = petSprites[petType]
  local artSet = pet.moods[mood] or pet.moods["default"]
  frame = math.max(1, (frame-1)%#artSet + 1)
  local art = artSet[frame]
  local artLines = #art
  local artW = 0
  for i=1,artLines do if #art[i] > artW then artW = #art[i] end end
  local yStart = math.floor(h*0.17)
  local xStart = math.floor((w - artW)/2)+1
  for i=1,artLines do
    monitor.setCursorPos(xStart, yStart + i - 1)
    monitor.setTextColor(theme.fg)
    monitor.write(art[i])
  end
  return {x1=xStart, y1=yStart, x2=xStart+artW-1, y2=yStart+artLines-1}
end

local function drawStatBar(stat, value, ypos, theme)
  local label = stat:sub(1,1):upper()..stat:sub(2)
  monitor.setCursorPos(4, ypos)
  monitor.setTextColor(theme.fg)
  monitor.write(label)
  local barW = math.floor(w/2)
  local filled = math.floor(barW * math.max(0,math.min(1,value/maxStat)))
  monitor.setCursorPos(15, ypos)
  monitor.setBackgroundColor(theme.bar)
  monitor.write(string.rep(" ",filled))
  monitor.setBackgroundColor(theme.bg)
  monitor.write(string.rep(" ",barW-filled))
  monitor.setCursorPos(w-6, ypos)
  monitor.setTextColor(theme.fg)
  monitor.write(tostring(value))
end

local function drawStats(stats, theme)
  local y = math.floor(h*0.45)
  drawStatBar("hunger", stats.hunger, y, theme)
  drawStatBar("happiness", stats.happiness, y+2, theme)
  drawStatBar("cleanliness", stats.cleanliness, y+4, theme)
  drawStatBar("health", stats.health, y+6, theme)
  monitor.setCursorPos(4, y+8)
  monitor.setTextColor(theme.fg)
  monitor.write("Age: " .. tostring(math.floor(stats.age)))
end

-- Button helpers
local function drawButton(label, x, y, wBtn, hBtn, theme)
  monitor.setBackgroundColor(theme.bar)
  for yy=0,hBtn-1 do monitor.setCursorPos(x,y+yy) monitor.write(string.rep(" ",wBtn)) end
  monitor.setCursorPos(x+math.floor((wBtn-#label)/2), y+math.floor(hBtn/2))
  monitor.setTextColor(theme.fg)
  monitor.write(label)
end

local function drawThemeBtn(themeIdx, theme)
  drawButton("Theme", 2, h-2, 10, 3, theme)
  monitor.setCursorPos(3, h)
  monitor.setTextColor(theme.fg)
  monitor.write("Theme#" .. tostring(themeIdx))
end

local function drawActionBtns(theme)
  -- 4 buttons, fixed widths, fixed positions, evenly spaced, always on screen
  local btnW, btnH, gap = 10, 3, 2
  local totalBtnsW = btnW*4 + gap*3
  local xStart = math.floor((w - totalBtnsW)/2) + 1
  local yBtn = h-2
  drawButton("Feed",  xStart + (btnW+gap)*0, yBtn, btnW, btnH, theme)
  drawButton("Play",  xStart + (btnW+gap)*1, yBtn, btnW, btnH, theme)
  drawButton("Clean", xStart + (btnW+gap)*2, yBtn, btnW, btnH, theme)
  drawButton("Heal",  xStart + (btnW+gap)*3, yBtn, btnW, btnH, theme)
end

local function drawPetMessage(msg, theme)
  monitor.setCursorPos(centerX(msg), math.floor(h*0.30))
  monitor.setTextColor(theme.fg)
  monitor.write(msg)
end

local function drawDeath(theme)
  clear(monitor, theme)
  local lines = {
    "     X   X     ",
    "       v       ",
    "    \\ ___ /    ",
    "",
    "    Your pet   ",
    "    has died!  ",
    "",
    "   Touch to    ",
    "   hatch a new ",
    "   friend.     "
  }
  for i,ln in ipairs(lines) do
    monitor.setCursorPos(centerX(ln), math.floor(h/2)-5+i)
    monitor.write(ln)
  end
end

local function getMood(stats)
  if stats.health < 30 then return "sick"
  elseif stats.happiness < 35 then return "sad"
  elseif stats.hunger < 35 then return "sad"
  elseif stats.cleanliness < 25 then return "sad"
  else return "happy" end
end

local function clamp(v) return math.max(minStat, math.min(maxStat, math.floor(v))) end

local function applyDecay(stats, hours)
  for k,decay in pairs(statDecay) do stats[k] = clamp(stats[k] - decay * hours) end
  if stats.hunger < 20 or stats.cleanliness < 20 then stats.health = clamp(stats.health - 10 * hours) end
  if stats.hunger < 25 or stats.cleanliness < 25 or stats.health < 40 then stats.happiness = clamp(stats.happiness - 5 * hours) end
end

local function doAction(state, act)
  local eff = actionDefs[act]
  for k,v in pairs(eff) do state.stats[k] = clamp(state.stats[k] + v) end
end

local function checkDeath(stats)
  for _,k in ipairs({"hunger","happiness","cleanliness","health"}) do
    if stats[k] <= 0 then return true end
  end
  if stats.age >= 100 then return true end
  return false
end

-- Pet selection screen
local function petSelect(theme)
  clear(monitor, theme)
  local n = #petTypes
  local cols = n
  local artH = 4
  local yArt = math.floor(h*0.20)
  local xStep = math.floor(w / (cols+1))
  for i,ptype in ipairs(petTypes) do
    local pet = petSprites[ptype]
    local art = pet.moods["happy"][1]
    local x = xStep*i - math.floor(#art[1]/2)
    for j=1,#art do
      monitor.setCursorPos(x, yArt+j-1)
      monitor.setTextColor(theme.fg)
      monitor.write(art[j])
    end
    monitor.setCursorPos(x, yArt+artH)
    monitor.setTextColor(theme.fg)
    monitor.write(" "..pet.name.." ")
  end
  local selMsg = "Touch your new friend to hatch!"
  monitor.setCursorPos(centerX(selMsg), h-5)
  monitor.write(selMsg)
  -- Wait for selection
  while true do
    local _,_,x,y = os.pullEvent("monitor_touch")
    for i,ptype in ipairs(petTypes) do
      local px = xStep*i - math.floor(#petSprites[ptype].moods["happy"][1][1]/2)
      local py1 = yArt
      local py2 = yArt+artH-1
      if x >= px and x <= px+#petSprites[ptype].moods["happy"][1][1]-1 and y >= py1 and y <= py2 then
        return ptype
      end
    end
  end
end

local function petMain()
  while true do
    local state = loadState()
    if not state or not state.alive then
      local theme = themes[1]
      local ptype = petSelect(theme)
      local stateNew = newPetState(ptype)
      saveState(stateNew)
    end

    local state = loadState()

    while true do
      local t = os.epoch("utc")
      local lastT = state.lastTick or t
      local dt = math.max(0, (t - lastT) / 3600000)
      state.lastTick = t

      if dt > 0 then
        state.stats.age = state.stats.age + dt
        applyDecay(state.stats, dt)
      end

      if checkDeath(state.stats) then
        state.alive = false
        saveState(state)
        drawDeath(themes[state.theme])
        fs.delete(SAVE_FILE)
        os.sleep(5)
        break
      end

      state.mood = getMood(state.stats)
      state.anim = (state.anim % 2) + 1

      local theme = themes[state.theme]
      clear(monitor, theme)
      drawPetName(petSprites[state.petType].name, theme)
      state.artBox = drawPetCenteredY(state.petType, state.mood, state.anim, theme)
      drawStats(state.stats, theme)
      drawThemeBtn(state.theme, theme)
      drawActionBtns(theme)

      if state.happyFlash and (os.epoch("utc") - state.happyFlash < 1500) then
        drawPetMessage("<3 " .. petSprites[state.petType].name .. " enjoyed that! <3", theme)
      end

      saveState(state)

      local timer = os.startTimer(TICK_TIME)
      local animT = os.startTimer(ANIM_TIME)
      while true do
        local e, p1, p2, p3, p4 = os.pullEvent()
        if e == "monitor_touch" then
          local x, y = p2, p3
          if x >= 2 and x <= 11 and y >= h-2 and y <= h then
            state.theme = (state.theme % #themes) + 1
            break
          end
          -- Feed button
          local btnW, btnH, gap = 10, 3, 2
          local totalBtnsW = btnW*4 + gap*3
          local xStart = math.floor((w - totalBtnsW)/2) + 1
          local btns = {
            {x1=xStart, x2=xStart+btnW-1,   y1=h-2, y2=h},                           -- Feed
            {x1=xStart+btnW+gap, x2=xStart+2*btnW+gap-1, y1=h-2, y2=h},              -- Play
            {x1=xStart+2*(btnW+gap), x2=xStart+3*btnW+2*gap-1, y1=h-2, y2=h},        -- Clean
            {x1=xStart+3*(btnW+gap), x2=xStart+4*btnW+3*gap-1, y1=h-2, y2=h}         -- Heal
          }
          if x >= btns[1].x1 and x <= btns[1].x2 and y >= btns[1].y1 and y <= btns[1].y2 then doAction(state, "feed") break
          elseif x >= btns[2].x1 and x <= btns[2].x2 and y >= btns[2].y1 and y <= btns[2].y2 then doAction(state, "play") break
          elseif x >= btns[3].x1 and x <= btns[3].x2 and y >= btns[3].y1 and y <= btns[3].y2 then doAction(state, "clean") break
          elseif x >= btns[4].x1 and x <= btns[4].x2 and y >= btns[4].y1 and y <= btns[4].y2 then doAction(state, "heal") break
          -- Secret: pet art
          elseif x >= state.artBox.x1 and x <= state.artBox.x2 and y >= state.artBox.y1 and y <= state.artBox.y2 then
            doAction(state, "pet")
            state.happyFlash = os.epoch("utc")
            break
          end
        elseif e == "timer" and p1 == animT then
          state.anim = (state.anim % 2) + 1
          clear(monitor, theme)
          drawPetName(petSprites[state.petType].name, theme)
          state.artBox = drawPetCenteredY(state.petType, state.mood, state.anim, theme)
          drawStats(state.stats, theme)
          drawThemeBtn(state.theme, theme)
          drawActionBtns(theme)
          if state.happyFlash and (os.epoch("utc") - state.happyFlash < 1500) then
            drawPetMessage("<3 " .. petSprites[state.petType].name .. " enjoyed that! <3", theme)
          end
        elseif e == "timer" and p1 == timer then
          break
        end
      end
    end
  end
end

math.randomseed(os.time())
monitor = getMonitor()
monitor.setTextScale(0.5)
w, h = monitor.getSize()
petMain()
