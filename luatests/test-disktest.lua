-- Run NDOS's destructive 128-sector RAM-disk test, then independently
-- verify that sector N contains 512 copies of byte N.
local frames=0
emu.register_frame_done(function()
 frames=frames+1
 if frames==100 then emu.keypost('DISKTEST\r') end
 if frames==500 then
  local machine=manager.machine
  local cpu=machine.devices[':maincpu']
  local mem=cpu.spaces['program']
  local mismatches=0
  local first_bad=-1
  for sector=0,127 do
   for offset=0,511 do
    local address=0x00100000+sector*512+offset
    if mem:read_u8(address)~=sector then
     mismatches=mismatches+1
     if first_bad<0 then first_bad=address end
    end
   end
  end
  local f=assert(io.open('disktest-result.txt','w'))
  f:write(string.format('PC=%08X MISMATCHES=%d FIRST_BAD=%08X S0=%02X S1=%02X S127=%02X\n',
    cpu.state['PC'].value,mismatches,first_bad,mem:read_u8(0x00100000),
    mem:read_u8(0x00100200),mem:read_u8(0x0010fe00)))
  f:close()
  for _,screen in pairs(machine.screens) do screen:snapshot('ndos-disktest.png') end
 end
end)
