local function GetFountainLocation(enemy)
  if GetTeam() == TEAM_RADIANT and not enemy or GetTeam() == TEAM_DIRE and enemy then
    return Vector(-7000, -7000, 0)
  else
    return Vector(7000, 7000, 0)
  end
end

local function GetLocationToLocationDistance(l1, l2)
  return math.sqrt((l1[1] - l2[1])*(l1[1] - l2[1]) + (l1[2] - l2[2])*(l1[2] - l2[2]))
end

local function MoveAlongLine(source, target, distance)
  local dv = Vector(target[1] - source[1], target[2] - source[2])
  local len = math.sqrt(dv[1]*dv[1] + dv[2]*dv[2])
  dv[1] = dv[1] / len
  dv[2] = dv[2] / len
  return Vector(source[1] + dv[1] * distance, source[2] + dv[2] * distance, source[3])
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

return {
  GetFountainLocation = GetFountainLocation,
  GetLocationToLocationDistance = GetLocationToLocationDistance,
  MoveAlongLine = MoveAlongLine,
  GetTurnTime = GetTurnTime
}