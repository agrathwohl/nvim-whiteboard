local M = {}

function M.microservice(node)
  return {
    icon = '⚙️',
    template = [[
  ┌─────────────┐
  │  ⚙️ SERVICE │
  │  ${text}    │
  └─────────────┘
    ]],
  }
end

function M.container(node)
  return {
    icon = '📦',
    template = [[
  ┌────────────────┐
  │ 📦 CONTAINER   │
  │ ${text}        │
  └────────────────┘
    ]],
  }
end

function M.pod(node)
  return {
    icon = '🔷',
    template = [[
    ╭───────────╮
    │ 🔷 POD    │
    │ ${text}   │
    ╰───────────╯
    ]],
  }
end

return M
