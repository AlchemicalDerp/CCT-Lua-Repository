-- Conway's Game of Life for CC:Tweaked
-- Fixed resolution: 51x19
-- Controls:
--  Arrow keys: move
--  Enter: place cell
--  Backspace: delete cell
--  Space: pause/resume
--  N: step one frame
--  Q: return to main menu

local w, h = 51, 19

-- Main program loop
while true do
  term.clear()
  term.setCursorPos(1,1)
  print("Conway's Game of Life")
  print("----------------------")
  print("1) Start new game")
  print("2) Exit")
  write("Choose an option: ")
  local choice = tonumber(read())

  if choice == 2 then
    term.clear()
    term.setCursorPos(1,1)
    print("Goodbye!")
    break
  elseif choice ~= 1 then
    term.setCursorPos(1,5)
    print("Invalid option. Press any key...")
    os.pullEvent("key")
  else
    -- Start new game
    term.clear()
    term.setCursorPos(1,1)

    -- Initialize grid
    local grid = {}
    for y=1,h do
      grid[y]={}
      for x=1,w do
        grid[y][x]=false
      end
    end

    -- Prompt user
    write("Number of initial live cells: ")
    local count = tonumber(read())

    print()
    print("1) Random placement")
    print("2) Manual placement")
    write("Choose placement mode: ")
    local mode = tonumber(read())

    if mode==2 then
      local placed=0
      local cx,cy=math.ceil(w/2),math.ceil(h/2)
      term.clear()
      while placed<count do
        term.setCursorPos(1,1)
        for y=1,h do
          for x=1,w do
            if x==cx and y==cy then
              if grid[y][x] then
                io.write("@") -- Cursor over live cell
              else
                io.write("+") -- Cursor over empty
              end
            else
              io.write(grid[y][x] and "O" or ".")
            end
          end
        end
        term.setCursorPos(1,h+1)
        write("Arrows=Move Enter=Place Backspace=Delete ("..(count-placed)..") ")

        local event,key=os.pullEvent("key")
        if key==keys.enter then
          if not grid[cy][cx] then
            grid[cy][cx]=true
            placed=placed+1
          end
        elseif key==keys.backspace then
          if grid[cy][cx] then
            grid[cy][cx]=false
            placed=placed-1
          end
        elseif key==keys.up and cy>1 then cy=cy-1
        elseif key==keys.down and cy<h then cy=cy+1
        elseif key==keys.left and cx>1 then cx=cx-1
        elseif key==keys.right and cx<w then cx=cx+1
        end
      end
    else
      local placed=0
      while placed<count do
        local rx,ry=math.random(1,w),math.random(1,h)
        if not grid[ry][rx] then
          grid[ry][rx]=true
          placed=placed+1
        end
      end
    end

    -- Game loop
    local paused=false
    while true do
      term.setCursorPos(1,1)
      for y=1,h do
        for x=1,w do
          io.write(grid[y][x] and "O" or ".")
        end
      end
      term.setCursorPos(1,h+1)
      write(paused and "[PAUSED] Space=Resume N=Next Q=Menu " or "Space=Pause Q=Menu ")

      local t=os.startTimer(0.3)
      local event,p1=os.pullEvent()
      if event=="timer" and not paused then
        local newGrid={}
        for y=1,h do
          newGrid[y]={}
          for x=1,w do
            local c=0
            for dy=-1,1 do
              for dx=-1,1 do
                if not(dx==0 and dy==0) then
                  local nx,ny=x+dx,y+dy
                  if nx>=1 and nx<=w and ny>=1 and ny<=h and grid[ny][nx] then c=c+1 end
                end
              end
            end
            newGrid[y][x]=(grid[y][x] and(c==2 or c==3)) or(not grid[y][x] and c==3)
          end
        end
        grid=newGrid
      elseif event=="key" then
        if p1==keys.space then paused=not paused
        elseif p1==keys.n and paused then
          local newGrid={}
          for y=1,h do
            newGrid[y]={}
            for x=1,w do
              local c=0
              for dy=-1,1 do
                for dx=-1,1 do
                  if not(dx==0 and dy==0) then
                    local nx,ny=x+dx,y+dy
                    if nx>=1 and nx<=w and ny>=1 and ny<=h and grid[ny][nx] then c=c+1 end
                  end
                end
              end
              newGrid[y][x]=(grid[y][x] and(c==2 or c==3)) or(not grid[y][x] and c==3)
            end
          end
          grid=newGrid
        elseif p1==keys.q then
          -- Return to main menu
          break
        end
      end
    end
  end
end
