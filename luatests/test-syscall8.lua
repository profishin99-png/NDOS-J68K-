local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then emu.keypost('RUN STEST.NEX\r') end
  if frames == 500 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local f = assert(io.open('syscall8-result.txt', 'w'))
    local info = 0x000100aa
    f:write(string.format('PC=%08X SP=%08X PROC_EXIT=%08X TOTAL=%08X FREE=%08X CLUSTERS=%08X FREE_CLUSTERS=%08X BPC=%08X\n',
      cpu.state['PC'].value, cpu.state['A7'].value,
      cpu.spaces['program']:read_u32(0x00001ad4),
      cpu.spaces['program']:read_u32(info),
      cpu.spaces['program']:read_u32(info + 4),
      cpu.spaces['program']:read_u32(info + 8),
      cpu.spaces['program']:read_u32(info + 12),
      cpu.spaces['program']:read_u32(info + 16)))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-syscall8.png')
    end
    machine:exit()
  end
end)
