-- Run the optional MAME-only QUICC.NEX playground and confirm that its
-- dual-worker drawing reaches the temporary framebuffer.  This uses an
-- isolated NVRAM directory, never the interactive NDOS development disk.
local frames = 0
local machine = manager.machine
local cpu = machine.devices[':maincpu']
local mem = cpu.spaces['program']

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 250 then emu.keypost('RUN QUICC.NEX\r') end
  if frames == 450 then
    local f = assert(io.open('test-results/quicc-play-app-result.txt', 'w'))
    f:write(string.format('LEFT=%02X RIGHT=%02X CENTRE=%02X STATUS=%08X COMMANDS=%u HEART_A=%08X HEART_B=%08X\n',
      mem:read_u8(0x00e00000 + 10 * 320 + 20),
      mem:read_u8(0x00e00000 + 10 * 320 + 300),
      mem:read_u8(0x00e00000 + 100 * 320 + 160),
      mem:read_u32(0x00e20004), mem:read_u32(0x00e20020),
      mem:read_u32(0x00e20024), mem:read_u32(0x00e20028)))
    f:close()
    assert(mem:read_u8(0x00e00000 + 10 * 320 + 20) == 0xe0, 'left worker did not render red')
    assert(mem:read_u8(0x00e00000 + 10 * 320 + 300) == 0x1c, 'right worker did not render green')
    assert(mem:read_u8(0x00e00000 + 100 * 320 + 160) == 0xfc, 'centre box did not render yellow')
    assert(mem:read_u32(0x00e20024) ~= 0 and mem:read_u32(0x00e20028) ~= 0, 'one M68000 heartbeat did not advance')
    for _, screen in pairs(machine.screens) do screen:snapshot('quicc-play-app.png') end
  end
  if frames == 475 then emu.keypost('Q') end
  if frames == 620 then machine:exit() end
end)
