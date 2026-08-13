local wb = require('whiteboard')
local canvas = require('whiteboard.canvas')
local nodes = require('whiteboard.nodes')
local connections = require('whiteboard.connections')
local history = require('whiteboard.history')
local ui = require('whiteboard.ui')

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

local function close_edit_popup()
  local cur = vim.api.nvim_get_current_win()
  if cur ~= canvas.get_winnr() then
    vim.cmd('stopinsert')
    vim.api.nvim_win_close(cur, true)
    vim.api.nvim_set_current_win(canvas.get_winnr())
  end
end

wb.setup({ ui = { toolbar = { enabled = false }, sidebar = { enabled = false } } })
wb.open('undo-test')

ui.selected_shape = 'box'
canvas.move_cursor(4, 4)
nodes.add_at_cursor(false)
close_edit_popup()
eq(count(nodes.nodes), 1, 'node added')
eq(#history.stack, 1, 'add recorded')

local id = nodes.sorted()[1].id
canvas.move_cursor(2, 2)
nodes.move_at_cursor(1, 0)
nodes.move_at_cursor(1, 0)
nodes.move_at_cursor(1, 0)
eq(#history.stack, 2, 'moves coalesced into one step')
eq(nodes.get_by_id(id).x, 8, 'node moved')

canvas.move_cursor(1, 0)
nodes.resize_at_cursor(2, 0)
eq(#history.stack, 3, 'resize recorded as new step')
local w = nodes.get_by_id(id).width

history.undo()
eq(nodes.get_by_id(id).width, w - 2, 'resize undone')
history.undo()
eq(nodes.get_by_id(id).x, 5, 'coalesced move undone in one step')
eq(#history.stack, 1, 'stack unwound')

vim.ui.input = function(_, cb)
  cb('hello')
end
nodes.edit_label_at_cursor()
eq(nodes.get_by_id(id).label, 'hello', 'label set')
eq(#history.stack, 2, 'label edit recorded')
nodes.edit_label_at_cursor()
eq(#history.stack, 2, 'unchanged label not recorded')

canvas.move_cursor(40, 0)
nodes.add_at_cursor(false)
close_edit_popup()
local id2 = nil
for _, n in ipairs(nodes.sorted()) do
  if n.id ~= id then
    id2 = n.id
  end
end
eq(#history.stack, 3, 'second add recorded')

canvas.move_cursor(-40, 0)
connections.start_connection()
canvas.move_cursor(40, 0)
connections.complete_connection()
connections.clear_connection_keymaps(canvas.get_bufnr())
eq(count(connections.connections), 1, 'connection created')
eq(#history.stack, 4, 'connection recorded')

nodes.delete_at_cursor()
eq(count(nodes.nodes), 1, 'node deleted')
eq(count(connections.connections), 0, 'connections removed with node')
history.undo()
eq(count(nodes.nodes), 2, 'deleted node restored')
eq(count(connections.connections), 1, 'connection restored with node')
eq(nodes.get_by_id(id2).text ~= nil, true, 'restored node intact')

while #history.stack > 0 do
  history.undo()
end
eq(count(nodes.nodes), 0, 'undo to empty board')
history.undo()
eq(count(nodes.nodes), 0, 'undo on empty stack is a no-op')

history.record()
eq(#history.stack, 1, 'stack refilled')
wb.open('other-board')
eq(#history.stack, 0, 'history cleared on open')

print('OK undo_test')
