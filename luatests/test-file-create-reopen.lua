-- Confirm a file made by the preceding MAME process persisted to disk.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 45 then emu.keypost('DIR\r') end
  if frames == 170 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local base = 0x00100000
    local root = base + 0x600
    local f = assert(io.open('file-create-reopen-result.txt', 'w'))
    f:write(string.format(
      'NAME=%c%c%c%c%c%c EXT=%c%c%c SIZE=%02X%02X%02X%02X CLUSTER=%02X%02X FAT1=%02X%02X%02X FAT2=%02X%02X%02X\n',
      mem:read_u8(root+0), mem:read_u8(root+1), mem:read_u8(root+2),
      mem:read_u8(root+3), mem:read_u8(root+4), mem:read_u8(root+5),
      mem:read_u8(root+8), mem:read_u8(root+9), mem:read_u8(root+10),
      mem:read_u8(root+31), mem:read_u8(root+30),
      mem:read_u8(root+29), mem:read_u8(root+28),
      mem:read_u8(root+27), mem:read_u8(root+26),
      mem:read_u8(base+0x203), mem:read_u8(base+0x204), mem:read_u8(base+0x205),
      mem:read_u8(base+0x403), mem:read_u8(base+0x404), mem:read_u8(base+0x405)))
    f:close()
    manager.machine:exit()
  end
end)
