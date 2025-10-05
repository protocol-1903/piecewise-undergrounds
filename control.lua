local ordered_deconstruction = {}
local cancelled_deconstruction = {}

local xutil = require "xutil"

lazy_poll_ticks = 10

-- per tick, might slow down if required
script.on_event(defines.events.on_tick, function()
  ordered_deconstruction = {}
  cancelled_deconstruction = {}
  local checked = {}

  for index, entities in pairs(storage) do

    if not checked[index] and -- only need to check each pair once per tick
      index % lazy_poll_ticks == game.tick % lazy_poll_ticks and -- lazy polling logic
      -- entities will technically be polled twice as often (because double indexed) unless they happen to be on the same poll tick, which is fine
      entities[1].valid and entities[2].valid and -- verify both are valid
      not entities[1].to_be_deconstructed() and not entities[2].to_be_deconstructed() then
      -- if either is supposed to be deconstructed, ignore (shouldnt happen but check anyway)

      -- search for proper entities
      local placements = entities[1].surface.find_entities_filtered {
        name = xutil.get_type.psuedo(entities[1]),
        quality = entities[1].quality.name,
        area = { -- this bs because reasons
          {
            entities[1].position.x <= entities[2].position.x and entities[1].position.x - 0.01 or entities[2].position.x - 0.01,
            entities[1].position.y <= entities[2].position.y and entities[1].position.y - 0.01 or entities[2].position.y - 0.01
          },
          {
            entities[1].position.x >= entities[2].position.x and entities[1].position.x + 0.01 or entities[2].position.x + 0.01,
            entities[1].position.y >= entities[2].position.y and entities[1].position.y + 0.01 or entities[2].position.y + 0.01
          }
        }
      }

      -- if everything is in place
      if #placements == xutil.distance(entities[1], entities[2]) then
        -- get rid of temporary entities
        for _, entity in pairs(placements) do
          entity.destroy()
        end

        -- clear storage
        storage[entities[1].unit_number] = nil
        storage[entities[2].unit_number] = nil

        local fluids = {
          entities[1].fluidbox[1],
          entities[2].fluidbox[1]
        }

        local new_entities = {}

        -- remove fluids before messing around
        entities[1].fluidbox[1] = nil

        -- revert fake undergrounds to normal ones
        for i, underground in pairs(entities) do
          -- make new entity
          local new_entity = underground.surface.create_entity {
            name = xutil.get_type.base(underground),
            position = underground.position,
            direction = underground.direction,
            quality = underground.quality,
            force = underground.force,
            type = xutil.is_belt(entity) and entity.belt_to_ground_type,
            create_build_effect_smoke = true
          }

          new_entities[i] = new_entity

          -- remove old entity
          underground.destroy()
        end

        local current_fluid = new_entities[1].fluidbox[1] and {
          name = new_entities[1].fluidbox[1].name,
          amount = new_entities[1].fluidbox[1] and new_entities[1].fluidbox.get_fluid_segment_contents(1)[new_entities[1].fluidbox[1].name],
          temperature = new_entities[1].fluidbox[1].temperature
        }

        if current_fluid then
          -- fluid exists, check if it agrees with the old fluids. if not then complex logic
          -- for loop works great cause it skips nil entities, meaning no extra logic required
          local found = false
          for _, fluid in pairs(fluids) do
            if current_fluid.name == fluid.name then
              current_fluid.amount = current_fluid.amount + fluid.amount
            else
              found = true
            end
          end
          -- some extra logic for another edge case
          while found do
            found = false
            for _, fluid in pairs(fluids) do
              if current_fluid.name ~= fluid.name and fluid.amount > current_fluid.amount then
                current_fluid = fluid
                found = true
              end
            end
          end
          new_entities[1].fluidbox[1] = current_fluid
        elseif fluids[1] and fluids[2] then
          if fluids[1].name == fluids[2].name then
            -- same fluid, add amounts together and add to fluidbox
            fluids[1].amount = fluids[1].amount + fluids[2].amount
            new_entities[1].fluidbox[1] = fluids[1]
          else
            -- not the same fluid, copy whichever has more
            new_entities[1].fluidbox[1] = fluids[fluids[1].amount > fluids[2].amount and 1 or 2]
          end
        elseif fluids[1] or fluids[2] then
          new_entities[1].fluidbox[1] = fluids[1] or fluids[2]
        end

      else -- make sure we only check one of the pair per tick
        checked[entities[1].unit_number] = true
        checked[entities[2].unit_number] = true
      end
    end
  end
end)

local function order_construction(entity, neighbour, player)

  local distance = xutil.distance(entity, neighbour)
  local dir = xutil.relative_direction(entity, neighbour)

  local amount_required = distance - entity.surface.count_entities_filtered {
    name = xutil.get_type.psuedo(entity),
    quality = entity.quality.name,
    area = { -- this bs because reasons
      {
        entity.position.x <= neighbour.position.x and entity.position.x - 0.01 or neighbour.position.x - 0.01,
        entity.position.y <= neighbour.position.y and entity.position.y - 0.01 or neighbour.position.y - 0.01
      },
      {
        entity.position.x >= neighbour.position.x and entity.position.x + 0.01 or neighbour.position.x + 0.01,
        entity.position.y >= neighbour.position.y and entity.position.y + 0.01 or neighbour.position.y + 0.01
      }
    }
  }

  local player_built

  local item = prototypes.entity[xutil.get_type.psuedo(entity)].items_to_place_this[1].name

  if amount_required > 0 and player and player.get_main_inventory().get_item_count{
    name = item,
    quality = entity.quality
  } >= amount_required then

    -- remove amount from player inventory
    player.get_main_inventory().remove{
      name = item,
      quality = entity.quality,
      count = amount_required
    }

    -- notify player
    player.create_local_flying_text{
      create_at_cursor = true,
      text = { "notification.took-from-inventory", amount_required, {"?", {"entity-name." .. item}, {"item-name." .. item}} }
    }

    player_built = true
  end

  -- underground handler
  for i = 0.5, distance - 0.5 do
    -- find any existing underground
    local existing_units = entity.surface.find_entities_filtered {
      name = xutil.get_type.psuedo(entity),
      quality = entity.quality.name,
      position = {
        entity.position.x + dir.x * i,
        entity.position.y + dir.y * i
      },
      radius = 0.01
    }
    
    -- if entity doesn't already exist, create one
    if #existing_units == 0 then
      entity.surface.create_entity {
        name = not player_built and "entity-ghost" or xutil.get_type.psuedo(entity),
        inner_name = not player_built and xutil.get_type.psuedo(entity) or nil,
        position = { -- shift one tile 
          entity.position.x + dir.x * i,
          entity.position.y + dir.y * i
        },
        quality = entity.quality,
        force = entity.force,
        create_build_effect_smoke = false
      }
    elseif #existing_units == 1 then
      -- entity exists, cancel deconstruction
      cancelled_deconstruction[existing_units[1].unit_number] = true
      ordered_deconstruction[existing_units[1].unit_number] = nil
      existing_units[1].cancel_deconstruction(entity.force)
    end
  end

  -- add to construction checks
  storage[entity.unit_number] = {entity, neighbour}
  storage[neighbour.unit_number] = {entity, neighbour}
end

local function cancel_construction(entity, player)
  local entities = storage[entity.unit_number]
  local other_entity = entities[1] == entity and entities[2] or entities[1]
  storage[entities[1].unit_number] = nil
  storage[entities[2].unit_number] = nil

  -- mark extraneous underground entities for decosntruction/remove by player
  local undergrounds = entities[1].surface.find_entities_filtered {
    name = xutil.get_type.psuedo(entity),
    quality = entity.quality.name,
    area = { -- this bs because reasons
      {
        entity.position.x <= other_entity.position.x and entity.position.x - 0.01 or other_entity.position.x - 0.01,
        entity.position.y <= other_entity.position.y and entity.position.y - 0.01 or other_entity.position.y - 0.01
      },
      {
        entity.position.x >= other_entity.position.x and entity.position.x + 0.01 or other_entity.position.x + 0.01,
        entity.position.y >= other_entity.position.y and entity.position.y + 0.01 or other_entity.position.y + 0.01
      }
    }
  }

  -- take care of existing entities
  if player and #undergrounds > 0 then
    local item = undergrounds[1].prototype.mineable_properties.products[1].name

    if player.get_main_inventory().can_insert{
      name = item,
      quality = undergrounds[1].quality,
      count = #undergrounds
    } then -- only insert items if every single one can be inserted
      player.get_main_inventory().insert{
        name = item,
        quality = undergrounds[1].quality,
        count = #undergrounds
      }

      -- notify player
      player.create_local_flying_text{
        create_at_cursor = true,
        text = { "notification.put-into-inventory", #undergrounds, {"?", {"entity-name." .. item}, {"item-name." .. item}} }
      }

      -- delete entities
      for _, unit in pairs(undergrounds) do
        unit.destroy()
      end
    end
  else -- mark for deconstruction
    for _, unit in pairs(undergrounds) do
      ordered_deconstruction[unit.unit_number] = true
      unit.order_deconstruction(unit.force)
    end
  end

  -- delete ghost entities
  for _, unit in pairs(entities[1].surface.find_entities_filtered {
    name = "entity-ghost",
    quality = entity.quality.name,
    inner_name = xutil.get_type.psuedo(entity),
    area = { -- this bs because reasons
      {
        entity.position.x <= other_entity.position.x and entity.position.x - 0.01 or other_entity.position.x - 0.01,
        entity.position.y <= other_entity.position.y and entity.position.y - 0.01 or other_entity.position.y - 0.01
      },
      {
        entity.position.x >= other_entity.position.x and entity.position.x + 0.01 or other_entity.position.x + 0.01,
        entity.position.y >= other_entity.position.y and entity.position.y + 0.01 or other_entity.position.y + 0.01
      }
    }
  }) do
    unit.destroy()
  end
end

local function order_deconstruction(entity, ignore, player, direction)
  local other_entity = xutil.get_neighbour(entity, ignore, direction)

  local distance = xutil.distance(entity, other_entity)
  local dir = xutil.relative_direction(entity, other_entity)

  local item = xutil.get_type.item(entity)

  -- if player exists
  if not entity.to_be_deconstructed() and player and player.get_main_inventory().can_insert{
    name = item,
    quality = entity.quality,
    count = distance
  } then -- only insert items if every single one can be inserted
    player.get_main_inventory().insert{
      name = item,
      quality = entity.quality,
      count = distance
    }

    -- notify player
    player.create_local_flying_text{
      create_at_cursor = true,
      text = { "notification.put-into-inventory", distance, {"?", {"item-name." .. item}, {"entity-name." .. item}} }
    }

  else -- create underground entities and mark for deconstruction
    for i = 0.5, distance - 0.5 do
      local unit = entity.surface.create_entity {
        name = xutil.get_type.psuedo(entity),
        position = { -- shift one tile 
          entity.position.x + dir.x * i,
          entity.position.y + dir.y * i
        },
        quality = entity.quality,
        force = entity.force,
        create_build_effect_smoke = false
      }
      ordered_deconstruction[unit.unit_number] = true
      unit.order_deconstruction(unit.force)
    end
  end

  local new_entities = {}

  local fluid = other_entity.fluidbox[1]
  local total_fluid = (other_entity.get_fluid(1) and other_entity.get_fluid(1).amount or 0) + ((direction or entity.to_be_deconstructed()) and entity.get_fluid(1) and entity.get_fluid(1).amount or 0)

  -- replace existing pipes with incomplete variants
  for i, underground in pairs{(direction or entity.to_be_deconstructed()) and entity or nil, other_entity} do
    -- create new entity
    local new_entity = underground.surface.create_entity {
      name = xutil.get_type.incomplete(underground),
      position = underground.position,
      direction = underground.direction,
      quality = underground.quality,
      force = underground.force,
      create_build_effect_smoke = false
    }

    if underground.to_be_deconstructed() then
      new_entity.order_deconstruction(new_entity.force)
    end

    -- remove old entity
    underground.destroy()

    new_entities[i] = new_entity
  end

  local remaining_fluid = 0

  -- there was some fluid... figure out how much to put where
  if fluid then
    for _, entity in pairs(new_entities) do
      for _, connection in pairs(entity.fluidbox.get_pipe_connections(1)) do
        if connection.target and connection.target[1] then
          remaining_fluid = remaining_fluid + connection.target.get_fluid_segment_contents(1)[connection.target[1].name]
        end
      end
    end
  end

  -- if some fluid not accounted for, put it into the old entities
  if total_fluid > remaining_fluid then
    for _, entity in pairs(new_entities) do
      fluid.amount = (entity.fluidbox[1] and entity.fluidbox.get_fluid_segment_contents(1)[entity.fluidbox[1].name] or 0) + (total_fluid - remaining_fluid) / 2
      entity.fluidbox[1] = fluid
    end
  end

  return new_entities
end

local function attempt_to_construct(entity, player)
  local neighbour = xutil.get_neighbour(entity)

  if not neighbour or neighbour.to_be_deconstructed() then return end
  
  if xutil.is_type.incomplete(neighbour) then
    if storage[neighbour.unit_number] then
      cancel_construction(neighbour)
    end

    order_construction(entity, neighbour, player)

  elseif xutil.is_type.base(neighbour) then
    new_entities = order_deconstruction(neighbour, entity, player, neighbour.direction)

    order_construction(entity, new_entities[1], player)
  end
end

--- @param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive|EventData.on_space_platform_built_entity|EventData.on_cancelled_deconstruction
local function on_constructed(event)
  local entity = event.entity
  local player = event.name ~= defines.events.on_cancelled_deconstruction and event.player_index and game.players[event.player_index]

  if xutil.is_type.base(entity) then

    if entity.surface.count_entities_filtered{
      name = xutil.get_type.incomplete(entity),
      quality = entity.quality.name,
      position = entity.position
    } > 0 then
      -- placed a ghost normal one on top of a preexisting one, shenanegins ensue
      local old_entity = entity.surface.find_entities_filtered{
        name = xutil.get_type.incomplete(entity),
        quality = entity.quality.name,
        position = entity.position
      }[1]

      -- if old entity is marked for deconstruction, then remove
      if old_entity.to_be_deconstructed() then
        old_entity.cancel_deconstruction(entity.force)
        entity.destroy()
      end
    else
      -- somehow got a normal variant, replace with a base one
      local new_entity = entity.surface.create_entity {
        name = entity.name == "entity-ghost" and "entity-ghost" or xutil.get_type.incomplete(entity),
        ghost_name = entity.name == "entity-ghost" and xutil.get_type.incomplete(entity),
        position = entity.position,
        direction = entity.direction,
        quality = entity.quality,
        force = entity.force,
        type = xutil.is_belt(entity) and entity.belt_to_ground_type,
        raise_built = true
      }

      local fluid = entity.get_fluid(1)

      -- remove old entity
      entity.destroy()

      if fluid then new_entity.fluidbox[1] = fluid end
    end
  elseif entity.name ~= "entity-ghost" and xutil.is_type.psuedo(entity) and event.name == defines.events.on_cancelled_deconstruction and not cancelled_deconstruction[entity.unit_number] then
    ordered_deconstruction[entity.unit_number] = true
    entity.order_deconstruction(entity.force)
  elseif entity.name ~= "entity-ghost" and xutil.is_type.incomplete(entity) then
    attempt_to_construct(entity, player)
  -- elseif xutil.is_type.psuedo(entity) then
  --   -- placed a psuedo underground... make sure its not undo crap
  --   game.print(entity.name)
  --   if entity.surface.count_entities_filtered {
  --       name = entity.name,
  --       ghost_name = entity.name == "entity-ghost" and entity.ghost_name or nil,
  --       position = entity.position,
  --       quality = entity.quality.name,
  --       force = entity.force
  --     } ~= 0 then
  --       -- we found another entity, get rid of this one
  --       entity.destroy()
  --     end
  end
end

--- @param event EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.script_raised_destroy|EventData.on_space_platform_mined_entity|EventData.on_entity_died
local function on_deconstructed(event)
  local entity = event.entity
  local player = event.name ~= defines.events.on_marked_for_deconstruction and event.player_index and game.players[event.player_index]

  if xutil.is_type.incomplete(entity) and storage[entity.unit_number] then

    -- get current neighbour and potential new neighbour
    local entities = storage[entity.unit_number]
    local other_entity = entities[1] == entity and entities[2] or entities[1]
    local new_neighbour = xutil.get_neighbour(other_entity, entity)

    -- cancel old construction order
    cancel_construction(entity, player)

    -- remove old entities from storage
    storage[entity.unit_number] = nil
    storage[other_entity.unit_number] = nil

    -- if new neighbour exists, attempt to construct those
    if new_neighbour and not new_neighbour.to_be_deconstructed() then
      order_construction(other_entity, new_neighbour, player)
    end

  elseif xutil.is_type.base(entity) then
    -- completed pair, so 'deconstruct' both and delete this one
    local other_entity = xutil.get_neighbour(entity)
    local new_neighbour = xutil.get_neighbour(other_entity, entity)
    other_entity = order_deconstruction(entity, nil, player)[2]

    if new_neighbour then
      order_construction(other_entity, new_neighbour, player)
    end
  elseif entity.name ~= "entity-ghost" and xutil.is_type.psuedo(entity) and event.name == defines.events.on_marked_for_deconstruction and not ordered_deconstruction[entity.unit_number] then
    cancelled_deconstruction[entity.unit_number] = true
    entity.cancel_deconstruction(entity.force)
  end
  -- not marked for construction, deconstruct as normal
end

-- default, plus psuedo undergrounds
local event_filter = {
  {filter = "type", type = "simple-entity-with-owner"},
  {filter = "type", type = "pipe-to-ground"},
  {filter = "type", type = "valve"},
  {filter = "ghost_type", type = "pipe-to-ground"},
  {filter = "ghost_type", type = "valve"}
}

script.on_event(defines.events.script_raised_built, on_constructed, event_filter)
script.on_event(defines.events.script_raised_revive, on_constructed, event_filter)
script.on_event(defines.events.on_cancelled_deconstruction, on_constructed, event_filter)
script.on_event(defines.events.on_built_entity, on_constructed, event_filter)
script.on_event(defines.events.on_space_platform_built_entity, on_constructed, event_filter)
script.on_event(defines.events.on_robot_built_entity, on_constructed, event_filter)

script.on_event(defines.events.script_raised_destroy, on_deconstructed, event_filter)
script.on_event(defines.events.on_robot_mined_entity, on_deconstructed, event_filter)
script.on_event(defines.events.on_marked_for_deconstruction, on_deconstructed, event_filter)
script.on_event(defines.events.on_player_mined_entity, on_deconstructed, event_filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_deconstructed, event_filter)
script.on_event(defines.events.on_entity_died, on_deconstructed, event_filter)

-- if attempting to deconstruct ghost variations of the fake underground pipes, replace them (we can't cancel the event)
script.on_event(defines.events.on_pre_ghost_deconstructed, function(event)
  if xutil.is_type.psuedo(event.ghost) then
    -- recreate the entity
    event.ghost.surface.create_entity {
      name = "entity-ghost",
      inner_name = event.ghost.ghost_name,
      position = event.ghost.position,
      quality = event.ghost.quality,
      force = event.ghost.force,
      create_build_effect_smoke = false
    }
  end
end, {{filter = "type", type = "simple-entity-with-owner"}})

-- remove hidden underground items, and convert disconnected pipe-to-grounds to normal ones
script.on_event(defines.events.on_player_setup_blueprint, function (event)
	local player = game.players[event.player_index]
	local blueprint = player and player.blueprint_to_setup
  -- if normally invalid
	if not blueprint or not blueprint.valid_for_read then blueprint = player.cursor_stack end
  -- if non existant, cancel
  if not blueprint then return end
  local entities = blueprint and blueprint.get_blueprint_entities()
  if not entities then return; end
  -- update entities
  for i, entity in pairs(entities) do
    -- if fake underground, remove from blueprint
    if xutil.is_type.psuedo(entity) then
      entities[i] = nil
      -- if psuedo pipe to ground, replace with normal variant
    elseif xutil.is_pipe(entity) then
      entity.name = xutil.get_type.base(entity)
    end
  end
  blueprint.set_blueprint_entities(entities)
end)

-- TODO undo/redo
-- TODO rotations

script.on_event(defines.events.on_player_rotated_entity, function (event)
  local entity = event.entity
  local player = game.players[event.player_index]
  player = player.controller_type ~= defines.controllers.remote and player

  -- we dont care if its a ghost
  if entity.name == "entity-ghost" then return end

  if xutil.is_type.base(entity) then

    -- is complete, deconstruct
    local new_entities = order_deconstruction(entity, nil, player, event.previous_direction)

    -- attempt to construct this entity
    attempt_to_construct(new_entities[1], player)

    -- check if the old neighbour has a new one
    attempt_to_construct(new_entities[2], player)
  
  elseif xutil.is_type.incomplete(entity) then
    -- is incomplete attempt to construct
    if storage[entity.unit_number] then
      cancel_construction(entity, player)
    end

    attempt_to_construct(entity, player)

  end
end)

script.on_event(defines.events.on_selected_entity_changed, function (event)
  local player = game.players[event.player_index]

  if player.controller_type == defines.controllers.remote or not player.selected then return end

  local entity = player.selected

  if not xutil.is_type.incomplete(entity) then return end

  local entities = storage[entity.unit_number]

  -- if under construction, attempt to construct
  if entities then

    -- count missing items
    local ghosts = entity.surface.find_entities_filtered {
      name = "entity-ghost",
      ghost_name = xutil.get_type.psuedo(entity),
      quality = entity.quality.name,
      area = { -- this bs because reasons
        {
          entities[1].position.x <= entities[2].position.x and entities[1].position.x - 0.01 or entities[2].position.x - 0.01,
          entities[1].position.y <= entities[2].position.y and entities[1].position.y - 0.01 or entities[2].position.y - 0.01
        },
        {
          entities[1].position.x >= entities[2].position.x and entities[1].position.x + 0.01 or entities[2].position.x + 0.01,
          entities[1].position.y >= entities[2].position.y and entities[1].position.y + 0.01 or entities[2].position.y + 0.01
        }
      }
    }

    local item = prototypes.entity[xutil.get_type.psuedo(entity)].items_to_place_this[1].name

    if #ghosts ~= 0 and player.get_main_inventory().get_item_count{
      name = item,
      quality = entity.quality
    } >= #ghosts then
      -- remove from inventory
      player.get_main_inventory().remove{
        name = item,
        quality = entity.quality,
        count = #ghosts
      }

      -- notify player
      player.create_local_flying_text{
        create_at_cursor = true,
        text = { "notification.took-from-inventory", #ghosts, {"?", {"entity-name." .. item}, {"item-name." .. item}} }
      }

      -- place entities and remove the ghost entitieseeeeeddssddwamd
      for _, ghost in pairs(ghosts) do
        ghost.surface.create_entity{
          name = ghost.ghost_name,
          quality = ghost.quality,
          position = ghost.position
        }
        ghost.destroy()
      end
    end
  end
end)

-- no creating unwanted entities since the UndoRedoStack is only update *after* script calls which is dumb
script.on_event(defines.events.on_undo_applied, function (event)
  local force = game.players[event.player_index].force
  for _, action in pairs(event.actions) do
    if action.type == "removed-entity" then
      local entities = game.surfaces[action.surface_index].find_entities_filtered {
        name = action.target.name,
        position = action.target.position,
        quality = action.target.quality,
        force = force
      }
      local ghost_entities = game.surfaces[action.surface_index].find_entities_filtered {
        name = "entity-ghost",
        ghost_name = action.target.name,
        position = action.target.position,
        quality = action.target.quality,
        force = force
      }
      if #entities > 1 then
        -- get rid of all but 1 entity
        for index, entity in pairs(entities) do
          if index > 1 then entity.destroy() end
        end
        -- get rid of all ghost entities
        for _, entity in pairs(ghost_entities) do entity.destroy() end
      elseif #ghost_entities > 1 then
        for index, entity in pairs(ghost_entities) do
          -- if we have an entity, or not first ghost
          if index > 1 - #entities then entity.destroy() end
        end
      end
    end
  end
end)

-- print warning about not supporting quality
script.on_event(defines.events.on_singleplayer_init, function (event)
  if feature_flags.quality then
    game.show_message_dialog {text = {"messages.pu-no-quality-support"}}
  end
end)

scrip.on_event(defines.events.on_player_joined_game, function (event)
  if feature_flags.quality then
    game.get_player(event.player_index).print{"messages.pu-no-quality-support"}
  end
end)