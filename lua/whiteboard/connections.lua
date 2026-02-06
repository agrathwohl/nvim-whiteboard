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
  -- Re-establish the original add_node keymap
  local canvas = require('whiteboard.canvas')
  canvas.setup_keymaps()
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
