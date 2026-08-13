local wb = require('whiteboard')
local canvas = require('whiteboard.canvas')
local nodes = require('whiteboard.nodes')
local connections = require('whiteboard.connections')
local history = require('whiteboard.history')

local function eq(got, want, label)
  assert(got == want, string.format('%s: got %s, want %s', label, vim.inspect(got), vim.inspect(want)))
end

local function count(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

wb.setup({ ui = { toolbar = { enabled = false }, sidebar = { enabled = false } } })
wb.open('mouse-test')

-- Like a real mouse, the stub reports a screen cell and derives the byte
-- column from the buffer at event time, not at "press" time.
local mouse = { cell_x = 1, line = 1 }
vim.fn.getmousepos = function()
  local line = vim.api.nvim_buf_get_lines(canvas.get_bufnr(), mouse.line - 1, mouse.line, false)[1] or ''
  local column = mouse.column or (vim.fn.byteidx(line, mouse.cell_x - 1) + 1)
  return {
    winid = canvas.get_winnr(),
    line = mouse.line,
    column = column,
    coladd = mouse.coladd or 0,
  }
end

local function click_cell(x, y)
  mouse = { cell_x = x, line = y }
end

local a = nodes.add({ x = 10, y = 5, shape = 'box', text = 'A' })
local b = nodes.add({ x = 60, y = 20, shape = 'box', text = 'B' })
require('whiteboard.renderer').render()

click_cell(12, 6)
canvas.on_click()
local pos = canvas.get_cursor_pos()
eq(pos.x, 12, 'click x lands on cell despite multibyte border chars')
eq(pos.y, 6, 'click y')
eq(canvas.state.drag.id, a, 'drag armed on clicked node')

local base = #history.stack
click_cell(30, 12)
canvas.on_drag()
canvas.on_drag()
eq(nodes.get_by_id(a).x, 28, 'node dragged, grab offset preserved')
eq(nodes.get_by_id(a).y, 11, 'node dragged vertically')
eq(#history.stack, base + 1, 'whole drag is one undo step')
canvas.on_release()
eq(canvas.state.drag, nil, 'release disarms drag')

click_cell(32, 13)
canvas.on_click()
click_cell(40, 16)
canvas.on_drag()
canvas.on_release()
eq(#history.stack, base + 2, 'second drag gesture is a new undo step')

history.undo()
history.undo()
eq(nodes.get_by_id(a).x, 10, 'drags undone back to original x')
eq(nodes.get_by_id(a).y, 5, 'drags undone back to original y')

click_cell(2, 2)
canvas.on_click()
eq(canvas.state.drag, nil, 'clicking empty canvas arms nothing')
canvas.on_drag()
eq(nodes.get_by_id(a).x, 10, 'drag without armed node is a no-op')

click_cell(12, 6)
canvas.on_click()
connections.start_connection()
click_cell(62, 21)
canvas.on_click()
eq(count(connections.connections), 1, 'click completes connection on target node')
eq(connections.connecting, nil, 'connect mode exits after click completion')
eq(connections.get_by_id(1).from, a, 'connection direction from')
eq(connections.get_by_id(1).to, b, 'connection direction to')

click_cell(12, 6)
canvas.on_click()
connections.start_connection()
click_cell(2, 2)
canvas.on_click()
eq(connections.connecting ~= nil, true, 'clicking empty space keeps connect mode')
click_cell(12, 6)
canvas.on_click()
eq(connections.connecting ~= nil, true, 'clicking source node keeps connect mode')
connections.cancel_connection()
connections.clear_connection_keymaps(canvas.get_bufnr())

canvas.set_cursor(15, 7)
local rt = canvas.get_cursor_pos()
eq(rt.x, 15, 'set/get cursor round-trips over multibyte line')
eq(rt.y, 7, 'set/get cursor row round-trips')

mouse = { line = 3, column = 9999, coladd = 4 }
canvas.on_click()
eq(canvas.get_cursor_pos().x <= 120, true, 'click past line end clamps to canvas')

print('OK mouse_test')
