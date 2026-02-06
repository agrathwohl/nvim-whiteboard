local M = {}
local config = require('whiteboard.config')

M.state = {
  name = nil,
  bufnr = nil,
  winnr = nil,
  namespace = nil,
  cursor = { x = 1, y = 1 },
  offset = { x = 0, y = 0 },
  zoom = 1.0,
  grid_ns = nil,
}

function M.create(name)
  M.state.name = name
  M.state.namespace = vim.api.nvim_create_namespace('whiteboard_' .. name)
  M.state.grid_ns = vim.api.nvim_create_namespace('whiteboard_grid_' .. name)
  
  -- Create buffer
  M.state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.state.bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(M.state.bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(M.state.bufnr, 'filetype', 'whiteboard')
  
  -- Calculate window size
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.min(config.options.canvas.width, ui.width - 10)
  local height = math.min(config.options.canvas.height, ui.height - 10)
  
  -- Create window
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' ' .. name .. ' ',
    title_pos = 'center',
  }
  
  M.state.winnr = vim.api.nvim_open_win(M.state.bufnr, true, win_opts)
  
  -- Set window options
  vim.api.nvim_win_set_option(M.state.winnr, 'cursorline', false)
  vim.api.nvim_win_set_option(M.state.winnr, 'cursorcolumn', false)
  vim.api.nvim_win_set_option(M.state.winnr, 'number', false)
  vim.api.nvim_win_set_option(M.state.winnr, 'relativenumber', false)
  vim.api.nvim_win_set_option(M.state.winnr, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(M.state.winnr, 'winhighlight', 
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight)
  
  -- Initialize canvas content
  M.initialize_canvas()
  
  -- Draw grid if enabled
  if config.options.canvas.show_grid then
    M.draw_grid()
  end
  
  -- Set up keymaps
  M.setup_keymaps()
  
  return M.state
end

function M.initialize_canvas()
  local lines = {}
  local width = config.options.canvas.width
  
  for i = 1, config.options.canvas.height do
    table.insert(lines, string.rep(' ', width))
  end
  
  vim.api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, lines)
end

function M.draw_grid()
  if not M.state.grid_ns then return end
  
  local grid_size = config.options.canvas.grid_size
  local height = config.options.canvas.height
  local width = config.options.canvas.width
  
  vim.api.nvim_buf_clear_namespace(M.state.bufnr, M.state.grid_ns, 0, -1)
  
  -- Draw horizontal grid lines
  for row = 0, height - 1, grid_size do
    for col = 0, width - 1 do
      if col % grid_size == 0 then
        vim.api.nvim_buf_set_extmark(M.state.bufnr, M.state.grid_ns, row, col, {
          virt_text = {{'·', 'Comment'}},
          virt_text_pos = 'overlay',
        })
      end
    end
  end
end

function M.setup_keymaps()
  local keymaps = config.options.keymaps
  local opts = { buffer = M.state.bufnr, silent = true }
  
  -- Navigation
  vim.keymap.set('n', keymaps.move_up, function() M.move_cursor(0, -1) end, opts)
  vim.keymap.set('n', keymaps.move_down, function() M.move_cursor(0, 1) end, opts)
  vim.keymap.set('n', keymaps.move_left, function() M.move_cursor(-1, 0) end, opts)
  vim.keymap.set('n', keymaps.move_right, function() M.move_cursor(1, 0) end, opts)
  
  -- Fast movement with Ctrl
  vim.keymap.set('n', '<C-Up>', function() M.move_cursor(0, -5) end, opts)
  vim.keymap.set('n', '<C-Down>', function() M.move_cursor(0, 5) end, opts)
  vim.keymap.set('n', '<C-Left>', function() M.move_cursor(-5, 0) end, opts)
  vim.keymap.set('n', '<C-Right>', function() M.move_cursor(5, 0) end, opts)
  
  -- Actions
  vim.keymap.set('n', keymaps.add_node, function()
    require('whiteboard.nodes').add_at_cursor(true)  -- with selector
  end, opts)

  vim.keymap.set('n', 'a', function()
    require('whiteboard.nodes').add_at_cursor(false)  -- quick add with selected shape
  end, opts)
  
  vim.keymap.set('n', keymaps.delete_node, function()
    require('whiteboard.nodes').delete_at_cursor()
  end, opts)
  
  vim.keymap.set('n', keymaps.edit_text, function()
    require('whiteboard.nodes').edit_at_cursor()
  end, opts)

  -- Node movement (Shift + arrow keys OR capital HJKL)
  vim.keymap.set('n', '<S-Up>', function()
    require('whiteboard.nodes').move_at_cursor(0, -1)
  end, opts)
  vim.keymap.set('n', '<S-Down>', function()
    require('whiteboard.nodes').move_at_cursor(0, 1)
  end, opts)
  vim.keymap.set('n', '<S-Left>', function()
    require('whiteboard.nodes').move_at_cursor(-1, 0)
  end, opts)
  vim.keymap.set('n', '<S-Right>', function()
    require('whiteboard.nodes').move_at_cursor(1, 0)
  end, opts)
  -- Alternative: capital HJKL for node movement
  vim.keymap.set('n', 'K', function()
    require('whiteboard.nodes').move_at_cursor(0, -1)
  end, opts)
  vim.keymap.set('n', 'J', function()
    require('whiteboard.nodes').move_at_cursor(0, 1)
  end, opts)
  vim.keymap.set('n', 'H', function()
    require('whiteboard.nodes').move_at_cursor(-1, 0)
  end, opts)
  vim.keymap.set('n', 'L', function()
    require('whiteboard.nodes').move_at_cursor(1, 0)
  end, opts)

  -- Node resizing: > < for width, + - for height
  vim.keymap.set('n', '>', function()
    require('whiteboard.nodes').resize_at_cursor(2, 0)
  end, opts)
  vim.keymap.set('n', '<', function()
    require('whiteboard.nodes').resize_at_cursor(-2, 0)
  end, opts)
  vim.keymap.set('n', '=', function()
    require('whiteboard.nodes').resize_at_cursor(0, 1)
  end, opts)
  vim.keymap.set('n', '-', function()
    require('whiteboard.nodes').resize_at_cursor(0, -1)
  end, opts)

  -- Connection mode
  vim.keymap.set('n', keymaps.start_connect, function()
    require('whiteboard.connections').start_connection()
  end, opts)
  
  -- View controls
  vim.keymap.set('n', keymaps.zoom_in, function() M.zoom(0.1) end, opts)
  vim.keymap.set('n', keymaps.zoom_out, function() M.zoom(-0.1) end, opts)
  vim.keymap.set('n', keymaps.toggle_grid, M.toggle_grid, opts)
  
  -- File operations
  vim.keymap.set('n', keymaps.save, function()
    require('whiteboard').save()
  end, opts)
  
  vim.keymap.set('n', keymaps.close, function()
    require('whiteboard').close()
  end, opts)
end

function M.move_cursor(dx, dy)
  local new_x = math.max(1, math.min(config.options.canvas.width, M.state.cursor.x + dx))
  local new_y = math.max(1, math.min(config.options.canvas.height, M.state.cursor.y + dy))
  
  M.state.cursor.x = new_x
  M.state.cursor.y = new_y
  
  vim.api.nvim_win_set_cursor(M.state.winnr, { new_y, new_x - 1 })
end

function M.zoom(delta)
  M.state.zoom = math.max(0.5, math.min(2.0, M.state.zoom + delta))
  require('whiteboard.renderer').render()
end

function M.toggle_grid()
  config.options.canvas.show_grid = not config.options.canvas.show_grid
  if config.options.canvas.show_grid then
    M.draw_grid()
  else
    vim.api.nvim_buf_clear_namespace(M.state.bufnr, M.state.grid_ns, 0, -1)
  end
end

function M.get_cursor_pos()
  if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
    local cursor = vim.api.nvim_win_get_cursor(M.state.winnr)
    M.state.cursor.y = cursor[1]
    M.state.cursor.x = cursor[2] + 1
  end
  return { x = M.state.cursor.x, y = M.state.cursor.y }
end

function M.get_name()
  return M.state.name
end

function M.get_bufnr()
  return M.state.bufnr
end

function M.get_winnr()
  return M.state.winnr
end

function M.get_namespace()
  return M.state.namespace
end

function M.get_state()
  return {
    name = M.state.name,
    cursor = M.state.cursor,
    offset = M.state.offset,
    zoom = M.state.zoom,
  }
end

function M.load(state)
  M.state.name = state.name
  M.state.cursor = state.cursor
  M.state.offset = state.offset
  M.state.zoom = state.zoom
end

function M.close()
  if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
    vim.api.nvim_win_close(M.state.winnr, true)
  end
  if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    vim.api.nvim_buf_delete(M.state.bufnr, { force = true })
  end
  
  M.state = {
    name = nil,
    bufnr = nil,
    winnr = nil,
    namespace = nil,
    cursor = { x = 1, y = 1 },
    offset = { x = 0, y = 0 },
    zoom = 1.0,
    grid_ns = nil,
  }
end

return M
