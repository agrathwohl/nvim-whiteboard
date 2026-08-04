local M = {}
local utils = require('whiteboard.utils')

local function centered(text, width)
  local w = vim.fn.strdisplaywidth(text)
  local left = math.floor((width - w) / 2)
  return string.rep(' ', math.max(0, left))
    .. text
    .. string.rep(' ', math.max(0, width - w - left))
end

local function body_lines(text, inner_width, content_height)
  local wrapped = utils.wrap_text(text, inner_width)
  local start = math.floor((content_height - #wrapped) / 2)
  local lines = {}
  for i = 0, content_height - 1 do
    local idx = i - start + 1
    lines[i + 1] = wrapped[idx] or ''
  end
  return lines
end

local function label_for(node)
  if node.text ~= nil and node.text ~= '' then
    return node.text
  end
  return node.shape or 'box'
end

function M.render_box(node)
  local border = utils.get_border_chars(node.style and node.style.border or 'single')
  local inner_width = node.width - 2

  local lines = { border[1] .. string.rep(border[2], inner_width) .. border[3] }

  for _, text in ipairs(body_lines(label_for(node), inner_width - 4, node.height - 2)) do
    lines[#lines + 1] = border[4] .. centered(text, inner_width) .. border[4]
  end

  lines[#lines + 1] = border[7] .. string.rep(border[2], inner_width) .. border[5]
  return lines
end

function M.render_database(node)
  local inner_width = node.width - 4
  local lines = {
    '  ' .. string.rep('_', inner_width) .. '  ',
    ' /' .. string.rep(' ', inner_width) .. '\\ ',
    '|' .. string.rep(' ', inner_width + 2) .. '|',
  }

  for _, text in ipairs(body_lines(label_for(node), inner_width - 2, node.height - 5)) do
    lines[#lines + 1] = '|' .. centered(text, inner_width + 2) .. '|'
  end

  lines[#lines + 1] = '|' .. string.rep('_', inner_width + 2) .. '|'
  lines[#lines + 1] = ' \\' .. string.rep('_', inner_width) .. '/ '
  return lines
end

function M.render_server(node)
  local inner_width = node.width - 2
  local lines = {
    '┌' .. string.rep('─', inner_width) .. '┐',
    '│' .. centered('[ SERVER ]', inner_width) .. '│',
    '│' .. string.rep('─', inner_width) .. '│',
  }

  for _, text in ipairs(body_lines(label_for(node), inner_width - 4, node.height - 4)) do
    lines[#lines + 1] = '│' .. centered(text, inner_width) .. '│'
  end

  lines[#lines + 1] = '└' .. string.rep('─', inner_width) .. '┘'
  return lines
end

function M.render(node)
  local shape_type = node.shape or 'box'

  if shape_type == 'database' or shape_type == 'cache' then
    return M.render_database(node)
  elseif shape_type == 'server' then
    return M.render_server(node)
  end

  return M.render_box(node)
end

M.dimensions = {
  box = { width = 16, height = 5 },
  database = { width = 18, height = 7 },
  cloud = { width = 18, height = 5 },
  server = { width = 18, height = 7 },
  client = { width = 16, height = 5 },
  api = { width = 16, height = 5 },
  service = { width = 18, height = 5 },
  queue = { width = 16, height = 5 },
  cache = { width = 18, height = 7 },
  component = { width = 16, height = 5 },
  class = { width = 18, height = 5 },
  function_ = { width = 18, height = 5 },
  module = { width = 16, height = 5 },
  package = { width = 16, height = 5 },
  router = { width = 16, height = 5 },
  firewall = { width = 18, height = 5 },
  switch = { width = 16, height = 5 },
  load_balancer = { width = 20, height = 5 },
}

function M.get_dimensions(shape_type)
  return M.dimensions[shape_type] or M.dimensions.box
end

return M
