local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 120 then emu.keypost('RUN SYS11.NEX\r') end
  if frames == 340 then emu.keypost('RUN SYS12.NEX\r') end
  if frames == 430 then emu.keypost('AC\bBD\r') end
  if frames == 700 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local f = assert(io.open('syscalls11-12-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X\n',
      cpu.state['PC'].value, cpu.state['A7'].value))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-syscalls11-12.png')
    end
    machine:exit()
  end
end)
