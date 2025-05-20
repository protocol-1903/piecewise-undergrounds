data:extend{{
  type = "recipe-category",
  name = "piecewise-undergrounds-void"
}}

local xutil = require "xutil"

require("__piecewise-undergrounds__/compatibility/compatibility")

-- modify undergrounds to only connect to proper same types, makes the whole thing a lot easier
if not mods["no-pipe-touching"] then
  for u, underground in pairs(data.raw["pipe-to-ground"]) do
    for _, connection in pairs(underground.fluid_box.pipe_connections) do
      if connection.connection_type == "underground" then
        connection.connection_category = u
      end
    end
  end
end

for u, underground in pairs(data.raw["pipe-to-ground"]) do

  if u:sub(1,9) ~= "incomplete-" then

    pipe = data.raw.pipe[underground.pu_compat.associated_pipe] or data.raw["storage-tank"][underground.pu_compat.associated_pipe]
    -- only create if the item exists, and it has not already been created
    if pipe and data.raw.item[pipe.name] and not data.raw["simple-entity-with-owner"]["pu-under-" .. pipe.name] then
      data:extend({
        {
          type = "simple-entity-with-owner",
          name = "pu-under-" .. pipe.name,
          localised_name = {"entity-name.psuedo-underground", {"entity-name." .. pipe.name}},
          picture = util.empty_sprite(),
          icon = util.empty_icon().icon,
          selection_box = {{-0.35, -0.35}, {0.35, 0.35}},
          selection_priority = 60,
          allow_copy_paste = false,
          flags = { "placeable-neutral", "not-on-map", "not-upgradable", "placeable-off-grid", "player-creation" },
          placeable_by = { item = pipe.name, count = 1},
          minable = { mining_time = 1, result = pipe.name },
          hidden_in_factoriopedia = true
        }
      })
    end

    -- make the old item place this new item
    data.raw.item[u].place_result = "incomplete-" .. u
    underground.placeable_by = {item = u, count = 1}

    local incomplete = {
      type = "valve",
      name = "incomplete-" .. u,
      localised_name = {"entity-name.incomplete", {"entity-name." .. u}},
      hidden_in_factoriopedia = true,
      icon = underground.icon,
      icon_size = underground.icon_size,
      placeable_by = underground.placeable_by,
      minable = underground.minable,
      flags = underground.flags,
      collision_box = underground.collision_box,
      selection_box = underground.selection_box,
      heating_energy = underground.heating_energy,
      fluid_box = table.deepcopy(underground.fluid_box),
      mode = "one-way",
      flow_rate = 0,
      animations = underground.pictures
    }
    data.raw.valve["incomplete-" .. u] = incomplete

    for _, connection in pairs(incomplete.fluid_box.pipe_connections) do
      connection.flow_direction = connection.connection_type == "underground" and "input-output" or "output"
    end

    -- if recipe exists
    if not mods["bztin"] and data.raw.recipe[u] then
      local ingredients = data.raw.recipe[u].ingredients
      data.raw.recipe[u].ingredients = {}
      -- add ingredient if not the associated pipe
      for _, ingredient in pairs(ingredients) do
        if not data.raw.pipe[ingredient.name] then -- if not a pipe then add to ingredients
          data.raw.recipe[u].ingredients[#data.raw.recipe[u].ingredients+1] = ingredient
        end
      end
    elseif mods["bztin"] and data.raw.recipe[u] then
      -- modify counts
      for _, ingredient in pairs(data.raw.recipe[u].ingredients) do
        if data.raw.pipe[ingredient.name] and ingredient.amount > 2 then
          ingredient.amount = 2 -- if a pipe, set amount to 2
        end
      end
    end
  end
end