local function GetItem(player, itemName)
  for i = 0,5 do
    local item = player:GetItemInSlot(i)
    if item and item:GetName() == itemName then
      return item
    end
  end
end

return {
  GetItem = GetItem
}