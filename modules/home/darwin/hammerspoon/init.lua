-- EmmyLua provides completion and docs for spoons
-- Run before any path watchers are defined
hs.loadSpoon("EmmyLua")

-- Lets the `hs` CLI query this config
require("hs.ipc")

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

local config = {}

local hyper = require("hyper")
hyper.start(config)

-- Restarts SonoBus when the KVM hands the headset back (see sonobus-kvm.lua)
local sonobusKvm = require("sonobus-kvm")
sonobusKvm.start()

local apps = {}

local unbind = function()
	for _, app in pairs(apps) do
		app:disable()
	end
end

-- apps["arc"] = hs.hotkey.new("", "A", "Arc", function()
-- 	hs.application.launchOrFocus("Arc")
-- 	unbind()
-- end)
-- apps["term"] = hs.hotkey.new("", "T", "Terminal", function()
-- 	hs.application.launchOrFocus("kitty")
-- 	unbind()
-- end)

-- hs.hotkey.bind({ "cmd", "alt" }, "A", "Open Application", function()
-- 	for _, app in pairs(apps) do
-- 		app:enable()
-- 	end
-- end)

-- local apps_mode = hs.hotkey.modal.new({ "cmd", "shift" }, "a", "Open Application")
-- apps_mode:bind({}, "escape", function()
-- 	hs.alert("Exited")
-- 	apps_mode:exit()
-- end)
-- apps_mode:bind({ "cmd", "shift" }, "a", "Arc", function()
-- 	apps_mode:exit()
-- 	hs.application.launchOrFocus("Arc")
-- end)
-- apps_mode:bind({ "cmd", "shift" }, "t", "kitty", function()
-- 	apps_mode:exit()
-- 	hs.application.launchOrFocus("kitty")
-- end)

hs.hotkey.bind({ "cmd", "alt" }, "A", "Open Application", function()
	for _, app in pairs(apps) do
		app:enable()
	end
end)

hs.hotkey.showHotkeys({ "cmd", "shift" }, "/")
