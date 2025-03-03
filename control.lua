-- init
script.on_init(function()
  storage.under_construction = {}
end)

local ordered = {}
local cancelled = {}
local check = {}
local remove = {}

--------------------------------------------------------------------------------------------------- find neighbours
local function get_neighbour(entity, direction)
  if not entity then return end
  if entity.type == "pipe-to-ground" and not entity.to_be_deconstructed() and not direction then

    -- get each fluidbox
    for i=1, #entity.fluidbox do

      -- get each pipe connection in the current fluidbox
      for j, pipe_connection in pairs(entity.fluidbox.get_pipe_connections(i)) do

        -- must have a connection and must be underground type and not ordered for deconstruction
        if pipe_connection.target and pipe_connection.connection_type == "underground" and pipe_connection.target.owner.type ~= "entity-ghost" and not pipe_connection.target.owner.to_be_deconstructed() then
          return pipe_connection.target.owner
        end
      end
    end

  elseif entity.type == "pipe-to-ground" and entity.to_be_deconstructed() or direction then

    local max_distance = 0
    for i=1, #entity.fluidbox do
      -- get each pipe connection in the current fluidbox
      for j, pipe_connection in pairs(entity.fluidbox.get_pipe_connections(i)) do
        -- must have a connection and must be underground type and not ordered for deconstruction
        if pipe_connection.connection_type == "underground" then
          max_distance = pipe_connection.max_underground_distance
          break
        end
      end
    end

    local possibles = {}

    local dir = {
      x = (direction or entity.direction == 12) == 12 and 1 or (direction or entity.direction) == 4 and -1 or 0,
      y = (direction or entity.direction) == 0 and 1 or (direction or entity.direction) == 8 and -1 or 0
    }
    local pos1 = {
      x = entity.position.x,
      y = entity.position.y
    }
    local pos2 = {
      x = pos1.x + prototypes.max_pipe_to_ground_distance * dir.x,
      y = pos1.y + prototypes.max_pipe_to_ground_distance * dir.y
    }

    local shortest_distance = 0
    local neighbour

    for _, placement in pairs(entity.surface.find_entities_filtered{
      area = { -- find the same entity in that direction
        {
          x = pos1.x < pos2.x and pos1.x or pos2.x - 0.1,
          y = pos1.y < pos2.y and pos1.y or pos2.y - 0.1
        },
        {
          x = pos1.x > pos2.x and pos1.x or pos2.x - 0.1,
          y = pos1.y > pos2.y and pos1.y or pos2.y - 0.1
        }
      },
      name = entity.name,
      direction = ((direction or entity.direction + 8) + 8) % 16
    }) do
      -- make sure pipe is disconnected
      if not get_neighbour(placement) then
        local distance = math.abs(placement.position.x - entity.position.x) + math.abs(placement.position.y - entity.position.y)
        if shortest_distance == 0 or shortest_distance > distance then
          neighbour = placement
          shortest_distance = distance
        end
      end
    end
    return neighbour
  
  elseif entity.neighbours and entity.type == "underground-belt" and not entity.neighbours[1].to_be_deconstructed() then
    -- underground belt with a neighbour
    return entity.neighbours
  end
end

--------------------------------------------------------------------------------------------------- "build" or request robot construction
local function construct(entity, player)
  -- find neighbours, if any
  local neighbour = get_neighbour(entity)

  -- if not found (i.e. disconnected for whatever reason)
  if not neighbour then return end

  -- neighbour is part of a pair under construction, get rid of that pair to make the new pair
  if neighbour.type == "pump" then
    local entities = storage.under_construction[neighbour.unit_number]
    remove[entities[1].unit_number] = true
    remove[entities[2].unit_number] = true
    local other_entity = entities[1] == neighbour and entities[2] or entities[1]

    -- mark extraneous underground entities for decosntruction/remove by player
    for _, unit in pairs(entities[1].surface.find_entities_filtered {
      name = "pu-under-" .. neighbour.name:sub(10, -11),
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
      ordered[unit.unit_number] = true
      unit.order_deconstruction(unit.force)
    end
    for _, unit in pairs(entities[1].surface.find_entities_filtered {
      name = "entity-ghost",
      inner_name = "pu-under-" .. neighbour.name:sub(10, -11),
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

    -- replace with basic pipe to grounds
    for i, underground in pairs(entities) do
      -- make new entity
      underground.surface.create_entity {
        name = underground.name:sub(10),
        position = underground.position,
        direction = underground.direction,
        quality = underground.quality,
        force = underground.force,
        -- player = underground.last_user,
        create_build_effect_smoke = false,
        type = underground.type == "underground-belt" and underground.belt_to_ground_type or nil
      }
      -- remove old entity
      underground.destroy()
    end

    -- update neighbour
    neighbour = get_neighbour(entity)
  end

  -- if player present, attempt to take from inventory
  if player then
    item = prototypes.item[entity.type == "pipe-to-ground" and entity.name:sub(1, -11)]
    if not item then -- this mess of code because theres no easy way to find the asociated belt
      i, j = entity.name:find("underground")
      item = prototypes.item[entity.name:sub(1,i-1) .. "transport" .. entity.name:sub(j+1)]
      if not item then error("item not found, someone broke convention :/") end
    end

    local amount_required = 0

    -- sum distances
    amount_required = math.abs(neighbour.position.x - entity.position.x) + math.abs(neighbour.position.y - entity.position.y)

    local count = player.get_inventory(defines.inventory.character_main).get_item_count{
      name = item.name,
      quality = entity.quality
    }

    if count >= amount_required then
      player.get_inventory(defines.inventory.character_main).remove{
        name = item.name,
        quality = entity.quality,
        count = amount_required
      }
      
      return -- process complete
    end
  end

  if entity.type ~= "pipe-to-ground" then return end

  -- not enough items in player inventory, or player didnt exist (i.e. script or bot placed)

  -- request entities from bots

  -- calculate relative direction and distance
  local distance = math.abs(neighbour.position.x - entity.position.x) + math.abs(neighbour.position.y - entity.position.y)
  local dir = {
    x = entity.position.x > neighbour.position.x and -1 or entity.position.x < neighbour.position.x and 1 or 0,
    y = entity.position.y > neighbour.position.y and -1 or entity.position.y < neighbour.position.y and 1 or 0
  }

  for i=0.5, distance-0.5 do
    local existing = neighbour.surface.find_entities_filtered{
      position = {
        entity.position.x + dir.x * i,
        entity.position.y + dir.y * i
      },
      radius = 0.01,
      name = "pu-under-" .. (entity.type == "pipe-to-ground" and entity.name:sub(1, -11))
    }
    local existing_ghost = neighbour.surface.find_entities_filtered{
      position = {
        entity.position.x + dir.x * i,
        entity.position.y + dir.y * i
      },
      radius = 0.01,
      inner_namename = "pu-under-" .. (entity.type == "pipe-to-ground" and entity.name:sub(1, -11))
    }
    
    -- if entity doesn't already exist
    if #existing == 0 and #existing_ghost == 0 then
      neighbour.surface.create_entity{
        name = "entity-ghost",
        inner_name = "pu-under-" .. (entity.type == "pipe-to-ground" and entity.name:sub(1, -11)),
        position = { -- shift one tile 
          entity.position.x + dir.x * i,
          entity.position.y + dir.y * i
        },
        quality = neighbour.quality,
        force = neighbour.force,
        create_build_effect_smoke = false
      }
    elseif #existing == 1 and existing[1].to_be_deconstructed() then
      -- cancel deconstruction if required_fluid
      existing[1].cancel_deconstruction(entity.force)
    end
  end

  -- add entity to table to be replaced
  entities = {neighbour, entity}
  
  for i, underground in pairs(entities) do
    -- make new entity
    local new = underground.surface.create_entity{
      name = "disabled-" .. underground.name,
      position = underground.position,
      direction = underground.direction,
      quality = underground.quality,
      force = underground.force,
      player = i == 2 and player and underground.last_user or nil,
      create_build_effect_smoke = false,
      type = underground.type == "underground-belt" and underground.belt_to_ground_type or nil
    }
    -- remove old entity
    underground.destroy()
    -- replace in entities
    entities[i] = new
  end
  -- player.undo_redo_stack.remove_undo_action(1,1)

  -- add to storage
  storage.under_construction[entities[1].unit_number] = entities
  storage.under_construction[entities[2].unit_number] = entities
end

--------------------------------------------------------------------------------------------------- create and mark underground entities for deconstruction
local function deconstruct_pipe(entity, player, direction)
  
  -- find neighbours, if any
  local entities = {entity, get_neighbour(entity, direction)}

  -- if not found (i.e. disconnected for whatever reason)
  if not entities[2] then return end

  -- number of entities to deconstruct on ground
  local amount_required = math.abs(entities[1].position.x - entities[2].position.x) + math.abs(entities[1].position.y - entities[2].position.y)
  
  -- if player present, attempt to put into inventory
  if player then
    item = prototypes.item[entity.type == "pipe-to-ground" and entity.name:sub(1, -11)]
    if not item then -- this mess of code because theres no easy way to find the asociated belt
      i, j = entity.name:find("underground")
      item = prototypes.item[entity.name:sub(1,i-1) .. "transport" .. entity.name:sub(j+1)]
      if not item then error("item not found, someone broke convention :/") end
    end

    amount_required = amount_required - player.get_main_inventory().insert {
      name = item.name,
      quality = entity.quality,
      count = amount_required
    }
  end

  -- amount_required is the number to leave on the ground for deconstruction

  -- cannot insert enough into inventory (or script mine)
  if amount_required ~= 0 then
    -- create and deconstruct entities

    -- calculate relative direction and distance
    local distance = math.abs(entities[1].position.x - entities[2].position.x) + math.abs(entities[1].position.y - entities[2].position.y)
    local dir = {
      x = entities[1].position.x > entities[2].position.x and -1 or entities[1].position.x < entities[2].position.x and 1 or 0,
      y = entities[1].position.y > entities[2].position.y and -1 or entities[1].position.y < entities[2].position.y and 1 or 0
    }

    for i=0.5, amount_required-0.5 do
      local temp = entity.surface.create_entity{
        name = "pu-under-" .. (entity.type == "pipe-to-ground" and entity.name:sub(1, -11)),
        position = { -- shift one tile 
          entity.position.x + dir.x * i,
          entity.position.y + dir.y * i
        },
        quality = entity.quality,
        force = entity.force,
        create_build_effect_smoke = false
      }
      ordered[temp.unit_number] = true
      temp.order_deconstruction(temp.force)
    end
  end

  -- delete entity so neighbour can be reconstructed, if needed
  if not entity.to_be_deconstructed() and not direction then
    entity.destroy()
  end

  -- if neighbour exists, attempt to reconstruct (i.e. a pipe between two undergrounds was removed)
  if not entities[2].to_be_deconstructed() then
    construct(entities[2], player)
  end
end

--------------------------------------------------------------------------------------------------- create and mark underground entities for deconstruction
local function cancel_underground(entity, player, direction)
  
  -- find neighbours, if any
  local entities = {entity, get_neighbour(entity, direction)}

  -- if not found (i.e. disconnected for whatever reason)
  if not entities[2] then return end

  -- number of entities to deconstruct on ground
  local amount_required = #entities[1].surface.find_entities_filtered {
    name = "pu-under-" .. ((entities[1].type == "pump") and entities[1].name:sub(10, -11)),
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
  
  -- if player present, attempt to put into inventory
  if player then
    item = prototypes.item[entity.type == "pump" and entity.name:sub(10, -11)]
    if not item then -- this mess of code because theres no easy way to find the asociated belt
      i, j = entity.name:find("underground")
      item = prototypes.item[entity.name:sub(1,i-1) .. "transport" .. entity.name:sub(j+1)]
      if not item then error("item not found, someone broke convention :/") end
    end

    amount_required = amount_required - player.get_main_inventory().insert {
      name = item.name,
      quality = entity.quality,
      count = amount_required
    }
  end

  -- amount_required is the number to leave on the ground for deconstruction

  -- cannot insert enough into inventory (or script mine)
  if amount_required ~= 0 then
    -- create and deconstruct entities

    -- calculate relative direction and distance
    local distance = math.abs(entities[1].position.x - entities[2].position.x) + math.abs(entities[1].position.y - entities[2].position.y)
    local dir = {
      x = entities[1].position.x > entities[2].position.x and -1 or entities[1].position.x < entities[2].position.x and 1 or 0,
      y = entities[1].position.y > entities[2].position.y and -1 or entities[1].position.y < entities[2].position.y and 1 or 0
    }

    for i=0.5, amount_required-0.5 do
      local temp = entity.surface.create_entity{
        name = "pu-under-" .. (entity.type == "pipe-to-ground" and entity.name:sub(1, -11)),
        position = { -- shift one tile 
          entity.position.x + dir.x * i,
          entity.position.y + dir.y * i
        },
        quality = entity.quality,
        force = entity.force,
        create_build_effect_smoke = false
      }
      ordered[temp.unit_number] = true
      temp.order_deconstruction(temp.force)
    end
  end

  -- delete entity so neighbour can be reconstructed, if needed
  if not entity.to_be_deconstructed() and not direction then
    entity.destroy()
  end

  -- if neighbour exists, attempt to reconstruct (i.e. a pipe between two undergrounds was removed)
  if not entities[2].to_be_deconstructed() then
    construct(entities[2], player)
  end
end

script.on_event(defines.events.on_tick, function()
  ordered = {}
  cancelled = {}
  for index, entities in pairs(storage.under_construction) do

    -- make sure they aren't marked for deconstruction
    if not remove[index] and entities[1].valid and entities[2].valid and not entities[1].to_be_deconstructed() and not entities[2].to_be_deconstructed() then

      -- search for proper entities
      local placements = entities[1].surface.find_entities_filtered {
        name = "pu-under-" .. ((entities[1].type == "pump") and entities[1].name:sub(10, -11)),
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
      if #placements == math.abs(entities[1].position.x - entities[2].position.x + entities[1].position.y - entities[2].position.y) then
        -- get rid of temporary entities
        for _, entity in pairs(placements) do
          entity.destroy()
        end

        -- clear storage
        remove[entities[1].unit_number] = true
        remove[entities[2].unit_number] = true

        -- revert fake undergrounds to normal ones
        for i, underground in pairs(entities) do
          -- make new entity
          underground.surface.create_entity {
            name = underground.name:sub(10),
            position = underground.position,
            direction = underground.direction,
            quality = underground.quality,
            force = underground.force,
            -- player = underground.last_user,
            create_build_effect_smoke = false,
            type = underground.type == "underground-belt" and underground.belt_to_ground_type or nil
          }
          -- remove old entity
          underground.destroy()
        end
      end
    end
  end

  -- remove nil entities
  for index, _ in pairs(remove) do
    storage.under_construction[index] = nil
  end

  -- remove bad items from undoredostack here beacuse stupid out of order crap
  -- for _, id in pairs(check) do
  --   local shift = 0
  --   for index, action in pairs(game.players[id].undo_redo_stack.get_undo_item(1)) do
  --     if action.target.name:sub(1,9) == "pu-under-" then
  --       game.players[id].undo_redo_stack.remove_undo_action(1, index - shift)
  --       shift = shift + 1
  --     elseif action.target.name:sub(1,9) == "disabled-" then
  --       game.players[id].undo_redo_stack.remove_undo_action(1, index - shift)
  --       shift = shift + 1
  --     end
  --   end
  -- end
  check = {}
end)

-- todo undo/redo stack, redo should be basic undo will be more annoying
-- todo rotated entity :whyyyyyy:
-- todo upgraded entity

--------------------------------------------------------------------------------------------------- rotated
script.on_event(defines.events.on_player_rotated_entity, function(event)
  if event.entity.type == "pipe-to-ground" then
    deconstruct_pipe(event.entity, game.players[event.player_index], event.previous_direction)
    construct(event.entity, game.players[event.player_index])
  elseif event.entity.type == "pump" and event.entity.name:sub(1, 9) == "disabled-" then
    -- custom deconstruct event
    cancel_underground(event.entity, game.players[event.player_index], event.previous_direction)
    construct()
  end
end)

--------------------------------------------------------------------------------------------------- undo applied
script.on_event(defines.events.on_undo_applied, function (event)

end)

--------------------------------------------------------------------------------------------------- redo applied
script.on_event(defines.events.on_redo_applied, function (event)

end)

--------------------------------------------------------------------------------------------------- player mine
script.on_event(defines.events.on_player_mined_entity, function (event)
  if event.entity.type == "pump" then
    -- deconstruct(event.entity, game.players[event.player_index])

    -- add to undo stack via this mess
    -- event.entity.surface.create_entity {
    --   name = event.entity.name:sub(10),
    --   position = event.entity.position,
    --   direction = event.entity.direction,
    --   quality = event.entity.quality,
    --   force = event.entity.force,
    --   create_build_effect_smoke = false,
    --   type = event.entity.type == "underground-belt" and event.entity.belt_to_ground_type or nil
    -- }.destroy{player = event.player_index, item_index = 1}
  elseif event.entity.type == "pipe-to-ground" then
    deconstruct_pipe(event.entity, game.players[event.player_index])
  end
end, {{filter = "type", type = "pump"}, {filter = "type", type = "pipe-to-ground"}})

--------------------------------------------------------------------------------------------------- script mine
script.on_event(defines.events.script_raised_destroy, function (event)
  deconstruct_pipe(event.entity)
end, {{filter = "type", type = "pipe-to-ground"}})

--------------------------------------------------------------------------------------------------- player build
script.on_event(defines.events.on_built_entity, function (event)
  construct(event.entity, game.players[event.player_index])
end, {{filter = "type", type = "pipe-to-ground"}})

--------------------------------------------------------------------------------------------------- robot build
script.on_event(defines.events.on_robot_built_entity, function (event)
  construct(event.entity)
end, {{filter = "type", type = "pipe-to-ground"}})

--------------------------------------------------------------------------------------------------- script build
script.on_event(defines.events.script_raised_built, function (event)
  construct(event.entity)
end, {{filter = "type", type = "pipe-to-ground"}})

--------------------------------------------------------------------------------------------------- ghost marked for deconstruction
script.on_event(defines.events.on_pre_ghost_deconstructed, function (event)
  if event.ghost.ghost_name:sub(1,9) == "pu-under-" then
    -- recreate the entity
    event.ghost.surface.create_entity{
      name = "entity-ghost",
      inner_name = event.ghost.ghost_name,
      position = event.ghost.position,
      quality = event.ghost.quality,
      force = event.ghost.force,
      create_build_effect_smoke = false
    }
    check[#check+1] = event.player_index
  end
end, {{filter = "type", type = "simple-entity-with-owner"}})

--------------------------------------------------------------------------------------------------- cancel deconstruction
script.on_event(defines.events.on_cancelled_deconstruction, function (event)
  if not cancelled[event.entity.unit_number] and event.entity.type == "simple-entity-with-owner" and event.entity.name:sub(1,9) == "pu-under-" then
    event.entity.order_deconstruction(event.entity.force)
    ordered[event.entity.unit_number] = true
  elseif event.entity.type ~= "simple-entity-with-owner" then
    -- attempt to construct entity (will fail if the neighbour is marked for deconstruction)
    construct(event.entity)
  end
end, {{filter = "type", type = "pipe-to-ground"}, {filter = "type", type = "simple-entity-with-owner"}})

--------------------------------------------------------------------------------------------------- mark for deconstruction
script.on_event(defines.events.on_marked_for_deconstruction, function (event)
  -- if psuedo pipe, mark fake undergrounds for deconstruction
  if event.entity.type == "pump" and event.entity.name:sub(1,9) == "disabled-" then
    -- remove from undo_redo_stack... eventually
    -- check[#check+1] = event.player_index

    -- get relevant entities from storage
    local entities = storage.under_construction[event.entity.unit_number]
    
    -- remove from storage
    storage.under_construction[entities[1].unit_number] = nil
    storage.under_construction[entities[2].unit_number] = nil

    -- faux underground entities
    local placements = entities[1].surface.find_entities_filtered {
      name = "pu-under-" .. entities[1].name:sub(10, -11),
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
    local ghost_placements = entities[1].surface.find_entities_filtered {
      ghost_name = "pu-under-" .. entities[1].name:sub(10, -11),
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

    -- mark placed entities for deconstruction
    for _, entity in pairs(placements) do
      entity.order_deconstruction(entity.force)
    end

    -- delete ghost entities
    for _, entity in pairs(ghost_placements) do
      entity.destroy()
    end

    -- replace both entities with normal pipes and mark required ones for deconstruction
    for i, underground in pairs(entities) do
      -- make new entity
      new = underground.surface.create_entity {
        name = underground.name:sub(10),
        position = underground.position,
        direction = underground.direction,
        quality = underground.quality,
        force = underground.force,
        -- player = underground.last_user,
        create_build_effect_smoke = false,
        type = underground.type == "underground-belt" and underground.belt_to_ground_type or nil
      }
      -- mark for deconstruction
      if underground.to_be_deconstructed() then
        new.order_deconstruction(new.force, event.player_index)
      end
      -- remove old entity
      underground.destroy()
    end
  elseif event.entity.type == "pipe-to-ground" then
    -- for index, action in pairs(game.players[event.player_index].undo_redo_stack.get_undo_item(1)) do
    --   if action.target.position == event.entity.position then
    --     break
    --   end
    -- end
    -- create and mark relevant 'connections' for deconstruction
    -- also convert and mark pipe-to-ground for deconstruction
    deconstruct_pipe(event.entity)
  elseif not ordered[event.entity.unit_number] and event.entity.type == "simple-entity-with-owner" and event.entity.name:sub(1,9) == "pu-under-" then
    cancelled[event.entity.unit_number] = true
    event.entity.cancel_deconstruction(event.entity.force)
    -- remove from undo/redo queue?
    -- for index, action in pairs(game.players[event.player_index].undo_redo_stack.get_undo_item(1)) do
    -- end
  end
end, {{filter = "type", type = "pipe-to-ground"}, {filter = "type", type = "pump"}, {filter = "type", type = "simple-entity-with-owner"}})

--------------------------------------------------------------------------------------------------- on blueprinted
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
    if entity.name:sub(1,9) == "pu-under-" then
      entities[i] = nil
      -- if psuedo pipe to ground, replace with normal variant
    elseif entity.name:sub(1,9) == "disabled-" then
      entity.name = entity.name:sub(10)
    end
  end
  blueprint.set_blueprint_entities(entities)
end)