local M = {}
local nodes = require('whiteboard.nodes')
local connections = require('whiteboard.connections')
local config = require('whiteboard.config')

M.formats = { 'ascii', 'svg', 'plantuml', 'mermaid' }

local function target_path(extension)
  local name = require('whiteboard.canvas').get_name()
  return config.options.save_directory .. '/' .. name .. '.' .. extension
end

local function write_file(path, contents)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')

  local file, err = io.open(path, 'w')
  if not file then
    vim.notify('Export failed: ' .. (err or path), vim.log.levels.ERROR)
    return false
  end

  file:write(contents)
  file:close()
  vim.notify('Exported: ' .. path, vim.log.levels.INFO)
  return true
end

function M.export(format)
  local exporters = {
    ascii = M.export_ascii,
    svg = M.export_svg,
    plantuml = M.export_plantuml,
    mermaid = M.export_mermaid,
  }

  local exporter = exporters[format]
  if not exporter then
    vim.notify('Unknown export format: ' .. tostring(format)
      .. ' (expected: ' .. table.concat(M.formats, ', ') .. ')', vim.log.levels.ERROR)
    return nil
  end

  if vim.tbl_isempty(nodes.nodes) then
    vim.notify('Nothing to export: the whiteboard is empty', vim.log.levels.WARN)
    return nil
  end

  return exporter()
end

function M.export_ascii()
  local renderer = require('whiteboard.renderer')
  local lines = renderer.grid_to_lines(renderer.build_grid())

  for i, line in ipairs(lines) do
    lines[i] = (line:gsub('%s+$', ''))
  end
  while #lines > 0 and lines[#lines] == '' do
    lines[#lines] = nil
  end

  local text = table.concat(lines, '\n')
  write_file(target_path('txt'), text)
  return text
end

local function xml_escape(text)
  return (tostring(text)
    :gsub('&', '&amp;')
    :gsub('<', '&lt;')
    :gsub('>', '&gt;')
    :gsub('"', '&quot;'))
end

function M.export_svg()
  local opts = config.options.export.svg
  local cw = opts.cell_width
  local ch = opts.cell_height
  local width = config.options.canvas.width * cw
  local height = config.options.canvas.height * ch

  local svg = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    string.format('<svg width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">',
      width, height, width, height),
    '  <style>',
    '    .node { fill: #f6f6f6; stroke: #333; stroke-width: 2; }',
    string.format('    .text { font-family: %s; font-size: %dpx; }',
      xml_escape(opts.font_family), opts.font_size),
    '    .connection { stroke: #666; stroke-width: 2; fill: none; }',
    '    .label { font-family: ' .. xml_escape(opts.font_family) .. '; font-size: 11px; fill: #666; }',
    '  </style>',
  }

  local renderer = require('whiteboard.renderer')

  for _, conn in pairs(connections.connections) do
    local from_node = nodes.get_by_id(conn.from)
    local to_node = nodes.get_by_id(conn.to)

    if from_node and to_node then
      local segments = renderer.route(from_node, to_node)

      for _, seg in ipairs(segments) do
        svg[#svg + 1] = string.format(
          '  <line x1="%d" y1="%d" x2="%d" y2="%d" class="connection" />',
          (seg.x1 - 1) * cw, (seg.y1 - 1) * ch, (seg.x2 - 1) * cw, (seg.y2 - 1) * ch)
      end

      if conn.label and conn.label ~= '' then
        local mid = segments[2]
        svg[#svg + 1] = string.format(
          '  <text x="%d" y="%d" class="label" text-anchor="middle">%s</text>',
          math.floor((mid.x1 + mid.x2) / 2 - 1) * cw,
          math.floor((mid.y1 + mid.y2) / 2 - 1) * ch - 4,
          xml_escape(conn.label))
      end
    end
  end

  for _, node in ipairs(nodes.sorted()) do
    local x = (node.x - 1) * cw
    local y = (node.y - 1) * ch
    local w = node.width * cw
    local h = node.height * ch

    svg[#svg + 1] = string.format('  <rect x="%d" y="%d" width="%d" height="%d" rx="4" class="node" />',
      x, y, w, h)
    svg[#svg + 1] = string.format(
      '  <text x="%d" y="%d" class="text" text-anchor="middle">%s</text>',
      x + w / 2, y + h / 2 + opts.font_size / 3, xml_escape(node.text))
  end

  svg[#svg + 1] = '</svg>'

  local text = table.concat(svg, '\n')
  write_file(target_path('svg'), text)
  return text
end

local PLANTUML_ELEMENTS = {
  box = 'rectangle',
  database = 'database',
  cloud = 'cloud',
  server = 'node',
  client = 'actor',
  api = 'interface',
  service = 'component',
  queue = 'queue',
  cache = 'database',
  component = 'component',
  class = 'rectangle',
  function_ = 'component',
  module = 'package',
  package = 'package',
  router = 'node',
  firewall = 'node',
  switch = 'node',
  load_balancer = 'node',
}

local function quoted(text)
  return '"' .. tostring(text):gsub('"', "'"):gsub('\n', ' ') .. '"'
end

function M.export_plantuml()
  local puml = { '@startuml' }

  if config.options.export.plantuml.skinparam then
    puml[#puml + 1] = 'skinparam backgroundColor #FEFEFE'
    puml[#puml + 1] = 'skinparam componentStyle rectangle'
  end

  for _, node in ipairs(nodes.sorted()) do
    puml[#puml + 1] = string.format('%s %s as node%d',
      PLANTUML_ELEMENTS[node.shape] or 'rectangle', quoted(node.text), node.id)
  end

  for _, conn in pairs(connections.connections) do
    local line = string.format('node%d --> node%d', conn.from, conn.to)
    if conn.label and conn.label ~= '' then
      line = line .. ' : ' .. conn.label:gsub('\n', ' ')
    end
    puml[#puml + 1] = line
  end

  puml[#puml + 1] = '@enduml'

  local text = table.concat(puml, '\n')
  write_file(target_path('puml'), text)
  return text
end

function M.export_mermaid()
  local mmd = { 'graph TD' }

  for _, node in ipairs(nodes.sorted()) do
    local label = quoted(node.text)
    local body

    if node.shape == 'database' or node.shape == 'cache' then
      body = string.format('node%d[(%s)]', node.id, label)
    elseif node.shape == 'cloud' then
      body = string.format('node%d{{%s}}', node.id, label)
    elseif node.shape == 'queue' then
      body = string.format('node%d>%s]', node.id, label)
    else
      body = string.format('node%d[%s]', node.id, label)
    end

    mmd[#mmd + 1] = '    ' .. body
  end

  for _, conn in pairs(connections.connections) do
    local label = conn.label or ''
    if label ~= '' then
      mmd[#mmd + 1] = string.format('    node%d -->|%s| node%d',
        conn.from, label:gsub('|', '/'):gsub('\n', ' '), conn.to)
    else
      mmd[#mmd + 1] = string.format('    node%d --> node%d', conn.from, conn.to)
    end
  end

  local text = table.concat(mmd, '\n')
  write_file(target_path('mmd'), text)
  return text
end

return M
