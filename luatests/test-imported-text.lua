-- Verify a PC-imported HAM12.TXT can be found and displayed by TYPE.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 45 then emu.keypost('TYPE HAM12.TXT\r') end
  if frames == 180 then
    local machine = manager.machine
    local mem = machine.devices[':maincpu'].spaces['program']
    local out = 0x00110200
    local f = assert(io.open('imported-text-result.txt', 'w'))
    f:write(string.format('PC=%08X DATA=%c%c%c%c%c%c\n',
      machine.devices[':maincpu'].state['PC'].value,
      mem:read_u8(out+0), mem:read_u8(out+1), mem:read_u8(out+2),
      mem:read_u8(out+3), mem:read_u8(out+4), mem:read_u8(out+5)))
    f:close()
    for _, screen in pairs(machine.screens) do
      screen:snapshot('ndos-imported-text.png')
    end
    manager.machine:exit()
  end
end)
