local M = {}

function M.collect(registry)
  local list = {}
  for id, entry in pairs(registry or {}) do
    list[#list + 1] = { id = id, module = entry.module, version = entry.version }
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

return M
