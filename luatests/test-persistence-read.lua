-- Verify that MAME restored the FAT12 volume from the preceding process.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 50 then emu.keypost('DIR\r') end
  if frames == 180 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local base = 0x00100000
    local root = base + 0x600
    local f = assert(io.open('persistence-result.txt', 'w'))
    f:write(string.format(
      'SIG=%02X%02X FAT1=%02X%02X%02X ROOTNAME=%c%c%c%c%c ROOTEXT=%c%c%c ROOTSIZE=%02X%02X%02X%02X ROOTCLUSTER=%02X%02X ROOTATTR=%02X\n',
      mem:read_u8(base+0x1fe), mem:read_u8(base+0x1ff),
      mem:read_u8(base+0x200), mem:read_u8(base+0x201), mem:read_u8(base+0x202),
      mem:read_u8(root+0), mem:read_u8(root+1), mem:read_u8(root+2),
      mem:read_u8(root+3), mem:read_u8(root+4),
      mem:read_u8(root+8), mem:read_u8(root+9), mem:read_u8(root+10),
      mem:read_u8(root+31), mem:read_u8(root+30),
      mem:read_u8(root+29), mem:read_u8(root+28),
      mem:read_u8(root+27), mem:read_u8(root+26), mem:read_u8(root+11)))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-persistence.png')
    end
    manager.machine:exit()
  end
end)
