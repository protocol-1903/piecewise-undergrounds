local xutil = {}

-- verify entity when called so we can use it as a check if the entity exists
xutil.is_type = {
  base = function(entity)
    return entity and (entity.type ~= "entity-ghost" and entity.type or entity.ghost_type) == "pipe-to-ground" and
      prototypes.entity["incomplete-" .. ((entity.name ~= "entity-ghost" and entity.name or entity.ghost_name) or "")]
  end,
  incomplete = function(entity)
    return entity and (entity.type ~= "entity-ghost" and entity.type or entity.ghost_type) == "valve" and
      (entity.name ~= "entity-ghost" and entity.name or entity.ghost_name):sub(1,11) == "incomplete-"
  end,
  psuedo = function(entity)
    return (entity and (entity.type ~= "entity-ghost" and entity.type or entity.ghost_type) or "") == "simple-entity-with-owner" and
      (entity and (entity.name ~= "entity-ghost" and entity.name or entity.ghost_name) or ""):sub(1,9) == "pu-under-"
  end
}

xutil.get_type = {
  base = function(entity)
    name = entity and (entity.name ~= "entity-ghost" and entity.name or entity.ghost_name) or ""
    return xutil.is_type.incomplete(entity) and name:sub(12) or
      xutil.is_type.psuedo(entity) and name:sub(10) or
      name or ""
  end,
  pipe = function(entity)
    return xutil.get_type.base(entity):sub(1, prototypes.item[xutil.get_type.base(entity):sub(1,-11)] and -11 or -13)
  end,
  item = function(entity)
    return xutil.get_type.pipe(entity) .. (prototypes.item[xutil.get_type.base(entity):sub(1,-11)] and "" or "-small")
  end,
  incomplete = function(entity)
    return "incomplete-" .. xutil.get_type.base(entity)
  end,
  psuedo = function(entity)
    return "pu-under-" .. xutil.get_type.pipe(entity)
  end
}

-- return if the entity is a pipe to ground/variant
xutil.is_pipe = function(entity)
  return entity and prototypes.entity[xutil.get_type.base(entity)].type == "pipe-to-ground"
end

-- return if the entity is an underground belt/variant
xutil.is_belt = function(entity)
  return entity and prototypes.entity[xutil.get_type.base(entity)].type == "underground-belt"
end

xutil.distance = function(entity1, entity2)
  if entity1.valid and entity2.valid then
    return math.abs(entity1.position.x + entity1.position.y - entity2.position.x - entity2.position.y)
  end
end

xutil.relative_direction = function(entity1, entity2)
  return {
    x = entity1.position.x > entity2.position.x and -1 or entity1.position.x < entity2.position.x and 1 or 0,
    y = entity1.position.y > entity2.position.y and -1 or entity1.position.y < entity2.position.y and 1 or 0
  }
end

xutil.boolean_direction = function(direction)
  return {
    x = direction == 12 and 1 or direction == 4 and -1 or 0,
    y = direction == 0 and 1 or direction == 8 and -1 or 0
  }
end

xutil.get_neighbour = function(entity, entity_to_ignore, direction)
  if not entity or entity.name == "entity-ghost" then return end

  -- if it's a pipe, or some derivative
  if xutil.is_pipe(entity) then
    if not entity.to_be_deconstructed() and not entity_to_ignore and not direction then
      -- use simple search

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
    else -- use expensive search if check fails

      local max_distance = 0
      for i=1, #entity.fluidbox do
        -- get each pipe connection in the current fluidbox
        for _, pipe_connection in pairs(entity.prototype.fluidbox_prototypes[1].pipe_connections) do
          -- must have a connection and must be underground type and not ordered for deconstruction
          if pipe_connection.connection_type == "underground" then
            max_distance = pipe_connection.max_underground_distance
            break
          end
        end
      end

      local dir = xutil.boolean_direction(direction or entity.direction)
      local pos1 = {
        x = entity.position.x,
        y = entity.position.y
      }
      local pos2 = {
        x = pos1.x + max_distance * dir.x,
        y = pos1.y + max_distance * dir.y
      }

      local shortest_distance = 512
      local neighbour

      for _, placement in pairs(entity.surface.find_entities_filtered{
        area = { -- find the same entity in that direction
          {
            x = (pos1.x < pos2.x and pos1.x or pos2.x) - 0.5,
            y = (pos1.y < pos2.y and pos1.y or pos2.y) - 0.5
          },
          {
            x = (pos1.x > pos2.x and pos1.x or pos2.x) + 0.5,
            y = (pos1.y > pos2.y and pos1.y or pos2.y) + 0.5
          }
        },
        name = {
          xutil.get_type.base(entity),
          xutil.get_type.incomplete(entity)
        },
        direction = ((direction or entity.direction) + 8) % 16
      }) do
        -- make sure pipe is not the one we're ignoring
        if not entity_to_ignore or placement.unit_number ~= entity_to_ignore.unit_number then
          local distance = xutil.distance(placement, entity)
          -- make sure its the closest
          if shortest_distance > distance then
            neighbour = placement
            shortest_distance = distance
          end
        end
      end

      -- make sure the neighbour agrees
      return neighbour
    end
  elseif xutil.is_belt(entity) then
    -- if it's a belt, or some derivative
    return entity.neighbours
  end
end

return xutil