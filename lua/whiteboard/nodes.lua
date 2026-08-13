local M = {}
local config = require('whiteboard.config')

M.nodes = {}
M.next_id = 1

local H_PADDING = 4
local V_PADDING = 2
local MIN_WIDTH = 8
local MIN_HEIGHT = 5
local MAX_WIDTH = 60
local MAX_HEIGHT = 20

function M.calculate_dimensions(text, min_dims)
  local max_line_width = 0
  local lines = vim.split(text or '', '\n')

  for _, line in ipairs(lines) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end

  return {
    width = math.min(MAX_WIDTH, math.max(min_dims.width, max_line_width + H_PADDING)),
    height = math.min(MAX_HEIGHT, math.max(min_dims.height, #lines + V_PADDING)),
  }
end

function M.add(node)
  node.id = node.id or M.next_id
  M.next_id = math.max(M.next_id, node.id + 1)

  node.x = node.x or 1
  node.y = node.y or 1
  node.shape = node.shape or 'box'
  node.text = node.text or ''

  local min_dims = require('whiteboard.shapes').get_dimensions(node.shape)
  local dims = M.calculate_dimensions(node.text, min_dims)
  node.width = node.width or dims.width
  node.height = node.height or dims.height

  node.style = vim.tbl_deep_extend('force', config.options.shapes.default_style, node.style or {})

  M.nodes[node.id] = node
  return node.id
end

function M.add_at_cursor(use_selector)
  local pos = require('whiteboard.canvas').get_cursor_pos()
  local ui = require('whiteboard.ui')

  local function create_node(shape_type)
    if not shape_type then
      return
    end
    require('whiteboard.history').record()
    local shape_info = config.options.shapes.types[shape_type]
    local id = M.add({
      x = pos.x,
      y = pos.y,
      shape = shape_type,
      text = shape_info and shape_info.label or shape_type,
    })
    require('whiteboard.renderer').render()
    M.edit_node(id)
  end

  if use_selector then
    ui.show_shape_selector(create_node)
  else
    create_node(ui.selected_shape)
  end
end

function M.delete(id)
  if not M.nodes[id] then
    return
  end

  require('whiteboard.connections').remove_node_connections(id)
  M.nodes[id] = nil
  require('whiteboard.renderer').render()
end

function M.sorted()
  local list = {}
  for _, node in pairs(M.nodes) do
    list[#list + 1] = node
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

function M.get_node_at(x, y)
  local found
  for _, node in ipairs(M.sorted()) do
    if x >= node.x and x < node.x + node.width
      and y >= node.y and y < node.y + node.height then
      found = node
    end
  end
  return found
end

local function with_node_at_cursor(fn)
  local pos = require('whiteboard.canvas').get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)

  if not node then
    vim.notify('No node at cursor position', vim.log.levels.WARN)
    return
  end

  fn(node)
end

function M.delete_at_cursor()
  with_node_at_cursor(function(node)
    require('whiteboard.history').record()
    M.delete(node.id)
  end)
end

function M.edit_at_cursor()
  with_node_at_cursor(function(node) M.edit_node(node.id) end)
end

function M.move_at_cursor(dx, dy)
  with_node_at_cursor(function(node)
    require('whiteboard.history').record('move:' .. node.id)
    M.move_node(node.id, dx, dy)
  end)
end

function M.resize_at_cursor(dw, dh)
  with_node_at_cursor(function(node)
    require('whiteboard.history').record('resize:' .. node.id)
    M.resize_node(node.id, dw, dh)
  end)
end

function M.duplicate_at_cursor()
  with_node_at_cursor(function(node)
    require('whiteboard.history').record()
    M.duplicate(node.id)
  end)
end

function M.edit_label_at_cursor()
  with_node_at_cursor(function(node)
    vim.ui.input({ prompt = 'Node label: ', default = node.label or '' }, function(input)
      if input ~= nil and input ~= (node.label or '') then
        require('whiteboard.history').record()
        node.label = input
        require('whiteboard.renderer').render()
      end
    end)
  end)
end

function M.edit_node(id)
  local node = M.nodes[id]
  if not node then
    return
  end

  local canvas = require('whiteboard.canvas')
  local canvas_win = canvas.get_winnr()
  if not (canvas_win and vim.api.nvim_win_is_valid(canvas_win)) then
    return
  end

  local width = 40
  local height = 3

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(node.text, '\n'))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'win',
    win = canvas_win,
    width = width,
    height = height,
    col = math.max(0, math.floor((vim.api.nvim_win_get_width(canvas_win) - width) / 2)),
    row = math.max(0, math.floor((vim.api.nvim_win_get_height(canvas_win) - height) / 2)),
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Edit Node Text ',
    title_pos = 'center',
  })
  vim.wo[win].winhighlight =
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight

  local opts = { buffer = buf, silent = true }

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function save_and_close()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = (table.concat(lines, '\n'):gsub('^%s+', ''):gsub('%s+$', ''))
    if text ~= node.text then
      require('whiteboard.history').record()
      node.text = text

      local min_dims = require('whiteboard.shapes').get_dimensions(node.shape)
      local dims = M.calculate_dimensions(node.text, min_dims)
      node.width = dims.width
      node.height = dims.height
    end

    close()
    require('whiteboard.renderer').render()
  end

  vim.keymap.set('n', '<CR>', save_and_close, opts)
  vim.keymap.set('i', '<CR>', save_and_close, opts)
  vim.keymap.set('n', '<Esc>', close, opts)
  vim.keymap.set('i', '<C-c>', close, opts)

  vim.cmd('startinsert!')
end

function M.move_node(id, dx, dy)
  local node = M.nodes[id]
  if not node then
    return
  end

  local canvas = config.options.canvas
  node.x = math.max(1, math.min(math.max(1, canvas.width - node.width + 1), node.x + dx))
  node.y = math.max(1, math.min(math.max(1, canvas.height - node.height + 1), node.y + dy))

  require('whiteboard.renderer').render()
end

function M.resize_node(id, dw, dh)
  local node = M.nodes[id]
  if not node then
    return
  end

  node.width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, node.width + dw))
  node.height = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, node.height + dh))

  require('whiteboard.renderer').render()
end

function M.duplicate(id)
  local node = M.nodes[id]
  if not node then
    return nil
  end

  local new_node = vim.deepcopy(node)
  new_node.id = nil
  new_node.x = node.x + 2
  new_node.y = node.y + 1

  local new_id = M.add(new_node)
  require('whiteboard.renderer').render()
  return new_id
end

function M.get_all()
  return vim.deepcopy(M.nodes)
end

function M.get_by_id(id)
  return M.nodes[id]
end

function M.load(nodes_data)
  M.clear()

  for _, node_data in pairs(nodes_data or {}) do
    if type(node_data) == 'table' then
      M.add(node_data)
    end
  end
end

function M.clear()
  M.nodes = {}
  M.next_id = 1
end

return M
