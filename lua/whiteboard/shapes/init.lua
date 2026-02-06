local M = {}
local utils = require('whiteboard.utils')

M.systems = require('whiteboard.shapes.systems')
M.network = require('whiteboard.shapes.network')
M.code = require('whiteboard.shapes.code')

function M.render_box(node)
  local width = node.width or 10
  local height = node.height or 3
  local border = utils.get_border_chars(node.style.border or 'single')
  
  local lines = {}
  
  -- Top border
  table.insert(lines, border[1] .. string.rep(border[2], width - 2) .. border[3])
  
  -- Content lines
  local text_lines = utils.wrap_text(node.text, width - 2)
  local content_height = height - 2
  
  for i = 1, content_height do
    local line_text = text_lines[i] or ''
    local padded = line_text .. string.rep(' ', width - 2 - vim.fn.strdisplaywidth(line_text))
    table.insert(lines, border[4] .. padded .. border[4])
  end
  
  -- Bottom border
  table.insert(lines, border[6] .. string.rep(border[2], width - 2) .. border[5])
  
  return lines
end

function M.render_database(node)
  local width = node.width or 12
  local height = node.height or 4
  
  local lines = {}
  
  -- Database top (ellipse-like)
  table.insert(lines, '  ' .. string.rep('_', width - 4) .. '  ')
  table.insert(lines, ' /' .. string.rep(' ', width - 4) .. '\\ ')
  
  -- Content
  local text_lines = utils.wrap_text(node.text, width - 4)
  local content_height = height - 3
  
  for i = 1, content_height do
    local line_text = text_lines[i] or ''
    local padded = '│ ' .. line_text .. string.rep(' ', width - 4 - vim.fn.strdisplaywidth(line_text)) .. ' │'
    table.insert(lines, padded)
  end
  
  -- Bottom
  table.insert(lines, ' \\' .. string.rep('_', width - 4) .. '/ ')
  
  return lines
end

function M.render_cloud(node)
  local width = node.width or 12
  local text = node.text
  
  local lines = {
    '    .-~~~-.       ',
    '  ."  o    \".     ',
    ' /          \\    ',
    '│   ' .. utils.center_text(text, 10) .. '  │',
    ' \\          /    ',
    '   "-.___.-"      ',
  }
  
  return lines
end

function M.render_server(node)
  local width = node.width or 10
  local height = node.height or 5
  local text = node.text
  
  local lines = {
    '┌' .. string.rep('─', width - 2) .. '┐',
    '│ SERVER   │',
    '│' .. string.rep(' ', width - 2) .. '│',
    '│ ' .. text:sub(1, width - 4) .. string.rep(' ', width - 4 - #text) .. ' │',
    '│' .. string.rep(' ', width - 2) .. '│',
    '└' .. string.rep('─', width - 2) .. '┘',
  }
  
  return lines
end

function M.render(node)
  local shape_type = node.shape or 'box'
  
  if shape_type == 'database' then
    return M.render_database(node)
  elseif shape_type == 'cloud' then
    return M.render_cloud(node)
  elseif shape_type == 'server' then
    return M.render_server(node)
  else
    return M.render_box(node)
  end
end

function M.get_dimensions(shape_type)
  local dimensions = {
    box = { width = 10, height = 3 },
    database = { width = 12, height = 4 },
    cloud = { width = 18, height = 6 },
    server = { width = 12, height = 5 },
    client = { width = 10, height = 3 },
    api = { width = 10, height = 3 },
    service = { width = 12, height = 3 },
    queue = { width = 10, height = 3 },
    cache = { width = 10, height = 3 },
    component = { width = 10, height = 3 },
    class = { width = 12, height = 4 },
    function_ = { width = 12, height = 3 },
    module = { width = 10, height = 3 },
    package = { width = 10, height = 3 },
    router = { width = 10, height = 3 },
    firewall = { width = 12, height = 3 },
    switch = { width = 10, height = 3 },
    load_balancer = { width = 14, height = 3 },
  }
  
  return dimensions[shape_type] or dimensions.box
end

return M
