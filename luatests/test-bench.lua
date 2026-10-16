-- BENCH.NEX runs for 100 DUART timer ticks and returns to the NDOS shell.
local frames = 0

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN BENCH.NEX\r') end
  if frames == 900 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local ticks = read_u32_be(mem, 0x000011ba)
    local process_state = read_u32_be(mem, 0x00001e82)
    local f = assert(io.open('build/test-results/bench-result.txt', 'w'))
    f:write(string.format('PC=%08X TICKS=%u PROC_STATE=%u\n',
      cpu.state['PC'].value, ticks, process_state))
    f:close()
    assert(ticks >= 100, 'DUART tick counter did not advance')
    assert(process_state == 4, 'BENCH.NEX did not return through SYS_EXIT')
    machine:exit()
  end
end)
