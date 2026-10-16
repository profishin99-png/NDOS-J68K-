-- Exercise KDR without using its intentionally absent run command.
local frames=0
emu.register_frame_done(function()
 frames=frames+1
 if frames==25 then
  emu.keypost('KDR\r100000: DE AD BE EF\r110000: CA FE\r100000.10000F\r000100: 12\rR\rQ\r')
 end
 if frames==500 then
  local machine=manager.machine
  local cpu=machine.devices[':maincpu']
  local mem=cpu.spaces['program']
  local f=assert(io.open('kdr-result.txt','w'))
  f:write(string.format('PC=%08X RAMDISK=%08X SECTOR=%04X KERNEL_BYTE=%02X\n',
    cpu.state['PC'].value,mem:read_u32(0x100000),mem:read_u16(0x110000),mem:read_u8(0x100)))
  f:close()
  for _,screen in pairs(machine.screens) do screen:snapshot('ndos-kdr.png') end
 end
end)
