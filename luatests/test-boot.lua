local n=0
emu.register_frame_done(function()
 n=n+1
 if n==30 then emu.keypost('HELP\r') end
 if n==100 then emu.keypost('VERSION\r') end
 if n==200 then
  local cpu=manager.machine.devices[':maincpu']
  local f=assert(io.open('boot-result.txt','w'))
  f:write(string.format('PC=%08X SP=%08X RAM_SSP=%08X RAM_PC=%08X\n',cpu.state['PC'].value,cpu.state['A7'].value,cpu.spaces['program']:read_u32(0),cpu.spaces['program']:read_u32(4)))
  f:close()
  for _,screen in pairs(manager.machine.screens) do screen:snapshot('ndos-boot.png') end
 end
end)
