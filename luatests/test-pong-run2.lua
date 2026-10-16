-- Verify two RUN2 PONG copies render in separate framebuffer halves.
local frames = 0
local machine = manager.machine
local mem = machine.devices[':maincpu'].spaces['program']

local function read_u16(address)
  return mem:read_u8(address) * 0x100 + mem:read_u8(address + 1)
end

local function read_u32(address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

local function symbol_address(name, listing)
  local file = assert(io.open(listing, 'r'))
  for line in file:lines() do
    local hex = line:match(name .. '%s+A:([%x]+)')
    if hex then file:close(); return tonumber(hex, 16) end
  end
  file:close()
  error('symbol not found: ' .. name)
end

local game_state = symbol_address('GAME_STATE', 'build/apps/PONG.lst')
local current_pcb = symbol_address('CURRENT_PROCESS', 'build/ndos.lst')
local second_pcb = symbol_address('SECOND_PROCESS', 'build/ndos.lst')
local video = 0x00e00000
local result = assert(io.open('build/test-results/pong-run2-result.txt', 'w'))
local launched = false
local checked = false

emu.register_frame_done(function()
  frames = frames + 1
  if frames >= 150 and not launched then
    launched = true
    emu.keypost('RUN2 PONG.NEX\r')
  elseif frames >= 400 and not checked then
    checked = true
    local left_state = 0x00010000 + game_state
    local right_state = 0x00020000 + game_state
    local left_view = read_u16(left_state + 26)
    local right_view = read_u16(right_state + 26)
    assert(left_view == 0, 'Slot A should render at the left edge')
    assert(right_view == 160, 'Slot B should render in the right half')

    local green_left, green_right = 0, 0
    for y = 31, 199 do
      if mem:read_u8(video + y * 320) == 0x1c then green_left = green_left + 1 end
      if mem:read_u8(video + y * 320 + 319) == 0x1c then green_right = green_right + 1 end
    end
    assert(green_left > 100, 'left Pong viewport was not drawn')
    assert(green_right > 100, 'right Pong viewport was not drawn')
    assert(mem:read_u8(video + 100 * 320 + 159) == 0x1c,
      'left court edge should meet the center divider')
    assert(mem:read_u8(video + 100 * 320 + 160) == 0x1c,
      'right court edge should meet the center divider')

    local state_a = read_u32(current_pcb + 4)
    local state_b = read_u32(second_pcb + 4)
    assert(state_a == 1 or state_a == 2, 'Slot A Pong is not runnable')
    assert(state_b == 1 or state_b == 2, 'Slot B Pong is not runnable')

    result:write(string.format(
      'PASS LEFT_VIEW=%u RIGHT_VIEW=%u LEFT_EDGE_PIXELS=%u RIGHT_EDGE_PIXELS=%u TASK_A=%u TASK_B=%u\n',
      left_view, right_view, green_left, green_right, state_a, state_b))
    result:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('pong-run2.png') end
    machine:exit()
  elseif frames > 550 and not checked then
    error('RUN2 PONG viewport regression timed out')
  end
end)
