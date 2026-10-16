-- Two CPU-busy BRKLOOP.NEX instances should switch on 100 Hz DUART ticks
-- without either program executing TRAP #1. Uses an isolated MAME disk copy.
local frames = 0
local baseline_ticks
local baseline_yields
local baseline_switches

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

local ticks_address = symbol_address('tick_counter')
local yields_address = symbol_address('YIELD_COUNT')
local switches_address = symbol_address('SCHED_SWITCH_COUNT')
local task_a_address = symbol_address('CURRENT_PROCESS')
local task_b_address = symbol_address('SECOND_PROCESS')
local current_address = symbol_address('SCHED_CURRENT_PCB')

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

  if frames == 100 then
    baseline_ticks = read_u32_be(mem, ticks_address)
    baseline_yields = read_u32_be(mem, yields_address)
    baseline_switches = read_u32_be(mem, switches_address)
  elseif frames == 150 then
    emu.keypost('RUN2 BRKLOOP.NEX\r')
  elseif frames == 600 then
    local ticks = read_u32_be(mem, ticks_address)
    local yields = read_u32_be(mem, yields_address)
    local switches = read_u32_be(mem, switches_address)
    local state_a = read_u32_be(mem, task_a_address + 4)
    local state_b = read_u32_be(mem, task_b_address + 4)
    local current = read_u32_be(mem, current_address)
    local result = assert(io.open('build/test-results/timer-preempt-result.txt', 'w'))
    result:write(string.format(
      'TICK_DELTA=%u YIELD_DELTA=%u SWITCH_DELTA=%u TASK_A_STATE=%u TASK_B_STATE=%u CURRENT=%08X\n',
      ticks - baseline_ticks, yields - baseline_yields,
      switches - baseline_switches, state_a, state_b, current))
    result:close()
    assert(ticks > baseline_ticks, 'DUART timer did not advance during RUN2')
    assert(yields == baseline_yields, 'BRKLOOP unexpectedly yielded through TRAP #1')
    assert(switches > baseline_switches,
      'timer IRQ did not preempt between the two busy NEX instances')
    assert((current == task_a_address and state_a == 2 and state_b == 1)
        or (current == task_b_address and state_b == 2 and state_a == 1),
      'expected one RUNNING process and one READY process after timer preemption')
    machine:exit()
  end
end)
