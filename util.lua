
function Filter(t, f)
  local res = {}
  for _,v in ipairs(t) do
    if f(v) then
      res[#res + 1] = v
    end
  end
  return res
end

function PrintObject(object)
  local function valueToString(v)
    if type(v) == "function" then
      local value = "function call failed"
      local function f()
        value = "=> "..tostring(v(object))
      end
      local status,err = pcall(f)
      return value
    else
      return tostring(v)
    end
  end
  
  local function printKeyValuePairs(kv)
    local keyLength = 1
    local sortedKeys = {}
    for k in pairs(kv) do
      table.insert(sortedKeys, k)
      keyLength = math.max(keyLength, #tostring(k))
    end
    table.sort(sortedKeys)
    local valueOffset = keyLength + 4
    for i,k in ipairs(sortedKeys) do
      print(k..string.rep(".", valueOffset - #tostring(k))..valueToString(kv[k]))
    end
  end
  
  if type(object) == "table" then
    print("Table values:")
    printKeyValuePairs(object)
  end
  if getmetatable(object) and type(getmetatable(object).__index) == "table" then
    print("From metatable:")
    printKeyValuePairs(getmetatable(object).__index)
  end
  print()
end

function PrintLocation(location)
  print(math.floor(location[1]),math.floor(location[2]))
end