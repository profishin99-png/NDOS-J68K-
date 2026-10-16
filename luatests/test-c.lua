-- Execute the GCC-built MC68020 code through the NDOS command interface.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 40 then emu.keypost('CTEST\r') end
  if frames == 180 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local program = cpu.spaces['program']
    local f = assert(io.open('c-test-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X C000=%04X C002=%04X\n',
      cpu.state['PC'].value, cpu.state['A7'].value,
      program:read_u16(0x0000c000), program:read_u16(0x0000c002)))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-c-test.png')
    end
    manager.machine:exit()
  end
end)
