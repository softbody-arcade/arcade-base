local collect = require("arcade_probe.collect").collect

ArcadeProbeState = ArcadeProbeState or { inits = 0, loads = 0, round = nil, reports = 0 }
local state = ArcadeProbeState

local function log(text)
  print("[arcade-probe] " .. text)
end

local function count(registry)
  local n = 0
  for _ in pairs(registry or {}) do n = n + 1 end
  return n
end

local function registryText()
  if ArcadeProbeGames == nil then return "nil" end
  return "visible"
end

local function looseCheck()
  local entry = "Resources/Server/ArcadeProbeLoose/?.lua"
  if not package.path:find(entry, 1, true) then
    package.path = entry .. ";" .. package.path
  end
  local ok, mod = pcall(require, "arcade_probe_loose.rules")
  local hello
  if ok then
    local called, value = pcall(mod.hello)
    hello = tostring(value)
    ok = called
  else
    hello = tostring(mod)
  end
  log("loose ok=" .. tostring(ok) .. " hello=" .. hello)
end

local function moduleOf(id)
  local entry = (ArcadeProbeGames or {})[id]
  return entry and entry.module
end

local function callRule(fresh)
  local round = state.round
  if not round then
    log("rule none")
    return
  end
  local module = moduleOf(round.rule)
  if not module then
    log("rule " .. tostring(round.rule) .. " has no module")
    return
  end
  if fresh then package.loaded[module] = nil end
  local ok, value = pcall(function() return require(module).hello() end)
  log("rule" .. (fresh and " fresh" or "") .. " ok=" .. tostring(ok) .. " value=" .. tostring(value))
end

state.loads = state.loads + 1
log("base loaded loads=" .. state.loads .. " registry=" .. registryText() .. " games=" .. count(ArcadeProbeGames))
looseCheck()

function onInit()
  state.inits = state.inits + 1
  log("onInit inits=" .. state.inits .. " loads=" .. state.loads .. " registry=" .. registryText() .. " games=" .. count(ArcadeProbeGames))
  for _, item in ipairs(collect(ArcadeProbeGames)) do
    local ok, value = pcall(function() return require(item.module).hello() end)
    log("shared require " .. item.id .. " ok=" .. tostring(ok) .. " hello=" .. tostring(value))
  end
  log("package.path=" .. package.path)
end

function arcadeProbeOnFileChanged(path)
  log("file changed " .. tostring(path))
  local game = tostring(path):match("arcade_probe_(%w+)/rules%.lua$")
  if game then
    local module = "arcade_probe_" .. game .. ".rules"
    package.loaded[module] = nil
    log("cache cleared " .. module)
  end
end

local commands = {
  ["/probe start"] = function()
    local first = collect(ArcadeProbeGames)[1]
    state.round = { id = os.time(), rule = first and first.id }
    log("round started id=" .. state.round.id .. " rule=" .. tostring(state.round.rule))
  end,
  ["/probe state"] = function()
    local round = state.round
    log("state round=" .. (round and (round.id .. " rule=" .. tostring(round.rule)) or "none") .. " inits=" .. state.inits .. " loads=" .. state.loads)
  end,
  ["/probe rule"] = function() callRule(false) end,
  ["/probe rule fresh"] = function() callRule(true) end,
  ["/probe loose"] = looseCheck,
  ["/probe versions"] = function() log("versions reports=" .. state.reports) end,
}

function arcadeProbeOnChat(pid, name, message)
  local command = commands[message]
  if not command then return 0 end
  command()
  return 1
end

function arcadeProbeOnVersions(pid, body)
  state.reports = state.reports + 1
  log("versions from " .. tostring(MP.GetPlayerName(pid)) .. ": " .. tostring(body))
end

MP.RegisterEvent("onChatMessage", "arcadeProbeOnChat")
MP.RegisterEvent("onFileChanged", "arcadeProbeOnFileChanged")
MP.RegisterEvent("arcadeProbeVersions", "arcadeProbeOnVersions")
