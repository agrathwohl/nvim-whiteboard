local M = {}
local config = require('whiteboard.config')

M.connections = {}
M.next_id = 1
M.connecting = nil

function M.add(from_id, to_id, style, label)
  local conn = {
    id = M.next_id,
    from = from_id,
    to = to_id,
    style = style or config.options.connections.default_style,
    label = label or '',
  }

  M.connections[conn.id] = conn
  M.next_id = M.next_id + 1
  return conn.id
end

function M.exists(from_id, to_id)
  for _, conn in pairs(M.connections) do
    if conn.from == from_id and conn.to == to_id then
      return true
    end
  end
  return false
end

function M.start_connection()
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = require('whiteboard.nodes').get_node_at(pos.x, pos.y)

  if not node then
    vim.notify('Select a node to start connection', vim.log.levels.WARN)
    return
  end

  M.connecting = { from_id = node.id }
  vim.notify('Connect from "' .. (node.text or node.id) .. '": move to target, <CR> to link, <Esc> to cancel',
    vim.log.levels.INFO)

  local bufnr = canvas.get_bufnr()
  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set('n', '<CR>', function()
    M.complete_connection()
    M.clear_connection_keymaps(bufnr)
  end, opts)

  vim.keymap.set('n', config.options.keymaps.cancel_connect, function()
    M.cancel_connection()
    M.clear_connection_keymaps(bufnr)
  end, opts)
end

function M.clear_connection_keymaps(bufnr)
  if not M.connecting then
    return
  end
  M.connecting = nil
  pcall(vim.keymap.del, 'n', '<CR>', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', config.options.keymaps.cancel_connect, { buffer = bufnr })
  require('whiteboard.canvas').setup_keymaps()
end

function M.complete_connection()
  if not M.connecting then
    return false
  end

  if not require('whiteboard.nodes').get_by_id(M.connecting.from_id) then
    vim.notify('Connection source no longer exists', vim.log.levels.WARN)
    M.clear_connection_keymaps(require('whiteboard.canvas').get_bufnr())
    return false
  end

  local pos = require('whiteboard.canvas').get_cursor_pos()
  local node = require('whiteboard.nodes').get_node_at(pos.x, pos.y)

  if not node then
    vim.notify('No node at cursor position', vim.log.levels.WARN)
    return false
  end

  if node.id == M.connecting.from_id then
    vim.notify('Cannot connect a node to itself', vim.log.levels.WARN)
    return false
  end

  if M.exists(M.connecting.from_id, node.id) then
    vim.notify('Connection already exists', vim.log.levels.WARN)
    return false
  end

  require('whiteboard.history').record()
  M.add(M.connecting.from_id, node.id)
  require('whiteboard.renderer').render()
  vim.notify('Connection created', vim.log.levels.INFO)
  return true
end

function M.cancel_connection()
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

function M.get_connection_at(x, y)
  local nodes = require('whiteboard.nodes')
  local renderer = require('whiteboard.renderer')

  for _, conn in pairs(M.connections) do
    local from_node = nodes.get_by_id(conn.from)
    local to_node = nodes.get_by_id(conn.to)

    if from_node and to_node then
      local segments = renderer.route(from_node, to_node)
      if renderer.route_contains(segments, x, y) then
        return conn
      end
    end
  end

  return nil
end

function M.delete_connection_at_cursor()
  local pos = require('whiteboard.canvas').get_cursor_pos()
  local conn = M.get_connection_at(pos.x, pos.y)

  if not conn then
    vim.notify('No connection at cursor position', vim.log.levels.WARN)
    return
  end

  require('whiteboard.history').record()
  M.delete(conn.id)
  vim.notify('Connection deleted', vim.log.levels.INFO)
end

function M.edit_label_at_cursor()
  local pos = require('whiteboard.canvas').get_cursor_pos()
  local conn = M.get_connection_at(pos.x, pos.y)

  if not conn then
    vim.notify('No connection at cursor position', vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = 'Connection label: ', default = conn.label or '' }, function(input)
    if input ~= nil and input ~= (conn.label or '') then
      require('whiteboard.history').record()
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
  M.clear()

  for _, conn_data in pairs(connections_data or {}) do
    if type(conn_data) == 'table' and conn_data.id then
      M.connections[conn_data.id] = vim.deepcopy(conn_data)
      M.next_id = math.max(M.next_id, conn_data.id + 1)
    end
  end
end

function M.clear()
  M.connections = {}
  M.next_id = 1
  M.connecting = nil
end

return M
