-- Verify RUN usage and missing-file reporting without launching a program.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 40 then emu.keypost('RUN MISSING.NEX\r') end
  if frames == 150 then emu.keypost('RUN\r') end
  if frames == 280 then
    for _, screen in pairs(manager.machine.screens) do
      screen:snapshot('ndos-nex-errors.png')
    end
    manager.machine:exit()
  end
end)
