if exists('b:current_syntax')
  finish
endif

syntax match WhiteboardGrid /·/
syntax match WhiteboardConnection /[─━┄┈│▶◀▲▼→]/

let b:current_syntax = 'whiteboard'
