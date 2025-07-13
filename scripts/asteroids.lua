-- Asteroids Clone for CC:Tweaked Terminal, Lua 5.1
-- Menu, Controls, Persistent Asteroids BG, Corrected Input Logic

local w, h = term.getSize()
local math, random = math, math.random

-- Game State
local ship = {}
local bullets, asteroids = {}, {}
local score, lives = 0, 3
local isRunning, isDead = false, false -- not running until start
local inMenu = true

-- Respawn/Invincibility State
local invincible = false
local invTimer = 0
local INVINCIBILITY_FRAMES = 37 -- About 3 seconds at ~0.08s/frame

local menuAsteroids = {}
local menuAsteroidCount = 12

-- Asteroid split sizes and drawing
local ASTEROID_SIZES = {3, 2, 1}
local ASTEROID_RADIUS = { [3]=2, [2]=1, [1]=0 }
local ASTEROID_CHARS  = { [3]="O", [2]="o", [1]="." }
local BULLET_CHAR = "*"

-- Quit flag
local quitRequested = false

-- Utility Functions
local function wrap(v, max)
    if v < 1 then return max
    elseif v > max then return 1 end
    return v
end

local function dist(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

-- Drawing Functions
local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
end

local function drawShip()
    local x, y, a = ship.x, ship.y, ship.angle
    local pts = {}
    for i=0,2 do
        local ang = a + i * (2*math.pi/3)
        pts[#pts+1] = {
            math.floor(x + math.cos(ang)*2 + 0.5),
            math.floor(y + math.sin(ang)*1 + 0.5)
        }
    end
    term.setCursorPos(math.floor(x), math.floor(y))
    term.write("^")
    for i=1,3 do
        local ax, ay = pts[i][1], pts[i][2]
        if ax > 0 and ay > 0 and ax <= w and ay <= h then
            term.setCursorPos(ax, ay)
            term.write(".")
        end
    end
end

local function drawBullets()
    for _, b in ipairs(bullets) do
        term.setCursorPos(math.floor(b.x), math.floor(b.y))
        term.write(BULLET_CHAR)
    end
end

local function drawAsteroids(list)
    for _, a in ipairs(list) do
        local char = ASTEROID_CHARS[a.size]
        for dx=-a.size, a.size do
            for dy=-a.size, a.size do
                if dx*dx + dy*dy <= a.size*a.size then
                    local x, y = math.floor(a.x+dx), math.floor(a.y+dy)
                    if x >= 1 and x <= w and y >= 1 and y <= h then
                        term.setCursorPos(x, y)
                        term.write(char)
                    end
                end
            end
        end
    end
end

local function drawGameUI()
    term.setCursorPos(2,1)
    term.write("SCORE: " .. score)
    term.setCursorPos(w-11,1)
    term.write("LIVES: " .. lives)
    if invincible and not isDead then
        term.setCursorPos(2,2)
        term.write("INVINCIBLE!")
    end
end

local function drawMenuUI()
    local midx = math.floor(w/2)
    local midy = math.floor(h/2)
    -- Title
    term.setCursorPos(midx-5, midy-6)
    term.write("ASTEROIDS")
    -- Press to start
    term.setCursorPos(midx-14, midy-3)
    term.write("Press [SPACE] or [ENTER] to Start")
    -- Controls panel (bottom right)
    local bx = w - 20
    local by = h - 10
    term.setCursorPos(bx, by)
    term.write("+------------------+")
    term.setCursorPos(bx, by+1)
    term.write("|    CONTROLS      |")
    term.setCursorPos(bx, by+2)
    term.write("|                  |")
    term.setCursorPos(bx, by+3)
    term.write("| W / Up   Thrust  |")
    term.setCursorPos(bx, by+4)
    term.write("| A / Lft  Left    |")
    term.setCursorPos(bx, by+5)
    term.write("| D / Rt   Right   |")
    term.setCursorPos(bx, by+6)
    term.write("| Space    Shoot   |")
    term.setCursorPos(bx, by+7)
    term.write("| Q        Quit    |")
    term.setCursorPos(bx, by+8)
    term.write("+------------------+")
    if lives == 0 then
        term.setCursorPos(midx-4, midy+3)
        term.write("GAME OVER")
        term.setCursorPos(midx-8, midy+4)
        term.write("Final Score: " .. score)
    end
end

local function draw()
    clear()
    if inMenu then
        drawAsteroids(menuAsteroids)
        drawMenuUI()
    else
        if not isDead and (not invincible or (invTimer % 2 == 0)) then
            drawShip()
        end
        drawAsteroids(asteroids)
        drawBullets()
        drawGameUI()
        if isDead and lives > 0 then
            term.setCursorPos(math.floor(w/2-5), math.floor(h/2))
            term.write("YOU DIED!")
        end
    end
end

-- Spawning Functions
local function spawnAsteroid(list, size, x, y, speed)
    local ang = random()*2*math.pi
    local a = {
        x = x or (random(1, w)),
        y = y or (random(2, h)),
        dx = math.cos(ang)*(speed or (random()*0.7+0.4)),
        dy = math.sin(ang)*(speed or (random()*0.7+0.4)),
        size = size
    }
    list[#list+1] = a
end

local function spawnWave(num)
    for i=1,num do
        local safe = false
        local x, y
        while not safe do
            x, y = random(1,w), random(2,h)
            safe = dist(x, y, ship.x, ship.y) > 8
        end
        spawnAsteroid(asteroids, ASTEROID_SIZES[1], x, y)
    end
end

local function resetShip()
    ship.x, ship.y = w/2, h/2
    ship.angle = 0
    ship.dx, ship.dy = 0, 0
end

local function initMenuAsteroids()
    menuAsteroids = {}
    for i=1,menuAsteroidCount do
        spawnAsteroid(menuAsteroids, ASTEROID_SIZES[random(1,3)], random(2,w-2), random(3,h-2), random()*0.6+0.15)
    end
end

-- Input Functions
local function getMenuInput()
    while inMenu do
        local ev = { os.pullEvent() }
        if ev[1] == "key" then
            local key = ev[2]
            if key == keys.space or key == keys.enter then
                inMenu = false
                isRunning = true
                isDead = false
                invincible = false
                score = 0
                lives = 3
                bullets = {}
                asteroids = {}
                resetShip()
                spawnWave(3)
                break
            elseif key == keys.q then
                quitRequested = true
                break
            end
        elseif ev[1] == "terminate" then
            quitRequested = true
            break
        end
    end
end

local function getGameInput()
    if not isRunning then return end
    local ev = { os.pullEvent("key") }
    local key = ev[2]
    if key == keys.left or key == keys.a then
        ship.angle = (ship.angle - math.pi/12) % (2*math.pi)
    elseif key == keys.right or key == keys.d then
        ship.angle = (ship.angle + math.pi/12) % (2*math.pi)
    elseif key == keys.up or key == keys.w then
        ship.dx = ship.dx + math.cos(ship.angle)*0.4
        ship.dy = ship.dy + math.sin(ship.angle)*0.4
    elseif key == keys.space then
        if #bullets < 4 and not isDead then
            bullets[#bullets+1] = {
                x = ship.x, y = ship.y,
                dx = math.cos(ship.angle)*1.3 + ship.dx,
                dy = math.sin(ship.angle)*1.3 + ship.dy,
                ttl = 22
            }
        end
    elseif key == keys.q then
        isRunning = false
        quitRequested = true
    end
end

-- Game Logic
local function update()
    if isDead then
        invincible = false
        if not inMenu then
            respawnTimer = respawnTimer + 1
            if respawnTimer > 40 and lives > 0 then
                resetShip()
                isDead = false
                respawnTimer = 0
                invincible = true
                invTimer = 0
            end
        end
        return
    end

    if invincible then
        invTimer = invTimer + 1
        if invTimer > INVINCIBILITY_FRAMES then
            invincible = false
        end
    end

    ship.x = wrap(ship.x + ship.dx, w)
    ship.y = wrap(ship.y + ship.dy, h)
    ship.dx = ship.dx * 0.98
    ship.dy = ship.dy * 0.98

    for _, a in ipairs(asteroids) do
        a.x = wrap(a.x + a.dx, w)
        a.y = wrap(a.y + a.dy, h)
    end

    for i=#bullets,1,-1 do
        local b = bullets[i]
        b.x = wrap(b.x + b.dx, w)
        b.y = wrap(b.y + b.dy, h)
        b.ttl = b.ttl - 1
        if b.ttl <= 0 then
            table.remove(bullets, i)
        end
    end

    for i=#bullets,1,-1 do
        local b = bullets[i]
        for j=#asteroids,1,-1 do
            local a = asteroids[j]
            if dist(b.x, b.y, a.x, a.y) <= a.size + 0.5 then
                score = score + 10 * a.size
                table.remove(bullets, i)
                if a.size > 1 then
                    for s=1,2 do
                        spawnAsteroid(asteroids, a.size-1, a.x, a.y, random()*1.2+0.4)
                    end
                end
                table.remove(asteroids, j)
                break
            end
        end
    end

    if not invincible then
        for _, a in ipairs(asteroids) do
            if dist(ship.x, ship.y, a.x, a.y) <= a.size + 0.5 then
                lives = lives - 1
                if lives > 0 then
                    isDead = true
                    respawnTimer = 0
                end
                if lives == 0 then
                    isDead = true
                    isRunning = false
                end
                return
            end
        end
    end

    if #asteroids == 0 then
        spawnWave(math.min(3 + math.floor(score/200), 7))
    end
end

local function updateMenuAsteroids()
    for _, a in ipairs(menuAsteroids) do
        a.x = wrap(a.x + a.dx, w)
        a.y = wrap(a.y + a.dy, h)
    end
end

math.randomseed(os.epoch("utc"))
initMenuAsteroids()
clear()
draw()
sleep(0.3)

while not quitRequested do
    inMenu = true
    isRunning = false
    isDead = false
    respawnTimer = 0
    invincible = false
    invTimer = 0
    draw()
    local function menuThread()
        while inMenu and not quitRequested do
            updateMenuAsteroids()
            draw()
            sleep(0.09)
        end
    end
    local function menuInputThread()
        getMenuInput()
    end
    parallel.waitForAny(menuThread, menuInputThread)
    if quitRequested then break end

    clear()
    draw()
    sleep(0.4)
    local function inputThread()
        while isRunning and not quitRequested do
            getGameInput()
        end
    end
    local function gameThread()
        while (isRunning or isDead) and not quitRequested do
            update()
            draw()
            sleep(0.08)
        end
        inMenu = true
        initMenuAsteroids()
    end
    parallel.waitForAny(gameThread, inputThread)
end
clear()
term.setCursorPos(1,1)
