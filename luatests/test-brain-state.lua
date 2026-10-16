local frame = 0

local function read_u32(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

emu.register_frame_done(function()
  frame = frame + 1
  if frame == 120 then emu.keypost('RUN2 BRAIN.NEX\r') end
  if frame == 600 then
    local mem = manager.machine.devices[':maincpu'].spaces['program']
    local out = assert(io.open('C:/Users/jvkow/Documents/Codex/2026-09-21/files-mentioned-by-the-user-j68k/outputs/ndos-alpha-002/build/test-results/brain-state.txt', 'w'))
    local task_b_ssp = read_u32(mem, 0x22dc + 60)
    out:write(string.format('TASK_A_STATE=%u\nTASK_B_STATE=%u\nCURRENT_PCB=%08X\nYIELDS=%u\nTICKS=%u\nTASK_B_SSP=%08X\nTASK_B_D6=%08X\nTASK_B_D7=%08X\n',
      read_u32(mem, 0x229c), read_u32(mem, 0x22e0), read_u32(mem, 0x2320),
      read_u32(mem, 0x1efb), read_u32(mem, 0x154c), task_b_ssp, read_u32(mem, task_b_ssp + 24),
      read_u32(mem, task_b_ssp + 28)))
    out:close()
    manager.machine:exit()
  end
end)
