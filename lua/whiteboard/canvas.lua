local M = {}
local config = require('whiteboard.config')

local function blank_state()
  return {
    name = nil,
    bufnr = nil,
    winnr = nil,
    namespace = nil,
    cursor = { x = 1, y = 1 },
  }
end

M.state = blank_state()

function M.is_open()
  return M.state.bufnr ~= nil and vim.api.nvim_buf_is_valid(M.state.bufnr)
end

function M.create(name)
  if M.is_open() then
    M.close()
  end

  M.state = blank_state()
  M.state.name = name
  M.state.namespace = vim.api.nvim_create_namespace('whiteboard')

  M.state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[M.state.bufnr].buftype = 'nofile'
  vim.bo[M.state.bufnr].swapfile = false
  vim.bo[M.state.bufnr].bufhidden = 'wipe'
  vim.bo[M.state.bufnr].filetype = 'whiteboard'

  local ui = vim.api.nvim_list_uis()[1]
  local avail_width = ui and ui.width or vim.o.columns
  local avail_height = ui and ui.height or vim.o.lines
  local width = math.min(config.options.canvas.width, avail_width - 10)
  local height = math.min(config.options.canvas.height, avail_height - 10)

  M.state.winnr = vim.api.nvim_open_win(M.state.bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((avail_width - width) / 2),
    row = math.floor((avail_height - height) / 2),
    style = 'minimal',
    border = config.options.ui.style.border,
    title = ' ' .. name .. ' ',
    title_pos = 'center',
  })

  vim.wo[M.state.winnr].cursorline = false
  vim.wo[M.state.winnr].cursorcolumn = false
  vim.wo[M.state.winnr].number = false
  vim.wo[M.state.winnr].relativenumber = false
  vim.wo[M.state.winnr].signcolumn = 'no'
  vim.wo[M.state.winnr].winhighlight =
    'Normal:Normal,FloatBorder:' .. config.options.ui.style.border_highlight

  M.initialize_canvas()
  M.setup_keymaps()

  return M.state
end

function M.initialize_canvas()
  local lines = {}
  for _ = 1, config.options.canvas.height do
    table.insert(lines, string.rep(' ', config.options.canvas.width))
  end
  vim.api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, lines)
end

function M.setup_keymaps()
  local km = config.options.keymaps
  local opts = { buffer = M.state.bufnr, silent = true }

  local function map(lhs, fn)
    if lhs and lhs ~= '' then
      vim.keymap.set('n', lhs, fn, opts)
    end
  end

  local function nodes()
    return require('whiteboard.nodes')
  end

  local cursor_moves = {
    [km.move_up] = { 0, -1 }, [km.move_up_alt] = { 0, -1 },
    [km.move_down] = { 0, 1 }, [km.move_down_alt] = { 0, 1 },
    [km.move_left] = { -1, 0 }, [km.move_left_alt] = { -1, 0 },
    [km.move_right] = { 1, 0 }, [km.move_right_alt] = { 1, 0 },
    [km.move_fast_up] = { 0, -5 }, [km.move_fast_down] = { 0, 5 },
    [km.move_fast_left] = { -5, 0 }, [km.move_fast_right] = { 5, 0 },
  }
  for lhs, d in pairs(cursor_moves) do
    map(lhs, function() M.move_cursor(d[1], d[2]) end)
  end

  local node_moves = {
    [km.node_up] = { 0, -1 }, [km.node_up_alt] = { 0, -1 },
    [km.node_down] = { 0, 1 }, [km.node_down_alt] = { 0, 1 },
    [km.node_left] = { -1, 0 }, [km.node_left_alt] = { -1, 0 },
    [km.node_right] = { 1, 0 }, [km.node_right_alt] = { 1, 0 },
  }
  for lhs, d in pairs(node_moves) do
    map(lhs, function() nodes().move_at_cursor(d[1], d[2]) end)
  end

  local resizes = {
    [km.resize_wider] = { 2, 0 },
    [km.resize_narrower] = { -2, 0 },
    [km.resize_taller] = { 0, 1 },
    [km.resize_shorter] = { 0, -1 },
  }
  for lhs, d in pairs(resizes) do
    map(lhs, function() nodes().resize_at_cursor(d[1], d[2]) end)
  end

  map(km.add_node, function() nodes().add_at_cursor(true) end)
  map(km.quick_add, function() nodes().add_at_cursor(false) end)
  map(km.delete_node, function() nodes().delete_at_cursor() end)
  map(km.duplicate, function() nodes().duplicate_at_cursor() end)
  map(km.edit_text, function() nodes().edit_at_cursor() end)

  map(km.delete_connection, function()
    require('whiteboard.connections').delete_connection_at_cursor()
  end)
  map(km.start_connect, function()
    require('whiteboard.connections').start_connection()
  end)

  map(km.edit_label, function()
    local connections = require('whiteboard.connections')
    local pos = M.get_cursor_pos()

    if connections.get_connection_at(pos.x, pos.y) then
      connections.edit_label_at_cursor()
    elseif nodes().get_node_at(pos.x, pos.y) then
      nodes().edit_label_at_cursor()
    else
      vim.notify('No connection or node at cursor position', vim.log.levels.WARN)
    end
  end)

  map(km.undo, function() require('whiteboard.history').undo() end)

  map(km.toggle_grid, M.toggle_grid)
  map(km.save, function() require('whiteboard').save() end)
  map(km.close, function() require('whiteboard').close() end)
end

function M.move_cursor(dx, dy)
  if not (M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr)) then
    return
  end

  M.state.cursor.x = math.max(1, math.min(config.options.canvas.width, M.state.cursor.x + dx))
  M.state.cursor.y = math.max(1, math.min(config.options.canvas.height, M.state.cursor.y + dy))

  vim.api.nvim_win_set_cursor(M.state.winnr, { M.state.cursor.y, M.state.cursor.x - 1 })
end

function M.toggle_grid()
  config.options.canvas.show_grid = not config.options.canvas.show_grid
  require('whiteboard.renderer').render()
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
  return M.state.name or 'untitled'
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
  }
end

function M.load(state)
  if type(state) ~= 'table' then
    return
  end
  M.state.name = state.name or M.state.name
  if type(state.cursor) == 'table' and state.cursor.x and state.cursor.y then
    M.state.cursor = { x = state.cursor.x, y = state.cursor.y }
  end
end

function M.close()
  if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
    vim.api.nvim_win_close(M.state.winnr, true)
  end
  if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    vim.api.nvim_buf_delete(M.state.bufnr, { force = true })
  end

  M.state = blank_state()
end

return M
