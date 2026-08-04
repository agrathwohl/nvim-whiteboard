" nvim-whiteboard - Diagramming plugin for Neovim
" Homepage: https://github.com/agrathwohl/nvim-whiteboard

if exists('g:loaded_whiteboard')
  finish
endif
let g:loaded_whiteboard = 1

highlight default link WhiteboardBorder FloatBorder
highlight default link WhiteboardTitle Title
highlight default link WhiteboardNode Normal
highlight default link WhiteboardConnection Comment
highlight default link WhiteboardGrid NonText
highlight default link WhiteboardSelected Visual

lua require('whiteboard').setup()
