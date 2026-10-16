-- Start two side-by-side Pong instances after the serial BIOS reaches NDOS.
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  if frames == 150 then emu.keypost('RUN2 PONG.NEX\r') end
end)
