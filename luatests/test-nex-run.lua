-- Load HELLO.NEX through FAT12, execute it in user mode, and verify its image.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 40 then emu.keypost('DIR\r') end
  if frames == 130 then emu.keypost('RUN hello.nex\r') end
  if frames == 300 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local input = io.open('HELLO.NEX', 'rb') or
                  assert(io.open('build/HELLO.NEX', 'rb'))
    local nex = input:read('*a')
    input:close()
    local mismatches = 0
    for i = 17, #nex do
      if mem:read_u8(0x00010000+i-17) ~= string.byte(nex, i) then
        mismatches = mismatches + 1
      end
    end
    local f = assert(io.open('nex-run-result.txt', 'w'))
    f:write(string.format(
      'PC=%08X SP=%08X NEX_SIZE=%u PAYLOAD=%u MISMATCHES=%u FIRST=%04X\n',
      cpu.state['PC'].value, cpu.state['A7'].value, #nex, #nex-16,
      mismatches, mem:read_u16(0x00010000)))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-nex-run.png') end
    manager.machine:exit()
  end
end)
