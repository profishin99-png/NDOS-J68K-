-- Start the interactive Pong demo after the serial BIOS reaches NDOS.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN PONG.NEX\r') end
end)
