local M = {}
local canvas = require('whiteboard.canvas')
local nodes = require('whiteboard.nodes')
local connections = require('whiteboard.connections')
local shapes = require('whiteboard.shapes')
local config = require('whiteboard.config')

-- The canvas is a grid of single display cells. Every draw path (screen render
-- and ASCII export) builds the same grid, so what you see is what you export.

local function split_chars(s)
  return vim.fn.split(s, '\\zs')
end

function M.new_grid()
  local grid = {}
  for y = 1, config.options.canvas.height do
    local row = {}
    for x = 1, config.options.canvas.width do
      row[x] = ' '
    end
    grid[y] = row
  end
  return grid
end

local function put(grid, x, y, ch)
  local row = grid[y]
  if row and row[x] then
    row[x] = ch
  end
end

function M.edge_point(node, target_x, target_y)
  local cx = node.x + math.floor(node.width / 2)
  local cy = node.y + math.floor(node.height / 2)
  local dx = target_x - cx
  local dy = target_y - cy

  if math.abs(dx) > math.abs(dy) then
    return (dx > 0) and (node.x + node.width - 1) or node.x, cy
  end
  return cx, (dy > 0) and (node.y + node.height - 1) or node.y
end

-- Drawing and hit-testing both consume this, so they cannot drift apart.
function M.route(from_node, to_node)
  local from_cx = from_node.x + math.floor(from_node.width / 2)
  local from_cy = from_node.y + math.floor(from_node.height / 2)
  local to_cx = to_node.x + math.floor(to_node.width / 2)
  local to_cy = to_node.y + math.floor(to_node.height / 2)

  local x1, y1 = M.edge_point(from_node, to_cx, to_cy)
  local x2, y2 = M.edge_point(to_node, from_cx, from_cy)

  local dx = x2 - x1
  local dy = y2 - y1

  if math.abs(dx) > math.abs(dy) then
    local mid_x = math.floor((x1 + x2) / 2)
    return {
      { x1 = x1, y1 = y1, x2 = mid_x, y2 = y1, dir = 'h' },
      { x1 = mid_x, y1 = y1, x2 = mid_x, y2 = y2, dir = 'v' },
      { x1 = mid_x, y1 = y2, x2 = x2, y2 = y2, dir = 'h' },
    }, { x = x2, y = y2, char = (dx > 0) and '▶' or '◀' }
  end

  local mid_y = math.floor((y1 + y2) / 2)
  return {
    { x1 = x1, y1 = y1, x2 = x1, y2 = mid_y, dir = 'v' },
    { x1 = x1, y1 = mid_y, x2 = x2, y2 = mid_y, dir = 'h' },
    { x1 = x2, y1 = mid_y, x2 = x2, y2 = y2, dir = 'v' },
  }, { x = x2, y = y2, char = (dy > 0) and '▼' or '▲' }
end

function M.route_contains(segments, x, y)
  for _, seg in ipairs(segments) do
    if x >= math.min(seg.x1, seg.x2) and x <= math.max(seg.x1, seg.x2)
      and y >= math.min(seg.y1, seg.y2) and y <= math.max(seg.y1, seg.y2) then
      return true
    end
  end
  return false
end

function M.draw_connection(grid, from_node, to_node, conn)
  local style = config.options.connections.styles[conn.style]
    or config.options.connections.styles.solid
  local segments, arrow = M.route(from_node, to_node)

  for _, seg in ipairs(segments) do
    local ch = (seg.dir == 'h') and style.char or '│'
    for y = math.min(seg.y1, seg.y2), math.max(seg.y1, seg.y2) do
      for x = math.min(seg.x1, seg.x2), math.max(seg.x1, seg.x2) do
        put(grid, x, y, ch)
      end
    end
  end

  put(grid, arrow.x, arrow.y, arrow.char)
end

function M.draw_node(grid, node)
  local shape_lines = shapes.render(node)
  for i, line in ipairs(shape_lines) do
    local y = node.y + i - 1
    local cells = split_chars(line)
    for j, ch in ipairs(cells) do
      put(grid, node.x + j - 1, y, ch)
    end
  end
end

function M.build_grid()
  local grid = M.new_grid()

  -- Connections first so nodes paint over them.
  for _, conn in pairs(connections.connections) do
    local from_node = nodes.get_by_id(conn.from)
    local to_node = nodes.get_by_id(conn.to)
    if from_node and to_node then
      M.draw_connection(grid, from_node, to_node, conn)
    end
  end

  for _, node in ipairs(nodes.sorted()) do
    M.draw_node(grid, node)
  end

  if config.options.canvas.show_grid then
    M.draw_grid(grid)
  end

  return grid
end

function M.draw_grid(grid)
  local step = math.max(1, config.options.canvas.grid_size)
  for y = 1, #grid, step do
    for x = 1, #grid[y], step do
      if grid[y][x] == ' ' then
        grid[y][x] = '·'
      end
    end
  end
end

function M.grid_to_lines(grid)
  local lines = {}
  for y = 1, #grid do
    lines[y] = table.concat(grid[y])
  end
  return lines
end

-- Byte offset of cell x on grid row y. Extmark columns are byte indices, and
-- the grid holds multi-byte box-drawing characters.
local function byte_col(grid, x, y)
  local row = grid[y]
  if not row or x < 1 or x > #row then
    return nil
  end
  local offset = 0
  for i = 1, x - 1 do
    offset = offset + #row[i]
  end
  return offset
end

local function place_label(bufnr, ns, grid, x, y, text)
  local col = byte_col(grid, x, y)
  if not col then
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, y - 1, col, {
    virt_text = { { text, 'Comment' } },
    virt_text_pos = 'overlay',
  })
end

function M.render_labels(bufnr, ns, grid)
  for _, node in pairs(nodes.nodes) do
    if node.label and node.label ~= '' then
      local width = vim.fn.strdisplaywidth(node.label)
      local x = node.x + math.floor(node.width / 2) - math.floor(width / 2)
      place_label(bufnr, ns, grid, math.max(1, x), node.y - 1, node.label)
    end
  end

  for _, conn in pairs(connections.connections) do
    if conn.label and conn.label ~= '' then
      local from_node = nodes.get_by_id(conn.from)
      local to_node = nodes.get_by_id(conn.to)
      if from_node and to_node then
        local segments = M.route(from_node, to_node)
        local mid = segments[2]
        local x = math.floor((mid.x1 + mid.x2) / 2)
        local y = math.floor((mid.y1 + mid.y2) / 2)
        place_label(bufnr, ns, grid, math.max(1, x), y, conn.label)
      end
    end
  end
end

function M.render()
  local bufnr = canvas.get_bufnr()
  local ns = canvas.get_namespace()

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local grid = M.build_grid()

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, M.grid_to_lines(grid))
  vim.bo[bufnr].modifiable = false

  M.render_labels(bufnr, ns, grid)
end

return M
