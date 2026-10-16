-- Confirm absent SD media falls through to the ROM-resident NDOS image.
local frames = 0
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local expected_file = assert(io.open("ndos.bin", "rb"))
local expected = expected_file:read("*a")
expected_file:close()
local function symbol_address(wanted)
  for line in io.lines("ndos.lst") do
    local address, name = line:match("^([0-9A-Fa-f]+)%s+([%w_]+)$")
    if name == wanted then return tonumber(address, 16) end
  end
  error("symbol not found in ndos.lst: " .. wanted)
end
local shell_wait_start = symbol_address("DUART_GETCHAR")
local shell_wait_end = symbol_address("DUART_PUTS")

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then
    local commands = mem:read_u32(0x00e30010)
    local mismatches = 0
    for offset = 0x100, 0x15ff do
      if mem:read_u8(offset) ~= expected:byte(offset + 1) then
        mismatches = mismatches + 1
      end
    end
    for offset = 0xc000, #expected - 1 do
      if mem:read_u8(offset) ~= expected:byte(offset + 1) then
        mismatches = mismatches + 1
      end
    end
    local pc = cpu.state["PC"].value
    local shell_wait = pc >= shell_wait_start and pc < shell_wait_end
    local passed = commands == 0 and mismatches == 0 and shell_wait
    for _, screen in pairs(machine.screens) do
      screen:snapshot("sd-fallback-" .. (passed and "pass" or "fail") .. ".png")
    end
    local result = assert(io.open("sd-fallback-result.txt", "w"))
    result:write(string.format("%s frames=%d mismatches=%d sd_commands=%d shell_wait=%s PC=%08X SSP=%08X\n",
      passed and "PASS" or "FAIL", frames, mismatches, commands, shell_wait and "PASS" or "FAIL",
      cpu.state["PC"].value, mem:read_u32(0)))
    result:close()
    machine:exit()
  end
end)
