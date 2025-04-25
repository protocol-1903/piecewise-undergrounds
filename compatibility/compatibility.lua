require("__piecewise-undergrounds__/compatibility/FluidMustFlow")

for u, underground in pairs(data.raw["pipe-to-ground"]) do
  if not underground.pu_compat then
    local pipe = u:sub(1, -11)
    if data.raw.pipe[pipe] then
      underground.pu_compat = {
        associated_pipe = pipe
      }
    else
      error("Associated pipe not found for: " .. u)
    end
  end
end