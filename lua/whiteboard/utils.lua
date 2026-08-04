local M = {}

function M.wrap_text(text, max_width)
  local lines = {}
  local current_line = ''

  if max_width < 1 then
    max_width = 1
  end

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

return M
