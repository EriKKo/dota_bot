local function f()
  -- Do stuff here
end
local status,err = pcall(f)
if not status then
  print(err)
end