local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then emu.keypost('DIR\r') end
  if frames == 250 then emu.keypost('TYPE README.TXT\r') end
  if frames == 400 then emu.keypost('TYPE HELLO.NEX\r') end
  if frames == 550 then emu.keypost('RUN ABOUT.NEX\r') end
  if frames == 700 then emu.keypost('RUN ADDTEST.NEX\r') end
  if frames == 850 then emu.keypost('RUN DINFO.NEX\r') end
  if frames == 1300 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local f = assert(io.open('build/test-results/apps-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X EXIT=%08X\n',
      cpu.state['PC'].value, cpu.state['A7'].value,
      cpu.spaces['program']:read_u32(0x00001b30)))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-apps.png') end
    machine:exit()
  end
end)
