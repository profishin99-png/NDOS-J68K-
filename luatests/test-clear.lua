-- Confirm CLEAR removes previous output and that the console still accepts HELP.
local frames=0
emu.register_frame_done(function()
 frames=frames+1
 if frames==30 then emu.keypost('HELP\r') end
 if frames==90 then emu.keypost('CLEAR\r') end
 if frames==150 then
  for _,screen in pairs(manager.machine.screens) do screen:snapshot('ndos-clear.png') end
 end
 if frames==170 then emu.keypost('HELP\r') end
 if frames==240 then
  for _,screen in pairs(manager.machine.screens) do screen:snapshot('ndos-after-clear.png') end
 end
end)
