local M = {}

M.defaults = {
  -- Canvas settings
  canvas = {
    width = 120,
    height = 40,
    grid_size = 2,
    show_grid = true,
    background = 'Normal',
  },
  
  -- UI settings
  ui = {
    toolbar = {
      enabled = true,
      position = 'top',
      height = 3,
    },
    sidebar = {
      enabled = true,
      position = 'left',
      width = 25,
    },
    -- Modern styling
    style = {
      border = 'rounded',
      title_highlight = 'Title',
      border_highlight = 'FloatBorder',
      selected_highlight = 'Visual',
    }
  },
  
  -- Shape styles
  shapes = {
    default_style = {
      border = 'single',
      padding = 1,
    },
    -- Predefined shape types with icons
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
    }
  },
  
  -- Connection styles
  connections = {
    styles = {
      solid = { char = '─', corner = '┌', arrow = '▶' },
      dashed = { char = '┄', corner = '╌', arrow = '▷' },
      dotted = { char = '·', corner = '·', arrow = '→' },
      bold = { char = '━', corner = '┏', arrow = '▶' },
    },
    default_style = 'solid',
    labels = {
      enabled = true,
      position = 'middle',
    }
  },
  
  -- Keymaps
  keymaps = {
    -- Mode toggles
    normal_mode = 'n',
    insert_mode = 'i',
    visual_mode = 'v',
    connect_mode = 'c',
    
    -- Navigation (arrows move cursor, Ctrl+arrows fast move, Shift+arrows move node)
    move_up = '<Up>',
    move_down = '<Down>',
    move_left = '<Left>',
    move_right = '<Right>',
    
    -- Actions
    add_node = '<CR>',
    delete_node = '<Del>',
    edit_text = '<C-e>',
    duplicate = '<C-d>',
    select = '<Space>',
    
    -- Connection
    start_connect = 'c',
    cancel_connect = '<Esc>',
    
    -- Node resize (> < for width, = - for height)
    resize_wider = '>',
    resize_narrower = '<',
    resize_taller = '=',
    resize_shorter = '-',

    -- Canvas
    toggle_grid = 'g',
    center_view = 'zz',
    
    -- UI
    toggle_toolbar = '<leader>t',
    toggle_sidebar = '<leader>s',
    
    -- File
    save = '<C-s>',
    close = '<C-q>',
  },
  
  -- Save settings
  save_directory = vim.fn.stdpath('data') .. '/whiteboard',
  autosave = false,
  autosave_interval = 300000, -- 5 minutes
  
  -- Export settings
  export = {
    ascii = {
      compact = false,
      use_unicode = true,
    },
    svg = {
      width = 800,
      height = 600,
      font_family = 'monospace',
      font_size = 14,
    },
    plantuml = {
      skinparam = true,
    }
  }
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
  
  -- Ensure save directory exists
  vim.fn.mkdir(M.options.save_directory, 'p')
end

return M
