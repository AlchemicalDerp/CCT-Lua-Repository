-- B.F.S. Storage Terminal with Multi-Vault Support and Fallback Deposits

-- Peripheral Setup
local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
local inputBarrel = peripheral.wrap("right")
local outputBarrelSide = "left"

-- Vaults
local rearVault = peripheral.wrap("back")
local allVaults = {}

-- Prioritize rear vault
table.insert(allVaults, rearVault)

-- Add any additional vaults except rear
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.getType(name) == "create:item_vault" and peripheral.wrap(name) ~= rearVault then
    table.insert(allVaults, peripheral.wrap(name))
  end
end

local passwordFile = ".password"
local password = ""

-- State
local items = {}
local selectedItem = nil
local selectedQty = 0
local page = 1
local pageSize = 10
local storagePercent = 0

-- Colors
local bgColor = colors.black
local textColor = colors.white
local highlightColor = colors.green
local titleColor = colors.cyan
local buttonColor = colors.lightBlue
local fillColor = colors.lime
local emptyColor = colors.gray

-- Utility Functions
local function clearMonitor()
  monitor.setBackgroundColor(bgColor)
  monitor.setTextColor(textColor)
  monitor.clear()
  monitor.setCursorPos(1,1)
end

local function writeAt(x,y,text,colorBG,colorFG)
  monitor.setCursorPos(x,y)
  if colorBG then monitor.setBackgroundColor(colorBG) end
  if colorFG then monitor.setTextColor(colorFG) end
  monitor.write(text)
  monitor.setBackgroundColor(bgColor)
  monitor.setTextColor(textColor)
end

local function centerText(y,text,colorBG,colorFG)
  local w,h = monitor.getSize()
  local x = math.floor((w - #text)/2) +1
  writeAt(x,y,text,colorBG,colorFG)
  return x
end

local function readPassword(prompt)
  term.write(prompt)
  local input = ""
  while true do
    local event, param = os.pullEvent()
    if event == "char" then
      input = input .. param
      term.write("*")
    elseif event == "key" and param == keys.enter then
      print()
      return input
    end
  end
end

local function savePassword(pw)
  local f = fs.open(passwordFile, "w")
  f.write(pw)
  f.close()
end

local function loadPassword()
  if fs.exists(passwordFile) then
    local f = fs.open(passwordFile, "r")
    local pw = f.readAll()
    f.close()
    return pw
  end
  return nil
end

local function pullItems()
  local inputList = inputBarrel.list()
  for slot, stack in pairs(inputList) do
    -- Try rear vault first
    local moved = rearVault.pullItems("right", slot)
    -- If rear vault full, try others
    if moved == 0 then
      for i=2,#allVaults do
        moved = allVaults[i].pullItems("right", slot)
        if moved >0 then break end
      end
    end
  end
end

local function updateItems()
  local combined = {}
  local totalSlots = 0
  local usedSlots = 0

  for _, vault in ipairs(allVaults) do
    local vaultList = vault.list()
    totalSlots = totalSlots + vault.size()
    for slot, stack in pairs(vaultList) do
      usedSlots = usedSlots + 1
      local detail = vault.getItemDetail(slot)
      if detail then
        local name = detail.displayName
        if combined[name] then
          combined[name].count = combined[name].count + detail.count
        else
          combined[name] = {name = name, count = detail.count}
        end
      end
    end
  end

  storagePercent = math.floor((usedSlots / totalSlots) * 100)

  local list = {}
  for _, v in pairs(combined) do
    table.insert(list, v)
  end
  table.sort(list, function(a,b) return a.name < b.name end)

  local maxPage = math.max(1, math.ceil(#list / pageSize))
  if page > maxPage then
    page = maxPage
  end

  return list
end

local function drawStorageBar(y)
  local w,h = monitor.getSize()
  local barWidth = w - 2
  local fillChars = math.floor((storagePercent/100)*barWidth)
  local emptyChars = barWidth - fillChars

  writeAt(2,y,string.rep(" ",fillChars),fillColor)
  writeAt(2+fillChars,y,string.rep(" ",emptyChars),emptyColor)

  local pctText = storagePercent.."% Full"
  local pctX = math.floor((w - #pctText)/2) +1
  writeAt(pctX,y,pctText,nil,textColor)
end

local function drawScreen()
  clearMonitor()
  centerText(1,"B.F.S.",nil,titleColor)
  centerText(2,"Page "..page.." / "..math.max(1, math.ceil(#items/pageSize)))

  for i=1,pageSize do
    local idx = (page-1)*pageSize + i
    if items[idx] then
      local y = i+3
      local name = items[idx].name
      local qty = items[idx].count
      local bg = (selectedItem==idx) and highlightColor or bgColor
      local fg = (selectedItem==idx) and colors.black or textColor
      writeAt(1,y,string.format("%-45s x%-5d",name,qty),bg,fg)
    end
  end

  centerText(15,"Quantity: "..selectedQty)

  local btns = {"-64","-16","-8","-1","+1","+8","+16","+64"}
  for i,b in ipairs(btns) do
    writeAt(1+(i-1)*6,16,"["..b.."]",buttonColor)
  end

  centerText(18,"[Confirm]   [Cancel]",buttonColor)
  centerText(20,"[Prev Page]     [Next Page]",buttonColor)
  centerText(22,"[Deposit]",buttonColor)

  drawStorageBar(23)
end

local function dispenseSelected()
  print("Dispense triggered.")
  if not selectedItem or not selectedQty or selectedQty <= 0 then
    print("Nothing selected or quantity <=0.")
    return
  end

  local item = items[selectedItem]
  if not item then
    print("Item was nil.")
    return
  end

  local remaining = selectedQty
  for _, vault in ipairs(allVaults) do
    local vaultList = vault.list()
    for slot, stack in pairs(vaultList) do
      local detail = vault.getItemDetail(slot)
      if detail and detail.displayName == item.name then
        local moved = vault.pushItems(outputBarrelSide, slot, math.min(remaining, detail.count))
        remaining = remaining - moved
        if remaining <=0 then break end
      end
    end
    if remaining <=0 then break end
  end

  if remaining >0 then
    print("Warning: Only moved part of requested amount.")
  end

  selectedQty = 0
end

-- Password handling
password = loadPassword()
if not password then
  term.clear()
  print("No password set.")
  local pw1 = readPassword("Set password (blank for none): ")
  savePassword(pw1)
  password = pw1
end

while true do
  term.clear()
  local entered = readPassword("Enter password: ")
  if entered == password then break end
  print("Incorrect. Try again.")
  sleep(1)
end

-- Background Refresh Thread
local function backgroundRefresh()
  while true do
    pullItems()
    items = updateItems()
    drawScreen()
    sleep(5)
  end
end

-- Start background polling
parallel.waitForAny(
  backgroundRefresh,
  function()
    while true do
      drawScreen()

      local event,side,x,y = os.pullEvent()
      if event=="monitor_touch" then
        if y>=4 and y<=13 then
          local idx=(page-1)*pageSize+(y-3)
          if items[idx] then
            selectedItem=idx
            selectedQty=1
          end
        end
        if y==16 then
          local qbtns={"-64","-16","-8","-1","+1","+8","+16","+64"}
          for i,label in ipairs(qbtns) do
            if x>=1+(i-1)*6 and x<=1+(i-1)*6+3 then
              local delta=tonumber(label)
              local maxQty=999999
              if selectedItem and items[selectedItem] then
                maxQty = items[selectedItem].count
              end
              selectedQty=math.max(0,math.min(maxQty,selectedQty+(delta or 0)))
            end
          end
        end
        if y==18 then
          if x>=20 and x<=28 then
            dispenseSelected()
            drawScreen()
            items=updateItems()
            drawScreen()
          elseif x>=30 and x<=38 then
            selectedQty=0
          end
        end
        if y==20 then
          local text = "[Prev Page]     [Next Page]"
          local startX = math.floor((monitor.getSize()-#text)/2)+1
          local prevStart = startX +1
          local prevEnd = prevStart +10
          local nextStart = prevEnd +6
          local nextEnd = nextStart +10

          local maxPage = math.max(1, math.ceil(#items / pageSize))
          if x>=prevStart and x<=prevEnd then
            page = page -1
            if page<1 then page = maxPage end
          elseif x>=nextStart and x<=nextEnd then
            page = page +1
            if page>maxPage then page =1 end
          end
        end
        if y==22 then
          local w,h=monitor.getSize()
          local depositX = math.floor((w-9)/2)+1
          if x>=depositX and x<=depositX+8 then
            pullItems()
            items=updateItems()
            drawScreen()
          end
        end
      end
    end
  end
)
