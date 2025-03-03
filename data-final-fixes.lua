for u, underground in pairs(data.raw["pipe-to-ground"]) do

  if u:sub(1,9) ~= "disabled-" then

    pipe = data.raw.pipe[u:sub(1,-11)]
    if pipe and data.raw.item[pipe.name] then
      data:extend({
        {
          type = "simple-entity-with-owner",
          name = "pu-under-" .. pipe.name,
          picture = {
            filename = "__piecewise-undergrounds__/nothing.png",
            size = {1, 1}
          },
          icon = "__piecewise-undergrounds__/nothing.png",
          icon_size = 1,
          -- selection_box = {{-0.25, -0.25}, {0.25, 0.25}},
          allow_copy_paste = false,
          flags = { "placeable-neutral", "not-on-map", "not-upgradable", "placeable-off-grid", "player-creation" },
          placeable_by = { item = pipe.name, count = 1},
          minable = { mining_time = 1, result = pipe.name },
          hidden_in_factoriopedia = true
        }
      })
    end

    local fake_v = table.deepcopy(underground)
    fake_v.name = "disabled-" .. u
    fake_v.type = "pump"
    fake_v.placeable_by = {item = u, count = 1}
    fake_v.localised_name = {"entity-name.disabled", {"entity-name." .. u}}
    fake_v.localised_description = {"entity-description.disabled"}
    fake_v.hidden_in_factoriopedia = true
    fake_v.animations = fake_v.pictures
    for _, connection in pairs(fake_v.fluid_box.pipe_connections) do
      connection.flow_direction = "output"
    end
    fake_v.energy_source = {
      type = "void"
    }
    fake_v.energy_usage = "0W"
    fake_v.pumping_speed = 0
    data.raw["pump"][fake_v.name] = fake_v

    -- if recipe exists, remove pipes from it
    if data.raw.recipe[u] then
      local ingredients = data.raw.recipe[u].ingredients
      data.raw.recipe[u].ingredients = {}
      -- add ingredient if not the associated pipe
      for _, ingredient in pairs(ingredients) do
        if not ingredient.name:find("pipe") then
          data.raw.recipe[u].ingredients[#data.raw.recipe[u].ingredients+1] = ingredient
        end
      end
    end
  end
end

-- for u, underground in pairs(data.raw["underground-belt"]) do

--   if u:sub(1,9) ~= "disabled-" then


    -- if not item then -- this mess of code because theres no easy way to find the asociated belt
    --   i, j = entity.name:find("underground")
    --   item = prototypes.item[entity.name:sub(1,i-1) .. "transport" .. entity.name:sub(j+1)]
    --   if not item then error("item not found, someone broke convention :/") end
    -- end

--     pipe = data.raw.pipe[u:sub(1,-11)]
--     if pipe and data.raw.item[pipe.name] then
--       data:extend({
--         {
--           type = "simple-entity-with-owner",
--           name = "pu-under-" .. pipe.name,
--           picture = {
--             filename = "__piecewise-undergrounds__/nothing.png",
--             size = {1, 1}
--           },
--           icon = "__piecewise-undergrounds__/nothing.png",
--           icon_size = 1,
--           selection_box = {{-0.25, -0.25}, {0.25, 0.25}},
--           flags = { "placeable-neutral", "not-on-map", "no-copy-paste", "not-upgradable", "placeable-off-grid", "player-creation" },
--           placeable_by = { item = pipe.name, count = 1},
--           hidden_in_factoriopedia = true
--         }
--       })
--     end

--     local fake_v = table.deepcopy(underground)
--     fake_v.name = "disabled-" .. u
--     fake_v.type = "pump"
--     fake_v.placeable_by = {item = u, count = 1}
--     fake_v.localised_name = {"entity-name.disabled", {"entity-name." .. u}}
--     fake_v.localised_description = {"entity-description.disabled"}
--     fake_v.hidden_in_factoriopedia = true
--     data.raw["linked-belt"][fake_v.name] = fake_v

--     -- if recipe exists, remove belts from it
--     if data.raw.recipe[u] then
--       local ingredients = data.raw.recipe[u].ingredients
--       data.raw.recipe[u].ingredients = {}
--       -- add ingredient if not the associated belt
--       for _, ingredient in pairs(ingredients) do
--         if ingredient.name:sub(-4) ~= "belt" or ingredient.name:sub(-16) == "underground-belt" then
--           data.raw.recipe[u].ingredients[#data.raw.recipe[u].ingredients+1] = ingredient
--         end
--       end
--     end
--   end
-- end

--[[
for u, underground in pairs(data.raw["underground-belt"]) do

  local fake_v = underground
  fake_v.speed = 0

  -- if recipe exists, remove belts from it
  if data.raw.recipe[u] then
    local ingredients = data.raw.recipe[u].ingredients
    data.raw.recipe[u].ingredients = {}
    -- add ingredient if not the associated pipe
    for _, ingredient in pairs(ingredients) do
      if ingredient.name:sub(-4) ~= "belt" or ingredient.name:sub(-16) == "underground-belt" then
        data.raw.recipe[u].ingredients[#data.raw.recipe[u].ingredients+1] = ingredient
      end
    end
  end
end
]]