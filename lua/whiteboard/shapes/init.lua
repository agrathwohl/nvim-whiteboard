local M = {}
local utils = require('whiteboard.utils')

M.systems = require('whiteboard.shapes.systems')
M.network = require('whiteboard.shapes.network')
M.code = require('whiteboard.shapes.code')

function M.render_box(node)
  local width = node.width or 24
  local height = node.height or 7
  local border = utils.get_border_chars(node.style.border or 'single')
  -- border: 1=TL, 2=H, 3=TR, 4=V, 5=BR, 6=H, 7=BL, 8=V
  local inner_width = width - 2

  local lines = {}

  -- Top border: ┌────┐
  table.insert(lines, border[1] .. string.rep(border[2], inner_width) .. border[3])

  -- Get text to display (handle empty text)
  local display_text = node.text
  if display_text == nil or display_text == '' then
    display_text = node.shape or 'box'
  end

  -- Wrap text to fit inside box with padding
  local text_width = inner_width - 4  -- leave 2 chars padding each side
  local text_lines = utils.wrap_text(display_text, text_width)
  if #text_lines == 0 then
    text_lines = { display_text:sub(1, text_width) }
  end

  -- Content area
  local content_height = height - 2
  local text_start = math.floor((content_height - #text_lines) / 2)

  for i = 0, content_height - 1 do
    local text_idx = i - text_start + 1
    local line_text = ''
    if text_idx >= 1 and text_idx <= #text_lines then
      line_text = text_lines[text_idx]
    end
    -- Center text horizontally
    local tw = vim.fn.strdisplaywidth(line_text)
    local left_pad = math.floor((inner_width - tw) / 2)
    local right_pad = inner_width - tw - left_pad
    local padded = string.rep(' ', left_pad) .. line_text .. string.rep(' ', right_pad)
    table.insert(lines, border[4] .. padded .. border[4])
  end

  -- Bottom border: └────┘
  table.insert(lines, border[7] .. string.rep(border[2], inner_width) .. border[5])

  return lines
end

function M.render_database(node)
  local width = node.width or 26
  local height = node.height or 9
  local inner_width = width - 4

  local display_text = node.text
  if display_text == nil or display_text == '' then
    display_text = 'Database'
  end

  local lines = {}

  -- Database top cylinder cap
  table.insert(lines, '  ' .. string.rep('_', inner_width) .. '  ')
  table.insert(lines, ' /' .. string.rep(' ', inner_width) .. '\\ ')
  table.insert(lines, '|' .. string.rep(' ', inner_width + 2) .. '|')

  -- Content area with centered text
  local text_lines = utils.wrap_text(display_text, inner_width - 2)
  if #text_lines == 0 then text_lines = { display_text } end
  local content_height = height - 5
  local text_start = math.floor((content_height - #text_lines) / 2)

  for i = 0, content_height - 1 do
    local text_idx = i - text_start + 1
    local line_text = ''
    if text_idx >= 1 and text_idx <= #text_lines then
      line_text = text_lines[text_idx]
    end
    local tw = vim.fn.strdisplaywidth(line_text)
    local left_pad = math.floor((inner_width - tw) / 2) + 1
    local right_pad = inner_width - tw - left_pad + 3
    table.insert(lines, '|' .. string.rep(' ', left_pad) .. line_text .. string.rep(' ', right_pad) .. '|')
  end

  -- Database bottom cylinder cap
  table.insert(lines, '|' .. string.rep('_', inner_width + 2) .. '|')
  table.insert(lines, ' \\' .. string.rep('_', inner_width) .. '/ ')

  return lines
end

function M.render_cloud(node)
  local width = node.width or 30
  local height = node.height or 10

  local display_text = node.text
  if display_text == nil or display_text == '' then
    display_text = 'Cloud'
  end

  -- Use box rendering for cloud - proper cloud shape is complex
  node.text = display_text
  return M.render_box(node)
end

function M.render_server(node)
  local width = node.width or 26
  local height = node.height or 9
  local inner_width = width - 2

  local display_text = node.text
  if display_text == nil or display_text == '' then
    display_text = 'Server'
  end

  local lines = {}

  -- Top border
  table.insert(lines, '┌' .. string.rep('─', inner_width) .. '┐')

  -- Server header
  local header = '[ SERVER ]'
  local hw = vim.fn.strdisplaywidth(header)
  local hlp = math.floor((inner_width - hw) / 2)
  local hrp = inner_width - hw - hlp
  table.insert(lines, '│' .. string.rep(' ', hlp) .. header .. string.rep(' ', hrp) .. '│')
  table.insert(lines, '│' .. string.rep('─', inner_width) .. '│')

  -- Content area with centered text
  local text_lines = utils.wrap_text(display_text, inner_width - 4)
  if #text_lines == 0 then text_lines = { display_text } end
  local content_height = height - 4
  local text_start = math.floor((content_height - #text_lines) / 2)

  for i = 0, content_height - 1 do
    local text_idx = i - text_start + 1
    local line_text = ''
    if text_idx >= 1 and text_idx <= #text_lines then
      line_text = text_lines[text_idx]
    end
    local tw = vim.fn.strdisplaywidth(line_text)
    local left_pad = math.floor((inner_width - tw) / 2)
    local right_pad = inner_width - tw - left_pad
    table.insert(lines, '│' .. string.rep(' ', left_pad) .. line_text .. string.rep(' ', right_pad) .. '│')
  end

  -- Bottom border
  table.insert(lines, '└' .. string.rep('─', inner_width) .. '┘')

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
