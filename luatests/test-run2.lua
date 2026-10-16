local frames = 0
local initial_count = nil
local function find_symbol_address(symbol_name)
  local listing = assert(io.open('build/ndos.lst', 'r'))
  for line in listing:lines() do
    local address, name = line:match('^%s*(%x+)%s+([%w_]+)%s*$')
    if name == symbol_name then
      listing:close()
      return tonumber(address, 16)
    end
  end
  listing:close()
  error('symbol not found in build/ndos.lst: ' .. symbol_name)
end
local yield_count_address = find_symbol_address('YIELD_COUNT')
local current_pcb_address = find_symbol_address('CURRENT_PROCESS')
local second_pcb_address = find_symbol_address('SECOND_PROCESS')
local current_pcb_pointer_address = find_symbol_address('SCHED_CURRENT_PCB')
local fg_write_count_address = find_symbol_address('CONSOLE_FG_WRITE_COUNT')
local bg_suppressed_count_address = find_symbol_address('CONSOLE_BG_SUPPRESSED_COUNT')
local switch_count_address = find_symbol_address('SCHED_SWITCH_COUNT')
local tm_command_count_address = find_symbol_address('TM_COMMAND_COUNT')
local pcb_saved_ssp_offset = 60
local pcb_base_offset = 8
local pcb_size_offset = 12

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

emu.register_frame_done(function()
  frames = frames + 1
  local cpu = manager.machine.devices[':maincpu']
  if frames == 100 then
    initial_count = read_u32_be(cpu.spaces['program'], yield_count_address)
  end
  if frames == 150 then
    emu.keypost('RUN2 YIELD.NEX\r')
  end
  if frames == 650 then
    local final_count = read_u32_be(cpu.spaces['program'], yield_count_address)
    local delta = final_count - initial_count
    local mem = cpu.spaces['program']
    local task_a_state = read_u32_be(mem, current_pcb_address + 4)
    local task_b_state = read_u32_be(mem, second_pcb_address + 4)
    local current_pcb = read_u32_be(mem, current_pcb_pointer_address)
    local switch_count = read_u32_be(mem, switch_count_address)
    local fg_write_count = read_u32_be(mem, fg_write_count_address)
    local bg_suppressed_count = read_u32_be(mem, bg_suppressed_count_address)
    local task_b_ssp = read_u32_be(mem, second_pcb_address + pcb_saved_ssp_offset)
    local task_b_saved_pc = read_u32_be(mem, task_b_ssp + 62)
    local task_b_base = read_u32_be(mem, second_pcb_address + pcb_base_offset)
    local task_b_size = read_u32_be(mem, second_pcb_address + pcb_size_offset)
    local task_b_pc_valid = task_b_saved_pc >= task_b_base
      and task_b_saved_pc < task_b_base + task_b_size
    local f = assert(io.open('build/test-results/run2-yield-result.txt', 'w'))
    f:write(string.format('INITIAL=%u FINAL=%u DELTA=%u TASK_A_STATE=%u TASK_B_STATE=%u CURRENT_PCB=%08X TASK_B_PC=%08X TASK_B_PC_VALID=%s FG_WRITES=%u BG_SUPPRESSED=%u SWITCHES=%u\n',
      initial_count, final_count, delta, task_a_state, task_b_state,
      current_pcb, task_b_saved_pc, tostring(task_b_pc_valid),
      fg_write_count, bg_suppressed_count, switch_count))
    f:close()
    assert(delta == 16, 'RUN2 should produce 8 yields from each YIELD.NEX instance')
    assert(task_b_pc_valid,
      'Task B saved PC must remain inside its separate NEX program region')
    assert(task_a_state == 4, 'Task A should exit normally after its eight yields')
    assert(task_b_state == 4, 'Task B should resume after Task A exits, then exit normally')
    assert(fg_write_count > 0, 'Task A should still be able to write to the console')
    assert(bg_suppressed_count > 0, 'Task B console output should be suppressed')
    assert(switch_count > 0, 'round-robin should count at least one actual process switch')
    assert(current_pcb == current_pcb_address,
      'Task A should be current after it finishes and returns to the shell')
    emu.keypost('TM\r')
  end
  if frames == 750 then
    local mem = manager.machine.devices[':maincpu'].spaces['program']
    local tm_command_count = read_u32_be(mem, tm_command_count_address)
    local f = assert(io.open('build/test-results/run2-yield-result.txt', 'a'))
    f:write(string.format('TM_COMMANDS=%u\n', tm_command_count))
    f:close()
    assert(tm_command_count > 0, 'TM shell command was not dispatched')
    manager.machine:exit()
  end
end)
