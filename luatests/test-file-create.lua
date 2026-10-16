-- Run the MC68020 file creator, list the result, and inspect both FAT copies.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 40 then emu.keypost('WTEST\r') end
  if frames == 150 then emu.keypost('DIR\r') end
  if frames == 280 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local base = 0x00100000
    local root = base + 0x600
    local f = assert(io.open('file-create-result.txt', 'w'))
    f:write(string.format(
      'PC=%08X NAME=%c%c%c%c%c%c EXT=%c%c%c SIZE=%02X%02X%02X%02X CLUSTER=%02X%02X FAT1=%02X%02X%02X FAT2=%02X%02X%02X\n',
      machine.devices[':maincpu'].state['PC'].value,
      mem:read_u8(root+0), mem:read_u8(root+1), mem:read_u8(root+2),
      mem:read_u8(root+3), mem:read_u8(root+4), mem:read_u8(root+5),
      mem:read_u8(root+8), mem:read_u8(root+9), mem:read_u8(root+10),
      mem:read_u8(root+31), mem:read_u8(root+30),
      mem:read_u8(root+29), mem:read_u8(root+28),
      mem:read_u8(root+27), mem:read_u8(root+26),
      mem:read_u8(base+0x203), mem:read_u8(base+0x204), mem:read_u8(base+0x205),
      mem:read_u8(base+0x403), mem:read_u8(base+0x404), mem:read_u8(base+0x405)))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-file-create.png')
    end
    manager.machine:exit()
  end
end)
