-- Capture POST before its clear-screen handoff, then verify the BIOS header.
local frames=0
emu.register_frame_done(function()
 frames=frames+1
 if frames==1 then
  for _,screen in pairs(manager.machine.screens) do screen:snapshot('j68k-post.png') end
 end
 if frames==2 then
  for _,screen in pairs(manager.machine.screens) do screen:snapshot('j68k-post-complete.png') end
 end
 if frames==10 then
  for _,screen in pairs(manager.machine.screens) do screen:snapshot('j68k-post-result.png') end
 end
 if frames==120 then
  local machine=manager.machine
  local cpu=machine.devices[':maincpu']
  local mem=cpu.spaces['program']
  local signature=''
  for i=0,7 do signature=signature..string.char(mem:read_u8(0xfff00020+i)) end
  local f=assert(io.open('bios-result.txt','w'))
  f:write(string.format('SIGNATURE=%s VERSION=%04X SERVICE0=%08X PC=%08X\n',
    signature,mem:read_u16(0xfff0002a),mem:read_u32(0xfff00040),cpu.state['PC'].value))
  f:close()
 end
end)
