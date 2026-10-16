-- Exercise the NDOS MEM MAP command through the interrupt-driven console.
local frames=0
emu.register_frame_done(function()
 frames=frames+1
 if frames==40 then emu.keypost('MEM MAP\r') end
 if frames==180 then
  local machine=manager.machine
  local cpu=machine.devices[':maincpu']
  local f=assert(io.open('map-result.txt','w'))
  f:write(string.format('PC=%08X SP=%08X\n',
    cpu.state['PC'].value,cpu.state['A7'].value))
  f:close()
  for _,screen in pairs(machine.screens) do screen:snapshot('ndos-map.png') end
 end
end)
