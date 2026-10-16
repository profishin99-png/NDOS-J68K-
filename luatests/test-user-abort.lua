-- Launch a NEX that never stops printing, then send Ctrl+C. The DUART RX IRQ
-- must redirect the user exception frame to the kernel abort trampoline.
local frames = 0

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

local function symbol_address(name)
  local file = assert(io.open('build/ndos.lst', 'r'))
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
local exit_code_address = symbol_address('PROC_EXIT_CODE')
local ticks_address = symbol_address('tick_counter')
local running_state = nil
local running_ticks = nil

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN BRKLOOP.NEX\r') end
  if frames == 300 then
    local mem = manager.machine.devices[':maincpu'].spaces['program']
    running_state = read_u32_be(mem, state_address)
    running_ticks = read_u32_be(mem, ticks_address)
  end
  if frames == 450 then emu.keypost(string.char(3)) end
  if frames == 800 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local state = read_u32_be(mem, state_address)
    local exit_code = read_u32_be(mem, exit_code_address)
    local ticks = read_u32_be(mem, ticks_address)
    local f = assert(io.open('build/test-results/user-abort-result.txt', 'w'))
    f:write(string.format(
      'PC=%08X RUN_STATE=%u RUN_TICKS=%u TICKS=%u PROC_STATE=%u EXIT_CODE=%u\n',
      cpu.state['PC'].value, running_state, running_ticks, ticks, state, exit_code))
    f:close()
    assert(running_state == 2, 'BRKLOOP.NEX was not running at the timer check')
    assert(running_ticks > 0, 'timer IRQ did not advance while user NEX was running')
    assert(state == 4, 'Ctrl+C did not return the runaway NEX to NDOS')
    assert(exit_code == 3, 'aborted NEX exit code was not recorded')
    machine:exit()
  end
end)
