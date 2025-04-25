data:extend{{
  type = "recipe-category",
  name = "piecewise-undergrounds-void"
}}

require("__piecewise-undergrounds__/compatibility/compatibility")

for u, underground in pairs(data.raw["pipe-to-ground"]) do

  if u:sub(1,9) ~= "disabled-" then

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
    data.raw.item[u].place_result = "placement-" .. u
    underground.placeable_by = {item = u, count = 1}

    data:extend{
      {
        type = "furnace",
        name = "placement-" .. u,
        localised_name = {"entity-name." .. u},
        hidden_in_factoriopedia = true,
        icon = underground.icon,
        icon_size = underground.icon_size,
        placeable_by = underground.placeable_by,
        minable = underground.minable,
        flags = underground.flags,
        collision_box = underground.collision_box,
        selection_box = underground.selection_box,
        heating_energy = underground.heating_energy,
        fluid_boxes = {
          {
            production_type = "input",
            volume = 100,
            hide_connection_info = true,
            pipe_connections = {},
            pipe_covers = underground.fluid_box.pipe_covers
          }
        },
        source_inventory_size = 0,
        result_inventory_size = 0,
        graphics_set = {
          frozen_patch = underground.frozen_patch,
          animation = underground.pictures
        },
        energy_source = { type = "void" },
        energy_usage = "1W",
        crafting_speed = 1,
        crafting_categories = { "piecewise-undergrounds-void" }
      },
      {
        type = "furnace",
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
        fluid_boxes = {
          {
            production_type = "input",
            volume = 100,
            hide_connection_info = true,
            pipe_connections = {},
            pipe_covers = underground.fluid_box.pipe_covers
          }
        },
        source_inventory_size = 0,
        result_inventory_size = 0,
        graphics_set = {
          frozen_patch = underground.frozen_patch,
          animation = underground.pictures
        },
        energy_source = { type = "void" },
        energy_usage = "1W",
        crafting_speed = 1,
        crafting_categories = { "piecewise-undergrounds-void" }
      },
    }

    for i, connection in pairs(underground.fluid_box.pipe_connections) do
      data.raw.furnace["placement-" .. u].fluid_boxes[1].pipe_connections[i] = table.deepcopy(connection)
      data.raw.furnace["incomplete-" .. u].fluid_boxes[1].pipe_connections[i] = table.deepcopy(connection)
      data.raw.furnace["placement-" .. u].fluid_boxes[1].pipe_connections[i].flow_direction = "output"
      data.raw.furnace["incomplete-" .. u].fluid_boxes[1].pipe_connections[i].flow_direction = connection.connection_type == "underground" and "input-output" or "output"
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