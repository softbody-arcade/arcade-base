package.path = "probes/engine/server/ArcadeProbeBase/?.lua;" .. package.path
local collect = require("arcade_probe.collect").collect

local function ids(list)
  local out = {}
  for i, item in ipairs(list) do out[i] = item.id end
  return table.concat(out, ",")
end

local registry = { zgame = { module = "a", version = "1" }, agame = { module = "b", version = "2" } }
local first = collect(registry)
assert(ids(first) == "agame,zgame", "sorted by id: " .. ids(first))
assert(first[1].module == "b" and first[1].version == "2", "fields kept")
local second = collect(registry)
assert(ids(second) == ids(first) and #second == #first, "a second call gives an equal list")
assert(#collect(nil) == 0, "nil registry gives an empty list")
assert(#collect({}) == 0, "empty registry gives an empty list")
print("collect ok")
