-- Run DELETE.NEX against README.TXT, then prove its root entry is marked deleted.
local frames = 0

local function root_contains_name(mem, root, name)
  for entry = 0, 127 do
    local address = root + entry * 32
    local first = mem:read_u8(address)
    if first == 0x00 then break end
    if first ~= 0xe5 then
      local found = ''
      for byte = 0, 10 do found = found .. string.char(mem:read_u8(address + byte)) end
      if found == name then return true end
    end
  end
  return false
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN DELETE.NEX\r') end
  if frames == 360 then emu.keypost('README.TXT\r') end
  if frames == 720 then
    local machine = manager.machine
    local cpu = machine.devices[':maincpu']
    local mem = cpu.spaces['program']
    local disk = 0x00100000
    local bytes_per_sector = mem:read_u8(disk + 11) * 256 + mem:read_u8(disk + 12)
    local reserved = mem:read_u8(disk + 14) * 256 + mem:read_u8(disk + 15)
    local fats = mem:read_u8(disk + 16)
    local sectors_per_fat = mem:read_u8(disk + 22) * 256 + mem:read_u8(disk + 23)
    local root = disk + (reserved + fats * sectors_per_fat) * bytes_per_sector
    local present = root_contains_name(mem, root, 'README  TXT')
    local f = assert(io.open('build/test-results/delete-app-result.txt', 'w'))
    f:write(string.format('PC=%08X SP=%08X README_PRESENT=%s\n',
      cpu.state['PC'].value, cpu.state['A7'].value, tostring(present)))
    f:close()
    for _, screen in pairs(machine.screens) do screen:snapshot('ndos-delete-app.png') end
    machine:exit()
  end
end)
