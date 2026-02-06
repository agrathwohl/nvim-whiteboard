local M = {}
local utils = require('whiteboard.utils')

M.systems = require('whiteboard.shapes.systems')
M.network = require('whiteboard.shapes.network')
M.code = require('whiteboard.shapes.code')

function M.render_box(node)
  local width = node.width or 16
  local height = node.height or 5
  local border = utils.get_border_chars(node.style.border or 'single')
  local inner_width = width - 2
  local margin = 2  -- horizontal margin inside box

  local lines = {}

  -- Top border
  table.insert(lines, border[1] .. string.rep(border[2], inner_width) .. border[3])

  -- Content lines with vertical centering
  local text_lines = utils.wrap_text(node.text, inner_width - (margin * 2))
  local content_height = height - 2
  local text_start = math.floor((content_height - #text_lines) / 2) + 1

  for i = 1, content_height do
    local text_idx = i - text_start + 1
    local line_text = ''
    if text_idx >= 1 and text_idx <= #text_lines then
      line_text = text_lines[text_idx]
    end
    -- Center text horizontally with margin
    local text_width = vim.fn.strdisplaywidth(line_text)
    local left_pad = math.floor((inner_width - text_width) / 2)
    local right_pad = inner_width - text_width - left_pad
    local padded = string.rep(' ', left_pad) .. line_text .. string.rep(' ', right_pad)
    table.insert(lines, border[4] .. padded .. border[4])
  end

  -- Bottom border
  table.insert(lines, border[6] .. string.rep(border[2], inner_width) .. border[5])

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
    box = { width = 24, height = 7 },
    database = { width = 26, height = 9 },
    cloud = { width = 30, height = 10 },
    server = { width = 26, height = 9 },
    client = { width = 24, height = 7 },
    api = { width = 24, height = 7 },
    service = { width = 26, height = 7 },
    queue = { width = 24, height = 7 },
    cache = { width = 24, height = 7 },
    component = { width = 24, height = 7 },
    class = { width = 26, height = 9 },
    function_ = { width = 26, height = 7 },
    module = { width = 24, height = 7 },
    package = { width = 24, height = 7 },
    router = { width = 24, height = 7 },
    firewall = { width = 26, height = 7 },
    switch = { width = 24, height = 7 },
    load_balancer = { width = 28, height = 7 },
  }

  return dimensions[shape_type] or dimensions.box
end

return M
