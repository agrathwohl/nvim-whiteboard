local M = {}
local config = require('whiteboard.config')

M.windows = { toolbar = nil, sidebar = nil, selector = nil }
M.buffers = { toolbar = nil, sidebar = nil, selector = nil }
M.selected_shape = 'box'

local function shape_list()
  local keys = {}
  for shape_type in pairs(config.options.shapes.types) do
    keys[#keys + 1] = shape_type
  end
  table.sort(keys)

  local lines = {}
  for i, shape_type in ipairs(keys) do
    local info = config.options.shapes.types[shape_type]
    lines[i] = string.format(' %s %s', info.icon, info.label)
  end

  return keys, lines
end

local function key_hint(lhs)
  return (lhs:gsub('^<', ''):gsub('>$', ''))
end

local function float(bufnr, enter, opts)
  local win = vim.api.nvim_open_win(bufnr, enter, opts)
  vim.wo[win].winhighlight =
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight
  return win
end

function M.show_toolbar()
  if not config.options.ui.toolbar.enabled then
    return
  end

  local canvas_win = require('whiteboard.canvas').get_winnr()
  if not (canvas_win and vim.api.nvim_win_is_valid(canvas_win)) then
    return
  end

  local km = config.options.keymaps
  local height = config.options.ui.toolbar.height

  M.buffers.toolbar = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.buffers.toolbar, 0, -1, false, {
    string.format(' %s add   %s quick-add   %s edit   %s label   %s connect   %s delete',
      key_hint(km.add_node), key_hint(km.quick_add), key_hint(km.edit_text),
      key_hint(km.edit_label), key_hint(km.start_connect), key_hint(km.delete_node)),
    string.format(' %s%s%s%s move/resize node   %s grid   %s save   %s close',
      key_hint(km.node_up_alt), key_hint(km.node_down_alt),
      key_hint(km.resize_wider), key_hint(km.resize_taller),
      key_hint(km.toggle_grid), key_hint(km.save), key_hint(km.close)),
  })
  vim.bo[M.buffers.toolbar].modifiable = false

  M.windows.toolbar = float(M.buffers.toolbar, false, {
    relative = 'win',
    win = canvas_win,
    width = vim.api.nvim_win_get_width(canvas_win),
    height = height,
    col = 0,
    row = -height - 1,
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Tools ',
    title_pos = 'center',
  })
end

function M.show_sidebar()
  if not config.options.ui.sidebar.enabled then
    return
  end

  local canvas = require('whiteboard.canvas')
  local canvas_win = canvas.get_winnr()
  if not (canvas_win and vim.api.nvim_win_is_valid(canvas_win)) then
    return
  end

  local width = config.options.ui.sidebar.width
  local keys, lines = shape_list()

  M.buffers.sidebar = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.buffers.sidebar, 0, -1, false, lines)
  vim.bo[M.buffers.sidebar].modifiable = false

  M.windows.sidebar = float(M.buffers.sidebar, false, {
    relative = 'win',
    win = canvas_win,
    width = width,
    height = vim.api.nvim_win_get_height(canvas_win),
    col = -width - 2,
    row = 0,
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Shapes ',
    title_pos = 'center',
  })

  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_win_get_cursor(M.windows.sidebar)[1]
    local shape_type = keys[line]
    if shape_type then
      M.selected_shape = shape_type
      vim.notify('Selected shape: ' .. shape_type, vim.log.levels.INFO)
      if canvas.get_winnr() and vim.api.nvim_win_is_valid(canvas.get_winnr()) then
        vim.api.nvim_set_current_win(canvas.get_winnr())
      end
    end
  end, { buffer = M.buffers.sidebar, silent = true })
end

function M.show_shape_selector(callback)
  local canvas_win = require('whiteboard.canvas').get_winnr()
  if not (canvas_win and vim.api.nvim_win_is_valid(canvas_win)) then
    return
  end

  local keys, lines = shape_list()
  local width = 30
  local height = math.min(#lines, vim.api.nvim_win_get_height(canvas_win) - 2)

  M.buffers.selector = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.buffers.selector, 0, -1, false, lines)
  vim.bo[M.buffers.selector].modifiable = false

  M.windows.selector = float(M.buffers.selector, true, {
    relative = 'win',
    win = canvas_win,
    width = width,
    height = math.max(1, height),
    col = math.max(0, math.floor((vim.api.nvim_win_get_width(canvas_win) - width) / 2)),
    row = math.max(0, math.floor((vim.api.nvim_win_get_height(canvas_win) - height) / 2)),
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' Select Shape ',
    title_pos = 'center',
  })

  local opts = { buffer = M.buffers.selector, silent = true }

  local function close()
    if M.windows.selector and vim.api.nvim_win_is_valid(M.windows.selector) then
      vim.api.nvim_win_close(M.windows.selector, true)
    end
    M.windows.selector = nil
  end

  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_win_get_cursor(M.windows.selector)[1]
    local shape_type = keys[line]
    close()
    if shape_type then
      M.selected_shape = shape_type
      callback(shape_type)
    end
  end, opts)

  vim.keymap.set('n', '<Esc>', close, opts)
  vim.keymap.set('n', 'q', close, opts)
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
