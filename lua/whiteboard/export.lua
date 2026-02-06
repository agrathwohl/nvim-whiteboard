local M = {}
local nodes = require('whiteboard.nodes')
local connections = require('whiteboard.connections')
local config = require('whiteboard.config')

function M.export(format)
  if format == 'ascii' then
    return M.export_ascii()
  elseif format == 'svg' then
    return M.export_svg()
  elseif format == 'plantuml' then
    return M.export_plantuml()
  elseif format == 'mermaid' then
    return M.export_mermaid()
  else
    vim.notify('Unknown export format: ' .. format, vim.log.levels.ERROR)
    return nil
  end
end

function M.export_ascii()
  local canvas_width = config.options.canvas.width
  local canvas_height = config.options.canvas.height
  local grid = {}
  
  -- Initialize empty grid
  for y = 1, canvas_height do
    grid[y] = {}
    for x = 1, canvas_width do
      grid[y][x] = ' '
    end
  end
  
  -- Draw nodes
  for _, node in pairs(nodes.get_all()) do
    M.draw_node_to_grid(grid, node)
  end
  
  -- Draw connections
  for _, conn in pairs(connections.get_all()) do
    M.draw_connection_to_grid(grid, conn)
  end
  
  -- Convert to string
  local lines = {}
  for y = 1, canvas_height do
    local line = ''
    for x = 1, canvas_width do
      line = line .. grid[y][x]
    end
    table.insert(lines, line)
  end
  
  -- Save to file
  local filename = config.options.save_directory .. '/' .. require('whiteboard.canvas').get_name() .. '.txt'
  local file = io.open(filename, 'w')
  if file then
    file:write(table.concat(lines, '\n'))
    file:close()
    vim.notify('Exported to ASCII: ' .. filename, vim.log.levels.INFO)
  end
  
  return lines
end

function M.draw_node_to_grid(grid, node)
  local x, y = node.x, node.y
  local width, height = node.width, node.height
  
  -- Draw border
  for i = 0, width - 1 do
    if y > 0 and y <= #grid and x + i > 0 and x + i <= #grid[1] then
      grid[y][x + i] = '─'
      if y + height - 1 > 0 and y + height - 1 <= #grid then
        grid[y + height - 1][x + i] = '─'
      end
    end
  end
  
  for i = 0, height - 1 do
    if y + i > 0 and y + i <= #grid and x > 0 and x <= #grid[1] then
      grid[y + i][x] = '│'
      if x + width - 1 > 0 and x + width - 1 <= #grid[1] then
        grid[y + i][x + width - 1] = '│'
      end
    end
  end
  
  -- Corners
  if y > 0 and y <= #grid and x > 0 and x <= #grid[1] then
    grid[y][x] = '┌'
    if x + width - 1 > 0 and x + width - 1 <= #grid[1] then
      grid[y][x + width - 1] = '┐'
    end
  end
  
  if y + height - 1 > 0 and y + height - 1 <= #grid then
    if x > 0 and x <= #grid[1] then
      grid[y + height - 1][x] = '└'
    end
    if x + width - 1 > 0 and x + width - 1 <= #grid[1] then
      grid[y + height - 1][x + width - 1] = '┘'
    end
  end
  
  -- Draw text
  local text_lines = require('whiteboard.utils').wrap_text(node.text, width - 2)
  for i, text in ipairs(text_lines) do
    local row = y + i
    if row > 0 and row < y + height - 1 and row <= #grid then
      for j = 1, #text do
        local col = x + j
        if col > 0 and col < x + width - 1 and col <= #grid[1] then
          grid[row][col] = text:sub(j, j)
        end
      end
    end
  end
end

function M.draw_connection_to_grid(grid, conn)
  local from_node = nodes.get_by_id(conn.from)
  local to_node = nodes.get_by_id(conn.to)
  
  if not from_node or not to_node then return end
  
  local x1 = from_node.x + math.floor(from_node.width / 2)
  local y1 = from_node.y + math.floor(from_node.height / 2)
  local x2 = to_node.x + math.floor(to_node.width / 2)
  local y2 = to_node.y + math.floor(to_node.height / 2)
  
  -- Simple line
  if x1 == x2 then
    -- Vertical line
    for y = math.min(y1, y2), math.max(y1, y2) do
      if y > 0 and y <= #grid and x1 > 0 and x1 <= #grid[1] then
        grid[y][x1] = '│'
      end
    end
  else
    -- Horizontal line with vertical segment
    local mid_x = math.floor((x1 + x2) / 2)
    
    for x = math.min(x1, mid_x), math.max(x1, mid_x) do
      if y1 > 0 and y1 <= #grid and x > 0 and x <= #grid[1] then
        grid[y1][x] = '─'
      end
    end
    
    for x = math.min(mid_x, x2), math.max(mid_x, x2) do
      if y2 > 0 and y2 <= #grid and x > 0 and x <= #grid[1] then
        grid[y2][x] = '─'
      end
    end
    
    for y = math.min(y1, y2), math.max(y1, y2) do
      if y > 0 and y <= #grid and mid_x > 0 and mid_x <= #grid[1] then
        grid[y][mid_x] = '│'
      end
    end
  end
end

function M.export_svg()
  local svg_options = config.options.export.svg
  local width = svg_options.width
  local height = svg_options.height
  
  local svg = {}
  table.insert(svg, '<?xml version="1.0" encoding="UTF-8"?>')
  table.insert(svg, '<svg width="' .. width .. '" height="' .. height .. '" xmlns="http://www.w3.org/2000/svg">')
  table.insert(svg, '  <defs>')
  table.insert(svg, '    <style>')
  table.insert(svg, '      .node { fill: #f0f0f0; stroke: #333; stroke-width: 2; }')
  table.insert(svg, '      .text { font-family: ' .. svg_options.font_family .. '; font-size: ' .. svg_options.font_size .. 'px; }')
  table.insert(svg, '      .connection { stroke: #666; stroke-width: 2; fill: none; }')
  table.insert(svg, '    </style>')
  table.insert(svg, '  </defs>')
  
  -- Draw connections
  for _, conn in pairs(connections.get_all()) do
    local from_node = nodes.get_by_id(conn.from)
    local to_node = nodes.get_by_id(conn.to)
    
    if from_node and to_node then
      local x1 = from_node.x * 8
      local y1 = from_node.y * 16
      local x2 = to_node.x * 8
      local y2 = to_node.y * 16
      
      table.insert(svg, string.format('  <line x1="%d" y1="%d" x2="%d" y2="%d" class="connection" />',
        x1, y1, x2, y2))
    end
  end
  
  -- Draw nodes
  for _, node in pairs(nodes.get_all()) do
    local x = node.x * 8
    local y = node.y * 16
    local w = node.width * 8
    local h = node.height * 16
    
    table.insert(svg, string.format('  <rect x="%d" y="%d" width="%d" height="%d" class="node" />',
      x, y, w, h))
    table.insert(svg, string.format('  <text x="%d" y="%d" class="text" text-anchor="middle">%s</text>',
      x + w / 2, y + h / 2 + 5, node.text:gsub('<', '&lt;'):gsub('>', '&gt;')))
  end
  
  table.insert(svg, '</svg>')
  
  -- Save
  local filename = config.options.save_directory .. '/' .. require('whiteboard.canvas').get_name() .. '.svg'
  local file = io.open(filename, 'w')
  if file then
    file:write(table.concat(svg, '\n'))
    file:close()
    vim.notify('Exported to SVG: ' .. filename, vim.log.levels.INFO)
  end
  
  return table.concat(svg, '\n')
end

function M.export_plantuml()
  local puml = {}
  
  table.insert(puml, '@startuml')
  
  if config.options.export.plantuml.skinparam then
    table.insert(puml, 'skinparam backgroundColor #FEFEFE')
    table.insert(puml, 'skinparam componentStyle rectangle')
  end
  
  -- Define nodes
  for id, node in pairs(nodes.get_all()) do
    local shape_type = node.shape or 'component'
    local line = string.format('%s "%s" as node%d', shape_type:gsub('_', ''), node.text, id)
    table.insert(puml, line)
  end
  
  -- Define connections
  for _, conn in pairs(connections.get_all()) do
    local line = string.format('node%d --> node%d', conn.from, conn.to)
    if conn.label and conn.label ~= '' then
      line = line .. ' : ' .. conn.label
    end
    table.insert(puml, line)
  end
  
  table.insert(puml, '@enduml')
  
  -- Save
  local filename = config.options.save_directory .. '/' .. require('whiteboard.canvas').get_name() .. '.puml'
  local file = io.open(filename, 'w')
  if file then
    file:write(table.concat(puml, '\n'))
    file:close()
    vim.notify('Exported to PlantUML: ' .. filename, vim.log.levels.INFO)
  end
  
  return table.concat(puml, '\n')
end

function M.export_mermaid()
  local mmd = {}
  
  table.insert(mmd, 'graph TD')
  
  -- Define nodes
  for id, node in pairs(nodes.get_all()) do
    local shape = node.shape or 'box'
    local node_id = 'node' .. id
    
    local line
    if shape == 'database' then
      line = string.format('%s[("%s")]', node_id, node.text)
    elseif shape == 'cloud' then
      line = string.format('%s{"%s"}', node_id, node.text)
    else
      line = string.format('%s["%s"]', node_id, node.text)
    end
    
    table.insert(mmd, '    ' .. line)
  end
  
  -- Define connections
  for _, conn in pairs(connections.get_all()) do
    local from_id = 'node' .. conn.from
    local to_id = 'node' .. conn.to
    local line = string.format('%s -->|%s| %s', from_id, conn.label or '', to_id)
    table.insert(mmd, '    ' .. line)
  end
  
  -- Save
  local filename = config.options.save_directory .. '/' .. require('whiteboard.canvas').get_name() .. '.mmd'
  local file = io.open(filename, 'w')
  if file then
    file:write(table.concat(mmd, '\n'))
    file:close()
    vim.notify('Exported to Mermaid: ' .. filename, vim.log.levels.INFO)
  end
  
  return table.concat(mmd, '\n')
end

return M
