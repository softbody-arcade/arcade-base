local here = arg[0]:match("^(.*)/tests/") or "."
local source = here .. "/client-base/lua/ge/extensions/arcadeProbeBase.lua"

local failures = 0
local function check(name, ok)
  print((ok and "ok   " or "FAIL ") .. name)
  if not ok then failures = failures + 1 end
end

local function encode(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(t[k]) end
  return table.concat(parts, ";")
end

local function run(modList, extraGetters)
  local sent
  local calledWithArg = false
  log = function() end
  FS = { fileExists = function() return false end }
  jsonReadFile = function() return nil end
  jsonEncode = function(t) sent = t return encode(t) end
  TriggerServerEvent = function() end
  core_modmanager = {
    getModList = function() return modList end,
    getModFromPath = function(path)
      calledWithArg = true
      return {}
    end,
  }
  for k, v in pairs(extraGetters or {}) do core_modmanager[k] = v end
  local M = dofile(source)
  M.versions()
  return sent, calledWithArg
end

local report = run({
  multiplayerarcadeprobe = { modname = "multiplayerarcadeprobe", active = true, modData = { version_string = "0.0.1" } },
  multiplayerarcadeprobegame = { modname = "multiplayerarcadeprobegame", active = true, modData = { version_string = "0.0.2" } },
})
check("BeamMP-prefixed mod names report base 0.0.1", report.base == "0.0.1")
check("BeamMP-prefixed mod names report game 0.0.2", report.game == "0.0.2")
check("the reading names its getter", report.source == "getModList")

report = run({
  arcadeprobe = { modname = "arcadeprobe", active = true, modData = { version_string = "0.0.1" } },
  arcadeprobegame = { modname = "arcadeprobegame", modData = { version_string = "0.0.2" } },
})
check("a record without activation evidence is not reported as installed", report.game ~= "0.0.2" and report.game:find("unconfirmed", 1, true) ~= nil)
check("an active base is still reported", report.base == "0.0.1")

report = run({
  arcadeprobe = { modname = "arcadeprobe", mounted = true, modData = { version_string = "0.0.1" } },
  arcadeprobegame = { modname = "arcadeprobegame", active = false, modData = { version_string = "0.0.2" } },
})
check("a mounted record counts as installed", report.base == "0.0.1")
check("an inactive record reports missing", report.game == "missing")

local _, calledWithArg = run({})
check("getters that take parameters are not called", not calledWithArg)

local varargCalled = false
run({}, { getAnything = function(...) varargCalled = true return {} end })
check("getters with variadic parameters are not called", not varargCalled)

report = run({
  arcadeprobe = { modname = "arcadeprobe", modData = { version_string = "0.0.1" } },
}, {
  getZList = function()
    return {
      arcadeprobe = { modname = "arcadeprobe", active = true, modData = { version_string = "0.0.1" } },
      arcadeprobegame = { modname = "arcadeprobegame", active = true, modData = { version_string = "0.0.2" } },
    }
  end,
})
check("a later getter's confirmed versions win over an earlier unconfirmed one", report.base == "0.0.1" and report.game == "0.0.2")

report = run({
  arcadeprobe = { modname = "arcadeprobe", active = true },
}, {
  getZList = function()
    return { arcadeprobe = { modname = "arcadeprobe", active = true, modData = { version_string = "0.0.1" } } }
  end,
})
check("an active record without a version doesn't hide a versioned one", report.base == "0.0.1")

report = run({
  arcadeprobe = { modname = "arcadeprobe", active = true, modData = { version_string = "0.0.1" } },
  myarcadeprobegame = { modname = "myarcadeprobegame", active = true, modData = { version_string = "0.0.2" } },
})
check("an unrelated mod whose name ends like a probe is ignored", report.game == "missing")

if failures > 0 then
  print(failures .. " version checks failed")
  os.exit(1)
end
print("all version checks passed")
