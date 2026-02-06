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

  -- Clear buffer and reset to empty canvas
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  local empty_lines = {}
  for i = 1, config.options.canvas.height do
    table.insert(empty_lines, string.rep(' ', config.options.canvas.width))
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, empty_lines)

  -- Render nodes first (write to buffer)
  for id, node in pairs(nodes.nodes) do
    M.render_node(node)
  end

  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

  -- Render connections on top (using extmarks)
  M.render_connections()

  -- Highlight selected node
  if nodes.selected_id then
    M.highlight_node(nodes.selected_id)
  end
end

function M.render_node(node)
  local bufnr = canvas.get_bufnr()
  local shape_lines = shapes.render(node)

  for i, line in ipairs(shape_lines) do
    local row = node.y + i - 2  -- 0-indexed (node.y is 1-indexed, i is 1-indexed)
    if row >= 0 and row < config.options.canvas.height then
      local col = node.x - 1  -- 0-indexed

      -- Get current line content
      local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

      -- Ensure line is long enough
      local current_len = #current_line
      if current_len < col + #line then
        current_line = current_line .. string.rep(' ', col + #line - current_len)
      end

      -- Simple byte-based replacement (works for ASCII canvas)
      local new_line
      if col == 0 then
        new_line = line .. current_line:sub(#line + 1)
      else
        new_line = current_line:sub(1, col) .. line .. current_line:sub(col + #line + 1)
      end

      vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
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

function M.get_edge_connection_point(node, target_x, target_y)
  -- Calculate center of node
  local cx = node.x + math.floor(node.width / 2)
  local cy = node.y + math.floor(node.height / 2)

  -- Determine which edge to connect from based on target direction
  local dx = target_x - cx
  local dy = target_y - cy

  local x, y

  if math.abs(dx) > math.abs(dy) then
    -- Connect from left or right edge
    if dx > 0 then
      x = node.x + node.width - 1  -- right edge
    else
      x = node.x  -- left edge
    end
    y = cy
  else
    -- Connect from top or bottom edge
    if dy > 0 then
      y = node.y + node.height - 1  -- bottom edge
    else
      y = node.y  -- top edge
    end
    x = cx
  end

  return x, y
end

function M.draw_connection_line(bufnr, ns, from_node, to_node, conn)
  local style = config.options.connections.styles[conn.style] or config.options.connections.styles.solid

  -- Calculate centers for direction
  local from_cx = from_node.x + math.floor(from_node.width / 2)
  local from_cy = from_node.y + math.floor(from_node.height / 2)
  local to_cx = to_node.x + math.floor(to_node.width / 2)
  local to_cy = to_node.y + math.floor(to_node.height / 2)

  -- Get edge connection points
  local x1, y1 = M.get_edge_connection_point(from_node, to_cx, to_cy)
  local x2, y2 = M.get_edge_connection_point(to_node, from_cx, from_cy)

  -- Determine primary direction
  local dx = x2 - x1
  local dy = y2 - y1

  if math.abs(dx) > math.abs(dy) then
    -- Primarily horizontal - draw horizontal then vertical
    local mid_x = math.floor((x1 + x2) / 2)

    -- First horizontal segment
    for x = math.min(x1, mid_x), math.max(x1, mid_x) do
      M.draw_char(bufnr, ns, y1, x, style.char)
    end

    -- Vertical segment
    for y = math.min(y1, y2), math.max(y1, y2) do
      M.draw_char(bufnr, ns, y, mid_x, '│')
    end

    -- Second horizontal segment
    for x = math.min(mid_x, x2), math.max(mid_x, x2) do
      M.draw_char(bufnr, ns, y2, x, style.char)
    end
  else
    -- Primarily vertical - draw vertical then horizontal
    local mid_y = math.floor((y1 + y2) / 2)

    -- First vertical segment
    for y = math.min(y1, mid_y), math.max(y1, mid_y) do
      M.draw_char(bufnr, ns, y, x1, '│')
    end

    -- Horizontal segment
    for x = math.min(x1, x2), math.max(x1, x2) do
      M.draw_char(bufnr, ns, mid_y, x, style.char)
    end

    -- Second vertical segment
    for y = math.min(mid_y, y2), math.max(mid_y, y2) do
      M.draw_char(bufnr, ns, y, x2, '│')
    end
  end

  -- Draw arrow pointing TOWARD destination (second object)
  if math.abs(dx) > math.abs(dy) then
    if x2 > x1 then
      M.draw_char(bufnr, ns, y2, x2, '▶')  -- pointing right toward dest
    else
      M.draw_char(bufnr, ns, y2, x2, '◀')  -- pointing left toward dest
    end
  else
    if y2 > y1 then
      M.draw_char(bufnr, ns, y2, x2, '▼')  -- pointing down toward dest
    else
      M.draw_char(bufnr, ns, y2, x2, '▲')  -- pointing up toward dest
    end
  end

  -- Draw label if exists
  if conn.label and conn.label ~= '' then
    local mid_x = math.floor((x1 + x2) / 2)
    local mid_y = math.floor((y1 + y2) / 2)
    vim.api.nvim_buf_set_extmark(bufnr, ns, mid_y - 1, mid_x, {
      virt_text = {{conn.label, 'Comment'}},
      virt_text_pos = 'overlay',
    })
  end
end

function M.draw_char(bufnr, ns, row, col, char)
  if row >= 0 and col >= 0 and row < config.options.canvas.height then
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

    -- Ensure line is long enough
    while #current_line <= col do
      current_line = current_line .. ' '
    end

    -- Replace character at position
    local new_line
    if col == 0 then
      new_line = char .. current_line:sub(2)
    else
      new_line = current_line:sub(1, col) .. char .. current_line:sub(col + 2)
    end

    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
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
