local M = {}
local config = require('whiteboard.config')

M.connections = {}
M.next_id = 1
M.connecting = nil

function M.add(from_id, to_id, style, label)
  style = style or config.options.connections.default_style
  local conn = {
    id = M.next_id,
    from = from_id,
    to = to_id,
    style = style,
    label = label or '',
  }
  
  M.connections[conn.id] = conn
  M.next_id = M.next_id + 1
  return conn.id
end

function M.start_connection()
  local nodes = require('whiteboard.nodes')
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = nodes.get_node_at(pos.x, pos.y)

  if not node then
    vim.notify('Select a node to start connection', vim.log.levels.WARN)
    return
  end

  M.connecting = {
    from_id = node.id,
  }

  vim.notify('Connection mode: Select destination node (or Esc to cancel)', vim.log.levels.INFO)

  -- Set up temporary keymap for connection completion
  local canvas_buf = canvas.get_bufnr()
  local opts = { buffer = canvas_buf, silent = true }

  -- Store original keymaps to restore later
  M.connection_keymaps_set = true

  vim.keymap.set('n', '<CR>', function()
    M.complete_connection()
    M.clear_connection_keymaps(canvas_buf)
  end, opts)

  vim.keymap.set('n', config.options.keymaps.cancel_connect, function()
    M.cancel_connection()
    M.clear_connection_keymaps(canvas_buf)
  end, opts)
end

function M.clear_connection_keymaps(bufnr)
  if not M.connection_keymaps_set then return end
  M.connection_keymaps_set = false
  pcall(vim.keymap.del, 'n', '<CR>', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', config.options.keymaps.cancel_connect, { buffer = bufnr })
  -- Re-establish only the add_node keymap (not all keymaps)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', config.options.keymaps.add_node, function()
    require('whiteboard.nodes').add_at_cursor(true)
  end, opts)
end

function M.complete_connection()
  if not M.connecting then return end
  
  local nodes = require('whiteboard.nodes')
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = nodes.get_node_at(pos.x, pos.y)
  
  if not node then
    vim.notify('No node selected', vim.log.levels.WARN)
    M.cancel_connection()
    return
  end
  
  if node.id == M.connecting.from_id then
    vim.notify('Cannot connect node to itself', vim.log.levels.WARN)
    M.cancel_connection()
    return
  end
  
  -- Check for duplicate connection
  for _, conn in pairs(M.connections) do
    if conn.from == M.connecting.from_id and conn.to == node.id then
      vim.notify('Connection already exists', vim.log.levels.WARN)
      M.cancel_connection()
      return
    end
  end
  
  M.add(M.connecting.from_id, node.id)
  M.connecting = nil
  
  require('whiteboard.renderer').render()
  vim.notify('Connection created', vim.log.levels.INFO)
end

function M.cancel_connection()
  M.connecting = nil
  vim.notify('Connection cancelled', vim.log.levels.INFO)
end

function M.delete(id)
  M.connections[id] = nil
  require('whiteboard.renderer').render()
end

function M.remove_node_connections(node_id)
  for id, conn in pairs(M.connections) do
    if conn.from == node_id or conn.to == node_id then
      M.connections[id] = nil
    end
  end
end

function M.get_all()
  return vim.deepcopy(M.connections)
end

function M.get_by_id(id)
  return M.connections[id]
end

function M.get_edge_point(node, target_x, target_y)
  local cx = node.x + math.floor(node.width / 2)
  local cy = node.y + math.floor(node.height / 2)
  local dx = target_x - cx
  local dy = target_y - cy

  if math.abs(dx) > math.abs(dy) then
    if dx > 0 then
      return node.x + node.width - 1, cy
    else
      return node.x, cy
    end
  else
    if dy > 0 then
      return cx, node.y + node.height - 1
    else
      return cx, node.y
    end
  end
end

function M.get_connection_at(x, y)
  local nodes_mod = require('whiteboard.nodes')

  for _, conn in pairs(M.connections) do
    local from_node = nodes_mod.get_by_id(conn.from)
    local to_node = nodes_mod.get_by_id(conn.to)

    if from_node and to_node then
      -- Use same edge-to-edge logic as renderer
      local from_cx = from_node.x + math.floor(from_node.width / 2)
      local from_cy = from_node.y + math.floor(from_node.height / 2)
      local to_cx = to_node.x + math.floor(to_node.width / 2)
      local to_cy = to_node.y + math.floor(to_node.height / 2)

      local x1, y1 = M.get_edge_point(from_node, to_cx, to_cy)
      local x2, y2 = M.get_edge_point(to_node, from_cx, from_cy)

      local dx = x2 - x1
      local dy = y2 - y1

      if math.abs(dx) > math.abs(dy) then
        local mid_x = math.floor((x1 + x2) / 2)
        -- First horizontal segment
        if y == y1 and x >= math.min(x1, mid_x) and x <= math.max(x1, mid_x) then
          return conn
        end
        -- Vertical segment
        if x == mid_x and y >= math.min(y1, y2) and y <= math.max(y1, y2) then
          return conn
        end
        -- Second horizontal segment
        if y == y2 and x >= math.min(mid_x, x2) and x <= math.max(mid_x, x2) then
          return conn
        end
      else
        local mid_y = math.floor((y1 + y2) / 2)
        -- First vertical segment
        if x == x1 and y >= math.min(y1, mid_y) and y <= math.max(y1, mid_y) then
          return conn
        end
        -- Horizontal segment
        if y == mid_y and x >= math.min(x1, x2) and x <= math.max(x1, x2) then
          return conn
        end
        -- Second vertical segment
        if x == x2 and y >= math.min(mid_y, y2) and y <= math.max(mid_y, y2) then
          return conn
        end
      end
    end
  end
  return nil
end

function M.edit_label_at_cursor()
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local conn = M.get_connection_at(pos.x, pos.y)

  if not conn then
    vim.notify('No connection at cursor position', vim.log.levels.WARN)
    return
  end

  -- Create input for label
  local current_label = conn.label or ''
  vim.ui.input({ prompt = 'Connection label: ', default = current_label }, function(input)
    if input ~= nil then
      conn.label = input
      require('whiteboard.renderer').render()
    end
  end)
end

function M.get_for_node(node_id)
  local result = { from = {}, to = {} }
  for _, conn in pairs(M.connections) do
    if conn.from == node_id then
      table.insert(result.from, conn)
    end
    if conn.to == node_id then
      table.insert(result.to, conn)
    end
  end
  return result
end

function M.load(connections_data)
  M.connections = {}
  M.next_id = 1
  
  for _, conn_data in pairs(connections_data) do
    M.connections[conn_data.id] = vim.deepcopy(conn_data)
    M.next_id = math.max(M.next_id, conn_data.id + 1)
  end
end

function M.clear()
  M.connections = {}
  M.next_id = 1
  M.connecting = nil
end

return M
