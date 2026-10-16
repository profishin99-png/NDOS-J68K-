-- Exercise TYPE through the real NDOS parser and MC68020 FAT12 reader.
local frames = 0
local content = ''
for i = 1, 24 do
  content = content .. string.format('LINE %02d FROM CHAIN.TXT\r\n', i)
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 35 then
    local mem = manager.machine.devices[':maincpu'].spaces['program']
    local base = 0x00100000
    local root = base + 0x600
    local name = 'CHAIN   TXT'
    for i = 1, #name do mem:write_u8(root+i-1, string.byte(name, i)) end
    mem:write_u8(root+11, 0x20)
    mem:write_u8(root+26, 0x02)
    mem:write_u8(root+27, 0x00)
    local size = #content
    for i = 0, 3 do mem:write_u8(root+28+i, (size >> (i*8)) & 0xFF) end
    mem:write_u8(root+32, 0x00)

    for _, fat_offset in ipairs({0x200, 0x400}) do
      mem:write_u8(base+fat_offset+3, 0x05) -- cluster 2 -> 5
      mem:write_u8(base+fat_offset+4, 0x00)
      mem:write_u8(base+fat_offset+7, 0xF0) -- cluster 5 -> $FFF
      mem:write_u8(base+fat_offset+8, 0xFF)
    end
    for i = 0, 511 do
      local value = i < #content and string.byte(content, i+1) or 0
      mem:write_u8(base+0xE00+i, value)
    end
    for i = 0, 511 do
      local source = 513+i
      local value = source <= #content and string.byte(content, source) or 0
      mem:write_u8(base+0x1400+i, value)
    end
    emu.keypost('TYPE chain.txt\r')
  end

  if frames == 190 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local out = 0x00110200
    local mismatches = 0
    for i = 1, #content do
      if mem:read_u8(out+i-1) ~= string.byte(content, i) then
        mismatches = mismatches + 1
      end
    end
    local f = assert(io.open('type-result.txt', 'w'))
    f:write(string.format('PC=%08X SIZE=%u MISMATCHES=%u FIRST=%02X BOUNDARY=%02X LAST=%02X\n',
      machine.devices[':maincpu'].state['PC'].value, #content, mismatches,
      mem:read_u8(out), mem:read_u8(out+512), mem:read_u8(out+#content-1)))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-type.png') end
    emu.keypost('TYPE MISSING.TXT\r')
  end

  if frames == 285 then emu.keypost('TYPE\r') end
  if frames == 430 then
    for _, screen in pairs(manager.machine.screens) do
      screen:snapshot('ndos-type-errors.png')
    end
    manager.machine:exit()
  end
end)
