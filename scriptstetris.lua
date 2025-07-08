-- CONFIGURATION
local leaderboardFile = "leaderboard.txt"
local playfieldWidth = 10
local playfieldHeight = 17
local dropInterval = 0.8

-- TETROMINO SHAPES
local tetrominoes = {
    I = {color=colors.lightBlue, rotations={
        {{0,1},{1,1},{2,1},{3,1}},
        {{2,0},{2,1},{2,2},{2,3}},
    }},
    O = {color=colors.brown, rotations={
        {{1,0},{2,0},{1,1},{2,1}},
    }},
    T = {color=colors.purple, rotations={
        {{1,0},{0,1},{1,1},{2,1}},
        {{1,0},{1,1},{2,1},{1,2}},
        {{0,1},{1,1},{2,1},{1,2}},
        {{1,0},{0,1},{1,1},{1,2}},
    }},
    S = {color=colors.green, rotations={
        {{1,0},{2,0},{0,1},{1,1}},
        {{1,0},{1,1},{2,1},{2,2}},
    }},
    Z = {color=colors.red, rotations={
        {{0,0},{1,0},{1,1},{2,1}},
        {{2,0},{1,1},{2,1},{1,2}},
    }},
    J = {color=colors.blue, rotations={
        {{0,0},{0,1},{1,1},{2,1}},
        {{1,0},{2,0},{1,1},{1,2}},
        {{0,1},{1,1},{2,1},{2,2}},
        {{1,0},{1,1},{0,2},{1,2}},
    }},
    L = {color=colors.orange, rotations={
        {{2,0},{0,1},{1,1},{2,1}},
        {{1,0},{1,1},{1,2},{2,2}},
        {{0,1},{1,1},{2,1},{0,2}},
        {{0,0},{1,0},{1,1},{1,2}},
    }},
}
local tetrominoKeys = {}
for k in pairs(tetrominoes) do table.insert(tetrominoKeys, k) end

-- PERIPHERALS
local monitor = peripheral.find("monitor")
if not monitor then error("Monitor not found!") end
monitor.setTextScale(1.75)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local speaker = peripheral.find("speaker")

-- PLAYFIELD
local playfield = {}
for y=1,playfieldHeight do
    playfield[y] = {}
    for x=1,playfieldWidth do
        playfield[y][x] = nil
    end
end

-- FUNCTIONS
local function deepcopy(t)
    local r = {}
    for k,v in pairs(t) do
        if type(v)=="table" then r[k]=deepcopy(v) else r[k]=v end
    end
    return r
end

local function spawnPiece()
    if nextPiece then
        current = nextPiece.piece
    else
        current = tetrominoes[tetrominoKeys[math.random(#tetrominoKeys)]]
    end
    nextPiece = {piece = tetrominoes[tetrominoKeys[math.random(#tetrominoKeys)]]}
    rotation = 1
    posX = 4
    posY = 0
end

local function getCells(shape, ox, oy, rot)
    local cells = {}
    local r = rot or rotation
    for _,v in ipairs(shape.rotations[r]) do
        table.insert(cells, {x=ox+v[1], y=oy+v[2]})
    end
    return cells
end

local function canMove(dx, dy, dr)
    local r = rotation
    if dr then
        r = r + dr
        if r > #current.rotations then r=1 end
        if r<1 then r=#current.rotations end
    end
    for _,c in ipairs(getCells(current, posX+dx, posY+dy, r)) do
        if c.x<1 or c.x>playfieldWidth or c.y>playfieldHeight then return false end
        if c.y>0 and playfield[c.y][c.x] then return false end
    end
    return true
end

local function lockPiece()
    for _,c in ipairs(getCells(current,posX,posY)) do
        if c.y>0 then
            playfield[c.y][c.x] = current.color
        else
            return false
        end
    end
    return true
end

local function clearLines()
    local cleared=0
    y=playfieldHeight
    while y>=1 do
        local full=true
        for x=1,playfieldWidth do
            if not playfield[y][x] then
                full=false
                break
            end
        end
        if full then
            for yy=y,2,-1 do
                playfield[yy]=deepcopy(playfield[yy-1])
            end
            local newLine={}
            for x=1,playfieldWidth do newLine[x]=nil end
            playfield[1]=newLine
            cleared=cleared+1
        else
            y=y-1
        end
    end
    return cleared
end

local function playBeep()
    if speaker then
        speaker.playNote("bell",1,12)
    end
end

local function loadLeaderboard()
    local file=fs.open(leaderboardFile,"r")
    local scores={}
    if file then
        scores=textutils.unserialize(file.readAll())
        file.close()
    end
    return scores or {}
end

local function saveLeaderboard(scores)
    local file=fs.open(leaderboardFile,"w")
    file.write(textutils.serialize(scores))
    file.close()
end

local function updateLeaderboard(newEntry)
    local scores=loadLeaderboard()
    table.insert(scores,newEntry)
    table.sort(scores,function(a,b) return a.score>b.score end)
    while #scores>20 do table.remove(scores) end
    saveLeaderboard(scores)
end

local function qualifiesForLeaderboard(s)
    local scores=loadLeaderboard()
    if #scores<20 then return true end
    return s > scores[#scores].score
end

local function drawLeaderboard()
    monitor.clear()
    local w,h = monitor.getSize()
    local function center(y,text,color)
        local x = math.floor((w - #text)/2) + 1
        monitor.setCursorPos(x,y)
        if color then
            monitor.setTextColor(color)
        else
            monitor.setTextColor(colors.white)
        end
        monitor.write(text)
    end

    center(1,"=== TETRIS ===", colors.red)

    local scores = loadLeaderboard()
    if #scores == 0 then
        center(3,"No scores yet.")
    else
        for i,s in ipairs(scores) do
            local line
            if type(s) == "table" then
                line = i..". "..s.initials.." - "..s.score
            else
                line = i..". ??? - "..s
            end

            -- Rank colors
            local c
            if i == 1 then c = colors.yellow
            elseif i == 2 then c = colors.lightGray
            elseif i == 3 then c = colors.brown
            elseif i <=5 then c = colors.magenta
            else c = colors.lightBlue
            end

            center(2 + i, line, c)
        end
    end
end

local function draw()
    term.clear()
    local w,h=term.getSize()
    local offsetX=math.floor((w-playfieldWidth-8)/2)
    for y=1,playfieldHeight do
        term.setCursorPos(offsetX,y)
        for x=1,playfieldWidth do
            local c=playfield[y][x]
            if c then
                term.setBackgroundColor(c)
                term.write(" ")
            else
                term.setBackgroundColor(colors.black)
                term.write(".")
            end
        end
    end
    for _,c in ipairs(getCells(current,posX,posY)) do
        if c.y>0 then
            term.setCursorPos(offsetX+(c.x-1),c.y)
            term.setBackgroundColor(current.color)
            term.write(" ")
        end
    end
    local boxX=offsetX+playfieldWidth+2
    local boxY=math.floor((playfieldHeight-6)/2)
    term.setCursorPos(boxX,boxY)
    term.write("+------+")

    for i=1,4 do
        term.setCursorPos(boxX,boxY+i)
        term.write("|      |")
    end
    term.setCursorPos(boxX,boxY+5)
    term.write("+------+")

    for _,c in ipairs(getCells(nextPiece.piece,0,0,1)) do
        local px=boxX+1+c.x
        local py=boxY+1+c.y
        if py>=boxY+1 and py<=boxY+4 then
            term.setCursorPos(px,py)
            term.setBackgroundColor(nextPiece.piece.color)
            term.write(" ")
        end
    end
    term.setCursorPos(boxX,boxY+7)
    print("Score: "..score)
    term.setCursorPos(boxX,boxY+8)
    print("Lines: "..linesCleared)
    term.setCursorPos(boxX,boxY+9)
    print("Level: "..level)

    term.setCursorPos(1,playfieldHeight-3)
    print("Arrows = Move")
    term.setCursorPos(1,playfieldHeight-2)
    print("Z/X = Rotate")
    term.setCursorPos(1,playfieldHeight-1)
    print("Space = Drop")
    term.setCursorPos(1,playfieldHeight)
    print("Q = Quit")
end
-- MAIN LOOP
while true do
    drawLeaderboard()
    term.clear()
    local asciiTitle = {
        "  ______        __                         ",
        "/\\__  _\\      /\\ \\__         __          ",
        "\\/_/\\ \\/    __\\ \\ ,_\\  _ __ /\\_\\    ____ ",
        "   \\ \\ \\  /'__`\\ \\ \\/ /\\`'__\\/\\ \\  /',__\\",
        "     \\ \\ \\/\\  __/\\ \\ \\_\\ \\ \\/ \\ \\ \\/\\__, `\\",
        "      \\ \\_\\ \\____\\\\ \\__\\\\ \\_\\  \\ \\_\\/\\____/",
        "       \\/_/\\/____/ \\/__/ \\/_/   \\/_/\\/___/ "
    }
    local w,h=term.getSize()
    for i,line in ipairs(asciiTitle) do
        term.setCursorPos(math.floor((w-#line)/2)+1,i)
        print(line)
    end
    term.setCursorPos(math.floor(w/2-10),#asciiTitle+2)
    print("Press Enter to start")
    term.setCursorPos(math.floor(w/2-10),#asciiTitle+3)
    print("Press Q to quit")
    while true do
        local e,k=os.pullEvent("key")
        if k==keys.q then return end
        if k==keys.enter then break end
    end
    for y=1,playfieldHeight do
        for x=1,playfieldWidth do
            playfield[y][x]=nil
        end
    end
    score=0
    linesCleared=0
    level=1
    spawnPiece()
    monitor.clear()
    local interval=dropInterval
    local timer=os.startTimer(interval)
    local gameOver=false
    while not gameOver do
        local e,param=os.pullEvent()
        if e=="key" then
            if param==keys.left and canMove(-1,0) then posX=posX-1 end
            if param==keys.right and canMove(1,0) then posX=posX+1 end
            if param==keys.down and canMove(0,1) then posY=posY+1 end
            if param==keys.z and canMove(0,0,-1) then rotation=rotation-1 if rotation<1 then rotation=#current.rotations end end
            if param==keys.x and canMove(0,0,1) then rotation=rotation+1 if rotation>#current.rotations then rotation=1 end end
            if param==keys.space then
                while canMove(0,1) do posY=posY+1 end
                if not lockPiece() then
                    playBeep()
                    if qualifiesForLeaderboard(score) then
                        term.clear()
                        local gameOverArt={
" _____                                            ",
"|  __ \\                                           ",
"| |  \\/ __ _ _ __ ___   ___    _____   _____ _ __ ",
"| | __ / _` | '_ ` _ \\ / _ \\  / _ \\ \\ / / _ \\ '__|",
"| |_\\ \\ (_| | | | | | |  __/ | (_) \\ V /  __/ |   ",
" \\____/\\__,_|_| |_| |_|\\___|  \\___/ \\_/ \\___|_|   "
                        }
                        for i,line in ipairs(gameOverArt) do
                            term.setCursorPos(math.floor((w-#line)/2)+1,i)
                            print(line)
                        end
                        term.setCursorPos(1,#gameOverArt+2)
                        print("Your score: "..score)
                        write("Enter initials (3 letters): ")
                        local initials=read()
                        initials=(initials:upper().."   "):sub(1,3)
                        updateLeaderboard({score=score,initials=initials})
                    end
                    gameOver=true
                    break
                end
                playBeep()
                local cleared=clearLines()
                if cleared>0 then
                    -- NES scoring rules
                    local pts=0
                    if cleared==1 then pts=40*(level+1)
                    elseif cleared==2 then pts=100*(level+1)
                    elseif cleared==3 then pts=300*(level+1)
                    elseif cleared==4 then pts=1200*(level+1) end
                    score=score+pts
                    linesCleared=linesCleared+cleared
                    if linesCleared>=10 then
                        level=level+1
                        linesCleared=0
                    end
                    interval=math.max(0.1,dropInterval - (level-1)*0.1)
                end
                spawnPiece()
                draw()
            end
            if param==keys.q then gameOver=true break end
        elseif e=="timer" and param==timer then
            if canMove(0,1) then
                posY=posY+1
                timer=os.startTimer(interval)
            else
                if not lockPiece() then
                    playBeep()
                    if qualifiesForLeaderboard(score) then
                        term.clear()
                        local gameOverArt={
" _____                                            ",
"|  __ \\                                           ",
"| |  \\/ __ _ _ __ ___   ___    _____   _____ _ __ ",
"| | __ / _` | '_ ` _ \\ / _ \\  / _ \\ \\ / / _ \\ '__|",
"| |_\\ \\ (_| | | | | | |  __/ | (_) \\ V /  __/ |   ",
" \\____/\\__,_|_| |_| |_|\\___|  \\___/ \\_/ \\___|_|   "
                        }
                        for i,line in ipairs(gameOverArt) do
                            term.setCursorPos(math.floor((w-#line)/2)+1,i)
                            print(line)
                        end
                        term.setCursorPos(1,#gameOverArt+2)
                        print("Your score: "..score)
                        write("Enter initials (3 letters): ")
                        local initials=read()
                        initials=(initials:upper().."   "):sub(1,3)
                        updateLeaderboard({score=score,initials=initials})
                    end
                    gameOver=true
                    break
                end
                playBeep()
                local cleared=clearLines()
                if cleared>0 then
                    -- NES scoring rules
                    local pts=0
                    if cleared==1 then pts=40*(level+1)
                    elseif cleared==2 then pts=100*(level+1)
                    elseif cleared==3 then pts=300*(level+1)
                    elseif cleared==4 then pts=1200*(level+1) end
                    score=score+pts
                    linesCleared=linesCleared+cleared
                    if linesCleared>=10 then
                        level=level+1
                        linesCleared=0
                    end
                    interval=math.max(0.1,dropInterval - (level-1)*0.1)
                end
                spawnPiece()
                draw()
                timer=os.startTimer(interval)
            end
        end
        draw()
    end
end
