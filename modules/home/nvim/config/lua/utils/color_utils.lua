local M = {}

function M.hex_to_rgb(hex)
  hex = hex:gsub('#', '')
  return tonumber('0x' .. hex:sub(1, 2)), tonumber('0x' .. hex:sub(3, 4)), tonumber('0x' .. hex:sub(5, 6))
end

function M.rgb_to_hex(r, g, b)
  return string.format('#%02X%02X%02X', r, g, b)
end

function M.blend(color1, color2, alpha)
  local r1, g1, b1 = M.hex_to_rgb(color1)
  local r2, g2, b2 = M.hex_to_rgb(color2)

  local r = math.floor(r1 * (1 - alpha) + r2 * alpha)
  local g = math.floor(g1 * (1 - alpha) + g2 * alpha)
  local b = math.floor(b1 * (1 - alpha) + b2 * alpha)

  return M.rgb_to_hex(r, g, b)
end

return M
