--- Premium rendering pack for VibeGE Solitaire games.
-- Provides shadows, rounded corners, themes, animations, statistics.
local P = {}

-- Themes
P.THEMES = {
    felt = {
        bg = { 0.05, 0.25, 0.08 }, table_bg = { 0.04, 0.20, 0.06 },
        card_bg = { 1, 1, 1 }, card_border = { 0.6, 0.6, 0.6 },
        shadow = { 0, 0, 0, 0.25 }, text = { 0.8, 0.8, 0.9 },
        accent = { 0.2, 0.6, 0.3 }, win_bg = { 0.1, 0.3, 0.1, 0.9 },
    },
    walnut = {
        bg = { 0.15, 0.08, 0.03 }, table_bg = { 0.12, 0.06, 0.02 },
        card_bg = { 0.98, 0.95, 0.88 }, card_border = { 0.5, 0.4, 0.3 },
        shadow = { 0, 0, 0, 0.3 }, text = { 0.7, 0.65, 0.6 },
        accent = { 0.6, 0.4, 0.2 }, win_bg = { 0.15, 0.1, 0.05, 0.9 },
    },
    velvet = {
        bg = { 0.06, 0.08, 0.2 }, table_bg = { 0.04, 0.06, 0.18 },
        card_bg = { 1, 1, 1 }, card_border = { 0.6, 0.6, 0.8 },
        shadow = { 0, 0, 0.1, 0.25 }, text = { 0.7, 0.7, 0.9 },
        accent = { 0.3, 0.3, 0.7 }, win_bg = { 0.1, 0.1, 0.3, 0.9 },
    },
    carbon = {
        bg = { 0.08, 0.08, 0.08 }, table_bg = { 0.05, 0.05, 0.05 },
        card_bg = { 0.9, 0.9, 0.9 }, card_border = { 0.4, 0.4, 0.4 },
        shadow = { 0, 0, 0, 0.4 }, text = { 0.6, 0.6, 0.6 },
        accent = { 0.5, 0.5, 0.5 }, win_bg = { 0.1, 0.1, 0.1, 0.9 },
    },
    marble = {
        bg = { 0.15, 0.15, 0.12 }, table_bg = { 0.2, 0.2, 0.17 },
        card_bg = { 1, 1, 1 }, card_border = { 0.6, 0.6, 0.6 },
        shadow = { 0, 0, 0, 0.15 }, text = { 0.7, 0.7, 0.7 },
        accent = { 0.8, 0.7, 0.5 }, win_bg = { 0.15, 0.15, 0.12, 0.9 },
    },
    midnight = {
        bg = { 0.02, 0.02, 0.06 }, table_bg = { 0.01, 0.01, 0.04 },
        card_bg = { 0.12, 0.12, 0.15 }, card_border = { 0.2, 0.2, 0.3 },
        shadow = { 0, 0, 0, 0.5 }, text = { 0.4, 0.4, 0.5 },
        accent = { 0.15, 0.15, 0.3 }, win_bg = { 0.02, 0.02, 0.06, 0.9 },
    },
    modern = {
        bg = { 0.9, 0.9, 0.92 }, table_bg = { 0.85, 0.85, 0.88 },
        card_bg = { 1, 1, 1 }, card_border = { 0.7, 0.7, 0.7 },
        shadow = { 0, 0, 0, 0.1 }, text = { 0.3, 0.3, 0.3 },
        accent = { 0.3, 0.5, 0.8 }, win_bg = { 0.9, 0.95, 0.9, 0.95 },
    },
}

-- Easing functions
function P.ease_in_out(t)
    return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end

function P.ease_out(t)
    return 1 - (1 - t) * (1 - t)
end

function P.ease_out_back(t)
    local c1 = 1.70158; local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- Draw rounded rect using multiple small rectangles
function P.rounded_rect(x, y, w, h, r, cr, cg, cb, ca)
    local r2 = math.min(r, w / 2, h / 2)
    -- Center
    vibege.render.draw_rect(x + r2, y, w - r2 * 2, h, cr, cg, cb, ca)
    -- Left/right vertical strips
    vibege.render.draw_rect(x, y + r2, r2, h - r2 * 2, cr, cg, cb, ca)
    vibege.render.draw_rect(x + w - r2, y + r2, r2, h - r2 * 2, cr, cg, cb, ca)
    -- Corners (2x2 squares)
    vibege.render.draw_rect(x + r2 - 1, y, 1, 1, cr, cg, cb, ca)
    vibege.render.draw_rect(x + w - r2, y, 1, 1, cr, cg, cb, ca)
    vibege.render.draw_rect(x + r2 - 1, y + h - 1, 1, 1, cr, cg, cb, ca)
    vibege.render.draw_rect(x + w - r2, y + h - 1, 1, 1, cr, cg, cb, ca)
end

-- Draw card shadow
function P.card_shadow(cx, cy, cw, ch, theme)
    local sh = theme.shadow or { 0, 0, 0, 0.25 }
    -- Multi-layer shadow for depth
    vibege.render.draw_rect(cx + 3, cy + 3, cw, ch, sh[1], sh[2], sh[3], sh[4] * 0.5)
    vibege.render.draw_rect(cx + 2, cy + 2, cw, ch, sh[1], sh[2], sh[3], sh[4] * 0.7)
end

-- Draw premium card
function P.premium_card(card, x, y, w, h, theme, selected, highlighted)
    local t = theme
    if not card.face_up then
        -- Premium card back
        P.card_shadow(x, y, w, h, t)
        local b_col = { 0.15, 0.2, 0.5 }
        if selected then vibege.render.draw_rect(x - 2, y - 2, w + 4, h + 4, 0.8, 0.8, 0.2, 1) end
        P.rounded_rect(x + 1, y + 1, w - 2, h - 2, 4, b_col[1], b_col[2], b_col[3], 1)
        P.rounded_rect(x + 3, y + 3, w - 6, h - 6, 3, b_col[1] * 1.3, b_col[2] * 1.3, b_col[3] * 1.3, 1)
        -- Diamond center
        local cx, cy = x + w / 2, y + h / 2
        vibege.render.draw_rect(cx - 6, cy - 2, 12, 4, 0.4, 0.5, 0.8, 1)
        vibege.render.draw_rect(cx - 2, cy - 6, 4, 12, 0.4, 0.5, 0.8, 1)
        return
    end

    -- Card face
    P.card_shadow(x, y, w, h, t)
    if selected then vibege.render.draw_rect(x - 2, y - 2, w + 4, h + 4, 0.85, 0.85, 0.15, 1) end
    if highlighted then vibege.render.draw_rect(x - 2, y - 2, w + 4, h + 4, 0.2, 0.8, 0.3, 0.4) end
    P.rounded_rect(x + 1, y + 1, w - 2, h - 2, 4, t.card_bg[1], t.card_bg[2], t.card_bg[3], 1)
    -- Border
    vibege.render.draw_rect(x + 1, y + 1, w - 2, 1, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + 1, y + h - 2, w - 2, 1, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + 1, y + 1, 1, h - 2, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + w - 2, y + 1, 1, h - 2, t.card_border[1], t.card_border[2], t.card_border[3], 1)
end

-- Animated position
function P.anim_pos(anim, now)
    if not anim or anim.done then return anim and anim.to_x or 0, anim and anim.to_y or 0 end
    local elapsed = now - anim.start
    local t = math.min(elapsed / anim.duration, 1)
    local e = P.ease_out_back(t)
    local cx = anim.from_x + (anim.to_x - anim.from_x) * e
    local cy = anim.from_y + (anim.to_y - anim.from_y) * e
    return cx, cy
end

function P.anim_done(anim, now)
    if not anim then return true end
    return anim.done or (now - anim.start) >= anim.duration
end

-- Statistics tracking
function P.stats_load(game_name)
    local data = vibege.storage.load(game_name .. "_stats")
    if not data then
        return { played = 0, won = 0, best_time = 0, total_time = 0, total_moves = 0, streak = 0, best_streak = 0, hint_usage = 0, undo_usage = 0 }
    end
    local s = {}
    for pair in string.gmatch(data, "([^,]+)") do
        local eq = string.find(pair, "=")
        if eq then
            local k = string.sub(pair, 1, eq - 1)
            local v = tonumber(string.sub(pair, eq + 1)) or 0
            s[k] = v
        end
    end
    s.played = s.played or 0; s.won = s.won or 0; s.best_time = s.best_time or 0
    s.total_time = s.total_time or 0; s.total_moves = s.total_moves or 0
    s.streak = s.streak or 0; s.best_streak = s.best_streak or 0
    s.hint_usage = s.hint_usage or 0; s.undo_usage = s.undo_usage or 0
    return s
end

function P.stats_save(game_name, s)
    local parts = {}
    for k, v in pairs(s) do table.insert(parts, k .. "=" .. tostring(v)) end
    vibege.storage.save(game_name .. "_stats", table.concat(parts, ","))
end

function P.stats_record_win(game_name, time_secs, moves, hints, undos)
    local s = P.stats_load(game_name)
    s.played = (s.played or 0) + 1
    s.won = (s.won or 0) + 1
    s.streak = (s.streak or 0) + 1
    if s.streak > (s.best_streak or 0) then s.best_streak = s.streak end
    s.total_time = (s.total_time or 0) + time_secs
    s.total_moves = (s.total_moves or 0) + moves
    s.hint_usage = (s.hint_usage or 0) + (hints or 0)
    s.undo_usage = (s.undo_usage or 0) + (undos or 0)
    if (s.best_time or 0) == 0 or time_secs < s.best_time then s.best_time = time_secs end
    P.stats_save(game_name, s)
end

function P.stats_record_loss(game_name, moves, hints, undos)
    local s = P.stats_load(game_name)
    s.played = (s.played or 0) + 1
    s.streak = 0
    s.total_moves = (s.total_moves or 0) + moves
    s.hint_usage = (s.hint_usage or 0) + (hints or 0)
    s.undo_usage = (s.undo_usage or 0) + (undos or 0)
    P.stats_save(game_name, s)
end

function P.stats_display(x, y, w, theme, s)
    local t = theme
    local pct = s.played > 0 and math.floor(s.won / s.played * 100) or 0
    local avg_time = s.won > 0 and math.floor(s.total_time / s.won) or 0
    local lines = {
        "Games: " .. s.played,
        "Wins: " .. s.won,
        "Win %: " .. pct .. "%",
        "Streak: " .. s.streak,
        "Best Streak: " .. s.best_streak,
        "Best Time: " .. P.fmt_time(s.best_time),
        "Avg Time: " .. P.fmt_time(avg_time),
        "Total Moves: " .. s.total_moves,
    }
    local ly = y
    for _, line in ipairs(lines) do
        vibege.render.draw_text(x, ly, line, 7, t.text[1], t.text[2], t.text[3])
        ly = ly + 10
    end
end

function P.fmt_time(secs)
    local m = math.floor(secs / 60)
    local s = math.floor(secs % 60)
    return string.format("%02d:%02d", m, s)
end

return P
