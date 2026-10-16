-- Launch two copies of FPUTEST.NEX and verify that timer preemption saves
-- both PCB FPU contexts and both processes return normally.
-- This checks the scheduler/FPU save path, not the numeric result of the app:
-- FPUTEST currently prints its pass message without comparing a result.
local frames = 0
local start_ticks
local start_switches
local launched = false

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
local fpu_frame_a = symbol_address('PROC_FPU_FRAME')
local switches_addr = symbol_address('SCHED_SWITCH_COUNT')
local ticks_addr = symbol_address('tick_counter')
local pcb_size = 364
local state_offset = 4
local exit_code_offset = 32
local fpu_frame_offset = 72
local fpu_regs_offset = 256
local fpu_regs_bytes = 96
local fpu_frame_bytes = 184

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

local function has_nonzero(mem, address, count)
  for i = 0, count - 1 do
    if mem:read_u8(address + i) ~= 0 then return true end
  end
  return false
end

emu.register_frame_done(function()
  frames = frames + 1
  local machine = manager.machine
  local mem = machine.devices[':maincpu'].spaces['program']

  if frames == 100 then
    start_ticks = read_u32_be(mem, ticks_addr)
    start_switches = read_u32_be(mem, switches_addr)
  elseif frames == 150 then
    emu.keypost('RUN2 FPUTEST.NEX\r')
    launched = true
  elseif launched then
    local state_a = read_u32_be(mem, task_a + state_offset)
    local state_b = read_u32_be(mem, task_b + state_offset)

    if state_a == 4 and state_b == 4 then
      local ticks = read_u32_be(mem, ticks_addr)
      local switches = read_u32_be(mem, switches_addr)
      local exit_a = read_u32_be(mem, task_a + exit_code_offset)
      local exit_b = read_u32_be(mem, task_b + exit_code_offset)
      local frame_b = task_b + fpu_frame_offset
      local regs_a = task_a + fpu_regs_offset
      local regs_b = task_b + fpu_regs_offset
      local saved_frame_a = has_nonzero(mem, fpu_frame_a, fpu_frame_bytes)
      local saved_frame_b = has_nonzero(mem, frame_b, fpu_frame_bytes)
      local saved_regs_a = has_nonzero(mem, regs_a, fpu_regs_bytes)
      local saved_regs_b = has_nonzero(mem, regs_b, fpu_regs_bytes)
      local passed = ticks > start_ticks and switches > start_switches
        and exit_a == 0 and exit_b == 0
        and saved_frame_a and saved_frame_b
        and saved_regs_a and saved_regs_b
      local result = assert(io.open('build/test-results/fpu-context-result.txt', 'w'))
      result:write(string.format(
        'TEST_STATUS=%s TICK_DELTA=%u SWITCH_DELTA=%u TASK_A_STATE=%u TASK_B_STATE=%u EXIT_A=%u EXIT_B=%u FRAME_A=%s FRAME_B=%s FP_REGS_A=%s FP_REGS_B=%s PCB_SIZE=%u FRAME_OFFSET=%u FRAME_BYTES=%u\n',
        passed and 'PASS' or 'FAIL', ticks - start_ticks,
        switches - start_switches, state_a, state_b, exit_a, exit_b,
        tostring(saved_frame_a), tostring(saved_frame_b),
        tostring(saved_regs_a), tostring(saved_regs_b), pcb_size,
        fpu_frame_offset, fpu_frame_bytes))
      result:close()
      machine:exit()
    elseif frames > 7000 then
      local result = assert(io.open('build/test-results/fpu-context-result.txt', 'w'))
      result:write(string.format(
        'TEST_STATUS=FAIL REASON=timeout TASK_A_STATE=%u TASK_B_STATE=%u\n',
        state_a, state_b))
      result:close()
      machine:exit()
    end
  end
end)
