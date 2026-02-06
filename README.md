# nvim-whiteboard

A powerful, modern diagramming plugin for Neovim designed for systems design, code architecture, and network diagrams.

## Features

- 🎨 **Modern GUI** - Beautiful floating windows with customizable styling
- 📐 **Multiple Shape Types** - Predefined shapes for systems, networks, and code architecture
- 🔗 **Connection System** - Easy node linking with multiple connection styles
- 💾 **Save & Load** - Persist your diagrams
- 📤 **Export** - Export to ASCII, SVG, PlantUML, and Mermaid
- ⌨️ **Keyboard-Driven** - Efficient vim-like workflow
- ⚙️ **Highly Configurable** - Sane defaults with full customization

## Installation

### Using Nix (recommended)

Add to your flake.nix:

```nix
{
  inputs.nvim-whiteboard.url = "path:~/flakes/dctec/nvim-whiteboard";
  
  outputs = { self, nixpkgs, nixvim, nvim-whiteboard }: {
    # In your nixvim configuration
    programs.nixvim = {
      imports = [ nvim-whiteboard.nixvimModules.default ];
      
      plugins.whiteboard = {
        enable = true;
        settings = {
          # Your configuration here
        };
      };
    };
  };
}
```

### Using Packer

```lua
use {
  'yourusername/nvim-whiteboard',
  config = function()
    require('whiteboard').setup()
  end
}
```

### Using lazy.nvim

```lua
{
  'yourusername/nvim-whiteboard',
  config = function()
    require('whiteboard').setup()
  end
}
```

## Usage

### Commands

- `:Whiteboard [name]` - Open or create a whiteboard
- `:WhiteboardSave [name]` - Save current whiteboard
- `:WhiteboardExport {format}` - Export diagram (ascii, svg, plantuml, mermaid)
- `:WhiteboardClose` - Close whiteboard

### Default Keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Add node at cursor |
| `<Del>` | Delete node at cursor |
| `<C-e>` | Edit node text |
| `c` | Start connection mode |
| `<Esc>` | Cancel connection |
| `+`/`-` | Zoom in/out |
| `g` | Toggle grid |
| `<C-s>` | Save |
| `<C-q>` | Close |

### Available Shapes

- **Systems**: box, database, cloud, server, client, api, service, queue, cache
- **Network**: router, firewall, switch, load_balancer
- **Code**: class, module, function, component, package, interface

## Configuration

```lua
require('whiteboard').setup({
  canvas = {
    width = 120,
    height = 40,
    show_grid = true,
  },
  ui = {
    toolbar = { enabled = true, position = 'top' },
    sidebar = { enabled = true, position = 'left' },
    style = {
      border = 'rounded',
    },
  },
  keymaps = {
    add_node = '<CR>',
    delete_node = '<Del>',
    -- ... customize as needed
  },
})
```

## License

MIT
