-- Task A yields, then Task B exits.  A must resume, exit, and return to shell.
local frames = 0

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

local task_a = symbol_address('CURRENT_PROCESS')
local task_b = symbol_address('SECOND_PROCESS')
local current_ptr = symbol_address('SCHED_CURRENT_PCB')
local switches_ptr = symbol_address('SCHED_SWITCH_COUNT')

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

emu.register_frame_done(function()
  frames = frames + 1
  local machine = manager.machine
  local mem = machine.devices[':maincpu'].spaces['program']

  -- Allow a clean, per-run MAME/NVRAM instance to finish booting before input.
  if frames == 300 then
    emu.keypost('RUN2 EXITORD.NEX\r')
  elseif frames == 700 then
    local state_a = read_u32_be(mem, task_a + 4)
    local state_b = read_u32_be(mem, task_b + 4)
    local current = read_u32_be(mem, current_ptr)
    local switches = read_u32_be(mem, switches_ptr)
    assert(state_a == 4, 'Task A did not resume after Task B exited, then exit')
    assert(state_b == 4, 'Task B did not exit normally')
    assert(current == task_a, 'return to shell did not re-anchor current PCB to Task A')
    assert(switches > 0, 'test did not perform a process switch')

    local result = assert(io.open('build/test-results/exit-order-result.txt', 'w'))
    result:write(string.format(
      'STATUS=PASS TASK_A_STATE=%u TASK_B_STATE=%u CURRENT_PCB=%08X SWITCHES=%u\n',
      state_a, state_b, current, switches))
    result:close()
    machine:exit()
  end
end)
