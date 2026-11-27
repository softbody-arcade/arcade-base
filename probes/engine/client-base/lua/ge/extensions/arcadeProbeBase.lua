local M = {}

local GAME = "arcadeProbeGame"

local function say(text)
  log("I", "arcadeProbe", "[arcade-probe] " .. text)
end

function M.loadGame()
  local ok, err = pcall(extensions.load, GAME)
  say("load ok=" .. tostring(ok and extensions[GAME] ~= nil) .. (ok and "" or (" error=" .. tostring(err))))
end

function M.unloadGame()
  local ok, err = pcall(extensions.unload, GAME)
  say("unload ok=" .. tostring(ok) .. (ok and "" or (" error=" .. tostring(err))))
end

function M.ping()
  extensions.hook("onArcadeProbePing")
  say("ping sent")
end

function M.show(fields)
  guihooks.trigger("ArcadeProbe", fields or {})
end

function M.snapshot(fields)
  guihooks.trigger("ArcadeProbeSnapshot", fields or {})
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  return keys
end

local function findVersions(list)
  local found = {}
  for key, mod in pairs(list) do
    if type(mod) == "table" then
      local name = tostring(mod.modname or mod.name or key)
      local data = type(mod.modData) == "table" and mod.modData or mod
      local version = data.version_string or data.version or mod.version_string or mod.version
      local lower = name:lower()
      local which = (lower:sub(-15) == "arcadeprobegame" and "game") or (lower:sub(-11) == "arcadeprobe" and "base") or nil
      if which then
        local evidence = (mod.active == true and "active") or (mod.mounted == true and "mounted") or ((mod.active == false or mod.mounted == false) and "inactive") or "unknown"
        say("mod " .. name .. " as=" .. which .. " evidence=" .. evidence .. " version=" .. tostring(version) .. " fields=" .. table.concat(sortedKeys(mod), ","))
        if evidence == "active" or evidence == "mounted" then
          found[which] = tostring(version)
        elseif evidence == "unknown" and found[which] == nil then
          found[which] = "unconfirmed " .. tostring(version)
        end
      end
    end
  end
  return found
end

local function fileVersion(path)
  if not FS:fileExists(path) then return "missing" end
  local ok, data = pcall(jsonReadFile, path)
  if ok and type(data) == "table" and data.version_string then return tostring(data.version_string) end
  return "unreadable"
end

function M.versions()
  local report = { base = "missing", game = "missing", source = "none" }
  local mm = core_modmanager
  if type(mm) ~= "table" then
    say("modmanager keys=missing")
  else
    say("modmanager keys=" .. table.concat(sortedKeys(mm), ","))
    for _, key in ipairs(sortedKeys(mm)) do
      local fn = mm[key]
      local info = type(fn) == "function" and debug.getinfo(fn, "u") or nil
      if info and key:sub(1, 3) == "get" and (info.nparams or 0) == 0 then
        local ok, result = pcall(fn)
        local size = type(result) == "table" and #sortedKeys(result) or "-"
        say("modmanager " .. key .. " ok=" .. tostring(ok) .. " type=" .. type(result) .. " count=" .. tostring(size))
        if ok and type(result) == "table" and report.source == "none" then
          local found = findVersions(result)
          if next(found) then
            report.source = key
            report.base = found.base or "missing"
            report.game = found.game or "missing"
          end
        end
      end
    end
  end
  report.base_file = fileVersion("/mod_info/ArcadeProbe/info.json")
  report.game_file = fileVersion("/mod_info/ArcadeProbeGame/info.json")
  local body = jsonEncode(report)
  if TriggerServerEvent then
    TriggerServerEvent("arcadeProbeVersions", body)
    say("versions sent " .. body)
  else
    say("versions not sent (no TriggerServerEvent) " .. body)
  end
end

function M.onWorldReadyState(st)
  if st == 2 then M.versions() end
end

return M
