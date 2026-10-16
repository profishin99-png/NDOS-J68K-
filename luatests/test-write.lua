local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 120 then emu.keypost('RUN WRITE.NEX\r') end
  if frames == 190 then emu.keypost('NOTE.TXT\r') end
  if frames == 260 then emu.keypost('hello from write\r') end
  if frames == 390 then emu.keypost('RUN LS.NEX\r') end
  if frames == 550 then emu.keypost('RUN CAT.NEX NOTE.TXT\r') end
  if frames == 850 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local f = assert(io.open('build/test-results/write-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X\n', cpu.state['PC'].value, cpu.state['A7'].value))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-write.png') end
    machine:exit()
  end
end)
