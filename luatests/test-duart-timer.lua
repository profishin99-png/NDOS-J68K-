-- The MAME development image programs MC68681 C/T for a 100 Hz tick.
local frames = 0
local initial_ticks = nil

local function symbol_address(wanted)
  local f = assert(io.open('build/ndos.lst', 'r'))
  for line in f:lines() do
    local address, symbol = line:match('^%s*(%x+)%s+([%w_]+)%s*$')
    if symbol == wanted then
      f:close()
      return tonumber(address, 16)
    end
  end
  f:close()
  error('symbol not found in build/ndos.lst: ' .. wanted)
end

local tick_address = symbol_address('tick_counter')

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 120 then
    initial_ticks = read_u32_be(manager.machine.devices[':maincpu'].spaces['program'], tick_address)
  end
  if frames == 420 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local final_ticks = read_u32_be(cpu.spaces['program'], tick_address)
    local delta = final_ticks - initial_ticks
    local f = assert(io.open('build/test-results/duart-timer-result.txt', 'w'))
    f:write(string.format('INITIAL=%u FINAL=%u DELTA=%u\n', initial_ticks, final_ticks, delta))
    f:close()
    assert(delta > 0, 'MC68681 timer did not deliver any NDOS ticks')
    machine:exit()
  end
end)
