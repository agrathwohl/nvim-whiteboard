local M = {}

M.config = require('whiteboard.config')
M.canvas = require('whiteboard.canvas')
M.nodes = require('whiteboard.nodes')
M.connections = require('whiteboard.connections')
M.ui = require('whiteboard.ui')
M.shapes = require('whiteboard.shapes')
M.renderer = require('whiteboard.renderer')
M.export = require('whiteboard.export')

local function board_path(name)
  return M.config.options.save_directory .. '/' .. name .. '.wb'
end

function M.list()
  local names = {}
  for _, path in ipairs(vim.fn.glob(board_path('*'), false, true)) do
    names[#names + 1] = vim.fn.fnamemodify(path, ':t:r')
  end
  table.sort(names)
  return names
end

function M.setup(opts)
  M.config.setup(opts)

  vim.api.nvim_create_user_command('Whiteboard', function(args)
    M.open(args.args ~= '' and args.args or nil)
  end, { nargs = '?', desc = 'Open a new whiteboard' })

  vim.api.nvim_create_user_command('WhiteboardSave', function(args)
    M.save(args.args ~= '' and args.args or nil)
  end, { nargs = '?', desc = 'Save the current whiteboard' })

  vim.api.nvim_create_user_command('WhiteboardLoad', function(args)
    M.load(args.args)
  end, {
    nargs = 1,
    desc = 'Load a saved whiteboard',
    complete = M.list,
  })

  vim.api.nvim_create_user_command('WhiteboardExport', function(args)
    M.export_diagram(args.args)
  end, {
    nargs = 1,
    desc = 'Export the current whiteboard (' .. table.concat(M.export.formats, ', ') .. ')',
    complete = function()
      return M.export.formats
    end,
  })

  vim.api.nvim_create_user_command('WhiteboardClose', function()
    M.close()
  end, { desc = 'Close the current whiteboard' })
end

function M.open(name)
  name = name or 'untitled'

  M.nodes.clear()
  M.connections.clear()
  M.canvas.create(name)
  M.ui.show_toolbar()
  M.ui.show_sidebar()
  M.renderer.render()

  vim.notify('Whiteboard: ' .. name, vim.log.levels.INFO)
end

function M.close()
  if not M.canvas.is_open() then
    return
  end

  M.ui.close_all()
  M.canvas.close()
  M.nodes.clear()
  M.connections.clear()
  vim.notify('Whiteboard closed', vim.log.levels.INFO)
end

function M.save(name)
  if not M.canvas.is_open() then
    vim.notify('No whiteboard is open', vim.log.levels.ERROR)
    return
  end

  name = name or M.canvas.get_name()

  local ok, encoded = pcall(vim.json.encode, {
    version = 1,
    name = name,
    nodes = M.nodes.get_all(),
    connections = M.connections.get_all(),
    canvas = M.canvas.get_state(),
  })

  if not ok then
    vim.notify('Failed to serialize whiteboard: ' .. tostring(encoded), vim.log.levels.ERROR)
    return
  end

  local filepath = board_path(name)
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ':h'), 'p')

  local file, err = io.open(filepath, 'w')
  if not file then
    vim.notify('Failed to save whiteboard: ' .. (err or filepath), vim.log.levels.ERROR)
    return
  end

  file:write(encoded)
  file:close()
  vim.notify('Whiteboard saved: ' .. filepath, vim.log.levels.INFO)
end

function M.load(name)
  local filepath = board_path(name)
  local file = io.open(filepath, 'r')

  if not file then
    vim.notify('Whiteboard not found: ' .. filepath, vim.log.levels.ERROR)
    return
  end

  local content = file:read('*a')
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then
    vim.notify('Whiteboard file is corrupt: ' .. filepath, vim.log.levels.ERROR)
    return
  end

  M.open(data.name or name)
  M.nodes.load(data.nodes)
  M.connections.load(data.connections)
  M.canvas.load(data.canvas)
  M.renderer.render()

  vim.notify('Whiteboard loaded: ' .. name, vim.log.levels.INFO)
end

function M.export_diagram(format)
  if not M.canvas.is_open() then
    vim.notify('No whiteboard is open', vim.log.levels.ERROR)
    return
  end
  return M.export.export(format)
end

return M
