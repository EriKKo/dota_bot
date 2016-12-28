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

return {
  GetFountainLocation = GetFountainLocation,
  GetLocationToLocationDistance = GetLocationToLocationDistance,
  MoveAlongLine = MoveAlongLine
}