# Weather on the dashboard

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Current conditions and a forecast from Open-Meteo, which needs no key. Caelestia:
`services/Weather.qml`, `modules/dashboard/WeatherTab.qml`; ambxst: `scripts/weather.sh`
(ideas only).

- A card in the Overview's new header row (issue 48, choice 1): icon, temperature,
  condition, place, today's high and low. A click opens the Weather tab.
- A **Weather** tab: now (feels like, humidity, wind in km/h), the next 24 hours in
  3-hour steps, 7 days, sunrise and sunset.
- A `services/Weather.qml` singleton holds the data; views register while they exist.
  Icons are Nerd Font weather glyphs, mapped from Open-Meteo's WMO codes and `is_day`.

This is the first request the shell makes of its own. (The media card already loads
cover art from whatever URL the player gives, which can be a web address.)

## Proposed choices

1. **Requests, with QML's `XMLHttpRequest`, so no process.** Each has a 15 s timeout (a
   Timer and `abort()`: Qt 6.11.2's QML `XMLHttpRequest` has none, checked), and sends
   `User-Agent: custom-shell` (Qt allows that header; it blocks `Referer`).
   - The forecast, the only regular one, with the fields Caelestia asks for:
     `https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=7`
   - A set city, once per change:
     `https://geocoding-api.open-meteo.com/v1/search?name=…&count=1&format=json`
   - No city: **`https://ipapi.co/json/`** (HTTPS, as ambxst) for `latitude`,
     `longitude` and `city`, at most every 6 hours. Alternative: Caelestia's
     `http://ip-api.com/json?fields=status,city,lat,lon`, which is plain HTTP.
2. **Location: by IP unless a city is set** (`weather.location`, default `""`).
   Alternative: a city only, and with none the card says "Set a city in Settings".
   Reason: it works with no setup and follows the laptop. **Question:** shall Nix set a
   city for both hosts (`local.customShell.settings.weather.location`)? Which? With a
   city set, no IP lookup is made.
3. **When: only while a weather view shows, at most every 30 minutes**
   (`weather.refreshMinutes`, 30; 15 to 180, step 15). Opening the dashboard fetches
   only stale data. A Timer runs only while a view exists, never in game mode.
   Alternatives: hourly (Caelestia), 10 minutes (ambxst). Reason: weather changes
   slowly, and nothing is sent while the dashboard is closed. At most 48 a day.
4. **Offline:** no request unless `Networking.connectivity` is `Full` or `Unknown`
   (NetworkManager reports `full` on brett-desktop, checked). Views show the cached data
   with "Updated 14:05", or "No weather while offline". When the network comes back with
   a view open and stale data, it fetches. After a failure it waits 5 minutes.
5. **Cache** in `Quickshell.statePath("weather.json")`: place, coordinates, the last
   forecast and its time. A restart shows it at once, with no request if fresh.
6. **Units:** temperatures follow `dashboard.fahrenheit`, converted in QML, so a change
   sends nothing. Its row moves to a "Units" heading on the Dashboard page.
7. **Settings,** on the Dashboard page: `dashboard.showWeather` (tab, `true`),
   `dashboard.weatherCard` (`true`) and the two above. With the tab and card both off,
   nothing is sent.

## Acceptance criteria

- [ ] With no city, the card shows the IP's place; with a city, that city.
- [ ] HTTPS works from `qs`. qtbase ships `plugins/tls/libqopensslbackend.so` (checked);
      that `qs` loads it is unchecked.
- [ ] With the dashboard closed, nothing is sent (a log line per request) and no weather
      Timer runs. Reopening within 30 minutes sends nothing.
- [ ] Offline (the laptop with Wi-Fi off), the cached data shows with its time, and it
      fetches when the network is back. °F applies without a request.
- [ ] Costs nothing in game mode.

## Blocked by

- None. It shares the Overview's header row with issue 52.
