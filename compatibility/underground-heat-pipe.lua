if not mods["underground-heat-pipe"] then return end

for p, prototype in pairs(data.raw["pipe-to-ground"]) do
  if p:find("underground%-heat%-pipe") then
    prototype.pu_compat = {ignore = true}
  end
end