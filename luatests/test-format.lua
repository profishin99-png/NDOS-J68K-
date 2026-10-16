-- Exercise FAT12 formatting and root-directory listing.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 40 then emu.keypost('FORMAT\r') end
  if frames == 100 then emu.keypost('FORMAT YES\r') end
  if frames == 190 then emu.keypost('DIR\r') end
  if frames == 260 then
    local mem = manager.machine.devices[':maincpu'].spaces['program']
    local root = 0x00100600
    local name = 'HELLO   NEX'
    for i = 1, #name do mem:write_u8(root+i-1, string.byte(name, i)) end
    mem:write_u8(root+11, 0x20) -- archive attribute
    mem:write_u8(root+26, 0x02) -- first cluster, little endian
    mem:write_u8(root+27, 0x00)
    mem:write_u8(root+28, 0x34) -- size $00001234, little endian
    mem:write_u8(root+29, 0x12)
    mem:write_u8(root+30, 0x00)
    mem:write_u8(root+31, 0x00)
    mem:write_u8(root+32, 0x00) -- end of root directory
    emu.keypost('DIR\r')
  end
  if frames == 420 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local base = 0x00100000
    local root = base + 0x600
    local f = assert(io.open('format-result.txt', 'w'))
    f:write(string.format(
      'PC=%08X BPS=%02X%02X SPC=%02X FATS=%02X ROOT=%02X%02X TOTAL=%02X%02X SIG=%02X%02X FAT1=%02X%02X%02X FAT2=%02X%02X%02X ROOT0=%02X DATA0=%02X ROOTSIZE=%02X%02X%02X%02X ROOTCLUSTER=%02X%02X ROOTATTR=%02X\n',
      cpu.state['PC'].value,
      mem:read_u8(base+0x0b), mem:read_u8(base+0x0c),
      mem:read_u8(base+0x0d), mem:read_u8(base+0x10),
      mem:read_u8(base+0x11), mem:read_u8(base+0x12),
      mem:read_u8(base+0x13), mem:read_u8(base+0x14),
      mem:read_u8(base+0x1fe), mem:read_u8(base+0x1ff),
      mem:read_u8(base+0x200), mem:read_u8(base+0x201), mem:read_u8(base+0x202),
      mem:read_u8(base+0x400), mem:read_u8(base+0x401), mem:read_u8(base+0x402),
      mem:read_u8(root), mem:read_u8(base+0xe00),
      mem:read_u8(root+31), mem:read_u8(root+30),
      mem:read_u8(root+29), mem:read_u8(root+28),
      mem:read_u8(root+27), mem:read_u8(root+26), mem:read_u8(root+11)))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-format.png')
    end
    manager.machine:exit()
  end
end)
