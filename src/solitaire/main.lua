-- Solitaire (Klondike) for VibeGE — Professional Edition
-- Uses: render, scene, animation, save, input, runtime, math, util

-- ─── Constants ───

local SUITS = { "hearts", "diamonds", "clubs", "spades" }
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local VALUES = {} for i, r in ipairs(RANKS) do VALUES[r] = i end
local SYMBOLS = { hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠" }

local RED = { hearts = true, diamonds = true }

local THEMES = {
    felt = { bg={0.05,0.25,0.08}, card_bg={1,1,1}, card_border={0.6,0.6,0.6}, shadow={0,0,0,0.25},
             text={0.8,0.8,0.9}, red={1,0.2,0.2}, black={0.1,0.1,0.1} },
    walnut = { bg={0.15,0.08,0.03}, card_bg={0.98,0.95,0.88}, card_border={0.5,0.4,0.3},
               shadow={0,0,0,0.3}, text={0.7,0.65,0.6}, red={1,0.3,0.3}, black={0.2,0.15,0.1} },
    midnight = { bg={0.02,0.02,0.06}, card_bg={0.12,0.12,0.15}, card_border={0.2,0.2,0.3},
                 shadow={0,0,0,0.5}, text={0.4,0.4,0.5}, red={1,0.3,0.4}, black={0.5,0.5,0.6} },
    modern = { bg={0.9,0.9,0.92}, card_bg={1,1,1}, card_border={0.7,0.7,0.7},
               shadow={0,0,0,0.1}, text={0.3,0.3,0.3}, red={1,0.2,0.2}, black={0.2,0.2,0.2} },
    carbon = { bg={0.08,0.08,0.08}, card_bg={0.9,0.9,0.9}, card_border={0.4,0.4,0.4},
               shadow={0,0,0,0.4}, text={0.6,0.6,0.6}, red={1,0.3,0.3}, black={0.4,0.4,0.4} },
}

-- ─── State ───

local t = { theme = "felt", hc = false, draw3 = true, seed = os.time() }
local game = nil  -- current game state (populated by new_game)

-- ─── Config ───

local CW, CH = 64, 88
local MG = 8
local TOP = 56
local STOCK_Y = 12

-- ─── Helpers ───

function card_color(s) return RED[s] and t.theme.red or t.theme.black end

function suit_color(s)
    if s == "hearts" or s == "diamonds" then return {1,0.2,0.2} end
    return {0.1,0.1,0.1}
end

function clone(o)
    if type(o) ~= "table" then return o end
    local r = {} for k,v in pairs(o) do r[k] = clone(v) end return r
end

function px(i) return MG + i * (CW + 6) end

function card_bounds(x, y)
    return x - CW/2, y - CH/2, CW, CH
end

function pt_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- ─── Deck / Shuffle (Fisher-Yates with seeded PRNG) ───

function create_deck()
    local d = {}
    for _, s in ipairs(SUITS) do
        for _, r in ipairs(RANKS) do
            d[#d+1] = { rank = r, suit = s, face_up = false, value = VALUES[r] }
        end
    end
    return d
end

function shuffle(deck, seed)
    vibege.util.set_seed(seed)
    for i = #deck, 2, -1 do
        local j = math.floor(vibege.util.random_int(1, i))
        deck[i], deck[j] = deck[j], deck[i]
    end
end

-- ─── Game Logic ───

function new_game()
    local d = create_deck()
    t.seed = t.seed + os.time() % 7919
    shuffle(d, t.seed)

    game = {
        stock = {},
        waste = {},
        foundations = {{},{},{},{}},
        tableau = {{},{},{},{},{},{},{}},
        score = 0, moves = 0, time = 0, won = false, game_over = false,
        timer_active = true, draw_count = t.draw3 and 3 or 1,
        undo_stack = {}, hint = {},
        redeals = 0, max_redeals = 2,
    }

    -- Deal tableau
    local idx = 1
    for col = 1, 7 do
        for row = 1, col do
            local card = d[idx]; idx = idx + 1
            if row == col then card.face_up = true end
            game.tableau[col][#game.tableau[col]+1] = card
        end
    end

    -- Remaining cards go to stock
    for i = idx, #d do game.stock[#game.stock+1] = d[i] end

    t.hc = t.hc
end

function is_face_up(card) return card and card.face_up or false end

function can_move_to_foundation(card, pile)
    if not card then return false end
    if #pile == 0 then return card.rank == "A" end
    local top = pile[#pile]
    return card.suit == top.suit and card.value == top.value + 1
end

function can_move_to_tableau(card, pile)
    if not card then return false end
    if #pile == 0 then return card.rank == "K" end
    local top = pile[#pile]
    local alt_color = RED[card.suit] ~= RED[top.suit]
    return alt_color and card.value == top.value - 1
end

function is_sequence(cards, idx)
    if idx >= #cards then return true end
    for i = idx, #cards-1 do
        local a, b = cards[i], cards[i+1]
        if not a.face_up or not b.face_up then return false end
        if RED[a.suit] == RED[b.suit] then return false end
        if a.value ~= b.value + 1 then return false end
    end
    return true
end

function find_foundation(card)
    for i, f in ipairs(game.foundations) do
        if #f == 0 and card.rank == "A" then return i end
    return clone(game)
end

function push_undo()
    if #game.undo_stack >= 500 then table.remove(game.undo_stack, 1) end
    game.undo_stack[#game.undo_stack+1] = save_state()
end

function undo()
    if #game.undo_stack == 0 then return false end
    game = table.remove(game.undo_stack)
    game.moves = game.moves + 1
    return true
end

function draw_from_stock()
    push_undo()
    if #game.stock == 0 and game.redeals < game.max_redeals then
        -- Redeal: waste back to stock
        for i = #game.waste, 1, -1 do
            local c = game.waste[i]
            c.face_up = false
            game.stock[#game.stock+1] = c
        end
        game.waste = {}
        game.redeals = game.redeals + 1
        return
    end
    if #game.stock == 0 then return end
    local n = math.min(game.draw_count, #game.stock)
    for i = 1, n do
        local c = table.remove(game.stock, #game.stock)
        c.face_up = true
        game.waste[#game.waste+1] = c
    end
    game.moves = game.moves + 1
end

function waste_to_foundation()
    if #game.waste == 0 then return false end
    local card = game.waste[#game.waste]
    for i, f in ipairs(game.foundations) do
        if can_move_to_foundation(card, f) then
            push_undo()
            table.remove(game.waste)
            f[#f+1] = card
            game.score = game.score + 10
            game.moves = game.moves + 1
            check_win()
            return true
        end
    end
    return false
end

function tableau_to_foundation(col, row)
    local cards = game.tableau[col]
    if not cards or #cards == 0 then return false end
    local card = cards[#cards]
    if not card.face_up then return false end
    for i, f in ipairs(game.foundations) do
        if can_move_to_foundation(card, f) then
            push_undo()
            table.remove(cards)
            f[#f+1] = card
            if #cards > 0 then cards[#cards].face_up = true end
            game.score = game.score + 10
            game.moves = game.moves + 1
            check_win()
            return true
        end
    end
    return false
end

function move_cards(from_col, from_idx, to_col)
    local src = game.tableau[from_col]
    if not src or from_idx > #src then return false end
    if not is_sequence(src, from_idx) then return false end
    local dst = game.tableau[to_col]
    if #dst == 0 then
        if src[from_idx].rank ~= "K" then return false end
    else
        local top = dst[#dst]
        local card = src[from_idx]
        if RED[card.suit] == RED[top.suit] then return false end
        if card.value ~= top.value - 1 then return false end
    end
    push_undo()
    local count = #src - from_idx + 1
    for i = from_idx, #src do
        dst[#dst+1] = src[i]
    end
    for i = 1, count do table.remove(src) end
    if #src > 0 then src[#src].face_up = true end
    game.moves = game.moves + 1
    return true
end

function check_win()
    for _, f in ipairs(game.foundations) do
        if #f < 13 then return end
    end
    game.won = true; game.game_over = true; game.timer_active = false
end

function find_hints()
    local hints = {}
    -- Waste to tableau
    if #game.waste > 0 then
        local c = game.waste[#game.waste]
        for col = 1, 7 do
            local t = game.tableau[col]
            if can_move_to_tableau(c, t) then
                hints[#hints+1] = { type = "waste_tableau", col = col }
            end
        end
    end
    -- Waste to foundation
    if #game.waste > 0 then
        local c = game.waste[#game.waste]
        for _, f in ipairs(game.foundations) do
            if can_move_to_foundation(c, f) then
                hints[#hints+1] = { type = "waste_foundation" }; break
            end
        end
    end
    -- Tableau to foundation
    for col = 1, 7 do
        local cards = game.tableau[col]
        if #cards > 0 then
            local c = cards[#cards]
            if c.face_up then
                for _, f in ipairs(game.foundations) do
                    if can_move_to_foundation(c, f) then
                        hints[#hints+1] = { type = "tableau_foundation", col = col }; break
                    end
                end
            end
        end
    end
    -- Tableau to tableau
    for from_col = 1, 7 do
        local src = game.tableau[from_col]
        for from_idx = 1, #src do
            local c = src[from_idx]
            if c.face_up and is_sequence(src, from_idx) then
                for to_col = 1, 7 do
                    if from_col ~= to_col then
                        local dst = game.tableau[to_col]
                        if #dst == 0 then
                            if c.rank == "K" then hints[#hints+1] = { type = "move", from = from_col, idx = from_idx, to = to_col } end
                        else
                            local top = dst[#dst]
                            if RED[c.suit] ~= RED[top.suit] and c.value == top.value - 1 then
                                hints[#hints+1] = { type = "move", from = from_col, idx = from_idx, to = to_col }
                            end
                        end
                    end
                end
            end
        end
    end
    return hints
end

function apply_hint(hint)
    if hint.type == "waste_foundation" then waste_to_foundation() end
    if hint.type == "tableau_foundation" then tableau_to_foundation(hint.col) end
    if hint.type == "waste_tableau" then
        local card = game.waste[#game.waste]
        if can_move_to_tableau(card, game.tableau[hint.col]) then
            push_undo()
            table.remove(game.waste)
            game.tableau[hint.col][#game.tableau[hint.col]+1] = card
            game.moves = game.moves + 1
        end
    end
    if hint.type == "move" then move_cards(hint.from, hint.idx, hint.to) end
end

function auto_complete()
    local moved = false
    for _ = 1, 200 do
        moved = false
        for col = 1, 7 do
            if game.tableau[col] and #game.tableau[col] > 0 then
                local c = game.tableau[col][#game.tableau[col]]
                if c.face_up then
                    for _, f in ipairs(game.foundations) do
                        if can_move_to_foundation(c, f) then
                            push_undo()
                            table.remove(game.tableau[col])
                            f[#f+1] = c
                            if #game.tableau[col] > 0 then game.tableau[col][#game.tableau[col]].face_up = true end
                            game.score = game.score + 10; moved = true; check_win()
                            break
                        end
                    end
                end
            end
        end
        if game.won then return end
        if not moved then break end
    end
end

function auto_complete_all()
    while not game.won do
        auto_complete()
        local h = find_hints()
        if #h == 0 then break end
        local found = false
        for _, hint in ipairs(h) do
            if hint.type == "waste_foundation" or hint.type == "tableau_foundation" then
                apply_hint(hint); found = true; break
            end
        end
        if found then break end
        if not found then break end
    end
end

-- ─── Table Serialization (Lua-native, no external deps) ───

function serialize(val)
    local seen = {}
    local function s(v, depth)
        if type(v) == "nil" then return "null" end
        if type(v) == "number" then return tostring(v) end
        if type(v) == "boolean" then return v and "true" or "false" end
        if type(v) == "string" then return string.format("%q", v) end
        if type(v) ~= "table" then return tostring(v) end
        if seen[v] then return "{}" end
        seen[v] = true
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts+1] = "[" .. s(k, depth+1) .. "]=" .. s(val, depth+1)
        end
        seen[v] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return s(val, 0)
end

function deserialize(str)
    local fn = load("return " .. str)
    if fn then return fn() end
    return nil
end

function serialize_game() return serialize(game) end

function deserialize_game(str)
    local g = deserialize(str)
    if g and g.tableau then game = g end
end

function do_save()
    local ok, str = pcall(serialize_game)
    if ok then
        pcall(function() vibege.save.save("solitaire", str) end)
    end
end

-- ─── Drawing ───

function draw_card(card, x, y, cw, ch, alpha)
    alpha = alpha or 1
    local t = THEMES[t.theme]
    local sh = t.shadow
    -- Shadow
    vibege.render.draw_rect(x+3, y+3, cw, ch, sh[1], sh[2], sh[3], sh[4]*alpha)
    -- Card body
    vibege.render.draw_rect(x, y, cw, ch, t.card_bg[1], t.card_bg[2], t.card_bg[3], alpha)
    -- Border
    vibege.render.draw_rect(x, y, cw, 1, t.card_border[1], t.card_border[2], t.card_border[3], alpha*0.5)
    vibege.render.draw_rect(x, y+ch-1, cw, 1, t.card_border[1], t.card_border[2], t.card_border[3], alpha*0.5)

    if not card.face_up then
        -- Card back pattern
        local pat = t.hc and {0.3,0.3,0.3} or {0.2,0.4,0.7}
        local p2 = t.hc and {0.4,0.4,0.4} or {0.3,0.5,0.8}
        vibege.render.draw_rect(x+6, y+6, cw-12, ch-12, pat[1], pat[2], pat[3], alpha*0.8)
        vibege.render.draw_rect(x+10, y+10, cw-20, ch-20, p2[1], p2[2], p2[3], alpha*0.6)
        return
    end

    -- Suit symbol
    local sym = SYMBOLS[card.suit]
    local col = t.hc and (RED[card.suit] and {1,1,1} or {0,0,0}) or card_color(card.suit)
    -- Small text for rank + suit at top-left and bottom-right
    local label = card.rank .. sym
    local ts = t.hc and 10 or 9
    vibege.render.draw_text(x+4, y+2, label, 7, col[1], col[2], col[3])
    -- Center suit symbol
    vibege.render.draw_text(x+cw/2-5, y+ch/2-8, sym, 12, col[1], col[2], col[3])

    if t.hc then
        -- High contrast outline
        vibege.render.draw_rect(x, y, cw, ch, 1, 1, 1, 0.3)
    end
end

function draw_tableau()
    for col, cards in ipairs(game.tableau) do
        local x = px(col-1)
        for i, card in ipairs(cards) do
            local y = TOP + (i-1) * (i == 1 and 0 or 18)
            draw_card(card, x, y, CW, CH)
        end
    end
end

-- ─── Input Handling ───

local drag = { active = false, from = nil, idx = nil, cards = {}, ox = 0, oy = 0 }
local sel = nil

function handle_input(dt)
    local mx, my = vibege.input.mouse_position()
    local clicked = vibege.input.is_mouse_pressed("left")
    local released = vibege.input.is_mouse_released("left")

    -- Keyboard shortcuts
    if vibege.input.is_key_pressed("z") and (vibege.input.is_key_down("lctrl") or vibege.input.is_key_down("rctrl")) then
        undo()
    end
    if vibege.input.is_key_pressed("h") then
        local hints = find_hints()
        if #hints > 0 then apply_hint(hints[1]) end
    end
    if vibege.input.is_key_pressed("d") then auto_complete() end
    if vibege.input.is_key_pressed("a") then auto_complete_all() end
    if vibege.input.is_key_pressed("n") then new_game() end
    if vibege.input.is_key_pressed("r") then new_game() end
    if vibege.input.is_key_pressed("s") then do_save() end
    if vibege.input.is_key_pressed("u") then undo() end
    if vibege.input.is_key_pressed("1") then t.draw3 = false; new_game() end
    if vibege.input.is_key_pressed("3") then t.draw3 = true; new_game() end
    if vibege.input.is_key_pressed("t") then
        local keys = {"felt","walnut","midnight","modern","carbon"}
        for i, k in ipairs(keys) do
            if t.theme == k then t.theme = keys[i % #keys + 1]; break end
        end
    end
    if vibege.input.is_key_pressed("c") then t.hc = not t.hc end

    if game.won or game.game_over then
        if vibege.input.is_key_pressed("n") or vibege.input.is_key_pressed("space") then new_game() end
        return
    end

    -- Drag from stock
    if clicked then
        local sx, sy = px(0), STOCK_Y
        if pt_in_rect(mx, my, sx, sy, CW, CH) and #game.stock > 0 then
            draw_from_stock(); return
        end
        -- Waste click
        if #game.waste > 0 then
            local wx, wy = px(1), STOCK_Y
            if pt_in_rect(mx, my, wx, wy, CW, CH) then
                -- Try waste to foundation first
                if waste_to_foundation() then return end
            end
        end
        -- Double-click on waste -> foundation
        if vibege.input.is_mouse_down("left") then
            -- Handled as drag
        end
    end

    if clicked then
        -- Tableau clicks and drags
        for col = 7, 1, -1 do
            local cards = game.tableau[col]
            if #cards > 0 then
                for i = #cards, 1, -1 do
                    local card = cards[i]
                    if card.face_up or i == #cards then
                        local y = TOP + (i-1) * 18
                        if pt_in_rect(mx, my, px(col-1), y, CW, CH + 18) then
                            if vibege.input.is_key_down("lshift") or released then
                                -- Double click to foundation
                                if tableau_to_foundation(col, i) then return end
                            end
                            if is_sequence(cards, i) then
                                drag.active = true; drag.from = col; drag.idx = i
                                drag.ox = mx - px(col-1); drag.oy = my - y
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    if released and drag.active then
        -- Find target column
        for col = 1, 7 do
            local y = TOP
            if #game.tableau[col] > 0 then y = TOP + (#game.tableau[col]-1) * 18 end
            if pt_in_rect(mx, my, px(col-1), y, CW, CH + 18) then
                if move_cards(drag.from, drag.idx, col) then
                    drag.active = false; return
                end
            end
        end
        drag.active = false
    end
end

-- ─── Main Loop ───

function init()
    new_game()
    -- Try to load saved game
    local ok, data = pcall(function() return vibege.save.load("solitaire") end)
    if ok and data then
        local ok2, g = pcall(function() return vibege.json.decode(data) end)
        if ok2 and g and g.tableau then game = g end
    end
end

function update(dt)
    if not game then return end
    if game.timer_active and not game.paused then
        game.time = game.time + dt
    end

    handle_input(dt)

    -- Check for auto-foundation (double-click auto)
    if vibege.input.is_key_pressed("space") and not game.won then
        draw_from_stock()
    end
end

function render()
    local t = THEMES[t.theme]
    vibege.render.clear(t.bg[1], t.bg[2], t.bg[3], 1)

    if not game then return end

    -- Stock pile
    local stock_color = #game.stock > 0 and {0.3,0.3,0.3} or {0.2,0.2,0.2}
    vibege.render.draw_rect(px(0), STOCK_Y, CW, CH, stock_color[1], stock_color[2], stock_color[3], 0.5)
    if #game.stock > 0 then
        vibege.render.draw_text(px(0)+20, STOCK_Y+35, tostring(#game.stock), 8, 0.7,0.7,0.7)
    end

    -- Waste pile
    if #game.waste > 0 then
        local c = game.waste[#game.waste]
        draw_card(c, px(1), STOCK_Y, CW, CH)
    end

    -- Foundations
    for i = 1, 4 do
        local x = px(3 + i)
        local f = game.foundations[i]
        if #f > 0 then
            draw_card(f[#f], x, STOCK_Y, CW, CH)
        else
            -- Empty foundation outline
            local c = t.card_border
            vibege.render.draw_rect(x, STOCK_Y, CW, CH, c[1], c[2], c[3], 0.2)
            local suits_tl = {"♠","♥","♣","♦"}
            vibege.render.draw_text(x+20, STOCK_Y+35, suits_tl[i], 10, c[1], c[2], c[3])
        end
    end

    -- Tableau
    for col, cards in ipairs(game.tableau) do
        for i, card in ipairs(cards) do
            local y = TOP + (i-1) * 18
            draw_card(card, px(col-1), y, CW, CH)
        end
    end

    -- Drag preview
    if drag.active and game.tableau[drag.from] then
        local mx, my = vibege.input.mouse_position()
        local dx = mx - drag.ox
        local dy = my - drag.oy
        for i = drag.idx, #game.tableau[drag.from] do
            local card = game.tableau[drag.from][i]
            draw_card(card, dx, dy + (i - drag.idx) * 18, CW, CH, 0.8)
        end
    end

    -- HUD
    local hud_y = vibege.runtime.screen_size().height - 20
    local hud = string.format("Score: %d  Moves: %d  Time: %s  Undo: %d",
        game.score, game.moves, format_time(game.time), #game.undo_stack)
    vibege.render.draw_text(10, hud_y, hud, 8, t.text[1], t.text[2], t.text[3])

    -- Theme indicator
    local tm = "[T]heme: " .. t.theme
    if t.hc then tm = tm .. " [C]HC" end
    vibege.render.draw_text(vibege.runtime.screen_size().width - 10 - #tm * 7, 2, tm, 7, 0.5, 0.5, 0.5)

    -- Win screen
    if game.won then
        vibege.render.draw_rect(0, 0, vibege.runtime.screen_size().width, vibege.runtime.screen_size().height,
            t.bg[1], t.bg[2], t.bg[3], 0.85)
        local w = vibege.runtime.screen_size().width
        vibege.render.draw_text(w/2-80, vibege.runtime.screen_size().height/2-20, "You Win!", 24, 1, 0.8, 0.2)
        vibege.render.draw_text(w/2-100, vibege.runtime.screen_size().height/2+20,
            string.format("Score: %d  Moves: %d  Time: %s", game.score, game.moves, format_time(game.time)),
            10, 1, 1, 1)
        vibege.render.draw_text(w/2-80, vibege.runtime.screen_size().height/2+50, "[Space] New Game", 8, 0.7, 0.7, 0.7)
    end
end

function format_time(s)
    local m = math.floor(s / 60)
    local sec = math.floor(s % 60)
    return string.format("%d:%02d", m, sec)
end
