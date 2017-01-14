local function GetFountainLocation(enemy)
  if GetTeam() == TEAM_RADIANT and not enemy or GetTeam() == TEAM_DIRE and enemy then
    return Vector(-6756.747070, -6312.382324, 512.000000)
  else
    return Vector(6698.524902, 6129.075195, 512.000000)
  end
end

local function GetLocationAlongLine(source, target, distance)
  local dv = target - source
  dv = dv / #dv
  return source + dv*distance
end

local function GetClosestPointAlongPath(startPoint, endPoint, p)
  local d = endPoint - startPoint
  if #d == 0 then
    return startPoint
  end
  local t = (d[1]*(p[1] - startPoint[1]) + d[2]*(p[2] - startPoint[2])) / (d[1]*d[1] + d[2]*d[2])
  t = math.max(0, math.min(1, t))
  return startPoint + t*d
end

local function GetAngle(sourceLocation, targetLocation)
  return math.atan2(targetLocation[2] - sourceLocation[2], targetLocation[1] - sourceLocation[1])
end

local l1 = {500, 1000}
local l2 = {500, 500}
print(GetAngle(l2, l1) * 180 / math.pi)

local function GetMinDistanceAlongPath(startPoint, endPoint, p)
  return #(GetClosestPointAlongPath(startPoint, endPoint, p) - p)
end

local function GetTurnTime(source, target)
  -- TODO Use turn rate other than 1.0
  local function mod(a)
    local p = 2*math.pi
    return (a%p + p) % p
  end
  
  local p1 = target:GetLocation()
  local p2 = source:GetLocation()
  local a = math.atan2(p1[2] - p2[2], p1[1] - p2[1])
  a = mod(a)
  local b = source:GetFacing() * math.pi / 180
  b = mod(b)
  local angleDiff = math.min(math.abs(a - b), math.abs(2*math.pi - a - b))
  angleDiff = math.max(0, angleDiff - 0.2)
  return 0.03 * angleDiff
end

function f()
  local PrintUtil = require(GetScriptDirectory() .. "/lib/print_util")

  local s = Vector(0, 0)
  local e = Vector(5, 5)
  local p = Vector(-1, 0)
  print(GetMinDistanceAlongPath(s, e, p))
end
local status,err = pcall(f)
if not status then
  print(err)
end

return {
  GetAngle = GetAngle,
  GetClosestPointAlongPath = GetClosestPointAlongPath,
  GetFountainLocation = GetFountainLocation,
  GetLocationToLocationDistance = GetLocationToLocationDistance,
  GetMinDistanceAlongPath = GetMinDistanceAlongPath,
  GetTurnTime = GetTurnTime,
  GetLocationAlongLine = GetLocationAlongLine
}