-- Sokoban for CC:Tweaked (centered, multi-level, clean text)
local term = term
local colors = colors

-- Color palette
local COLOR_BG   = colors.blue      -- Floor (dark blue)
local COLOR_WALL = colors.black     -- Wall/boundary
local COLOR_GOAL = colors.lime      -- Goal (bright lime)
local COLOR_BOX  = colors.pink      -- Box (bright pink)
local COLOR_PLAYER = colors.magenta -- Player (bright magenta)

-- Sprites
local SPR_WALL   = " "
local SPR_GOAL   = "X"
local SPR_BOX    = "#"
local SPR_BOX_ON_GOAL = "*"
local SPR_PLAYER = "8"
local SPR_PLAYER_ON_GOAL = "8"
local SPR_FLOOR  = " "

-- Four fresh levels
local LEVELS = {
  { -- Level 1: Simple starter
    "  ####  ",
    " ## .#  ",
    "##   ###",
    "# $ $ @#",
    "# $   ##",
    "#..#  # ",
    "####### "
  },
    {
"####################",
"#.                 #",
"# @     $   $      #",
"#                  #",
"#                  #",
"#       .          #",
"#                  #",
"#                  #",
"#                  #",
"####################"
}
}

-- Parse a level from strings to map
local function parseLevel(levelLines)
  local map, goals = {}, {}
  local playerX, playerY = 0, 0
  for y = 1, #levelLines do
    map[y] = {}
    for x = 1, #levelLines[y] do
      local c = levelLines[y]:sub(x, x)
      if c == '#' then
        map[y][x] = {type="wall"}
      elseif c == '$' then
        map[y][x] = {type="box"}
      elseif c == '.' then
        map[y][x] = {type="goal"}
        goals[#goals+1] = {x=x, y=y}
      elseif c == '*' then
        map[y][x] = {type="box", onGoal=true}
        goals[#goals+1] = {x=x, y=y}
      elseif c == '@' then
        map[y][x] = {type="floor"}
        playerX, playerY = x, y
      elseif c == '+' then
        map[y][x] = {type="goal"}
        playerX, playerY = x, y
        goals[#goals+1] = {x=x, y=y}
      else
        map[y][x] = {type="floor"}
      end
    end
  end
  -- If no explicit player, pick first open space
  if playerX == 0 then
    for y=1,#map do for x=1,#map[y] do
      if map[y][x].type == "floor" then playerX,playerY=x,y; break end
    end end
  end
  return map, goals, playerX, playerY
end

-- Get terminal size
local function getSize()
  return term.getSize()
end

-- Centered draw
local function draw(map, playerX, playerY, goals, moves, level, totalLevels)
  local sw, sh = getSize()
  term.setBackgroundColor(COLOR_BG)
  term.clear()

  local h, w = #map, 0
  for y=1,h do if #map[y]>w then w=#map[y] end end

  -- Center map
  local offsetX = math.floor((sw-w)/2)
  local offsetY = math.floor((sh-h)/2)

  for y=1, h do
    for x=1, w do
      local cell = map[y][x] or {type="floor"}
      local isGoal = false
      for _,g in ipairs(goals) do if g.x==x and g.y==y then isGoal = true; break end end

      local drawX = x + offsetX
      local drawY = y + offsetY

      if x == playerX and y == playerY then
        if isGoal then
          term.setBackgroundColor(COLOR_BG)
          term.setTextColor(COLOR_PLAYER)
          term.setCursorPos(drawX, drawY)
          term.write(SPR_PLAYER_ON_GOAL)
        else
          term.setBackgroundColor(COLOR_BG)
          term.setTextColor(COLOR_PLAYER)
          term.setCursorPos(drawX, drawY)
          term.write(SPR_PLAYER)
        end
      elseif cell.type == "wall" then
        term.setBackgroundColor(COLOR_WALL)
        term.setTextColor(COLOR_WALL)
        term.setCursorPos(drawX, drawY)
        term.write(SPR_WALL)
      elseif cell.type == "box" then
        if isGoal then
          term.setBackgroundColor(COLOR_BG)
          term.setTextColor(COLOR_BOX)
          term.setCursorPos(drawX, drawY)
          term.write(SPR_BOX_ON_GOAL)
        else
          term.setBackgroundColor(COLOR_BG)
          term.setTextColor(COLOR_BOX)
          term.setCursorPos(drawX, drawY)
          term.write(SPR_BOX)
        end
      elseif isGoal then
        term.setBackgroundColor(COLOR_BG)
        term.setTextColor(COLOR_GOAL)
        term.setCursorPos(drawX, drawY)
        term.write(SPR_GOAL)
      else
        term.setBackgroundColor(COLOR_BG)
        term.setTextColor(COLOR_BG)
        term.setCursorPos(drawX, drawY)
        term.write(SPR_FLOOR)
      end
    end
  end
  -- Draw info, centered under level
  local info = ("Moves: %d   Level: %d/%d  R=Restart Q=Quit"):format(moves, level, totalLevels)
  local infoX = math.floor((sw - #info) / 2) + 1
  local infoY = offsetY + h + 1
  if infoY <= sh then
    term.setCursorPos(infoX, infoY)
    term.setBackgroundColor(COLOR_BG)
    term.setTextColor(colors.white)
    term.write(info)
  end
end

local function messageCenter(msg, color)
  local sw, sh = getSize()
  term.setBackgroundColor(COLOR_BG)
  local y = math.floor(sh / 2)
  term.setCursorPos(math.floor((sw-#msg)/2)+1, y)
  term.setTextColor(color or colors.yellow)
  term.write(msg)
end

local function waitKey()
  local sw, sh = getSize()
  local info = "Press any key to continue..."
  term.setTextColor(colors.white)
  term.setCursorPos(math.floor((sw-#info)/2)+1, sh)
  term.write(info)
  os.pullEvent("key")
end

local function isSolved(map, goals)
  for _,g in ipairs(goals) do
    if not (map[g.y][g.x].type == "box") then
      return false
    end
  end
  return true
end

local function readMove()
  while true do
    local event, key = os.pullEvent()
    if event == "key" then
      if key == keys.w or key == keys.up then return 0, -1 end
      if key == keys.s or key == keys.down then return 0, 1 end
      if key == keys.a or key == keys.left then return -1, 0 end
      if key == keys.d or key == keys.right then return 1, 0 end
      if key == keys.r then return "restart" end
      if key == keys.q then return "quit" end
    end
  end
end

local function deepCopyMap(map)
  local c = {}
  for y=1,#map do
    c[y] = {}
    for x=1,#map[y] do
      c[y][x] = {}
      for k,v in pairs(map[y][x]) do c[y][x][k]=v end
    end
  end
  return c
end

local function playLevel(levelDef, levelNum, totalLevels)
  local map, goals, playerX, playerY = parseLevel(levelDef)
  local moves = 0
  local map0, px0, py0 = deepCopyMap(map), playerX, playerY

  while true do
    draw(map, playerX, playerY, goals, moves, levelNum, totalLevels)
    if isSolved(map, goals) then
      messageCenter("Level Complete!", colors.lime)
      waitKey()
      break
    end

    local dx, dy = readMove()
    if dx == "restart" then
      map = deepCopyMap(map0)
      playerX, playerY = px0, py0
      moves = 0
    elseif dx == "quit" then
      return false
    elseif dx then
      local tx, ty = playerX+dx, playerY+dy
      if map[ty] and map[ty][tx] then
        local target = map[ty][tx]
        if target.type == "floor" or target.type == "goal" then
          playerX, playerY = tx, ty
          moves = moves + 1
        elseif target.type == "box" then
          local bx, by = tx+dx, ty+dy
          if map[by] and map[by][bx] and (map[by][bx].type == "floor" or map[by][bx].type == "goal") then
            map[by][bx].type = "box"
            target.type = (function()
              for _,g in ipairs(goals) do
                if g.x==tx and g.y==ty then return "goal" end
              end
              return "floor"
            end)()
            playerX, playerY = tx, ty
            moves = moves + 1
          end
        end
      end
    end
  end
  return true
end

local function main()
  for level=1,#LEVELS do
    local res = playLevel(LEVELS[level], level, #LEVELS)
    if not res then
      messageCenter("Thanks for Playing!", colors.red)
      waitKey()
      return
    end
  end
  messageCenter("Congratulations!", colors.green)
  waitKey()
end

main()
