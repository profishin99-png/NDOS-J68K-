-- Run MANDELB.NEX and verify the app exits and draws a nontrivial image.
local frames = 0
local checked = false

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

local function symbol_address(name, listing)
  local file = assert(io.open(listing or 'build/ndos.lst', 'r'))
  for line in file:lines() do
    local hex = line:match(name .. '%s+A:([%x]+)')
    if hex then
      file:close()
      return tonumber(hex, 16)
    end
  end
  file:close()
  error('symbol not found in build/ndos.lst: ' .. name)
end

local state_address = symbol_address('PROC_STATE')
local video_base = 0x00e00000

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN MANDELB.NEX\r') end
  if frames >= 2000 and not checked then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local state = read_u32_be(mem, state_address)
    -- Poll until it returns to the shell, but keep the regression bounded at
    -- 10 minutes of emulated time (18,000 frames at 30 Hz). A high iteration
    -- limit may still be rendering when this bounded visual check runs.
    if state ~= 4 and frames < 18000 then return end
    checked = true
    local nonzero = 0
    local colours = {}
    for i = 0, (320 * 200) - 1 do
      local value = mem:read_u8(video_base + i)
      if value ~= 0 then nonzero = nonzero + 1 end
      colours[value] = true
    end
    local colour_count = 0
    for _ in pairs(colours) do colour_count = colour_count + 1 end
    local samples = {
      mem:read_u8(video_base + 100 * 320 + 214),
      mem:read_u8(video_base + 100 * 320 + 216),
      mem:read_u8(video_base + 100 * 320 + 200),
      mem:read_u8(video_base + 0 * 320 + 0),
    }
    local f = assert(io.open('build/test-results/mandelbrot-result.txt', 'w'))
    local status = state == 4 and 'COMPLETE' or 'IN_PROGRESS'
    f:write(string.format('STATUS=%s PROC_STATE=%u NONZERO=%u COLOURS=%u SAMPLES=%02X,%02X,%02X,%02X\n',
      status, state, nonzero, colour_count, samples[1], samples[2], samples[3], samples[4]))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('mandelbrot.png') end
    assert(state == 2 or state == 4, 'MANDELB.NEX is neither running nor returned to NDOS')
    assert(nonzero > 1000, 'Mandelbrot renderer did not draw enough pixels')
    assert(colour_count > 4, 'Mandelbrot image has too few colours')
    machine:exit()
  end
end)
