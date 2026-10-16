-- Verify FREE through the real command parser and independently count FAT12.
local frames = 0

local function fat12_entry(mem, fat, cluster)
  local offset = cluster + (cluster >> 1)
  local lo = mem:read_u8(fat + offset)
  local hi = mem:read_u8(fat + offset + 1)
  local word = lo | (hi << 8)
  if (cluster & 1) == 0 then return word & 0x0fff end
  return (word >> 4) & 0x0fff
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then emu.keypost('FREE\r') end
  if frames == 500 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local base = 0x00100000
    local free = 0
    local copies_match = true
    local fat1 = base + 0x200
    local fat2 = base + 0x800
    for cluster = 2, 1010 do
      local first = fat12_entry(mem, fat1, cluster)
      local second = fat12_entry(mem, fat2, cluster)
      if first ~= second then copies_match = false end
      if first == 0 then free = free + 1 end
    end
    local f = assert(io.open('free-result.txt', 'w'))
    f:write(string.format(
      'PHYSICAL=%08X RESERVED=%08X UNRESERVED=%08X CLUSTERS=%08X DISK_BYTES=%08X FAT_COPIES=%s\n',
      0x00200000, 0x000b0200, 0x0014fe00, free, free * 512,
      copies_match and 'MATCH' or 'MISMATCH'))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-free.png') end
    machine:exit()
  end
end)
