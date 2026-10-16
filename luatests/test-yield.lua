-- YIELD.NEX makes sixteen TRAP #1 calls.  The current scheduler stub counts
-- them in YIELD_COUNT and returns; later scheduler revisions retain this ABI.
local frames = 0
local initial_count = nil
local initial_task_b_count = nil

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then
    initial_count = read_u32_be(manager.machine.devices[':maincpu'].spaces['program'], 0x00001ec7)
    initial_task_b_count = read_u32_be(manager.machine.devices[':maincpu'].spaces['program'], 0x0000154a)
  end
  if frames == 150 then emu.keypost('RUN YIELD.NEX\r') end
  if frames == 450 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local final_count = read_u32_be(cpu.spaces['program'], 0x00001ec7)
    local final_task_b_count = read_u32_be(cpu.spaces['program'], 0x0000154a)
    local f = assert(io.open('build/test-results/yield-result.txt', 'w'))
    f:write(string.format('PC=%08X YIELD_INITIAL=%u YIELD_FINAL=%u YIELD_DELTA=%u TASK_B_INITIAL=%u TASK_B_FINAL=%u TASK_B_DELTA=%u\n',
      cpu.state['PC'].value, initial_count, final_count, final_count - initial_count,
      initial_task_b_count, final_task_b_count, final_task_b_count - initial_task_b_count))
    f:close()
    assert(final_count - initial_count == 32, 'expected 16 Task A plus 16 Task B TRAP #1 calls')
    assert(final_task_b_count - initial_task_b_count == 16, 'Task B did not run once per Task A yield')
    machine:exit()
  end
end)
