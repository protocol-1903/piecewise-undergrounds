require("__piecewise-undergrounds__/compatibility/FluidMustFlow")
require("__piecewise-undergrounds__/compatibility/matts-logistics")
require("__piecewise-undergrounds__/compatibility/underground-heat-pipe")
require("__piecewise-undergrounds__/compatibility/Krastorio2")
require("__piecewise-undergrounds__/compatibility/dredgeworks")
require("__piecewise-undergrounds__/compatibility/Factorio-Tiberium")
require("__piecewise-undergrounds__/compatibility/laserfence")
require("__piecewise-undergrounds__/compatibility/Unipipe-Temperature")
require("__piecewise-undergrounds__/compatibility/Krastorio2-spaced-out")
require("__piecewise-undergrounds__/compatibility/linox")

for u, underground in pairs(data.raw["pipe-to-ground"]) do
  if not underground.pu_compat then
    local i, j = u:find("-to-ground", nil, true)
    if not i then
       i, j = u:find("-underground", nil, true)
    end
    if not i or not j then error("Coult not find substring for [" .. u .. "]") end
    local p = u:sub(1, i - 1) .. (j and u:sub(j + 1) or "")
    if data.raw.pipe[p] then
      underground.pu_compat = {associated_pipe = p}
    else
      error("Associated pipe [" .. p .. "] not found for [" .. u .. "]")
    end
  end
end
