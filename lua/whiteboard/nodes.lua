local M = {}
local config = require('whiteboard.config')
local utils = require('whiteboard.utils')

M.nodes = {}
M.next_id = 1
M.selected_id = nil

function M.calculate_dimensions(text, shape, min_dims)
  local h_padding = 12  -- 6 chars each side for border + margin
  local v_padding = 6   -- 3 lines each side for border + margin
  local lines = vim.split(text, '\n')
  local max_line_width = 0

  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_line_width then
      max_line_width = w
    end
  end

  local width = math.max(min_dims.width, max_line_width + h_padding)
  local height = math.max(min_dims.height, #lines + v_padding)

  return { width = width, height = height }
end

function M.add(node)
  node.id = node.id or M.next_id
  M.next_id = math.max(M.next_id, node.id + 1)

  node.x = node.x or 1
  node.y = node.y or 1
  node.shape = node.shape or 'box'
  node.text = node.text or ''

  -- Get shape-specific minimum dimensions
  local shapes = require('whiteboard.shapes')
  local min_dims = shapes.get_dimensions(node.shape)

  -- Calculate actual dimensions based on text
  local dims = M.calculate_dimensions(node.text, node.shape, min_dims)
  node.width = node.width or dims.width
  node.height = node.height or dims.height

  node.style = vim.tbl_deep_extend('force', config.options.shapes.default_style, node.style or {})

  M.nodes[node.id] = node
  return node.id
end

function M.add_at_cursor(use_selector)
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local ui = require('whiteboard.ui')

  local function create_node(shape_type)
    local shape_info = config.options.shapes.types[shape_type]
    local node = {
      x = pos.x,
      y = pos.y,
      shape = shape_type,
      text = shape_info and shape_info.label or shape_type,
    }

    local id = M.add(node)
    require('whiteboard.renderer').render()

    -- Enter edit mode immediately
    M.edit_node(id)
  end

  if use_selector == false and ui.selected_shape then
    -- Quick add with sidebar-selected shape
    create_node(ui.selected_shape)
  else
    -- Show shape selector
    ui.show_shape_selector(function(shape_type)
      create_node(shape_type)
    end)
  end
end

function M.delete(id)
  if M.nodes[id] then
    -- Remove connections to/from this node
    require('whiteboard.connections').remove_node_connections(id)
    
    M.nodes[id] = nil
    if M.selected_id == id then
      M.selected_id = nil
    end
    
    require('whiteboard.renderer').render()
  end
end

function M.delete_at_cursor()
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)
  
  if node then
    M.delete(node.id)
  else
    vim.notify('No node at cursor position', vim.log.levels.WARN)
  end
end

function M.get_node_at(x, y)
  for id, node in pairs(M.nodes) do
    if x >= node.x and x < node.x + node.width and
       y >= node.y and y < node.y + node.height then
      return node
    end
  end
  return nil
end

function M.edit_at_cursor()
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)
  
  if node then
    M.edit_node(node.id)
  else
    vim.notify('No node at cursor position', vim.log.levels.WARN)
  end
end

function M.edit_label_at_cursor()
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)
  
  if not node then
    vim.notify('No node at cursor position', vim.log.levels.WARN)
    return
  end

  -- Create input for label
  local current_label = node.label or ''
  vim.ui.input({ prompt = 'Node label: ', default = current_label }, function(input)
    if input ~= nil then
      node.label = input
      require('whiteboard.renderer').render()
    end
  end)
end

function M.edit_node(id)
  local node = M.nodes[id]
  if not node then return end

  local canvas = require('whiteboard.canvas')

  -- Create input window
  local width = 40
  local height = 3

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { node.text })

  local win_opts = {
    relative = 'win',
    win = canvas.get_winnr(),
    width = width,
    height = height,
    col = math.floor((config.options.canvas.width - width) / 2),
    row = math.floor((config.options.canvas.height - height) / 2),
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Edit Node Text ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_win_set_option(win, 'winhighlight',
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight)

  -- Keymaps for input
  local opts = { buffer = buf, silent = true }

  local function save_and_close()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    node.text = table.concat(lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')

    -- Recalculate dimensions to fit new text
    local shapes = require('whiteboard.shapes')
    local min_dims = shapes.get_dimensions(node.shape)
    local dims = M.calculate_dimensions(node.text, node.shape, min_dims)
    node.width = dims.width
    node.height = dims.height

    vim.api.nvim_win_close(win, true)
    require('whiteboard.renderer').render()
  end

  local function cancel()
    vim.api.nvim_win_close(win, true)
  end

  vim.keymap.set('n', '<CR>', save_and_close, opts)
  vim.keymap.set('i', '<CR>', save_and_close, opts)
  vim.keymap.set('n', '<Esc>', cancel, opts)
  vim.keymap.set('i', '<C-c>', cancel, opts)

  -- Start insert mode at end of text
  vim.cmd('startinsert!')
  vim.api.nvim_win_set_cursor(win, { 1, #node.text })
end

function M.move_node(id, dx, dy)
  local node = M.nodes[id]
  if not node then return end

  local canvas = require('whiteboard.config').options.canvas
  node.x = math.max(1, math.min(canvas.width - node.width, node.x + dx))
  node.y = math.max(1, math.min(canvas.height - node.height, node.y + dy))

  require('whiteboard.renderer').render()
end

function M.move_at_cursor(dx, dy)
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)

  if node then
    M.move_node(node.id, dx, dy)
  else
    vim.notify('No node at cursor position', vim.log.levels.WARN)
  end
end

function M.resize_node(id, dw, dh)
  local node = M.nodes[id]
  if not node then return end

  local min_width = 8
  local min_height = 3
  local max_width = 60
  local max_height = 20

  node.width = math.max(min_width, math.min(max_width, node.width + dw))
  node.height = math.max(min_height, math.min(max_height, node.height + dh))

  require('whiteboard.renderer').render()
end

function M.resize_at_cursor(dw, dh)
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)

  if node then
    M.resize_node(node.id, dw, dh)
  else
    vim.notify('No node at cursor position', vim.log.levels.WARN)
  end
end

function M.duplicate(id)
  local node = M.nodes[id]
  if not node then return nil end
  
  local new_node = vim.deepcopy(node)
  new_node.id = nil
  new_node.x = node.x + 2
  new_node.y = node.y + 1
  
  return M.add(new_node)
end

function M.duplicate_at_cursor()
  local canvas = require('whiteboard.canvas')
  local pos = canvas.get_cursor_pos()
  local node = M.get_node_at(pos.x, pos.y)
  
  if node then
    M.duplicate(node.id)
    require('whiteboard.renderer').render()
  else
    vim.notify('No node at cursor position', vim.log.levels.WARN)
  end
end

function M.get_all()
  return vim.deepcopy(M.nodes)
end

function M.get_by_id(id)
  return M.nodes[id]
end

function M.load(nodes_data)
  M.nodes = {}
  M.next_id = 1
  
  for _, node_data in pairs(nodes_data) do
    M.add(node_data)
  end
end

function M.clear()
  M.nodes = {}
  M.next_id = 1
  M.selected_id = nil
end

return M
