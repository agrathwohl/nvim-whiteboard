local M = {}

M.defaults = {
  canvas = {
    width = 120,
    height = 40,
    grid_size = 4,
    show_grid = true,
  },

  ui = {
    toolbar = {
      enabled = true,
      height = 3,
    },
    sidebar = {
      enabled = true,
      width = 25,
    },
    style = {
      border = 'rounded',
      border_highlight = 'FloatBorder',
    },
  },

  shapes = {
    default_style = {
      border = 'single',
    },
    types = {
      box = { icon = '󰝤', label = 'Box' },
      database = { icon = '󰆼', label = 'Database' },
      cloud = { icon = '󰅟', label = 'Cloud' },
      server = { icon = '󰒋', label = 'Server' },
      client = { icon = '󰌢', label = 'Client' },
      api = { icon = '󰌁', label = 'API' },
      service = { icon = '󰆌', label = 'Service' },
      queue = { icon = '󰇙', label = 'Queue' },
      cache = { icon = '󰃨', label = 'Cache' },
      component = { icon = '󰏗', label = 'Component' },
      class = { icon = '󰠱', label = 'Class' },
      function_ = { icon = '󰊕', label = 'Function' },
      module = { icon = '󰆧', label = 'Module' },
      package = { icon = '󰏓', label = 'Package' },
      router = { icon = '󰑩', label = 'Router' },
      firewall = { icon = '󰒘', label = 'Firewall' },
      switch = { icon = '󰇄', label = 'Switch' },
      load_balancer = { icon = '󰿏', label = 'Load Balancer' },
    },
  },

  connections = {
    styles = {
      solid = { char = '─', arrow = '▶' },
      dashed = { char = '┄', arrow = '▷' },
      dotted = { char = '┈', arrow = '→' },
      bold = { char = '━', arrow = '▶' },
    },
    default_style = 'solid',
  },

  keymaps = {
    move_up = '<Up>',
    move_down = '<Down>',
    move_left = '<Left>',
    move_right = '<Right>',
    move_up_alt = 'k',
    move_down_alt = 'j',
    move_left_alt = 'h',
    move_right_alt = 'l',

    move_fast_up = '<C-Up>',
    move_fast_down = '<C-Down>',
    move_fast_left = '<C-Left>',
    move_fast_right = '<C-Right>',

    add_node = '<CR>',
    quick_add = 'a',
    delete_node = '<Del>',
    delete_connection = 'D',
    duplicate = '<C-d>',
    edit_text = '<C-e>',
    edit_label = 'E',

    node_up = '<S-Up>',
    node_down = '<S-Down>',
    node_left = '<S-Left>',
    node_right = '<S-Right>',
    node_up_alt = 'K',
    node_down_alt = 'J',
    node_left_alt = 'H',
    node_right_alt = 'L',

    resize_wider = '>',
    resize_narrower = '<',
    resize_taller = '=',
    resize_shorter = '-',

    start_connect = 'c',
    cancel_connect = '<Esc>',

    undo = 'u',

    toggle_grid = 'g',
    save = '<C-s>',
    close = '<C-q>',
  },

  save_directory = vim.fn.stdpath('data') .. '/whiteboard',

  export = {
    svg = {
      cell_width = 8,
      cell_height = 16,
      font_family = 'monospace',
      font_size = 14,
    },
    plantuml = {
      skinparam = true,
    },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
end

return M
