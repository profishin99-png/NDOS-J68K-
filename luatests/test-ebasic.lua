-- Deterministic EhBASIC smoke test under NDOS/MAME.
-- Start from an isolated, full-size MAME NVRAM image containing EBASIC.NEX.
-- The shell command uses the serial terminal keyboard path. The BASIC commands
-- are inserted as uppercase bytes into NDOS's already-tested RX ring because
-- MAME's natural-keyboard post helper maps alphabetic input to lowercase,
-- while upstream EhBASIC's keyword tables are uppercase.
local frames = 0
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local result = assert(io.open("ebasic-mame-result.txt", "w"))

local function inject_basic_line(text)
  local write_index = mem:read_u8(0x0015f9)
  local count = mem:read_u16(0x0015fa)
  for i = 1, #text do
    mem:write_u8(0x0014f8 + ((write_index + i - 1) & 0xff), text:byte(i))
  end
  mem:write_u8(0x0015f9, (write_index + #text) & 0xff)
  mem:write_u16(0x0015fa, count + #text)
end

local function capture(label)
  local n = 0
  for _, screen in pairs(machine.screens) do
    n = n + 1
    screen:snapshot("ebasic-" .. label .. "-" .. n .. ".png")
  end
  result:write(string.format(
    "%s frame=%d PC=%08X SR=%04X A7=%08X RX_COUNT=%u\n",
    label, frames, cpu.state["PC"].value, cpu.state["SR"].value,
    cpu.state["A7"].value, mem:read_u16(0x0015fa)))
  result:flush()
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then
    emu.keypost("RUN EBASIC.NEX\r")
  elseif frames == 400 then
    capture("ready")
  elseif frames == 450 then
    inject_basic_line("PRINT 2+2\r")
  elseif frames == 750 then
    capture("print")
  elseif frames == 800 then
    inject_basic_line('10 PRINT "J68K BASIC"\r')
  elseif frames == 1100 then
    capture("entered")
  elseif frames == 1150 then
    inject_basic_line("LIST\r")
  elseif frames == 1400 then
    capture("listed")
  elseif frames == 1450 then
    inject_basic_line("RUN\r")
  elseif frames == 1700 then
    capture("ran")
    inject_basic_line("EXIT\r")
  elseif frames == 1950 then
    capture("exited")
    result:close()
    machine:exit()
  end
end)
