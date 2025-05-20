local ordered_deconstruction = {}
local cancelled_deconstruction = {}
local remove_from_storage = {}

local xutil = require "xutil"

-- init
script.on_init(function()
  storage.under_construction = {}
end)

-- per tick, might slow down if required
script.on_event(defines.events.on_tick, function()
  ordered_deconstruction = {}
  cancelled_deconstruction = {}
  local checked = {}

  for index, entities in pairs(storage.under_construction) do

    -- make sure they aren't marked for deconstruction, and are valid
    if not checked[index] and entities[1].valid and entities[2].valid and not entities[1].to_be_deconstructed() and not entities[2].to_be_deconstructed() then

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

        -- revert fake undergrounds to normal ones
        for _, underground in pairs(entities) do
          -- make new entity
          underground.surface.create_entity {
            name = xutil.get_type.base(underground),
            position = underground.position,
            direction = underground.direction,
            quality = underground.quality,
            force = underground.force,
            create_build_effect_smoke = false,
            -- type = underground.type == "underground-belt" and underground.belt_to_ground_type or nil
          }
          -- remove old entity
          underground.destroy()
        end
      else -- make sure we only check one of the pair per tick
        checked[entities[1].unit_number] = true
        checked[entities[2].unit_number] = true
      end
    end
  end

  -- remove unneeded references
  for index, _ in pairs(remove_from_storage) do
    storage.under_construction[index] = nil
  end
end)

local function order_construction(entity, neighbour, player)
  game.print("order construction")

  local distance = xutil.distance(entity, neighbour)
  local dir = xutil.relative_direction(entity, neighbour)

  local amount_required = distance - entity.surface.count_entities_filtered {
    name = xutil.get_type.psuedo(entity),
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

  game.print(prototypes.entity[xutil.get_type.psuedo(entity)].items_to_place_this[1].name)

  if amount_required > 0 and player and player.get_main_inventory().get_item_count{
    name = prototypes.entity[xutil.get_type.psuedo(entity)].items_to_place_this[1].name,
    quality = entity.quality
  } >= amount_required then

    -- remove amount from player inventory
    player.get_main_inventory().remove{
      name = prototypes.entity[xutil.get_type.psuedo(entity)].items_to_place_this[1].name,
      quality = entity.quality,
      count = amount_required
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
      game.print("found an existing unit")
      -- entity exists, cancel deconstruction
      cancelled_deconstruction[existing_units[1].unit_number] = true
      ordered_deconstruction[existing_units[1].unit_number] = nil
      existing_units[1].cancel_deconstruction(entity.force)
    end
  end

  -- add to construction checks
  storage.under_construction[entity.unit_number] = {entity, neighbour}
  storage.under_construction[neighbour.unit_number] = {entity, neighbour}
end

local function cancel_construction(entity, player)
  game.print("cancel construction")
  local entities = storage.under_construction[entity.unit_number]
  local other_entity = entities[1] == entity and entities[2] or entities[1]
  storage.under_construction[entities[1].unit_number] = nil
  storage.under_construction[entities[2].unit_number] = nil

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
    if player.get_main_inventory().can_insert{
      name = undergrounds[1].prototype.mineable_properties.products[1].name,
      quality = undergrounds[1].quality,
      count = #undergrounds
    } then -- only insert items if every single one can be inserted
      player.get_main_inventory().insert{
        name = undergrounds[1].prototype.mineable_properties.products[1].name,
        quality = undergrounds[1].quality,
        count = #undergrounds
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

local function order_deconstruction(entity, ignore, player, dont_replace)
  game.print("order deconstruction")
  dont_replace = dont_replace or false
  local other_entity = xutil.get_neighbour(entity, ignore)

  local distance = xutil.distance(entity, other_entity)
  local dir = xutil.relative_direction(entity, other_entity)

  -- if player exists
  if not entity.to_be_deconstructed() and player and player.get_main_inventory().can_insert{
    name = xutil.get_type.pipe(entity),
    quality = entity.quality,
    count = distance
  } then -- only insert items if every single one can be inserted
    game.print("give pipes to player")
    player.get_main_inventory().insert{
      name = xutil.get_type.pipe(entity),
      quality = entity.quality,
      count = distance
    }
  else -- create underground entities and mark for deconstruction
    game.print("make psuedos")
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

  -- replace existing pipes with incomplete variants
  for i, underground in pairs{not dont_replace and entity or nil, other_entity} do
    -- local fluid = entity.getentity.get_fluid[1]
    -- fluid.amount = entity.get_fluid_count()
    -- create new entity
    local neighbour = underground.surface.create_entity {
      name = xutil.get_type.incomplete(underground),
      position = underground.position,
      direction = underground.direction,
      quality = underground.quality,
      force = underground.force,
      create_build_effect_smoke = false
    }--.insert_fluid(fluid)
    if underground.to_be_deconstructed() then
      neighbour.order_deconstruction(neighbour.force)
    end
    -- remove old entity
    underground.destroy()
    
    if i == 2 then return neighbour end
  end
end

--- @param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive|EventData.on_space_platform_built_entity|EventData.on_cancelled_deconstruction
local function on_constructed(event)
  game.print("on constructed")
  local entity = event.entity
  local player = event.name ~= defines.events.on_cancelled_deconstruction and event.player_index and game.players[event.player_index]

  if entity.type == "entity-ghost" and xutil.is_type.base(entity) then
    game.print("bad ghost to normal")

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
      entity.surface.create_entity {
        name = "entity-ghost",
        ghost_name = xutil.get_type.incomplete(entity),
        position = entity.position,
        direction = entity.direction,
        quality = entity.quality,
        force = entity.force,
        type = entity.ghost_type == "underground-belt" and entity.belt_to_ground_type or nil
      }
      entity.destroy()
    end
  elseif entity.name ~= "entity-ghost" and xutil.is_type.psuedo(entity) and event.name == defines.events.on_cancelled_deconstruction and not cancelled_deconstruction[entity.unit_number] then
    ordered_deconstruction[entity.unit_number] = true
    entity.order_deconstruction(entity.force)
  elseif entity.name ~= "entity-ghost" and xutil.is_type.incomplete(entity) then
    game.print("is incomplete, attempt to reconnect")
    -- was previously marked for deconstruction (assumed)

    local neighbour = xutil.get_neighbour(entity)
    
    if xutil.is_type.incomplete(neighbour) then
      -- found a neighbour, either under construction or isolated

      -- check if neighbour is under construction
      if storage.under_construction[neighbour.unit_number] then
        game.print("decon then recon")
        -- deconstruct old pair
        cancel_construction(neighbour)
        -- construct new pair
        order_construction(entity, neighbour)
      else -- isolated entity, mark both for construction
        game.print("construct new pair")
        order_construction(entity, neighbour)
      end

    elseif xutil.is_type.base(neighbour) then
      -- placed in between constructed pair, deconstruct them
      game.print("decon full pair and recon under con pair")

      neighbour = order_deconstruction(neighbour, entity, player)

      order_construction(entity, neighbour, player)
    end
  end
end

--- @param event EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.script_raised_destroy|EventData.on_space_platform_mined_entity|EventData.on_entity_died
local function on_deconstructed(event)
  game.print("on deconstructed")
  local entity = event.entity
  local player = event.name ~= defines.events.on_marked_for_deconstruction and event.player_index and game.players[event.player_index]

  if xutil.is_type.incomplete(entity) and storage.under_construction[entity.unit_number] then
    game.print("cancel construction for deconstructed entity")

    -- get current neighbour and potential new neighbour
    local entities = storage.under_construction[entity.unit_number]
    local other_entity = entities[1] == entity and entities[2] or entities[1]
    local new_neighbour = xutil.get_neighbour(other_entity, entity)

    -- cancel old construction order
    cancel_construction(entity, player)

    -- remove old entities from storage
    storage.under_construction[entity.unit_number] = nil
    storage.under_construction[other_entity.unit_number] = nil

    -- if new neighbour exists, attempt to construct those
    if new_neighbour then
      order_construction(other_entity, new_neighbour, player)
    end

    game.print("fidoshaiofhiodhsao")

  elseif xutil.is_type.base(entity) then
    -- completed pair, so 'deconstruct' both and delete this one
    local other_entity = xutil.get_neighbour(entity)
    local new_neighbour = xutil.get_neighbour(other_entity, entity)
    other_entity = order_deconstruction(entity, nil, player, true)

    if new_neighbour then
      order_construction(other_entity, new_neighbour, player)
    end
  elseif entity.name ~= "entity-ghost" and xutil.is_type.psuedo(entity) and event.name == defines.events.on_marked_for_deconstruction and not ordered_deconstruction[entity.unit_number] then
    game.print("cancelled deconstruction of psuedos", {skip = defines.print_skip.never})
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

-- TODO undo/redo: whenever i undo/redo a mark for deconstruction, or entity removal, or entity place...