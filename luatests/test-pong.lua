-- Exercise PONG.NEX on the MAME-only framebuffer and keyboard queue.
local frames = 0
local machine = manager.machine
local mem = machine.devices[':maincpu'].spaces['program']

local function read_u32_be(address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

local function read_u16_be(address)
  return mem:read_u8(address) * 0x100 + mem:read_u8(address + 1)
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

local process_state = symbol_address('PROC_STATE', 'build/ndos.lst')
local game_state = symbol_address('GAME_STATE', 'build/apps/PONG.lst')
local video = 0x00e00000
local result = assert(io.open('build/test-results/pong-result.txt', 'w'))
local paddle_before, drift_start, drift_end
local score_before, score_after, misses_before, misses_after
local hit_injected = false
local miss_injected = false
local move_sent = false
local quit_sent = false
local green_pixels, yellow_pixels, red_pixels = 0, 0, 0

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then
    emu.keypost('RUN PONG.NEX\r')
  elseif frames == 350 then
    assert(read_u32_be(process_state) == 2, 'PONG is not running')
    for i = 0, (320 * 200) - 1 do
      local pixel = mem:read_u8(video + i)
      if pixel == 0x1c then green_pixels = green_pixels + 1 end
      if pixel == 0xfc then yellow_pixels = yellow_pixels + 1 end
      if pixel == 0xe0 then red_pixels = red_pixels + 1 end
    end
    assert(green_pixels >= 200, 'green paddle/framebuffer was not rendered')
    assert(yellow_pixels >= 25, 'yellow ball/framebuffer was not rendered')
    assert(red_pixels >= 40, 'red miss counter HUD was not rendered')
    for _, screen in pairs(machine.screens) do screen:snapshot('pong.png') end
    local state = 0x00010000 + game_state
    paddle_before = read_u16_be(state + 8)
    score_before = read_u32_be(state + 14)
    misses_before = read_u32_be(state + 18)
    -- Put the ball just above the paddle to exercise a real collision update.
    mem:write_u16(state + 0, paddle_before + 18)
    mem:write_u16(state + 2, 184)
    mem:write_u16(state + 4, 2)
    mem:write_u16(state + 6, 2)
    hit_injected = true
  elseif frames == 370 and hit_injected then
    local state = 0x00010000 + game_state
    score_after = read_u32_be(state + 14)
    assert(score_after == score_before + 1,
      'paddle hit did not increment the score exactly once')
    -- Force the next downward step past the paddle and check the miss counter.
    mem:write_u16(state + 2, 194)
    mem:write_u16(state + 6, 2)
    miss_injected = true
  elseif frames == 390 and miss_injected then
    local state = 0x00010000 + game_state
    misses_after = read_u32_be(state + 18)
    assert(misses_after == misses_before + 1,
      'missed ball did not increment the miss counter exactly once')
    paddle_before = read_u16_be(state + 8)
    -- A 4 px/tick release should coast, then friction should bring it to rest.
    mem:write_u16(state + 22, 4)
    drift_start = paddle_before
    move_sent = true
  elseif frames == 395 and move_sent then
    local state = 0x00010000 + game_state
    drift_end = read_u16_be(state + 8)
    assert(drift_end > drift_start, 'paddle stopped immediately when released')
    assert(read_u16_be(state + 22) == 0, 'paddle friction did not bring it to rest')
    paddle_before = drift_end
    emu.keypost('d')
    move_sent = false
  elseif frames == 445 and not move_sent then
    local state = 0x00010000 + game_state
    assert(read_u16_be(state + 8) > paddle_before,
      'D input did not accelerate the paddle right')
    emu.keypost('q')
    quit_sent = true
  elseif frames == 500 and quit_sent then
    assert(read_u32_be(process_state) ~= 2, 'serial Q input did not exit Pong')
    result:write(string.format('PASS FRAMES=%d GREEN_PIXELS=%d YELLOW_PIXELS=%d RED_PIXELS=%d SCORE=%d->%d MISSES=%d->%d DRIFT=%d->%d PADDLE=%d->%d QUIT=1\n',
      frames, green_pixels, yellow_pixels, red_pixels, score_before,
      score_after, misses_before, misses_after, drift_start, drift_end,
      paddle_before, read_u16_be(0x00010000 + game_state + 8)))
    result:close()
    machine:exit()
  elseif frames > 650 then
    error('PONG regression timed out')
  end
end)
