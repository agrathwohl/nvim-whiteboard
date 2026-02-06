local M = {}

function M.clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

function M.distance(x1, y1, x2, y2)
  return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function M.center_text(text, width)
  local text_width = vim.fn.strdisplaywidth(text)
  if text_width >= width then
    return text:sub(1, width)
  end
  
  local left_pad = math.floor((width - text_width) / 2)
  local right_pad = width - text_width - left_pad
  
  return string.rep(' ', left_pad) .. text .. string.rep(' ', right_pad)
end

function M.wrap_text(text, max_width)
  local lines = {}
  local current_line = ''
  
  for word in text:gmatch('%S+') do
    local test_line = current_line .. (current_line ~= '' and ' ' or '') .. word
    if vim.fn.strdisplaywidth(test_line) <= max_width then
      current_line = test_line
    else
      if current_line ~= '' then
        table.insert(lines, current_line)
      end
      current_line = word
    end
  end
  
  if current_line ~= '' then
    table.insert(lines, current_line)
  end
  
  return lines
end

function M.get_border_chars(style)
  local styles = {
    single = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
    double = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' },
    rounded = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
    bold = { '┏', '━', '┓', '┃', '┛', '━', '┗', '┃' },
    ascii = { '+', '-', '+', '|', '+', '-', '+', '|' },
  }
  
  return styles[style] or styles.single
end

function M.generate_id()
  return os.time() .. '_' .. math.random(1000, 9999)
end

function M.table_copy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    if type(v) == 'table' then
      copy[k] = M.table_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

return M
