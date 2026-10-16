-- Verify one-sector writes are visible again through the mounted image.
local machine = manager.machine
local mem = machine.devices[":maincpu"].spaces["program"]
local lba = 2879
local buffer = 0x00e31000
local status = 0x00e30000
local command = 0x00e30004
local lba_register = 0x00e30008
local commands = 0x00e30010
local mismatches = 0

for offset = 0, 511 do
  mem:write_u8(buffer + offset, (offset * 29 + 0x53) % 256)
end
mem:write_u32(lba_register, lba)
mem:write_u32(command, 2)
local write_error = mem:read_u32(status) % 256
mem:write_u32(lba_register, lba)
mem:write_u32(command, 1)
local read_error = mem:read_u32(status) % 256
for offset = 0, 511 do
  if mem:read_u8(buffer + offset) ~= (offset * 29 + 0x53) % 256 then
    mismatches = mismatches + 1
  end
end

local passed = write_error == 0 and read_error == 0 and mismatches == 0
local result = assert(io.open("sd-write-result.txt", "w"))
result:write(string.format("%s lba=%d write_error=%d read_error=%d mismatches=%d commands=%d\n",
  passed and "PASS" or "FAIL", lba, write_error, read_error,
  mismatches, mem:read_u32(commands)))
result:close()
machine:exit()
