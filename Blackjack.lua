-- blackjack.lua
-- Complete Blackjack game with:
-- - Split integrated in main button row
-- - Bust animation shows final card
-- - Dealer only reveals after all hands
-- - 5s natural blackjack delay
-- - Debug mode
-- - Safe outcome sorting

-- Find monitor
local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
local monX, monY = monitor.getSize()
monitor.setBackgroundColor(colors.green)
monitor.clear()

-- Constants
local suits = {"H","D","C","S"}
local ranks = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}

-- Stats
local wins, losses, ties = 0,0,0

-- Game State
local deck = {}

-- Utilities
local function shuffleDeck()
  deck = {}
  for d=1,6 do
    for _,suit in ipairs(suits) do
      for _,rank in ipairs(ranks) do
        table.insert(deck, {suit=suit, rank=rank})
      end
    end
  end
  for i=#deck,2,-1 do
    local j=math.random(i)
    deck[i],deck[j]=deck[j],deck[i]
  end
end

local function drawCard()
  return table.remove(deck)
end

local function handValue(hand)
  local total, aces = 0,0
  for _,c in ipairs(hand) do
    if c.rank=="A" then total=total+11; aces=aces+1
    elseif c.rank=="10" or c.rank=="J" or c.rank=="Q" or c.rank=="K" then total=total+10
    else total=total+tonumber(c.rank) end
  end
  while total>21 and aces>0 do total=total-10; aces=aces-1 end
  return total
end

local function waitForTouch()
  while true do
    local _,_,x,y = os.pullEvent("monitor_touch")
    return x,y
  end
end

local function drawButton(label,x,y,w,h)
  monitor.setCursorPos(x + math.ceil((w-#label)/2), y + math.floor(h/2))
  monitor.setBackgroundColor(colors.green)
  monitor.setTextColor(colors.white)
  monitor.write(label)
end

local function drawCardGraphic(card,x,y,hidden)
  local lines
  if hidden then
    lines = {
      "+--------+","|********|","|********|","|********|",
      "|********|","|********|","|********|","+--------+"
    }
  else
    local r = #card.rank==1 and " "..card.rank or card.rank
    lines = {
      "+--------+",
      "|"..r.."     "..card.suit.."|",
      "|        |",
      "|        |",
      "|   "..r.."   |",
      "|        |",
      "|        |",
      "+--------+"
    }
  end
  for i,l in ipairs(lines) do
    monitor.setCursorPos(x,y+i-1)
    monitor.setBackgroundColor(colors.white)
    monitor.setTextColor(colors.black)
    monitor.write(l)
  end
  monitor.setBackgroundColor(colors.green)
  monitor.setTextColor(colors.white)
end

local function drawHand(hand,y,hideSecond)
  local w,s=10,2
  local tw=#hand*w+(#hand-1)*s
  local sx=math.ceil((monX - tw)/2)
  for i,c in ipairs(hand) do
    drawCardGraphic(c,sx+(i-1)*(w+s),y,(hideSecond and i==2))
  end
end

local function showMainMenu()
  monitor.clear()
  monitor.setCursorPos(math.ceil((monX-9)/2),2)
  monitor.write("BLACKJACK")
  local stats="Wins: "..wins.." Losses: "..losses.." Ties: "..ties
  monitor.setCursorPos(math.ceil((monX-#stats)/2),4)
  monitor.write(stats)
  drawButton("Start Game",math.ceil((monX-16)/2),math.floor(monY/2),16,3)
  drawButton("Debug",monX-10,monY-2,8,2)
end
local function showResult(results)
  monitor.clear()
  local y=2
  for _,text in ipairs(results) do
    if text=="NATURAL_BLACKJACK" then
      local art = {
"                                           ",
"             ,,                            ",
"`7MM\"\"\"Yp, `7MM                 `7MM      ",
"  MM    Yb   MM                   MM      ",
"  MM    dP   MM   ,6\"Yb.  ,p6\"bo  MM  ,MP'",
"  MM\"\"\"bg.   MM  8)   MM 6M'  OO  MM ;Y   ",
"  MM    `Y   MM   ,pm9MM 8M       MM;Mm   ",
"  MM    ,9   MM  8M   MM YM.    , MM `Mb. ",
".JMMmmmd9  .JMML.`Moo9^Yo.YMbmd'.JMML. YA.",
"                                           ",
"                                           ",
"                                           ",
"                                           ",
"   `7MMF'              `7MM      OO        ",
"     MM                  MM      88        ",
"     MM  ,6\"Yb.  ,p6\"bo  MM  ,MP'||        ",
"     MM 8)   MM 6M'  OO  MM ;Y   ||        ",
"     MM  ,pm9MM 8M       MM;Mm   `'        ",
"(O)  MM 8M   MM YM.    , MM `Mb. ,,        ",
" Ymmm9  `Moo9^Yo.YMbmd'.JMML. YA.db        ",
"                                           ",
      }
      for _,l in ipairs(art) do
        monitor.setCursorPos(math.ceil((monX-#l)/2),y)
        monitor.write(l)
        y=y+1
      end
    elseif text=="Your Hand Wins!" then
      local art = {
"                                        ",
"                                        ",
"____              ___ ______      ___ 8 ",
"`Mb(      db      )d' `MM`MM\\     `M'(M)",
" YM.     ,PM.     ,P   MM MMM\\     M (M)",
" `Mb     d'Mb     d'   MM M\\MM\\    M (M)",
"  YM.   ,P YM.   ,P    MM M \\MM\\   M  M ",
"  `Mb   d' `Mb   d'    MM M  \\MM\\  M  M ",
"   YM. ,P   YM. ,P     MM M   \\MM\\ M  M ",
"   `Mb d'   `Mb d'     MM M    \\MM\\M  8 ",
"    YM,P     YM,P      MM M     \\MMM   ",
"    `MM'     `MM'      MM M      \\MM 68b",
"     YP       YP      _MM_M_      \\M Y89",
"                                        ",
"                                        ",
      }
      for _,l in ipairs(art) do
        monitor.setCursorPos(math.ceil((monX-#l)/2),y)
        monitor.write(l)
        y=y+1
      end
    elseif text=="Your Hand Busted!" then
      local art = {
"                                                ",
"                                                ",
"`7MM\"\"\"Yp, `7MMF'   `7MF'.M\"\"\"bgd MMP\"\"MM\"\"YMM ",
"  MM    Yb   MM       M ,MI    \"Y P'   MM   `7 ",
"  MM    dP   MM       M `MMb.          MM      ",
"  MM\"\"\"bg.   MM       M   `YMMNq.      MM      ",
"  MM    `Y   MM       M .     `MM      MM      ",
"  MM    ,9   YM.     ,M Mb     dM      MM      ",
".JMMmmmd9     `bmmmmd\"' P\"Ybmmd\"     .JMML.    ",
"                                                ",
"                                                ",
      }
      for _,l in ipairs(art) do
        monitor.setCursorPos(math.ceil((monX-#l)/2),y)
        monitor.write(l)
        y=y+1
      end
    elseif text=="Your Hand Loses!" then
      local art = {
"                                                ",
"                                                ",
"`7MMF'        .g8\"\"8q.    .M\"\"\"bgd `7MM\"\"\"YMM  ",
"  MM        .dP'    `YM. ,MI    \"Y   MM    `7  ",
"  MM        dM'      `MM `MMb.       MM   d    ",
"  MM        MM        MM   `YMMNq.   MMmmMM    ",
"  MM      , MM.      ,MP .     `MM   MM   Y  , ",
"  MM     ,M `Mb.    ,dP' Mb     dM   MM     ,M ",
".JMMmmmmMMM   `\"bmmd\"'   P\"Ybmmd\"  .JMMmmmmMMM ",
"                                                ",
"                                                ",
      }
      for _,l in ipairs(art) do
        monitor.setCursorPos(math.ceil((monX-#l)/2),y)
        monitor.write(l)
        y=y+1
      end
    elseif text=="Push (Tie)" then
      local art = {
"                                                ",
"                                                ",
"`7MM\"\"\"Mq.`7MMF'   `7MF'.M\"\"\"bgd `7MMF'  `7MMF'",
"  MM   `MM. MM       M ,MI    \"Y   MM      MM  ",
"  MM   ,M9  MM       M `MMb.       MM      MM  ",
"  MMmmdM9   MM       M   `YMMNq.   MMmmmmmmMM  ",
"  MM        MM       M .     `MM   MM      MM  ",
"  MM        YM.     ,M Mb     dM   MM      MM  ",
".JMML.       `bmmmmd\"' P\"Ybmmd\"  .JMML.  .JMML.",
"                                                ",
"                                                ",
      }
      for _,l in ipairs(art) do
        monitor.setCursorPos(math.ceil((monX-#l)/2),y)
        monitor.write(l)
        y=y+1
      end
    else
      monitor.setCursorPos(math.ceil((monX-#text)/2),y)
      monitor.write(text)
      y=y+1
    end
  end
  drawButton("Play Again",math.ceil((monX-32)/2),monY-4,14,3)
  drawButton("Main Menu",math.ceil((monX-32)/2)+18,monY-4,14,3)
end
local function playSingleHand(playerHand,dealerHand,handLabel)
  local pTotal = handValue(playerHand)
  while true do
    monitor.clear()
    monitor.setCursorPos(2,1)
    monitor.write(handLabel.." - Dealer's Hand:")
    drawHand(dealerHand,3,true)
    monitor.setCursorPos(2,12)
    monitor.write(handLabel.." - Your Hand:")
    drawHand(playerHand,14,false)

    pTotal = handValue(playerHand)
    monitor.setCursorPos(2,22)
    monitor.write("Your Total: "..pTotal)

    if pTotal==21 then
      sleep(1)
      return pTotal
    end

    local canDoubleDown = (#playerHand==2) and (pTotal==9 or pTotal==10 or pTotal==11)
    local canSplit = (#playerHand==2) and (playerHand[1].rank==playerHand[2].rank)
    local allowHit = pTotal < 21

    local numButtons = 0
    if allowHit then
      numButtons=2
      if canDoubleDown then numButtons=numButtons+1 end
      if canSplit then numButtons=numButtons+1 end
    else
      numButtons=1
    end

    local btnW=12
    local gap=4
    local btnH=3
    local totalBlockWidth = btnW*numButtons + gap*(numButtons-1)
    local startX = math.ceil((monX - totalBlockWidth)/2)
    local btnY=24

    local labels={}
    if allowHit then
      table.insert(labels,"Hit")
      table.insert(labels,"Stand")
      if canDoubleDown then table.insert(labels,"Double Down") end
      if canSplit then table.insert(labels,"Split") end
    else
      table.insert(labels,"Stand")
    end

    for i,label in ipairs(labels) do
      drawButton(label,startX+(i-1)*(btnW+gap),btnY,btnW,btnH)
    end

    local tx,ty=waitForTouch()
    if ty>=btnY and ty<=btnY+2 then
      for i,label in ipairs(labels) do
        local bx=startX+(i-1)*(btnW+gap)
        if tx>=bx and tx<bx+btnW then
          if label=="Hit" then
            table.insert(playerHand,drawCard())
            local v=handValue(playerHand)
            if v>21 then
              monitor.clear()
              monitor.setCursorPos(2,1)
              monitor.write(handLabel.." - Dealer's Hand:")
              drawHand(dealerHand,3,true)
              monitor.setCursorPos(2,12)
              monitor.write(handLabel.." - Your Hand:")
              drawHand(playerHand,14,false)
              sleep(5)
              return "BUST"
            end
          elseif label=="Stand" then
            return handValue(playerHand)
          elseif label=="Double Down" then
            table.insert(playerHand,drawCard())
            local v=handValue(playerHand)
            if v>21 then
              monitor.clear()
              monitor.setCursorPos(2,1)
              monitor.write(handLabel.." - Dealer's Hand:")
              drawHand(dealerHand,3,true)
              monitor.setCursorPos(2,12)
              monitor.write(handLabel.." - Your Hand:")
              drawHand(playerHand,14,false)
              sleep(5)
              return "BUST"
            end
            return v
          elseif label=="Split" then
            local h1={playerHand[1],drawCard()}
            local h2={playerHand[2],drawCard()}
            local v1=playSingleHand(h1,dealerHand,"Hand 1")
            local v2=playSingleHand(h2,dealerHand,"Hand 2")
            return {{"Hand 1",v1},{"Hand 2",v2}}
          end
        end
      end
    end
  end
end
local function playDealerAndScore(dealerHand,playerHands)
  monitor.clear()
  monitor.setCursorPos(2,1)
  monitor.write("Dealer Reveals:")
  drawHand(dealerHand,3,false)
  sleep(1)

  local dealerTotal = handValue(dealerHand)

  -- If all player hands busted, skip dealer play
  local allBusted = true
  for _,ph in ipairs(playerHands) do
    if ph[2]~="BUST" then
      allBusted=false
      break
    end
  end

  if not allBusted then
    while true do
      local dTotal = handValue(dealerHand)
      local hasAce = false
      for _,c in ipairs(dealerHand) do
        if c.rank=="A" then hasAce=true end
      end
      if dTotal<17 or (dTotal==17 and hasAce) then
        table.insert(dealerHand,drawCard())
        monitor.clear()
        monitor.setCursorPos(2,1)
        monitor.write("Dealer Hits...")
        drawHand(dealerHand,3,false)
        sleep(1)
      else
        break
      end
    end
  end

  dealerTotal = handValue(dealerHand)
  local outcomes = {}
  for _,ph in ipairs(playerHands) do
    local label,value = unpack(ph)
    if value=="BUST" then
      table.insert(outcomes,label.." Busted!")
      losses=losses+1
    elseif dealerTotal>21 or value>dealerTotal then
      table.insert(outcomes,label.." Wins!")
      wins=wins+1
    elseif dealerTotal>value then
      table.insert(outcomes,label.." Loses!")
      losses=losses+1
    else
      table.insert(outcomes,label.." Push (Tie)")
      ties=ties+1
    end
  end

  -- Safe sort (fixes "compare nil with number" error)
  local priority = {
    ["Wins!"]=1, ["Push (Tie)"]=2, ["Loses!"]=3, ["Busted!"]=4
  }
  table.sort(outcomes,function(a,b)
    local matchA = a:match("%s(%S+)!")
    local matchB = b:match("%s(%S+)!")
    local ap=priority[matchA] or 5
    local bp=priority[matchB] or 5
    return ap<bp
  end)

  showResult(outcomes)

  while true do
    local tx,ty=waitForTouch()
    if ty>=monY-4 and ty<=monY-2 then
      if tx<=monX/2 then
        return true
      else
        return false
      end
    end
  end
end

local function playGame()
  shuffleDeck()
  local playerHand = {drawCard(),drawCard()}
  local dealerHand = {drawCard(),drawCard()}

  local function isBlackjack(h)
    local hasAce,hasTen=false,false
    for _,c in ipairs(h) do
      if c.rank=="A" then hasAce=true
      elseif c.rank=="10" or c.rank=="J" or c.rank=="Q" or c.rank=="K" then hasTen=true end
    end
    return hasAce and hasTen
  end

  if isBlackjack(playerHand) or isBlackjack(dealerHand) then
    monitor.clear()
    monitor.setCursorPos(2,1)
    monitor.write("Dealer's Hand:")
    drawHand(dealerHand,3,false)
    monitor.setCursorPos(2,12)
    monitor.write("Your Hand:")
    drawHand(playerHand,14,false)
    sleep(5)

    if isBlackjack(playerHand) and isBlackjack(dealerHand) then
      ties=ties+1
      showResult({"Push (Tie)"})
    elseif isBlackjack(playerHand) then
      wins=wins+1
      showResult({"NATURAL_BLACKJACK"})
    else
      losses=losses+1
      showResult({"Your Hand Loses!"})
    end
    while true do
      local tx,ty=waitForTouch()
      if ty>=monY-4 and ty<=monY-2 then
        if tx<=monX/2 then
          return true
        else
          return false
        end
      end
    end
  end

  local result = playSingleHand(playerHand,dealerHand,"Your")

  if type(result)=="table" then
    return playDealerAndScore(dealerHand,result)
  else
    return playDealerAndScore(dealerHand,{{"Your Hand",result}})
  end
end
-- Main loop with Debug mode
while true do
  showMainMenu()
  local tx,ty=waitForTouch()
  if ty>=math.floor(monY/2) and ty<=math.floor(monY/2)+2 then
    while true do
      local again=playGame()
      if not again then break end
    end
  elseif ty>=monY-2 and tx>=monX-10 then
    -- Debug mode
    local screens = {
      {"NATURAL_BLACKJACK"},
      {"Your Hand Wins!"},
      {"Your Hand Loses!"},
      {"Push (Tie)"},
      {"Your Hand Busted!"}
    }
    local idx=1
    while true do
      if idx<=#screens then
        showResult(screens[idx])
      else
        local i=idx-#screens
        local c=deck[i]
        monitor.clear()
        monitor.setCursorPos(2,2)
        monitor.write("Deck Card "..i.." of "..#deck)
        if c then
          monitor.setCursorPos(2,4)
          monitor.write("Rank: "..c.rank.."  Suit: "..c.suit)
        end
      end
      local t=os.startTimer(5)
      local e=os.pullEvent()
      if e=="timer" then
        idx=idx+1
        if idx>#screens+#deck then idx=1 end
      elseif e=="monitor_touch" then
        break
      end
    end
  end
end
