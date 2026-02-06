local M = {}
local config = require('whiteboard.config')
local shapes = require('whiteboard.shapes')

M.windows = {
  toolbar = nil,
  sidebar = nil,
  selector = nil,
}

M.buffers = {
  toolbar = nil,
  sidebar = nil,
  selector = nil,
}

M.selected_shape = 'box'
M.sidebar_shapes = {}

function M.show_toolbar()
  if not config.options.ui.toolbar.enabled then return end
  
  local canvas_win = require('whiteboard.canvas').get_winnr()
  if not canvas_win then return end
  
  local width = vim.api.nvim_win_get_width(canvas_win)
  local height = config.options.ui.toolbar.height
  
  M.buffers.toolbar = vim.api.nvim_create_buf(false, true)
  
  local win_opts = {
    relative = 'win',
    win = canvas_win,
    width = width,
    height = height,
    col = 0,
    row = -height - 1,
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Tools ',
    title_pos = 'center',
  }
  
  M.windows.toolbar = vim.api.nvim_open_win(M.buffers.toolbar, false, win_opts)
  
  -- Set toolbar content with actual keymaps
  local km = config.options.keymaps
  local tools = {
    string.format('[%s] Add  [%s] Delete  [%s] Edit  [%s] Connect',
      km.add_node:gsub('<CR>', 'CR'):gsub('<', ''):gsub('>', ''),
      km.delete_node:gsub('<', ''):gsub('>', ''),
      km.edit_text:gsub('<', ''):gsub('>', ''),
      km.start_connect),
    string.format('[%s] Save  [%s] Quit',
      km.save:gsub('<', ''):gsub('>', ''),
      km.close:gsub('<', ''):gsub('>', '')),
  }
  vim.api.nvim_buf_set_lines(M.buffers.toolbar, 0, -1, false, tools)
  
  vim.api.nvim_win_set_option(M.windows.toolbar, 'winhighlight',
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight)
end

function M.show_sidebar()
  if not config.options.ui.sidebar.enabled then return end

  local canvas_win = require('whiteboard.canvas').get_winnr()
  if not canvas_win then return end

  local sidebar_width = config.options.ui.sidebar.width
  local canvas_height = vim.api.nvim_win_get_height(canvas_win)

  M.buffers.sidebar = vim.api.nvim_create_buf(false, true)

  local win_opts = {
    relative = 'win',
    win = canvas_win,
    width = sidebar_width,
    height = canvas_height,
    col = -sidebar_width - 2,
    row = 0,
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Shapes ',
    title_pos = 'center',
  }

  M.windows.sidebar = vim.api.nvim_open_win(M.buffers.sidebar, false, win_opts)

  -- Get sorted shape keys for deterministic ordering
  local shape_keys = {}
  for shape_type, _ in pairs(config.options.shapes.types) do
    table.insert(shape_keys, shape_type)
  end
  table.sort(shape_keys)

  -- Populate sidebar with shape types (store order for selection)
  local lines = {}
  M.sidebar_shapes = {}
  for _, shape_type in ipairs(shape_keys) do
    local info = config.options.shapes.types[shape_type]
    local line = string.format(' %s %s', info.icon, info.label)
    table.insert(lines, line)
    table.insert(M.sidebar_shapes, shape_type)
  end

  vim.api.nvim_buf_set_lines(M.buffers.sidebar, 0, -1, false, lines)

  vim.api.nvim_win_set_option(M.windows.sidebar, 'winhighlight',
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight)

  vim.api.nvim_buf_set_option(M.buffers.sidebar, 'modifiable', false)

  -- Make sidebar interactive
  local opts = { buffer = M.buffers.sidebar, silent = true }
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_win_get_cursor(M.windows.sidebar)[1]
    local shape_type = M.sidebar_shapes[line]
    if shape_type then
      M.selected_shape = shape_type
      vim.notify('Selected shape: ' .. shape_type, vim.log.levels.INFO)
      -- Return focus to canvas
      local canvas = require('whiteboard.canvas')
      vim.api.nvim_set_current_win(canvas.get_winnr())
    end
  end, opts)
end

function M.show_shape_selector(callback)
  local canvas = require('whiteboard.canvas')
  local canvas_win = canvas.get_winnr()

  local width = 30
  local height = 20

  M.buffers.selector = vim.api.nvim_create_buf(false, true)

  local win_opts = {
    relative = 'win',
    win = canvas_win,
    width = width,
    height = height,
    col = math.floor((config.options.canvas.width - width) / 2),
    row = math.floor((config.options.canvas.height - height) / 2),
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Select Shape ',
    title_pos = 'center',
  }

  M.windows.selector = vim.api.nvim_open_win(M.buffers.selector, true, win_opts)

  -- Get sorted shape keys for deterministic ordering
  local shape_keys = {}
  for shape_type, _ in pairs(config.options.shapes.types) do
    table.insert(shape_keys, shape_type)
  end
  table.sort(shape_keys)

  -- Populate selector with sorted shapes
  local lines = {}
  local shape_list = {}

  for _, shape_type in ipairs(shape_keys) do
    local info = config.options.shapes.types[shape_type]
    local line = string.format(' %s %s', info.icon, info.label)
    table.insert(lines, line)
    table.insert(shape_list, shape_type)
  end

  vim.api.nvim_buf_set_lines(M.buffers.selector, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buffers.selector, 'modifiable', false)

  vim.api.nvim_win_set_option(M.windows.selector, 'winhighlight',
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight)

  -- Set up selection keymaps
  local opts = { buffer = M.buffers.selector, silent = true }

  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_win_get_cursor(M.windows.selector)[1]
    local selected_shape = shape_list[line]
    vim.api.nvim_win_close(M.windows.selector, true)
    if callback then
      callback(selected_shape)
    end
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(M.windows.selector, true)
  end, opts)

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(M.windows.selector, true)
  end, opts)
end

function M.close_all()
  for name, win in pairs(M.windows) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    M.windows[name] = nil
  end
  
  for name, buf in pairs(M.buffers) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    M.buffers[name] = nil
  end
end

return M
