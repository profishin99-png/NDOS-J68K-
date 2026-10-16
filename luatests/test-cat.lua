local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN CAT.NEX README.TXT\r') end
  if frames == 450 then emu.keypost('RUN CAT.NEX\r') end
  if frames == 800 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local f = assert(io.open('cat-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X BYTES=%08X DATA=',
      cpu.state['PC'].value, cpu.state['A7'].value,
      mem:read_u32(0x00010086)))
    for i = 0, 15 do f:write(string.format('%02X', mem:read_u8(0x0001008A+i))) end
    f:write('\n')
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-cat.png') end
    machine:exit()
  end
end)
