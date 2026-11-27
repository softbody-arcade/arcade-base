local M = {}

local frames, elapsed, pings, uiPings = 0, 0, 0, 0

local function say(text)
  log("I", "arcadeProbe", "[arcade-probe] " .. text)
end

function M.onUpdate(dtReal)
  frames = frames + 1
  elapsed = elapsed + (dtReal or 0)
  if elapsed >= 1 then
    elapsed = 0
    say("game onUpdate n=" .. frames)
  end
end

function M.onArcadeProbePing()
  pings = pings + 1
  say("game ping n=" .. pings)
end

function M.uiPing()
  uiPings = uiPings + 1
  say("game ui ping n=" .. uiPings)
end

function M.onExtensionUnloaded()
  say("game unloaded")
end

return M
