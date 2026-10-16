-- Verify the BIOS loaded NDOS.SYS from a mounted raw FAT12 SD image.
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
local result

local function finish(status, mismatches, commands, shell_wait, details)
  for _, screen in pairs(machine.screens) do
    screen:snapshot("sd-boot-" .. status:lower() .. ".png")
  end
  result = assert(io.open("sd-boot-result.txt", "w"))
  result:write(string.format(
    "%s frames=%d bytes=%d mismatches=%d sd_commands=%d shell_wait=%s PC=%08X SSP=%08X\n%s",
    status, frames, #expected, mismatches, commands, shell_wait and "PASS" or "FAIL",
    cpu.state["PC"].value, mem:read_u32(0), details or ""))
  result:close()
  machine:exit()
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then
    local commands = mem:read_u32(0x00e30010)
    local mismatches = 0
    local details = {}
    -- NDOS has writable globals and a live stack in its lower image area.
    -- Compare immutable startup code and the linked C image, not live state.
    local ranges = {{0x00000100, 0x00001600}, {0x0000c000, #expected}}
    for _, range in ipairs(ranges) do
      for offset = range[1], math.min(range[2], #expected) - 1 do
        local actual = mem:read_u8(offset)
        if actual ~= expected:byte(offset + 1) then
          mismatches = mismatches + 1
          if #details < 40 then
            details[#details + 1] = string.format("%06X expected=%02X actual=%02X\n",
              offset, expected:byte(offset + 1), actual)
          end
        end
      end
    end
    details = table.concat(details)
    local pc = cpu.state["PC"].value
    local shell_wait = pc >= shell_wait_start and pc < shell_wait_end
    if commands > 0 and mismatches == 0 and shell_wait then
      finish("PASS", mismatches, commands, shell_wait, details)
    else
      finish("FAIL", mismatches, commands, shell_wait, details)
    end
  end
end)
