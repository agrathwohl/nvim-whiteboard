local M = {}
local canvas = require('whiteboard.canvas')
local nodes = require('whiteboard.nodes')
local connections = require('whiteboard.connections')
local shapes = require('whiteboard.shapes')
local utils = require('whiteboard.utils')
local config = require('whiteboard.config')

function M.render()
  local bufnr = canvas.get_bufnr()
  local ns = canvas.get_namespace()
  
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  
  -- Render connections first (so they appear behind nodes)
  M.render_connections()
  
  -- Render nodes
  for id, node in pairs(nodes.nodes) do
    M.render_node(node)
  end
  
  -- Highlight selected node
  if nodes.selected_id then
    M.highlight_node(nodes.selected_id)
  end
end

function M.render_node(node)
  local bufnr = canvas.get_bufnr()
  local ns = canvas.get_namespace()
  
  local shape_lines = shapes.render(node)
  
  for i, line in ipairs(shape_lines) do
    local row = node.y + i - 2
    if row >= 0 then
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, node.x - 1, {
        virt_text = {{line, 'Normal'}},
        virt_text_pos = 'overlay',
      })
    end
  end
end

function M.render_connections()
  local bufnr = canvas.get_bufnr()
  local ns = canvas.get_namespace()
  local styles = config.options.connections.styles
  
  for _, conn in pairs(connections.connections) do
    local from_node = nodes.get_by_id(conn.from)
    local to_node = nodes.get_by_id(conn.to)
    
    if from_node and to_node then
      M.draw_connection_line(bufnr, ns, from_node, to_node, conn)
    end
  end
end

function M.draw_connection_line(bufnr, ns, from_node, to_node, conn)
  local style = config.options.connections.styles[conn.style] or config.options.connections.styles.solid
  
  -- Calculate connection points (center of each node)
  local x1 = from_node.x + math.floor(from_node.width / 2)
  local y1 = from_node.y + math.floor(from_node.height / 2)
  local x2 = to_node.x + math.floor(to_node.width / 2)
  local y2 = to_node.y + math.floor(to_node.height / 2)
  
  -- Simple line drawing (Manhattan routing)
  local mid_x = math.floor((x1 + x2) / 2)
  
  -- Draw horizontal then vertical
  if math.abs(x2 - x1) > math.abs(y2 - y1) then
    -- Horizontal segment
    for x = math.min(x1, x2), math.max(x1, x2) do
      M.draw_char(bufnr, ns, y1, x, style.char)
    end
    
    -- Vertical segment
    for y = math.min(y1, y2), math.max(y1, y2) do
      M.draw_char(bufnr, ns, y, x2, '│')
    end
  else
    -- Vertical segment
    for y = math.min(y1, y2), math.max(y1, y2) do
      M.draw_char(bufnr, ns, y, x1, '│')
    end
    
    -- Horizontal segment
    for x = math.min(x1, x2), math.max(x1, x2) do
      M.draw_char(bufnr, ns, y2, x, style.char)
    end
  end
  
  -- Draw arrow at end
  if x2 > x1 then
    M.draw_char(bufnr, ns, y2, x2 - 1, style.arrow)
  elseif x2 < x1 then
    M.draw_char(bufnr, ns, y2, x2 + 1, '◀')
  elseif y2 > y1 then
    M.draw_char(bufnr, ns, y2 - 1, x2, '▼')
  else
    M.draw_char(bufnr, ns, y2 + 1, x2, '▲')
  end
  
  -- Draw label if exists
  if conn.label and conn.label ~= '' then
    local mid_y = math.floor((y1 + y2) / 2)
    vim.api.nvim_buf_set_extmark(bufnr, ns, mid_y - 1, mid_x, {
      virt_text = {{conn.label, 'Comment'}},
      virt_text_pos = 'overlay',
    })
  end
end

function M.draw_char(bufnr, ns, row, col, char)
  if row >= 0 and col >= 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
      virt_text = {{char, 'Normal'}},
      virt_text_pos = 'overlay',
    })
  end
end

function M.highlight_node(node_id)
  local node = nodes.get_by_id(node_id)
  if not node then return end
  
  local bufnr = canvas.get_bufnr()
  local ns = canvas.get_namespace()
  
  -- Add visual highlight
  vim.api.nvim_buf_set_extmark(bufnr, ns, node.y - 2, node.x - 1, {
    virt_text = {{'▶', 'Visual'}},
    virt_text_pos = 'overlay',
  })
end

return M
