-- Spider Solitaire (1 Suit) for VibeGE
-- Build complete descending runs from K to A to remove them.

local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local SUITS = { "spades", "hearts", "diamonds", "clubs" }
local VALUES = {}
for i, r in ipairs(RANKS) do VALUES[r] = i end

-- Premium themes
local THEMES = {
    felt = { bg = { 0.05, 0.25, 0.08 }, table_bg = { 0.04, 0.20, 0.06 }, card_bg = { 1, 1, 1 }, card_border = { 0.6, 0.6, 0.6 }, shadow = { 0, 0, 0, 0.25 }, text = { 0.8, 0.8, 0.9 } },
    walnut = { bg = { 0.15, 0.08, 0.03 }, table_bg = { 0.12, 0.06, 0.02 }, card_bg = { 0.98, 0.95, 0.88 }, card_border = { 0.5, 0.4, 0.3 }, shadow = { 0, 0, 0, 0.3 }, text = { 0.7, 0.65, 0.6 } },
    midnight = { bg = { 0.02, 0.02, 0.06 }, table_bg = { 0.01, 0.01, 0.04 }, card_bg = { 0.12, 0.12, 0.15 }, card_border = { 0.2, 0.2, 0.3 }, shadow = { 0, 0, 0, 0.5 }, text = { 0.4, 0.4, 0.5 } },
    modern = { bg = { 0.9, 0.9, 0.92 }, table_bg = { 0.85, 0.85, 0.88 }, card_bg = { 1, 1, 1 }, card_border = { 0.7, 0.7, 0.7 }, shadow = { 0, 0, 0, 0.1 }, text = { 0.3, 0.3, 0.3 } },
    carbon = { bg = { 0.08, 0.08, 0.08 }, table_bg = { 0.05, 0.05, 0.05 }, card_bg = { 0.9, 0.9, 0.9 }, card_border = { 0.4, 0.4, 0.4 }, shadow = { 0, 0, 0, 0.4 }, text = { 0.6, 0.6, 0.6 } },
}
local current_theme = THEMES.felt
local high_contrast = false

local function rounded_rect_corner(x, y, w, h, r, cr, cg, cb, ca)
    local r2 = math.min(r, w/2, h/2)
    vibege.render.draw_rect(x + r2, y, w - r2*2, h, cr, cg, cb, ca)
    vibege.render.draw_rect(x, y + r2, r2, h - r2*2, cr, cg, cb, ca)
    vibege.render.draw_rect(x + w - r2, y + r2, r2, h - r2*2, cr, cg, cb, ca)
end

local function card_shadow(cx, cy, cw, ch)
    local sh = current_theme.shadow
    vibege.render.draw_rect(cx + 3, cy + 3, cw, ch, sh[1], sh[2], sh[3], sh[4] * 0.5)
    vibege.render.draw_rect(cx + 2, cy + 2, cw, ch, sh[1], sh[2], sh[3], sh[4] * 0.7)
end

local CARD_W, CARD_H = 56, 80
local MARGIN = 6
local TOP_OFFSET = 40

local state = {
    tableau = {},
    stock = {},
    completed = 0,
    score = 0,
    moves = 0,
    time = 0,
    timer_active = false,
    game_over = false,
    won = false,
    selected_col = nil,
    selected_idx = nil,
    suits = 1, -- 1, 2, or 4
}

local function pile_x(i) return MARGIN + i * (CARD_W + 4) end
local function tableau_y() return TOP_OFFSET + 5 end

-- Create deck(s) for Spider
local function make_deck(suit)
    local deck = {}
    for _, rank in ipairs(RANKS) do
        table.insert(deck, { suit = suit, rank = rank, value = VALUES[rank], face_up = true })
    end
    return deck
end

-- Deal initial game
local function new_game()
    local suits_needed = state.suits or 1
    local all_cards = {}
    for s = 1, suits_needed do
        local suit_name = SUITS[s] or "spades"
        for _ = 1, 2 do
            for _, rank in ipairs(RANKS) do
                table.insert(all_cards, { suit = suit_name, rank = rank, value = VALUES[rank], face_up = true })
            end
        end
    end

    -- Shuffle
    for i = #all_cards, 2, -1 do
        local j = math.random(1, i)
        all_cards[i], all_cards[j] = all_cards[j], all_cards[i]
    end

    -- Deal to tableau: 10 columns, first 4 get 6 cards, last 6 get 5
    state.tableau = {}
    for col = 1, 10 do
        state.tableau[col] = {}
        local count = col <= 4 and 6 or 5
        for _ = 1, count do
            local card = table.remove(all_cards)
            card.face_up = true
            table.insert(state.tableau[col], card)
        end
    end

    state.stock = all_cards
    state.completed = 0
    state.score = 500
    state.moves = 0
    state.time = 0
    state.timer_active = true
    state.game_over = false
    state.won = false
    state.selected_col = nil
    state.selected_idx = nil
end

-- Check if a run from card at idx is complete K-to-A
local function is_complete_run(pile, idx)
    if #pile - idx + 1 < 13 then return false end
    for i = idx, #pile do
        if pile[i].suit ~= pile[idx].suit then return false end
        local expected = VALUES["K"] - (i - idx)
        if pile[i].value ~= expected then return false end
    end
    return true
end

-- Remove a completed run
local function remove_completed_run(col, idx)
    local pile = state.tableau[col]
    for _ = idx, #pile do table.remove(pile, idx) end
    state.completed = state.completed + 1
    state.score = state.score + 100
    state.moves = state.moves + 1
    if state.completed == 8 then
        state.game_over = true
        state.won = true
        state.timer_active = false
        state.score = state.score + 200
    end
end

-- Deal from stock (one card to each column)
local function deal_stock()
    if #state.stock == 0 then return end
    if #state.stock < 10 then return end
    for col = 1, 10 do
        local card = table.remove(state.stock)
        card.face_up = true
        table.insert(state.tableau[col], card)
    end
    state.moves = state.moves + 1
    -- Check for completed runs
    check_completed_runs()
end

-- Check for completed runs across all columns
local function check_completed_runs()
    for col = 1, 10 do
        local pile = state.tableau[col]
        if #pile >= 13 then
            for i = 1, #pile - 12 do
                if is_complete_run(pile, i) then
                    remove_completed_run(col, i)
                    return true
                end
            end
        end
    end
    return false
end

-- Check if a move to tableau is valid (same suit, descending)
local function can_move_to_tableau(moving_card, target_col)
    local pile = state.tableau[target_col]
    if #pile == 0 then return true end
    local top = pile[#pile]
    return moving_card.suit == top.suit and moving_card.value == top.value - 1
end

-- Handle click
local function handle_click(mx, my)
    if state.game_over then
        new_game()
        return
    end

    -- Stock click
    local sx = pile_x(0)
    if #state.stock > 0 and mx >= sx and mx <= sx + CARD_W and my >= tableau_y() and my <= tableau_y() + CARD_H then
        deal_stock()
        return
    end

    -- Tableau columns
    for col = 1, 10 do
        local pile = state.tableau[col]
        local base_x = pile_x(col - 1)
        local base_y = tableau_y()

        for i = #pile, 1, -1 do
            local cy = base_y + (i - 1) * 22
            if i == 1 then cy = base_y end
            if i == #pile then cy = base_y + (#pile - 1) * 22 end
            if mx >= base_x and mx <= base_x + CARD_W and my >= cy and my <= cy + CARD_H then
                local card = pile[i]

                if state.selected_col and state.selected_idx then
                    -- Second click: attempt move
                    local from_col = state.selected_col
                    local from_idx = state.selected_idx
                    local moving_card = state.tableau[from_col][from_idx]
                    if can_move_to_tableau(moving_card, col) then
                        -- Move the run
                        local run = {}
                        local src = state.tableau[from_col]
                        for j = from_idx, #src do table.insert(run, src[j]) end
                        for _ = from_idx, #src do table.remove(src) end
                        for _, c in ipairs(run) do table.insert(state.tableau[col], c) end
                        state.moves = state.moves + 1
                        check_completed_runs()
                    end
                    state.selected_col = nil
                    state.selected_idx = nil
                    return
                end

                -- First click: select
                state.selected_col = col
                state.selected_idx = i
                return
            end
        end
    end

    -- Clicking empty space deselects
    state.selected_col = nil
    state.selected_idx = nil
end

-- Card serialization (single character rank encoding for compact saves)
local function card_key(c) return c.rank .. c.suit end

local function serialize_pile(pile, prefix)
    local parts = { prefix }
    for _, c in ipairs(pile) do
        table.insert(parts, c.rank .. ":" .. c.suit)
    end
    return table.concat(parts, ",")
end

-- Save game
local function save_game()
    local parts = { tostring(state.score), tostring(state.moves), tostring(math.floor(state.time)), tostring(state.completed), tostring(state.suits) }
    for col = 1, 10 do
        table.insert(parts, serialize_pile(state.tableau[col], "t" .. col))
    end
    table.insert(parts, serialize_pile(state.stock, "stock"))
    vibege.storage.save("spider_save", table.concat(parts, "|"))
end

-- Load game
local function load_game()
    local saved = vibege.storage.load("spider_save")
    if not saved then return false end
    local parts = {}
    for part in string.gmatch(saved, "[^|]+") do
        table.insert(parts, part)
    end
    if #parts < 7 then return false end
    state.score = tonumber(parts[1]) or 500
    state.moves = tonumber(parts[2]) or 0
    state.time = tonumber(parts[3]) or 0
    state.completed = tonumber(parts[4]) or 0
    state.suits = tonumber(parts[5]) or 1
    state.tableau = {}
    for col = 1, 10 do
        state.tableau[col] = {}
        local idx = 5 + col
        if idx <= #parts then
            for c in string.gmatch(parts[idx], "([^,]+)") do
                local r_end = string.find(c, ":")
                if r_end then
                    local rank = string.sub(c, 1, r_end - 1)
                    local suit = string.sub(c, r_end + 1)
                    state.tableau[col][#state.tableau[col] + 1] = { suit = suit, rank = rank, value = VALUES[rank], face_up = true }
                end
            end
        end
    end
    state.stock = {}
    local stock_idx = 16
    if stock_idx <= #parts then
        for c in string.gmatch(parts[stock_idx], "([^,]+)") do
            local r_end = string.find(c, ":")
            if r_end then
                local rank = string.sub(c, 1, r_end - 1)
                local suit = string.sub(c, r_end + 1)
                state.stock[#state.stock + 1] = { suit = suit, rank = rank, value = VALUES[rank], face_up = true }
            end
        end
    end
    state.timer_active = true
    state.game_over = false
    state.won = false
    state.selected_col = nil
    state.selected_idx = nil
    if state.completed == 8 then state.game_over = true state.won = true end
    return true
end

function init()
    math.randomseed(os.time() * 2)
    new_game()
    load_game()
end

function update(dt)
    if state.timer_active and not state.game_over then
        state.time = state.time + dt
    end
    if vibege.input.is_key_pressed("t") then
        local names = { "felt", "walnut", "midnight", "modern", "carbon" }
        local found = false
        for i, n in ipairs(names) do
            if current_theme == THEMES[n] then
                current_theme = THEMES[names[(i % #names) + 1]]
                found = true; break
            end
        end
        if not found then current_theme = THEMES.felt end
    end
    if vibege.input.is_key_pressed("c") then high_contrast = not high_contrast end
    if vibege.input.is_key_pressed("n") then new_game() end
    if vibege.input.is_key_pressed("s") then save_game() end
end

local SYMBOLS = { spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣" }

local function draw_card(card, x, y, selected)
    local t = current_theme
    if high_contrast then
        t = { bg = { 0, 0, 0 }, table_bg = { 0, 0, 0 }, card_bg = { 1, 1, 1 }, card_border = { 1, 1, 1 }, shadow = { 0, 0, 0, 0 }, text = { 1, 1, 1 } }
    end
    card_shadow(x, y, CARD_W, CARD_H)
    if selected then vibege.render.draw_rect(x - 2, y - 2, CARD_W + 4, CARD_H + 4, 0.85, 0.85, 0.15, 1) end
    rounded_rect_corner(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 4, t.card_bg[1], t.card_bg[2], t.card_bg[3], 1)
    vibege.render.draw_rect(x + 1, y + 1, CARD_W - 2, 1, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + 1, y + CARD_H - 2, CARD_W - 2, 1, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + 1, y + 1, 1, CARD_H - 2, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + CARD_W - 2, y + 1, 1, CARD_H - 2, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    local color = (card.suit == "hearts" or card.suit == "diamonds") and { 1, 0.2, 0.2 } or { 0.1, 0.1, 0.1 }
    if high_contrast then color = (card.suit == "hearts" or card.suit == "diamonds") and { 0.5, 0, 0 } or { 0, 0, 0 } end
    local symbol = SYMBOLS[card.suit] or "♠"
    local sz = CARD_W / 6
    vibege.render.draw_text(x + 2, y + 1, card.rank, sz, color[1], color[2], color[3])
    vibege.render.draw_text(x + 2, y + sz + 2, symbol, sz * 0.7, color[1], color[2], color[3])
    vibege.render.draw_text(x + CARD_W/2 - sz, y + CARD_H/2 - sz, symbol, sz * 1.8, color[1], color[2], color[3])
end

function render()
    local t = current_theme
    if high_contrast then
        t = { bg = { 0, 0, 0 }, table_bg = { 0, 0, 0 }, card_bg = { 1, 1, 1 }, card_border = { 1, 1, 1 }, shadow = { 0, 0, 0, 0 }, text = { 1, 1, 1 } }
    end
    vibege.render.clear(t.bg[1], t.bg[2], t.bg[3], 1.0)

    -- Stock
    local sx = pile_x(0)
    if #state.stock > 0 then
        vibege.render.draw_rect(sx, tableau_y(), CARD_W, CARD_H, 0.2, 0.3, 0.6, 1.0)
        vibege.render.draw_text(sx + CARD_W/4, tableau_y() + CARD_H/3, tostring(math.ceil(#state.stock/10)), CARD_W/5, 1, 1, 1)
    else
        vibege.render.draw_rect(sx, tableau_y(), CARD_W, CARD_H, t.table_bg[1], t.table_bg[2], t.table_bg[3], 0.5)
    end

    -- Tableau
    for col = 1, 10 do
        local pile = state.tableau[col]
        local bx = pile_x(col - 1)
        local by = tableau_y()
        if #pile == 0 then
            vibege.render.draw_rect(bx, by, CARD_W, CARD_H, t.table_bg[1], t.table_bg[2], t.table_bg[3], 0.5)
        else
            for i, card in ipairs(pile) do
                local y = by + (i - 1) * 22
                if i == 1 then y = by end
                draw_card(card, bx, y, state.selected_col == col and state.selected_idx == i)
            end
        end
    end

    -- Top bar
    local ty = 3
    local function fmt_time(s) local m = math.floor(s/60); return string.format("%02d:%02d", m, math.floor(s%60)) end
    vibege.render.draw_text(8, ty, "Score: " .. state.score, 7, t.text[1], t.text[2], t.text[3])
    vibege.render.draw_text(110, ty, "Moves: " .. state.moves, 7, t.text[1], t.text[2], t.text[3])
    vibege.render.draw_text(210, ty, "Time: " .. fmt_time(state.time), 7, t.text[1], t.text[2], t.text[3])
    vibege.render.draw_text(340, ty, "Done: " .. state.completed .. "/8", 7, t.text[1], t.text[2], t.text[3])
    vibege.render.draw_text(500, ty, "T:Theme C:HC N:New", 6, t.text[1], t.text[2], t.text[3])

    -- Win screen
    if state.won then
        vibege.render.draw_rect(180, 180, 440, 240, 0.1, 0.3, 0.1, 0.9)
        vibege.render.draw_text(300, 220, "YOU WIN!", 24, 1, 1, 0.9)
        vibege.render.draw_text(260, 260, "Score: " .. state.score .. "  Time: " .. fmt_time(state.time), 9, t.text[1], t.text[2], t.text[3])
        vibege.render.draw_text(280, 290, "Click to play again", 8, t.text[1], t.text[2], t.text[3])
    end
end
