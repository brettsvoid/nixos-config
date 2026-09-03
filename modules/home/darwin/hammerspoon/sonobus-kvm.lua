-- Work around a SonoBus bug exposed by KVM switching.
--
-- When the KVM takes the headset to another machine, SonoBus falls back to
-- "Mac mini Speakers" -- an output-only device. Its input channel group
-- collapses to zero channels and never rebuilds, so when the headset comes
-- back (same CoreAudio UID, full channels, already the system default in and
-- out) SonoBus stays parked on the speakers and sends no microphone audio.
-- Re-picking the device by hand restores the device but not the channel
-- group, which is why it takes two passes through the dropdown to recover.
--
-- SonoBus exposes no option to prevent that fallback -- its entire audio
-- device option set is sample-rate override, drift correction, Bluetooth
-- input and the FX limiter. So the only cure is a restart, which is what
-- this does when the headset reappears.
--
-- The restart uses `--load-setup`, whose setup file carries "any device
-- selection, input mixer setup, and all other options" -- the input mixer
-- being exactly the state that collapses. Create it once, while the mic is
-- actually working, via Save Setup... in SonoBus, saved to SETUP below.

local M = {}

local HEADSET  = "PRO X Wireless Gaming Headset"
local APP      = "SonoBus"
local APP_PATH = "/Applications/SonoBus.app"
local SUPPORT  = os.getenv("HOME") .. "/Library/Application Support/SonoBus"
local SETTINGS = SUPPORT .. "/SonoBus.settings"
local SETUP    = SUPPORT .. "/kvm-headset.sonobus"

-- The KVM re-attaches several USB devices at once and the monitors come back
-- separately, so let the bus settle before deciding the headset has landed.
local SETTLE = 3

local pending
local wasPresent

local function shq(s) return "'" .. s:gsub("'", [['\'']]) .. "'" end

-- NOT under ~/.hammerspoon: the ReloadConfiguration spoon watches that
-- directory, so logging into it would reload the config on every write.
local LOG = os.getenv("HOME") .. "/Library/Logs/sonobus-kvm.log"
local function log(fmt, ...)
  local f = io.open(LOG, "a")
  if not f then return end
  f:write(os.date("%H:%M:%S ") .. string.format(fmt, ...) .. "\n")
  f:close()
end

-- Present *and* offering an input. The headset leaves the device list
-- entirely when the KVM takes it, so a nil lookup is the usual "away" signal;
-- the input check guards against binding to a half-enumerated device.
local function headsetReady()
  local d = hs.audiodevice.findDeviceByName(HEADSET)
  -- hs.audiodevice exposes no channel count; isInputDevice() is the check.
  return d ~= nil and d:isInputDevice()
end

-- Belt and braces alongside --load-setup, and the whole fix when no setup file
-- has been saved yet. SonoBus only writes this file on quit, so it is safe to
-- edit between the kill and the relaunch -- and only then.
local function pinSettings()
  local f = io.open(SETTINGS, "r")
  if not f then return end
  local s = f:read("*a")
  f:close()

  s = s:gsub('audioInputDeviceName="[^"]*"',  'audioInputDeviceName="'  .. HEADSET .. '"')
  s = s:gsub('audioOutputDeviceName="[^"]*"', 'audioOutputDeviceName="' .. HEADSET .. '"')
  -- Without this the relaunch comes up disconnected and the restart is worse
  -- than the bug. SonoBus persists it once set, so this is self-healing.
  s = s:gsub('<PARAM id="reconnectlast" value="[^"]*"/>',
             '<PARAM id="reconnectlast" value="1.0"/>')

  f = io.open(SETTINGS, "w")
  if not f then return end
  f:write(s)
  f:close()
end

function M.restartNow()
  -- SIGKILL, not a clean quit: a clean quit would persist whatever broken
  -- fallback device SonoBus is currently sitting on.
  hs.execute("/usr/bin/pkill -9 -x " .. APP)
  hs.timer.doAfter(1, function()
    pinSettings()
    local cmd = "/usr/bin/open -a " .. shq(APP_PATH)
    if hs.fs.attributes(SETUP) then
      cmd = cmd .. " --args --load-setup " .. shq(SETUP)
    else
      hs.notify.new({
        title = "SonoBus restarted",
        informativeText = "No setup file yet -- use Save Setup... to create kvm-headset.sonobus",
      }):send()
    end
    hs.execute(cmd)
  end)
end

local function onDeviceChange(event)
  local present = headsetReady()
  log("event=%s present=%s was=%s sonobus=%s",
      tostring(event), tostring(present), tostring(wasPresent),
      tostring(hs.application.get(APP) ~= nil))
  if present and not wasPresent then
    log("  -> arrival detected, scheduling restart in %ds", SETTLE)
    if pending then pending:stop() end
    pending = hs.timer.doAfter(SETTLE, function()
      pending = nil
      -- Left alone if SonoBus is not running: closing it is a deliberate act.
      if headsetReady() and hs.application.get(APP) then
        log("  -> firing restartNow()")
        M.restartNow()
      else
        log("  -> ABORTED (ready=%s running=%s)",
            tostring(headsetReady()), tostring(hs.application.get(APP) ~= nil))
      end
    end)
  end
  wasPresent = present
end

function M.start()
  wasPresent = headsetReady()
  hs.audiodevice.watcher.setCallback(onDeviceChange)
  hs.audiodevice.watcher.start()
  log("started: wasPresent=%s watcherRunning=%s",
      tostring(wasPresent), tostring(hs.audiodevice.watcher.isRunning()))
  return M
end

return M
