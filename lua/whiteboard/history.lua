local M = {}

local LIMIT = 100

M.stack = {}
M.last_key = nil

local function snapshot()
  local nodes = require('whiteboard.nodes')
  local connections = require('whiteboard.connections')
  return {
    nodes = vim.deepcopy(nodes.nodes),
    nodes_next_id = nodes.next_id,
    connections = vim.deepcopy(connections.connections),
    connections_next_id = connections.next_id,
  }
end

-- Records pre-mutation state. Consecutive same-key records coalesce into one
-- undo step (held move keys, drags); a nil key always records. break_run()
-- ends a coalescing run early.
function M.record(key)
  if key ~= nil and key == M.last_key then
    return
  end
  M.last_key = key

  table.insert(M.stack, snapshot())
  if #M.stack > LIMIT then
    table.remove(M.stack, 1)
  end
end

function M.break_run()
  M.last_key = nil
end

function M.undo()
  local snap = table.remove(M.stack)
  if not snap then
    vim.notify('Nothing to undo', vim.log.levels.INFO)
    return
  end

  M.last_key = nil

  local nodes = require('whiteboard.nodes')
  local connections = require('whiteboard.connections')
  nodes.nodes = snap.nodes
  nodes.next_id = snap.nodes_next_id
  connections.connections = snap.connections
  connections.next_id = snap.connections_next_id

  require('whiteboard.renderer').render()
end

function M.clear()
  M.stack = {}
  M.last_key = nil
end

return M
