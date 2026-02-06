local M = {}

M.config = require('whiteboard.config')
M.canvas = require('whiteboard.canvas')
M.nodes = require('whiteboard.nodes')
M.connections = require('whiteboard.connections')
M.ui = require('whiteboard.ui')
M.shapes = require('whiteboard.shapes')
M.renderer = require('whiteboard.renderer')
M.export = require('whiteboard.export')

function M.setup(opts)
  opts = opts or {}
  M.config.setup(opts)
  
  vim.api.nvim_create_user_command('Whiteboard', function(args)
    M.open(args.args)
  end, { nargs = '?', desc = 'Open whiteboard for diagramming' })
  
  vim.api.nvim_create_user_command('WhiteboardSave', function(args)
    M.save(args.args)
  end, { nargs = '?', desc = 'Save current whiteboard' })
  
  vim.api.nvim_create_user_command('WhiteboardExport', function(args)
    M.export_diagram(args.args)
  end, { nargs = 1, desc = 'Export whiteboard (ascii, svg, plantuml)' })
  
  vim.api.nvim_create_user_command('WhiteboardClose', function()
    M.close()
  end, { desc = 'Close whiteboard' })
end

function M.open(name)
  name = name or 'untitled'
  M.canvas.create(name)
  M.ui.show_toolbar()
  M.ui.show_sidebar()
  M.renderer.render()
  
  vim.notify('Whiteboard: ' .. name .. ' opened', vim.log.levels.INFO)
end

function M.close()
  M.ui.close_all()
  M.canvas.close()
  vim.notify('Whiteboard closed', vim.log.levels.INFO)
end

function M.save(name)
  name = name or M.canvas.get_name()
  local data = {
    name = name,
    nodes = M.nodes.get_all(),
    connections = M.connections.get_all(),
    canvas = M.canvas.get_state()
  }
  
  local filepath = M.config.options.save_directory .. '/' .. name .. '.wb'
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ':h'), 'p')
  
  local file = io.open(filepath, 'w')
  if file then
    file:write(vim.fn.json_encode(data))
    file:close()
    vim.notify('Whiteboard saved: ' .. filepath, vim.log.levels.INFO)
  else
    vim.notify('Failed to save whiteboard', vim.log.levels.ERROR)
  end
end

function M.load(name)
  local filepath = M.config.options.save_directory .. '/' .. name .. '.wb'
  local file = io.open(filepath, 'r')
  
  if file then
    local content = file:read('*all')
    file:close()
    
    local data = vim.fn.json_decode(content)
    M.nodes.load(data.nodes)
    M.connections.load(data.connections)
    M.canvas.load(data.canvas)
    M.renderer.render()
    vim.notify('Whiteboard loaded: ' .. name, vim.log.levels.INFO)
  else
    vim.notify('Whiteboard not found: ' .. name, vim.log.levels.ERROR)
  end
end

function M.export_diagram(format)
  format = format or 'ascii'
  M.export.export(format)
end

return M
