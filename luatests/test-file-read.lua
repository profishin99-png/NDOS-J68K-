-- Build CHAIN.BIN directly in the virtual disk, then run the MC68020 reader.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 35 then
    local mem = manager.machine.devices[':maincpu'].spaces['program']
    local base = 0x00100000
    local root = base + 0x600
    local name = 'CHAIN   BIN'
    for i = 1, #name do mem:write_u8(root+i-1, string.byte(name, i)) end
    mem:write_u8(root+11, 0x20)
    mem:write_u8(root+26, 0x02)
    mem:write_u8(root+27, 0x00)
    mem:write_u8(root+28, 0xBC) -- 700 = $000002BC, little endian
    mem:write_u8(root+29, 0x02)
    mem:write_u8(root+30, 0x00)
    mem:write_u8(root+31, 0x00)
    mem:write_u8(root+32, 0x00)

    -- Cluster 2 -> 5 and cluster 5 -> $FFF in both FAT copies.
    for _, fat_offset in ipairs({0x200, 0x400}) do
      mem:write_u8(base+fat_offset+3, 0x05)
      mem:write_u8(base+fat_offset+4, 0x00)
      mem:write_u8(base+fat_offset+7, 0xF0)
      mem:write_u8(base+fat_offset+8, 0xFF)
    end
    for i = 0, 511 do mem:write_u8(base+0xE00+i, (i ~ 0x5A) & 0xFF) end
    for i = 0, 511 do mem:write_u8(base+0x1400+i, (i ~ 0xC3) & 0xFF) end
    emu.keypost('FTEST\r')
  end
  if frames == 190 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local out = 0x00110200
    local mismatches = 0
    for i = 0, 511 do
      if mem:read_u8(out+i) ~= ((i ~ 0x5A) & 0xFF) then mismatches = mismatches + 1 end
    end
    for i = 0, 187 do
      if mem:read_u8(out+512+i) ~= ((i ~ 0xC3) & 0xFF) then mismatches = mismatches + 1 end
    end
    local f = assert(io.open('file-read-result.txt', 'w'))
    f:write(string.format('PC=%08X MISMATCHES=%u FIRST=%02X BOUNDARY=%02X LAST=%02X\n',
      machine.devices[':maincpu'].state['PC'].value, mismatches,
      mem:read_u8(out), mem:read_u8(out+512), mem:read_u8(out+699)))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-file-read.png') end
    manager.machine:exit()
  end
end)
