-- Verify mount selection, root enumeration, and file lookup/read on the SD image.
local frames = 0
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local boot_commands = 0
local discovery_address
for line in io.lines("c-map.inc") do
  local name, hex = line:match("^%s*([%w_]+)%s+equ%s+%$(%x+)")
  if name == "NDOS_TEST_SD_DISCOVERY" then discovery_address = tonumber(hex, 16) end
end
assert(discovery_address, "ndos_test_sd_discovery is absent from c-map.inc")

local function start_call(address)
  local harness = 0x00190000
  mem:write_u16(harness, 0x4eb9) -- JSR absolute long
  mem:write_u32(harness + 2, address)
  mem:write_u16(harness + 6, 0x60fe) -- BRA.S to itself
  cpu.state["PC"].value = harness
end

local function finish(status, details)
  local file = assert(io.open("sd-filesystem-result.txt", "w"))
  file:write(string.format(
    "%s frames=%d boot_commands=%d final_commands=%d PC=%08X\n%s",
    status, frames, boot_commands, mem:read_u32(0x00e30010),
    cpu.state["PC"].value, details or ""))
  file:close()
  for _, screen in pairs(machine.screens) do screen:snapshot("sd-filesystem.png") end
  machine:exit()
end

emu.register_frame_done(function()
  frames = frames + 1
  if frames == 100 then
    boot_commands = mem:read_u32(0x00e30010)
    start_call(discovery_address)
  elseif frames == 350 then
    local return_pc = cpu.state["PC"].value
    local return_code = cpu.state["D0"].value
    local final_commands = mem:read_u32(0x00e30010)
    if return_pc ~= 0x00190006 or return_code ~= 0 then
      finish("FAIL", string.format(
        "SD mount/root enumeration/SDCOPY.TXT read failed: PC=%08X D0=%08X.\n",
        return_pc, return_code))
      return
    end
    if final_commands > boot_commands then
      finish("PASS", "SD mount selected the card; DIR enumeration found SDCOPY.TXT; file lookup/read matched host data.\n")
    else
      finish("FAIL", string.format(
        "C test result PC=%08X D0=%08X; SD commands did not advance as expected.\n",
        return_pc, return_code))
    end
  end
end)
