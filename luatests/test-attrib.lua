-- Run the ATTRIB syscall regression once and report its process exit code.
local frames = 0

local function symbol_address(wanted)
  local f = assert(io.open('build/ndos.lst', 'r'))
  for line in f:lines() do
    local address, symbol = line:match('^%s*(%x+)%s+([%w_]+)%s*$')
    if symbol == wanted then
      f:close()
      return tonumber(address, 16)
    end
  end
  f:close()
  error('symbol not found in build/ndos.lst: ' .. wanted)
end

local task_b = symbol_address('SECOND_PROCESS')
local process_state = symbol_address('PROC_STATE')
local exit_code = symbol_address('PROC_EXIT_CODE')

local function read_u32_be(mem, address)
  return mem:read_u8(address) * 0x1000000
       + mem:read_u8(address + 1) * 0x10000
       + mem:read_u8(address + 2) * 0x100
       + mem:read_u8(address + 3)
end

local function write_u32_be(mem, address, value)
  mem:write_u8(address, math.floor(value / 0x1000000) % 0x100)
  mem:write_u8(address + 1, math.floor(value / 0x10000) % 0x100)
  mem:write_u8(address + 2, math.floor(value / 0x100) % 0x100)
  mem:write_u8(address + 3, value % 0x100)
end

emu.register_frame_done(function()
  frames = frames + 1
  local machine = manager.machine
  local mem = machine.devices[':maincpu'].spaces['program']

  -- Keep this syscall-only regression single-tasked: the standard boot image
  -- initializes the demonstration Task B, but this test should run one copy.
  if frames == 300 then
    write_u32_be(mem, task_b + 4, 0) -- PROC_UNUSED
    emu.keypost('RUN ATTTEST.NEX\r')
  elseif frames == 700 then
    local state = read_u32_be(mem, process_state)
    local code = read_u32_be(mem, exit_code)
    local result = assert(io.open('__ATTRIB_RESULT_PATH__', 'w'))
    result:write(string.format('STATE=%u EXIT_CODE=%u\n', state, code))
    result:close()
    assert(state == 4, 'ATTRIB test executable did not exit')
    assert(code == 0, string.format('ATTRIB test failed at assembly check %u', code))
    machine:exit()
  end
end)
