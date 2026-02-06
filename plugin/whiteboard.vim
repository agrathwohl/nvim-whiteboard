" nvim-whiteboard - Diagramming plugin for Neovim
" Maintainer: Your Name
" Version: 0.1.0

if exists('g:loaded_whiteboard')
  finish
endif
let g:loaded_whiteboard = 1

" Define default highlight groups
highlight default link WhiteboardBorder FloatBorder
highlight default link WhiteboardTitle Title
highlight default link WhiteboardNode Normal
highlight default link WhiteboardConnection Comment
highlight default link WhiteboardGrid Comment
highlight default link WhiteboardSelected Visual

" Initialize plugin
lua require('whiteboard').setup()
