-- Klondike Solitaire (CC:Tweaked, 100x52 advanced monitor)
-- Features: Auto-complete, animated, 5 cards/sec, hints, leaderboard, undo, sound, name entry, no omissions.

local leaderboardFile = "/solitaire_leaderboard.dat"

local monitorSide = "top"
local mon = peripheral.wrap(monitorSide)
mon.setTextScale(0.5)
local w, h = mon.getSize()

local SPEAKER = peripheral.find and peripheral.find("speaker") or nil
local function playTick()
    if SPEAKER then
        SPEAKER.playNote("hat", 1, 15)
    end
end

local function clear()
    mon.setBackgroundColor(colors.green)
    mon.clear()
end

local CARD_W, CARD_H = 7, 5
local TABLEAU_COLS = 7
local TABLEAU_X = 3
local TABLEAU_Y = 7
local TABLEAU_SPACING_X = CARD_W + 2
local TABLEAU_OVERLAP = 2
local FOUNDATION_X = w - (CARD_W + 2) * 4 - 2
local FOUNDATION_Y = 2
local FOUNDATION_SPACING = CARD_W + 2
local STOCK_X, STOCK_Y = 3, 2
local WASTE_X, WASTE_Y = STOCK_X + CARD_W + 4, 2
local RELOAD_BTN_X = WASTE_X + CARD_W + 2
local RELOAD_BTN_Y = STOCK_Y + math.floor(CARD_H/2)
local UNDO_BTN_X = RELOAD_BTN_X + 5
local UNDO_BTN_Y = RELOAD_BTN_Y
local HINT_BTN_X = UNDO_BTN_X + 5
local HINT_BTN_Y = UNDO_BTN_Y

local LEADER_X = w - 23
local LEADER_Y = 24

local SUITS = {"H", "D", "C", "S"}
local SUIT_SYMBOL = {H = "\3", D = "\4", C = "\5", S = "\6"}
local SUIT_COLOR = {H = colors.red, D = colors.red, C = colors.black, S = colors.black}
local RANKS = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}
local COLOR = {H = "red", D = "red", C = "black", S = "black"}

local GAME = {
    deck = {},
    waste = {},
    tableau = {},
    foundation = {H={},D={},C={},S={}},
    selected = nil,
    moveStack = nil,
    score = 0,
    startTime = os.epoch("utc"),
    gameOver = false,
    won = false,
    undoStack = {},
    showLeaderboard = "score",
    winEntry = nil,
    hint = nil,
    noMovePopup = false
}

----------------------
-- Utilities
----------------------
local function deepcopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local t = {}
    for k,v in pairs(tbl) do t[k] = deepcopy(v) end
    return t
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function formatTimeVal(t)
    t = tonumber(t or 0)
    local m = math.floor(t/60)
    local s = t%60
    return string.format("%02d:%02d", m, s)
end
local function formatTime(utcms)
    local t = math.floor((utcms - GAME.startTime)/1000)
    return formatTimeVal(t)
end
local function getElapsed()
    return math.floor((os.epoch("utc") - GAME.startTime)/1000)
end

----------------------
-- Score/Points Event Handler
----------------------
local function scoreEvent(ev)
    local evMap = {
        ["moveToFoundation"] = 10,
        ["flipTableau"] = 5,
        ["wasteToFoundation"] = 10,
        ["turnStock"] = -2,
        ["reloadDeck"] = 0,
        ["undo"] = -2,
    }
    GAME.score = GAME.score + (evMap[ev] or 0)
end

----------------------
-- Leaderboards
----------------------
local function readLeaderboards()
    local ok, tbl = pcall(function()
        if fs.exists(leaderboardFile) then
            local f = fs.open(leaderboardFile, "r")
            local data = textutils.unserialize(f.readAll())
            f.close()
            return data or {scoreList={}, timeList={}}
        else return {scoreList={}, timeList={}} end
    end)
    if ok and tbl then
        tbl.scoreList = tbl.scoreList or {}
        tbl.timeList = tbl.timeList or {}
        return tbl
    else
        return {scoreList={}, timeList={}}
    end
end

local function saveLeaderboards(data)
    local f = fs.open(leaderboardFile, "w")
    f.write(textutils.serialize(data))
    f.close()
end

local function insertLeaderboardEntry(name, score, time)
    local lb = readLeaderboards()
    table.insert(lb.scoreList, {name=name, score=score, time=time})
    table.sort(lb.scoreList, function(a,b)
        if a.score == b.score then return a.time < b.time end
        return a.score > b.score
    end)
    while #lb.scoreList > 10 do table.remove(lb.scoreList) end
    table.insert(lb.timeList, {name=name, score=score, time=time})
    table.sort(lb.timeList, function(a,b)
        if a.time == b.time then return a.score > b.score end
        return a.time < b.time
    end)
    while #lb.timeList > 10 do table.remove(lb.timeList) end
    saveLeaderboards(lb)
end

----------------------
-- Game Setup
----------------------
local function buildDeck()
    local cards = {}
    for _,s in ipairs(SUITS) do
        for i,rank in ipairs(RANKS) do
            table.insert(cards, {
                rank = rank,
                value = i,
                suit = s,
                color = COLOR[s],
                revealed = false,
                id = s..rank
            })
        end
    end
    return cards
end

local function newGame()
    GAME.deck = {}
    GAME.waste = {}
    GAME.tableau = {}
    GAME.foundation = {H={},D={},C={},S={}}
    GAME.selected = nil
    GAME.moveStack = nil
    GAME.score = 0
    GAME.startTime = os.epoch("utc")
    GAME.gameOver = false
    GAME.won = false
    GAME.undoStack = {}
    GAME.winEntry = nil
    GAME.hint = nil
    GAME.noMovePopup = false

    local rawDeck = buildDeck()
    local fullDeck = {}
    for i=1, #rawDeck do
        if type(rawDeck[i]) == "table" then
            table.insert(fullDeck, deepcopy(rawDeck[i]))
        end
    end
    shuffle(fullDeck)

    local idx = 1
    for col=1,7 do
        GAME.tableau[col] = {}
        for row=1,col do
            local card = fullDeck[idx]
            if type(card) == "table" then
                if row == col then card.revealed = true end
                table.insert(GAME.tableau[col], card)
            end
            idx = idx + 1
        end
    end
    for i=idx,#fullDeck do
        local card = fullDeck[i]
        if type(card) == "table" then
            table.insert(GAME.deck, card)
        end
    end
end

----------------------
-- Move/Selection/Hint/AutoComplete Logic
----------------------

local function isRed(suit) return suit == "H" or suit == "D" end
local function canMoveTableau(source, dest)
    if type(source) ~= "table" or (dest and type(dest) ~= "table") then return false end
    if not dest then
        return source.rank == "K"
    end
    if isRed(source.suit) == isRed(dest.suit) then return false end
    return source.value == dest.value - 1
end

local function canMoveToFoundation(card, pile)
    if type(card) ~= "table" then return false end
    if #pile == 0 then
        return card.rank == "A"
    end
    local top = pile[#pile]
    return type(top) == "table" and card.suit == top.suit and card.value == top.value + 1
end

local function stackValid(cards)
    for i=1,#cards-1 do
        if type(cards[i]) ~= "table" or type(cards[i+1]) ~= "table" then return false end
        if not cards[i].revealed or not cards[i+1].revealed then return false end
        if isRed(cards[i].suit) == isRed(cards[i+1].suit) then return false end
        if cards[i].value ~= cards[i+1].value + 1 then return false end
    end
    return true
end

local function revealTopTableau()
    for col=1,7 do
        local pile = GAME.tableau[col]
        if #pile > 0 then
            local card = pile[#pile]
            if type(card) == "table" and not card.revealed then
                card.revealed = true
                scoreEvent("flipTableau")
            end
        end
    end
end

local function checkWin()
    for _, pile in pairs(GAME.foundation) do
        if #pile < 13 then return false end
    end
    return true
end

local function wouldReloadAllowMove()
    if #GAME.deck > 0 or #GAME.waste == 0 then return false end
    local simDeck = {}
    for i=#GAME.waste,1,-1 do
        local card = deepcopy(GAME.waste[i])
        card.revealed = false
        table.insert(simDeck, card)
    end
    for i=#simDeck,1,-1 do
        local card = deepcopy(simDeck[i])
        card.revealed = true
        for _, s in ipairs(SUITS) do
            if canMoveToFoundation(card, GAME.foundation[s]) and card.suit == s then
                return true
            end
        end
        for col=1,7 do
            local pile = GAME.tableau[col]
            if (#pile == 0 and card.rank == "K") or (#pile > 0 and canMoveTableau(card, pile[#pile])) then
                return true
            end
        end
    end
    return false
end

local function findFirstLegalMove()
    if #GAME.waste > 0 then
        local w = GAME.waste[#GAME.waste]
        for _, s in ipairs(SUITS) do
            if canMoveToFoundation(w, GAME.foundation[s]) and w.suit == s then
                return {type="wasteToFoundation", from="waste", idx=#GAME.waste, suit=s}
            end
        end
        for col=1,7 do
            local pile = GAME.tableau[col]
            if (#pile == 0 and w.rank == "K") or (#pile > 0 and canMoveTableau(w, pile[#pile])) then
                return {type="wasteToTableau", from="waste", idx=#GAME.waste, col=col}
            end
        end
    end
    for col=1,7 do
        local pile = GAME.tableau[col]
        if #pile > 0 then
            local t = pile[#pile]
            for _, s in ipairs(SUITS) do
                if canMoveToFoundation(t, GAME.foundation[s]) and t.suit == s then
                    return {type="tableauToFoundation", from="tableau", col=col, idx=#pile, suit=s}
                end
            end
        end
    end
    for srcCol=1,7 do
        local pile = GAME.tableau[srcCol]
        for row=1,#pile do
            local card = pile[row]
            if card.revealed then
                local stack = {}
                for i=row,#pile do table.insert(stack, pile[i]) end
                if stackValid(stack) then
                    local revealsHidden = (row > 1) and (not pile[row-1].revealed)
                    for destCol=1,7 do
                        if destCol ~= srcCol then
                            local destPile = GAME.tableau[destCol]
                            if #destPile == 0 and card.rank == "K" then
                                if revealsHidden then
                                    return {type="moveTableau", fromCol=srcCol, srcIdx=row, toCol=destCol, stackSize=#stack}
                                end
                            elseif #destPile > 0 and canMoveTableau(card, destPile[#destPile]) and revealsHidden then
                                return {type="moveTableau", fromCol=srcCol, srcIdx=row, toCol=destCol, stackSize=#stack}
                            end
                        end
                    end
                end
            end
        end
    end
    if #GAME.deck > 0 then
        return {type="drawFromStock"}
    end
    if wouldReloadAllowMove() then
        return {type="reloadStock"}
    end
    return nil
end

local function anyMovesLeft()
    return findFirstLegalMove() ~= nil
end

-- AUTO COMPLETE FEATURE
local function canAutoComplete()
    if #GAME.deck > 0 or #GAME.waste > 0 then return false end
    for col=1,7 do
        for _,card in ipairs(GAME.tableau[col]) do
            if not card.revealed then return false end
        end
    end
    for col=1,7 do if #GAME.tableau[col] > 0 then return true end end
    return false
end

-- === IMPROVED AUTO COMPLETE, 1 CARD AT A TIME, 5 CARDS/SEC ===
local function canAutoComplete()
    if #GAME.deck > 0 or #GAME.waste > 0 then return false end
    for col=1,7 do
        for _,card in ipairs(GAME.tableau[col]) do
            if not card.revealed then return false end
        end
    end
    for col=1,7 do if #GAME.tableau[col] > 0 then return true end end
    return false
end

local function autoCompleteStep()
    -- Only move one card per call, always topmost eligible
    for col=1,7 do
        local pile = GAME.tableau[col]
        if #pile > 0 and pile[#pile].revealed then
            local card = pile[#pile]
            local s = card.suit
            if canMoveToFoundation(card, GAME.foundation[s]) then
                table.insert(GAME.foundation[s], card)
                table.remove(pile)
                scoreEvent("moveToFoundation")
                revealTopTableau()
                return true
            end
        end
    end
    return false
end

local function doAutoComplete()
    while canAutoComplete() do
        sleep(0.2) -- 5 cards per second
        if autoCompleteStep() then
            redraw()
            playTick()
        else
            break
        end
    end
    if checkWin() then
        GAME.winEntry = {
            chars = {"A","A","A"},
            score = GAME.score,
            time = getElapsed()
        }
        redraw()
    end
end

----------------------
-- Drawing Functions (UI)
----------------------

local function drawBlueBorder(x, y)
    mon.setBackgroundColor(colors.blue)
    for dy = -1, CARD_H do
        mon.setCursorPos(x-1, y+dy)
        mon.write(" ")
        mon.setCursorPos(x+CARD_W, y+dy)
        mon.write(" ")
    end
    for dx = -1, CARD_W do
        mon.setCursorPos(x+dx, y-1)
        mon.write(" ")
        mon.setCursorPos(x+dx, y+CARD_H)
        mon.write(" ")
    end
end

local function drawBlueUnderline(x, y)
    mon.setBackgroundColor(colors.blue)
    mon.setCursorPos(x-1, y+CARD_H)
    mon.write((" "):rep(CARD_W+2))
end

local function drawAsciiCard(x, y, card, highlight, hint, blueBorder)
    if type(card) ~= "table" then return end
    local bg = card.revealed and colors.white or colors.lightGray
    local shadow_col = colors.gray
    for dx=0, CARD_W-1 do
        mon.setBackgroundColor(shadow_col)
        mon.setCursorPos(x+dx+1, y+CARD_H)
        mon.write("_")
    end
    for dy=0, CARD_H-1 do
        mon.setBackgroundColor(shadow_col)
        mon.setCursorPos(x+CARD_W, y+dy+1)
        mon.write("|")
    end
    for dy=0,CARD_H-1 do
        mon.setBackgroundColor(bg)
        mon.setCursorPos(x, y+dy)
        if dy==0 then
            mon.write("_"..("_"):rep(CARD_W-2).."_")
        elseif dy==CARD_H-1 then
            mon.write("|"..("_"):rep(CARD_W-2).."|")
        else
            mon.write("|")
            for dx=2,CARD_W-1 do mon.write(" ") end
            mon.write("|")
        end
    end
    if highlight then
        mon.setBackgroundColor(colors.yellow)
        for dy=0,CARD_H-1 do
            mon.setCursorPos(x-1, y+dy)
            mon.write(" ")
            mon.setCursorPos(x+CARD_W, y+dy)
            mon.write(" ")
        end
    end
    if blueBorder then
        drawBlueBorder(x, y)
    end
    if card.revealed then
        mon.setTextColor(SUIT_COLOR[card.suit] or colors.black)
        mon.setCursorPos(x+1, y+1)
        mon.write(card.rank)
        mon.setCursorPos(x+CARD_W-2, y+1)
        mon.write(SUIT_SYMBOL[card.suit] or "?")
        mon.setCursorPos(x+1, y+2)
        mon.write(card.suit)
    else
        mon.setTextColor(colors.blue)
        mon.setCursorPos(x+2, y+2)
        mon.write("#####")
    end
end

local function drawEmptyAsciiCard(x, y)
    for dy=0,CARD_H-1 do
        mon.setBackgroundColor(colors.lightGray)
        mon.setCursorPos(x, y+dy)
        if dy==0 then
            mon.write("_"..("_"):rep(CARD_W-2).."_")
        elseif dy==CARD_H-1 then
            mon.write("|"..("_"):rep(CARD_W-2).."|")
        else
            mon.write("|")
            for dx=2,CARD_W-1 do mon.write(" ") end
            mon.write("|")
        end
    end
    mon.setTextColor(colors.gray)
    mon.setCursorPos(x+2, y+2)
    mon.write("[ ]")
end

local function drawSidebar()
    local y = h-3
    mon.setBackgroundColor(colors.green)
    mon.setTextColor(colors.white)
    local title = "Klondike"
    -- Auto-complete button appears above Klondike if allowed
    if canAutoComplete() then
        mon.setBackgroundColor(colors.lime)
        mon.setTextColor(colors.black)
        mon.setCursorPos(math.floor((w-15)/2), y-1)
        mon.write(" [Auto Complete] ")
    else
        -- Blank out the line above if not used
        mon.setBackgroundColor(colors.green)
        mon.setCursorPos(1, y-1)
        mon.write((" "):rep(w))
    end
    mon.setBackgroundColor(colors.green)
    mon.setTextColor(colors.white)
    mon.setCursorPos(math.floor((w-#title)/2), y)
    mon.write(title)
    mon.setCursorPos(w-13, h-3)
    mon.setBackgroundColor(colors.green)
    mon.setTextColor(colors.white)
    mon.write(" New Game ")
end

local function sidebarNewGameHit(x, y)
    return x >= w-13 and x <= w-2 and y == h-3
end

local function autoCompleteBtnHit(x, y)
    local bx = math.floor((w-15)/2)
    local by = h-4
    return canAutoComplete() and y == by and x >= bx and x <= bx+14
end

local function drawTopInfo()
    local mid_x = math.floor(w/2)
    mon.setBackgroundColor(colors.green)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(mid_x-6, 2)
    mon.write("Score: "..tostring(GAME.score))
    mon.setCursorPos(mid_x-6, 3)
    mon.setTextColor(colors.lime)
    mon.write("Time: "..formatTime(os.epoch("utc")))
end

local function drawFoundations()
    for i, s in ipairs(SUITS) do
        local x = FOUNDATION_X + (i-1) * FOUNDATION_SPACING
        local y = FOUNDATION_Y
        local pile = GAME.foundation[s]
        local blueBorder = false
        if GAME.hint and (
            (GAME.hint.type=="wasteToFoundation" and GAME.hint.suit==s) or
            (GAME.hint.type=="tableauToFoundation" and GAME.hint.suit==s)
        ) then
            blueBorder = true
        end
        if #pile == 0 then
            drawEmptyAsciiCard(x, y)
            if blueBorder then drawBlueUnderline(x, y) end
            mon.setTextColor(SUIT_COLOR[s])
            mon.setCursorPos(x+CARD_W-2, y+CARD_H-2)
            mon.write(SUIT_SYMBOL[s])
        else
            mon.setTextColor(SUIT_COLOR[s])
            drawAsciiCard(x, y, pile[#pile], false, false, blueBorder)
            if blueBorder then drawBlueUnderline(x, y) end
        end
    end
end

local function drawStockWaste()
    local blueBorderStock = false
    if GAME.hint and (GAME.hint.type=="drawFromStock" or GAME.hint.type=="reloadStock") then
        blueBorderStock = true
    end
    if #GAME.deck > 0 and type(GAME.deck[#GAME.deck]) == "table" then
        local topCard = GAME.deck[#GAME.deck]
        topCard.revealed = false
        drawAsciiCard(STOCK_X, STOCK_Y, topCard, false, false, blueBorderStock)
    else
        drawEmptyAsciiCard(STOCK_X, STOCK_Y)
        if blueBorderStock then drawBlueUnderline(STOCK_X, STOCK_Y) end
    end
    -- Waste
    local blueBorderWaste = false
    if GAME.hint and (
        (GAME.hint.type=="wasteToTableau" and GAME.hint.from=="waste") or
        (GAME.hint.type=="wasteToFoundation" and GAME.hint.from=="waste")
    ) then
        blueBorderWaste = true
    end
    if #GAME.waste > 0 and type(GAME.waste[#GAME.waste]) == "table" then
        drawAsciiCard(WASTE_X, WASTE_Y, GAME.waste[#GAME.waste], GAME.selected and GAME.selected.from == "waste", false, blueBorderWaste)
    else
        drawEmptyAsciiCard(WASTE_X, WASTE_Y)
        if blueBorderWaste then drawBlueUnderline(WASTE_X, WASTE_Y) end
    end
end

local function drawReloadButton()
    if #GAME.deck == 0 and #GAME.waste > 0 then
        mon.setBackgroundColor(colors.lightGray)
        mon.setTextColor(colors.green)
        mon.setCursorPos(RELOAD_BTN_X, RELOAD_BTN_Y)
        mon.write("[R]")
    else
        mon.setBackgroundColor(colors.green)
        mon.setCursorPos(RELOAD_BTN_X, RELOAD_BTN_Y)
        mon.write("   ")
    end
end

local function drawUndoButton()
    mon.setBackgroundColor(colors.lightGray)
    mon.setTextColor(colors.orange)
    mon.setCursorPos(UNDO_BTN_X, UNDO_BTN_Y)
    mon.write("[U]")
end

local function drawHintButton()
    mon.setBackgroundColor(colors.lightGray)
    mon.setTextColor(colors.blue)
    mon.setCursorPos(HINT_BTN_X, HINT_BTN_Y)
    mon.write("[H]")
end

local function drawTableau()
    local move = GAME.hint
    for col=1,7 do
        local pile = GAME.tableau[col]
        local baseX = TABLEAU_X + (col-1)*TABLEAU_SPACING_X
        local baseY = TABLEAU_Y
        for row, card in ipairs(pile) do
            local y = baseY + (row-1)*TABLEAU_OVERLAP
            local highlight = false
            if GAME.selected and GAME.selected.from == "tableau" and GAME.selected.col == col and GAME.selected.idx == row then
                highlight = true
            end
            if GAME.moveStack and GAME.moveStack.srcCol == col and row >= GAME.moveStack.srcIdx then
                highlight = true
            end
            local blueBorder = false
            if move then
                if move.type == "moveTableau" and move.fromCol == col and row >= move.srcIdx then
                    blueBorder = true
                elseif move.type == "tableauToFoundation" and move.col == col and row == #pile then
                    blueBorder = true
                end
            end
            drawAsciiCard(baseX, y, card, highlight, false, blueBorder)
        end
        if #pile == 0 then
            drawEmptyAsciiCard(baseX, baseY)
        end
        if move then
            if (move.type == "moveTableau" and move.toCol == col) or (move.type == "wasteToTableau" and move.col == col) then
                drawBlueUnderline(baseX, baseY + (#pile-1)*TABLEAU_OVERLAP)
            end
        end
    end
end

local function drawLeaderboard()
    local lb = readLeaderboards()
    local entries
    local scoreCol, timeCol = "white", "white"
    if GAME.showLeaderboard == "score" then
        entries = lb.scoreList or {}
        scoreCol = "lime"
    else
        entries = lb.timeList or {}
        timeCol = "lime"
    end
    mon.setBackgroundColor(colors.green)
    mon.setCursorPos(LEADER_X, LEADER_Y)
    mon.setTextColor(scoreCol == "lime" and colors.lime or colors.white)
    mon.write("Score")
    mon.setTextColor(colors.white)
    mon.write(" / ")
    mon.setTextColor(timeCol == "lime" and colors.lime or colors.white)
    mon.write("Time")
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(LEADER_X, LEADER_Y+1)
    mon.write("NAME   SCORE   TIME")
    for i = 1, 10 do
        local entry = entries[i]
        if entry then
            mon.setTextColor(colors.white)
            mon.setCursorPos(LEADER_X, LEADER_Y+1+i)
            mon.write(string.format("%-3s", entry.name or ""))
            mon.setCursorPos(LEADER_X+6, LEADER_Y+1+i)
            mon.write(string.format("%-5d", entry.score or 0))
            mon.setCursorPos(LEADER_X+14, LEADER_Y+1+i)
            mon.write(formatTimeVal(entry.time or 0))
        end
    end
end

local function leaderScoreHit(x, y)
    return x >= LEADER_X and x < LEADER_X+5 and y == LEADER_Y
end
local function leaderTimeHit(x, y)
    return x >= LEADER_X+8 and x < LEADER_X+12 and y == LEADER_Y
end

local function redraw()
    clear()
    drawTopInfo()
    drawStockWaste()
    drawReloadButton()
    drawUndoButton()
    drawHintButton()
    drawFoundations()
    drawTableau()
    drawSidebar()
    drawLeaderboard()
    if GAME.noMovePopup then
        local popupW = 32
        local popupH = 7
        local px = math.floor((w-popupW)/2)
        local py = math.floor((h-popupH)/2)
        for dy=0,popupH-1 do
            mon.setBackgroundColor(colors.gray)
            mon.setCursorPos(px, py+dy)
            mon.write((" "):rep(popupW))
        end
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.red)
        mon.setCursorPos(px+6, py+1)
        mon.write("No more moves left!")
        mon.setTextColor(colors.white)
        mon.setCursorPos(px+4, py+3)
        mon.write("Undo moves or Start a new game?")
        mon.setBackgroundColor(colors.orange)
        mon.setTextColor(colors.black)
        mon.setCursorPos(px+6, py+5)
        mon.write(" [Undo] ")
        mon.setBackgroundColor(colors.green)
        mon.setTextColor(colors.black)
        mon.setCursorPos(px+19, py+5)
        mon.write(" [Restart] ")
    end
    if GAME.winEntry then
        local popupW = 26
        local popupH = 7
        local px = math.floor((w-popupW)/2)
        local py = math.floor((h-popupH)/2)
        for dy=0,popupH-1 do
            mon.setBackgroundColor(colors.lightGray)
            mon.setCursorPos(px, py+dy)
            mon.write((" "):rep(popupW))
        end
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.yellow)
        mon.setCursorPos(px+7, py+1)
        mon.write("Congratulations!")
        mon.setCursorPos(px+3, py+3)
        mon.setTextColor(colors.white)
        mon.write("Enter Your Name:")
        -- Draw name entry boxes, more centered
        local name_start = px + 10
        for i=1,3 do
            mon.setBackgroundColor(colors.white)
            mon.setTextColor(colors.black)
            mon.setCursorPos(name_start+(i-1)*2, py+4)
            mon.write(GAME.winEntry.chars[i] or "_")
        end
        mon.setBackgroundColor(colors.lime)
        mon.setTextColor(colors.black)
        mon.setCursorPos(px+9, py+6)
        mon.write("   [OK]   ")
    end
end

----------------------
-- Input/Hitboxes
----------------------
local function deckHitbox(x, y)
    return x >= STOCK_X and x < STOCK_X + CARD_W and y >= STOCK_Y and y < STOCK_Y + CARD_H
end

local function reloadBtnHitbox(x, y)
    return x >= RELOAD_BTN_X and x <= RELOAD_BTN_X+2 and y == RELOAD_BTN_Y
end

local function undoBtnHitbox(x, y)
    return x >= UNDO_BTN_X and x <= UNDO_BTN_X+2 and y == UNDO_BTN_Y
end

local function hintBtnHitbox(x, y)
    return x >= HINT_BTN_X and x <= HINT_BTN_X+2 and y == HINT_BTN_Y
end

local function wasteHitbox(x, y)
    return x >= WASTE_X and x < WASTE_X + CARD_W and y >= WASTE_Y and y < WASTE_Y + CARD_H
end

----------------------
-- Undo Logic
----------------------
local function pushUndoMove(data)
    table.insert(GAME.undoStack, data)
end

local function undoMove()
    local m = table.remove(GAME.undoStack)
    if not m then return end
    if m.type == "draw" then
        local card = table.remove(GAME.waste)
        if card then
            card.revealed = false
            table.insert(GAME.deck, card)
        end
    elseif m.type == "reload" then
        for i = #GAME.deck,1,-1 do
            local card = table.remove(GAME.deck, i)
            if card then
                card.revealed = true
                table.insert(GAME.waste, card)
            end
        end
    elseif m.type == "moveTableau" then
        local destPile = GAME.tableau[m.toCol]
        for i=1, m.count do table.remove(destPile) end
        local srcPile = GAME.tableau[m.fromCol]
        for _, card in ipairs(m.originalStack) do
            table.insert(srcPile, deepcopy(card))
        end
        if m.flippedCard and m.flippedCardIdx then
            local pile = GAME.tableau[m.fromCol]
            if pile[m.flippedCardIdx] then
                pile[m.flippedCardIdx].revealed = false
            end
        end
    elseif m.type == "tableauToFoundation" then
        local pile = GAME.foundation[m.suit]
        local card = table.remove(pile)
        if card then
            table.insert(GAME.tableau[m.fromCol], card)
            if m.flippedCard and m.flippedCardIdx then
                local tPile = GAME.tableau[m.fromCol]
                if tPile[m.flippedCardIdx] then
                    tPile[m.flippedCardIdx].revealed = false
                end
            end
        end
    elseif m.type == "wasteToTableau" then
        local card = table.remove(GAME.tableau[m.col])
        if card then
            card.revealed = true
            table.insert(GAME.waste, card)
        end
    elseif m.type == "wasteToFoundation" then
        local card = table.remove(GAME.foundation[m.suit])
        if card then
            card.revealed = true
            table.insert(GAME.waste, card)
        end
    end
    scoreEvent("undo")
    redraw()
end

----------------------
-- Input/Hint/Popup Handling, Move/Selection Logic
----------------------

local function showHint()
    local move = findFirstLegalMove()
    if move then
        GAME.hint = move
        redraw()
        sleep(1.5)
        GAME.hint = nil
        redraw()
        playTick()
    else
        playTick()
    end
end

local function checkNoMoves()
    if not anyMovesLeft() then
        GAME.noMovePopup = true
        redraw()
        return true
    end
    return false
end

local function handleNoMovePopup(x, y)
    local popupW = 32
    local popupH = 7
    local px = math.floor((w-popupW)/2)
    local py = math.floor((h-popupH)/2)
    if y == py+5 and x >= px+6 and x <= px+13 then
        GAME.noMovePopup = false
        playTick()
        undoMove()
        if not anyMovesLeft() then
            GAME.noMovePopup = true
        end
        redraw()
        return
    elseif y == py+5 and x >= px+19 and x <= px+27 then
        GAME.noMovePopup = false
        playTick()
        newGame()
        redraw()
        return
    end
end

local function selectAt(x, y)
    if autoCompleteBtnHit(x, y) then
        doAutoComplete()
        return
    end

    if GAME.noMovePopup then
        handleNoMovePopup(x, y)
        return
    end
    if GAME.winEntry then
        local popupW = 26
        local popupH = 7
        local px = math.floor((w-popupW)/2)
        local py = math.floor((h-popupH)/2)
        local name_start = px + 10
        for i=1,3 do
            if y == py+4 and x >= name_start+(i-1)*2 and x <= name_start+(i-1)*2+1 then
                local c = GAME.winEntry.chars[i] or "A"
                local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
                local idx = chars:find(c,1,true) or 1
                idx = idx + 1
                if idx > #chars then idx = 1 end
                GAME.winEntry.chars[i] = chars:sub(idx,idx)
                redraw()
                return
            end
        end
        if y == py+6 and x >= px+9 and x <= px+15 then
            if #GAME.winEntry.chars == 3 then
                local name = table.concat(GAME.winEntry.chars)
                local score = GAME.score
                local time = getElapsed()
                insertLeaderboardEntry(name, score, time)
                GAME.winEntry = nil
                newGame()
                redraw()
                return
            end
        end
        return
    end

    if deckHitbox(x, y) then
        if #GAME.deck > 0 then
            local card = table.remove(GAME.deck)
            if type(card) == "table" then
                card.revealed = true
                table.insert(GAME.waste, card)
                pushUndoMove({type="draw"})
                GAME.selected = nil
                GAME.moveStack = nil
                scoreEvent("turnStock")
                redraw()
                playTick()
                checkNoMoves()
            end
        end
        return
    end
    if reloadBtnHitbox(x, y) then
        if #GAME.deck == 0 and #GAME.waste > 0 then
            local movedCards = {}
            while #GAME.waste > 0 do
                local card = table.remove(GAME.waste)
                if type(card) == "table" then
                    card.revealed = false
                    table.insert(GAME.deck, card)
                    table.insert(movedCards, 1, card)
                end
            end
            pushUndoMove({type="reload", cards=movedCards})
            scoreEvent("reloadDeck")
            GAME.selected = nil
            GAME.moveStack = nil
            redraw()
            playTick()
            checkNoMoves()
        end
        return
    end
    if undoBtnHitbox(x, y) then
        undoMove()
        playTick()
        checkNoMoves()
        return
    end
    if hintBtnHitbox(x, y) then
        showHint()
        return
    end
    if leaderScoreHit(x, y) then
        GAME.showLeaderboard = "score"
        redraw()
        playTick()
        return
    end
    if leaderTimeHit(x, y) then
        GAME.showLeaderboard = "time"
        redraw()
        playTick()
        return
    end
    if wasteHitbox(x, y) then
        if #GAME.waste > 0 then
            if GAME.selected and GAME.selected.from == "waste" then
                GAME.selected = nil
                GAME.moveStack = nil
            else
                GAME.selected = {from = "waste", idx = #GAME.waste}
                GAME.moveStack = nil
            end
            redraw()
            playTick()
        end
        return
    end
    for i, s in ipairs(SUITS) do
        local fx = FOUNDATION_X + (i-1)*FOUNDATION_SPACING
        if x >= fx and x < fx+CARD_W and y >= FOUNDATION_Y and y < FOUNDATION_Y+CARD_H then
            GAME.selected = {from = "foundation", suit = s}
            GAME.moveStack = nil
            redraw()
            playTick()
            return
        end
    end
    for col=1,7 do
        local baseX = TABLEAU_X + (col-1)*TABLEAU_SPACING_X
        local baseY = TABLEAU_Y
        local pile = GAME.tableau[col]
        for row=#pile,1,-1 do
            local cardY = baseY + (row-1)*TABLEAU_OVERLAP
            if x >= baseX and x < baseX+CARD_W and y >= cardY and y < cardY+CARD_H then
                if type(pile[row]) == "table" and pile[row].revealed then
                    local stack = {}
                    for i=row,#pile do table.insert(stack, pile[i]) end
                    if stackValid(stack) then
                        GAME.moveStack = {cards = deepcopy(stack), srcCol = col, srcIdx = row}
                    else
                        GAME.moveStack = nil
                    end
                    GAME.selected = {from="tableau", col=col, idx=row}
                    redraw()
                    playTick()
                    return
                end
            end
        end
        if #pile == 0 and x >= baseX and x < baseX+CARD_W and y >= baseY and y < baseY+CARD_H then
            GAME.selected = {from="tableau", col=col, idx=0}
            GAME.moveStack = nil
            redraw()
            playTick()
            return
        end
    end
    if GAME.selected then
        GAME.selected = nil
        GAME.moveStack = nil
        redraw()
        playTick()
    end
end

local function moveSelectedTo(x, y)
    if GAME.noMovePopup or GAME.winEntry then return end
    for i, s in ipairs(SUITS) do
        local fx = FOUNDATION_X + (i-1)*FOUNDATION_SPACING
        if x >= fx and x < fx+CARD_W and y >= FOUNDATION_Y and y < FOUNDATION_Y+CARD_H then
            if GAME.selected.from == "tableau" then
                local col, idx = GAME.selected.col, GAME.selected.idx
                local pile = GAME.tableau[col]
                if idx == #pile then
                    local card = pile[idx]
                    if canMoveToFoundation(card, GAME.foundation[s]) and card.suit == s then
                        table.insert(GAME.foundation[s], card)
                        table.remove(pile, idx)
                        local flippedCard, flippedCardIdx
                        if #pile > 0 and not pile[#pile].revealed then
                            flippedCard = pile[#pile]
                            flippedCardIdx = #pile
                            pile[#pile].revealed = true
                        end
                        pushUndoMove({type="tableauToFoundation", suit=s, fromCol=col, flippedCard=flippedCard, flippedCardIdx=flippedCardIdx})
                        scoreEvent("moveToFoundation")
                        revealTopTableau()
                        GAME.selected = nil
                        GAME.moveStack = nil
                        redraw()
                        playTick()
                        if checkWin() then
                            GAME.winEntry = {
                                chars = {},
                                score = GAME.score,
                                time = getElapsed()
                            }
                            redraw()
                        else
                            checkNoMoves()
                        end
                        return
                    end
                end
            end
            if GAME.selected.from == "waste" then
                local card = GAME.waste[#GAME.waste]
                if canMoveToFoundation(card, GAME.foundation[s]) and card.suit == s then
                    table.insert(GAME.foundation[s], card)
                    table.remove(GAME.waste)
                    pushUndoMove({type="wasteToFoundation", suit=s})
                    scoreEvent("wasteToFoundation")
                    GAME.selected = nil
                    GAME.moveStack = nil
                    redraw()
                    playTick()
                    if checkWin() then
                        GAME.winEntry = {
                            chars = {},
                            score = GAME.score,
                            time = getElapsed()
                        }
                        redraw()
                    else
                        checkNoMoves()
                    end
                    return
                end
            end
            return
        end
    end
    for col=1,7 do
        local baseX = TABLEAU_X + (col-1)*TABLEAU_SPACING_X
        local baseY = TABLEAU_Y
        local pile = GAME.tableau[col]
        for row=#pile,1,-1 do
            local cardY = baseY + (row-1)*TABLEAU_OVERLAP
            if x >= baseX and x < baseX+CARD_W and y >= cardY and y < cardY+CARD_H then
                if GAME.selected.from == "waste" then
                    local moving = GAME.waste[#GAME.waste]
                    if moving and ((#pile==0 and moving.rank=="K") or (#pile>0 and canMoveTableau(moving, pile[#pile]))) then
                        table.insert(pile, moving)
                        table.remove(GAME.waste)
                        pushUndoMove({type="wasteToTableau", col=col})
                        scoreEvent("wasteToTableau")
                        revealTopTableau()
                        GAME.selected = nil
                        GAME.moveStack = nil
                        redraw()
                        playTick()
                        checkNoMoves()
                        return
                    end
                end
                if GAME.selected.from == "tableau" and GAME.moveStack then
                    local srcCol, srcIdx = GAME.moveStack.srcCol, GAME.moveStack.srcIdx
                    if srcCol ~= col then
                        local srcPile = GAME.tableau[srcCol]
                        local moving = {}
                        for i=srcIdx, #srcPile do table.insert(moving, srcPile[i]) end
                        if #moving == #GAME.moveStack.cards then
                            local legal = false
                            if #pile == 0 and moving[1].rank == "K" then
                                legal = true
                            elseif #pile > 0 and canMoveTableau(moving[1], pile[#pile]) then
                                legal = true
                            end
                            if legal then
                                for i=1,#moving do table.insert(pile, moving[i]) end
                                for i=#srcPile,srcIdx,-1 do table.remove(srcPile, i) end
                                local flippedCard, flippedCardIdx
                                if #srcPile > 0 and not srcPile[#srcPile].revealed then
                                    flippedCard = srcPile[#srcPile]
                                    flippedCardIdx = #srcPile
                                    srcPile[#srcPile].revealed = true
                                end
                                pushUndoMove({
                                    type="moveTableau",
                                    fromCol=srcCol,
                                    toCol=col,
                                    count=#moving,
                                    flippedCard=flippedCard,
                                    flippedCardIdx=flippedCardIdx,
                                    originalStack=deepcopy(moving)
                                })
                                revealTopTableau()
                                GAME.selected = nil
                                GAME.moveStack = nil
                                redraw()
                                playTick()
                                checkNoMoves()
                                return
                            end
                        end
                    end
                end
                return
            end
        end
        if #pile == 0 and x >= baseX and x < baseX+CARD_W and y >= baseY and y < baseY+CARD_H then
            if GAME.selected.from == "waste" then
                local moving = GAME.waste[#GAME.waste]
                if moving and moving.rank == "K" then
                    table.insert(pile, moving)
                    table.remove(GAME.waste)
                    pushUndoMove({type="wasteToTableau", col=col})
                    scoreEvent("wasteToTableau")
                    revealTopTableau()
                    GAME.selected = nil
                    GAME.moveStack = nil
                    redraw()
                    playTick()
                    checkNoMoves()
                    return
                end
            elseif GAME.selected.from == "tableau" and GAME.moveStack then
                local srcCol, srcIdx = GAME.moveStack.srcCol, GAME.moveStack.srcIdx
                local srcPile = GAME.tableau[srcCol]
                local moving = {}
                for i=srcIdx, #srcPile do table.insert(moving, srcPile[i]) end
                if moving[1] and moving[1].rank == "K" and #moving == #GAME.moveStack.cards then
                    for i=1,#moving do table.insert(pile, moving[i]) end
                    for i=#srcPile,srcIdx,-1 do table.remove(srcPile, i) end
                    local flippedCard, flippedCardIdx
                    if #srcPile > 0 and not srcPile[#srcPile].revealed then
                        flippedCard = srcPile[#srcPile]
                        flippedCardIdx = #srcPile
                        srcPile[#srcPile].revealed = true
                    end
                    pushUndoMove({
                        type="moveTableau",
                        fromCol=srcCol,
                        toCol=col,
                        count=#moving,
                        flippedCard=flippedCard,
                        flippedCardIdx=flippedCardIdx,
                        originalStack=deepcopy(moving)
                    })
                    revealTopTableau()
                    GAME.selected = nil
                    GAME.moveStack = nil
                    redraw()
                    playTick()
                    checkNoMoves()
                    return
                end
            end
        end
    end
    GAME.selected = nil
    GAME.moveStack = nil
    redraw()
    playTick()
end

----------------------
-- Main Event Loop
----------------------
local function waitForTouch()
    while true do
        local ev, side, x, y = os.pullEvent("monitor_touch")
        if sidebarNewGameHit(x, y) then
            newGame()
            redraw()
            playTick()
        elseif not GAME.selected then
            selectAt(x, y)
        else
            moveSelectedTo(x, y)
        end
    end
end

math.randomseed(os.epoch("utc"))
newGame()
redraw()

parallel.waitForAny(
    waitForTouch,
    function() while true do sleep(1) redraw() end end
)
