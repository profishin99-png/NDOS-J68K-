-- Run MHZ.NEX on an isolated J68K disk and verify it returns to NDOS.
local frames = 0
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local result = assert(io.open("mhz-mame-result.txt", "w"))

local function finish(status)
  local pc = cpu.state["PC"].value
  local ticks = mem:read_u32(0x0000161c)
  local process_state = mem:read_u32(0x00002374)
  local exit_code = mem:read_u32(0x00002390)
  for _, screen in pairs(machine.screens) do
    screen:snapshot("mhz-" .. status .. ".png")
  end
  result:write(string.format(
    "%s frame=%d PC=%08X ticks=%u state=%u exit=%d\n",
    status, frames, pc, ticks, process_state, exit_code))
  result:close()
  machine:exit()
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then
    emu.keypost("RUN MHZ.NEX\r")
  elseif frames > 100 then
    if mem:read_u32(0x00002374) == 4 then
      if mem:read_u32(0x00002390) == 0 then
        finish("PASS")
      else
        finish("FAIL")
      end
    elseif frames == 1300 then
      finish("TIMEOUT")
    end
  end
end)
