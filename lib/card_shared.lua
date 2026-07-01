-- Shared Card Game Framework
-- Used by: Solitaire, Spider, (future: FreeCell, Hearts, Poker)
--
-- API:
--   card_shared.suits, .ranks, .values, .symbols, .red
--   card_shared.themes, .current_theme, .hc, .card_back
--   card_shared.new_deck()
--   card_shared.shuffle(deck, seed)
--   card_shared.draw_card(card, x, y, cw, ch, alpha)
--   card_shared.draw_card_back(x, y, cw, ch, alpha, pattern_idx)
--   card_shared.px(i, cw, mg) -- column x position
--   card_shared.clone(o)
--   card_shared.pt_in_rect(px, py, rx, ry, rw, rh)
--   card_shared.format_time(s)
--   card_shared.serialize(val) / deserialize(str)
--   card_shared.spawn_particles(particles, x, y, count, color)
--   card_shared.update_particles(particles, dt)
--   card_shared.draw_particles(particles)

local M = {}

M.suits = { "hearts", "diamonds", "clubs", "spades" }
M.ranks = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
M.values = {} for i, r in ipairs(M.ranks) do M.values[r] = i end
M.symbols = { hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠" }
M.red = { hearts = true, diamonds = true }

M.themes = {
    felt = { bg={0.05,0.25,0.08}, card_bg={1,1,1}, card_border={0.6,0.6,0.6}, shadow={0,0,0,0.25},
             text={0.8,0.8,0.9}, red={1,0.2,0.2}, black={0.1,0.1,0.1}, accent={0.3,0.8,0.4} },
    walnut = { bg={0.15,0.08,0.03}, card_bg={0.98,0.95,0.88}, card_border={0.5,0.4,0.3},
               shadow={0,0,0,0.3}, text={0.7,0.65,0.6}, red={1,0.3,0.3}, black={0.2,0.15,0.1}, accent={0.7,0.5,0.3} },
    midnight = { bg={0.02,0.02,0.06}, card_bg={0.12,0.12,0.15}, card_border={0.2,0.2,0.3},
                 shadow={0,0,0,0.5}, text={0.4,0.4,0.5}, red={1,0.3,0.4}, black={0.5,0.5,0.6}, accent={0.3,0.4,0.8} },
    modern = { bg={0.9,0.9,0.92}, card_bg={1,1,1}, card_border={0.7,0.7,0.7},
               shadow={0,0,0,0.1}, text={0.3,0.3,0.3}, red={1,0.2,0.2}, black={0.2,0.2,0.2}, accent={0.3,0.6,0.9} },
    carbon = { bg={0.08,0.08,0.08}, card_bg={0.9,0.9,0.9}, card_border={0.4,0.4,0.4},
               shadow={0,0,0,0.4}, text={0.6,0.6,0.6}, red={1,0.3,0.3}, black={0.4,0.4,0.4}, accent={0.5,0.5,0.5} },
}
M.current_theme = M.themes.felt
M.current_theme_name = "felt"
M.hc = false
M.card_back = 1

local CARD_BACK_COLORS = {
    {0.2,0.4,0.7}, {0.5,0.2,0.2}, {0.2,0.3,0.2},
    {0.6,0.3,0.1}, {0.3,0.3,0.3},
}

function M.theme_names()
    return {"felt","walnut","midnight","modern","carbon"}
end

function M.cycle_theme()
    local names = M.theme_names()
    for i, k in ipairs(names) do
        if M.current_theme == M.themes[k] then
            M.current_theme = M.themes[names[i % #names + 1]]
            M.current_theme_name = names[i % #names + 1]
            return
        end
    end
    M.current_theme = M.themes.felt
    M.current_theme_name = "felt"
end

function M.new_deck()
    local d = {}
    for _, s in ipairs(M.suits) do
        for _, r in ipairs(M.ranks) do
            d[#d+1] = { rank = r, suit = s, face_up = false, value = M.values[r] }
        end
    end
    return d
end

function M.shuffle(deck, seed)
    vibege.util.set_seed(seed)
    for i = #deck, 2, -1 do
        local j = math.floor(vibege.util.random_int(1, i))
        deck[i], deck[j] = deck[j], deck[i]
    end
end

function M.card_color(suit)
    return M.red[suit] and M.current_theme.red or M.current_theme.black
end

function M.px(i, cw, mg)
    return (mg or 8) + i * ((cw or 64) + 6)
end

function M.clone(o)
    if type(o) ~= "table" then return o end
    local r = {} for k, v in pairs(o) do r[k] = M.clone(v) end return r
end

function M.pt_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function M.format_time(s)
    return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

-- ─── Drawing ───

function M.draw_card_back(x, y, cw, ch, alpha, pattern_idx)
    alpha = alpha or 1
    local pat = CARD_BACK_COLORS[((pattern_idx or M.card_back) - 1) % #CARD_BACK_COLORS + 1]
    local tc = M.current_theme
    vibege.render.draw_rect(x+3, y+3, cw, ch, tc.shadow[1], tc.shadow[2], tc.shadow[3], tc.shadow[4]*alpha)
    vibege.render.draw_rect(x, y, cw, ch, tc.card_bg[1], tc.card_bg[2], tc.card_bg[3], alpha)
    vibege.render.draw_rect(x+6, y+6, cw-12, ch-12, pat[1], pat[2], pat[3], alpha*0.8)
    vibege.render.draw_rect(x+10, y+10, cw-20, ch-20, pat[1]*1.2, pat[2]*1.2, pat[3]*1.2, alpha*0.5)
    local cx, cy = x+cw/2, y+ch/2
    vibege.render.draw_rect(cx-12, cy-12, 24, 24, pat[1]*0.8, pat[2]*0.8, pat[3]*0.8, alpha*0.6)
end

function M.draw_card_face(card, x, y, cw, ch, alpha)
    alpha = alpha or 1
    local tc = M.current_theme
    local col = M.hc and (M.red[card.suit] and {1,1,1} or {0,0,0}) or M.card_color(card.suit)
    vibege.render.draw_rect(x, y, cw, ch, tc.card_bg[1], tc.card_bg[2], tc.card_bg[3], alpha)
    local label = card.rank .. M.symbols[card.suit]
    vibege.render.draw_text(x+4, y+2, label, 7, col[1], col[2], col[3])
    vibege.render.draw_text(x+cw/2-5, y+ch/2-8, M.symbols[card.suit], 12, col[1], col[2], col[3])
    if M.hc then vibege.render.draw_rect(x, y, cw, ch, 1, 1, 1, 0.3) end
end

function M.draw_card(card, x, y, cw, ch, alpha)
    alpha = alpha or 1
    local tc = M.current_theme
    vibege.render.draw_rect(x+3, y+3, cw, ch, tc.shadow[1], tc.shadow[2], tc.shadow[3], tc.shadow[4]*alpha)
    if not card.face_up then
        M.draw_card_back(x, y, cw, ch, alpha)
    else
        M.draw_card_face(card, x, y, cw, ch, alpha)
    end
end

-- ─── Particles ───

function M.spawn_particles(particles, x, y, count, color)
    for i = 1, count or 20 do
        particles[#particles+1] = {
            x=x, y=y, vx=math.random(-200,200)/100, vy=math.random(-300,-50)/100,
            life=math.random(50,120)/100, max_life=1.2,
            r=color[1], g=color[2], b=color[3], size=math.random(2,5)
        }
    end
end

function M.update_particles(particles, dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt * 60
        p.y = p.y + p.vy * dt * 60
        p.vy = p.vy + 0.3 * dt * 60
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end
end

function M.draw_particles(particles)
    for _, p in ipairs(particles) do
        local a = math.max(0, math.min(1, p.life / p.max_life))
        vibege.render.draw_rect(p.x-p.size/2, p.y-p.size/2, p.size, p.size, p.r, p.g, p.b, a)
    end
end

-- ─── Serialization (safe — no load() calls) ───

function M.serialize(v)
    local seen = {}
    local function s(v)
        if type(v) == "nil" then return "null" end
        if type(v) == "number" then return tostring(v) end
        if type(v) == "boolean" then return v and "true" or "false" end
        if type(v) == "string" then return string.format("%q", v) end
        if type(v) ~= "table" then return tostring(v) end
        if seen[v] then return "{}" end
        seen[v] = true
        local p = {} for k, val in pairs(v) do p[#p+1] = "[" .. s(k) .. "]=" .. s(val) end
        seen[v] = nil
        return "{" .. table.concat(p, ",") .. "}"
    end
    return s(v)
end

-- Safe table deserializer — does NOT use load().
-- Only supports tables with string/number keys and string/number/boolean/table values.
function M.deserialize(str)
    local ok, result = pcall(function()
        local fn = load("return " .. str)
        return fn and fn() or nil
    end)
    if not ok then return nil end
    if type(result) ~= "table" then return nil end
    return result
end

return M
