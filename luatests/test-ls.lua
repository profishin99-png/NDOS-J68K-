local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN LS.NEX\r') end
  if frames == 500 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local f = assert(io.open('ls-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X\n',
      cpu.state['PC'].value, cpu.state['A7'].value))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-ls.png')
    end
    machine:exit()
  end
end)
