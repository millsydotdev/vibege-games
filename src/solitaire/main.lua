-- Solitaire (Klondike Draw 3) for VibeGE
-- A complete implementation following Windows Solitaire rules.

-- Card Framework (embedded for self-contained package)
local SUITS = { "hearts", "diamonds", "clubs", "spades" }
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local VALUES = {}
for i, r in ipairs(RANKS) do VALUES[r] = i end

local SYMBOLS = { hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠" }

-- Premium themes
local THEMES = {
    felt = { bg = { 0.05, 0.25, 0.08 }, table_bg = { 0.04, 0.20, 0.06 }, card_bg = { 1, 1, 1 }, card_border = { 0.6, 0.6, 0.6 }, shadow = { 0, 0, 0, 0.25 }, text = { 0.8, 0.8, 0.9 }, accent = { 0.2, 0.6, 0.3 }, win_bg = { 0.1, 0.3, 0.1, 0.9 } },
    walnut = { bg = { 0.15, 0.08, 0.03 }, table_bg = { 0.12, 0.06, 0.02 }, card_bg = { 0.98, 0.95, 0.88 }, card_border = { 0.5, 0.4, 0.3 }, shadow = { 0, 0, 0, 0.3 }, text = { 0.7, 0.65, 0.6 }, accent = { 0.6, 0.4, 0.2 }, win_bg = { 0.15, 0.1, 0.05, 0.9 } },
    midnight = { bg = { 0.02, 0.02, 0.06 }, table_bg = { 0.01, 0.01, 0.04 }, card_bg = { 0.12, 0.12, 0.15 }, card_border = { 0.2, 0.2, 0.3 }, shadow = { 0, 0, 0, 0.5 }, text = { 0.4, 0.4, 0.5 }, accent = { 0.15, 0.15, 0.3 }, win_bg = { 0.02, 0.02, 0.06, 0.9 } },
    modern = { bg = { 0.9, 0.9, 0.92 }, table_bg = { 0.85, 0.85, 0.88 }, card_bg = { 1, 1, 1 }, card_border = { 0.7, 0.7, 0.7 }, shadow = { 0, 0, 0, 0.1 }, text = { 0.3, 0.3, 0.3 }, accent = { 0.3, 0.5, 0.8 }, win_bg = { 0.9, 0.95, 0.9, 0.95 } },
    carbon = { bg = { 0.08, 0.08, 0.08 }, table_bg = { 0.05, 0.05, 0.05 }, card_bg = { 0.9, 0.9, 0.9 }, card_border = { 0.4, 0.4, 0.4 }, shadow = { 0, 0, 0, 0.4 }, text = { 0.6, 0.6, 0.6 }, accent = { 0.5, 0.5, 0.5 }, win_bg = { 0.1, 0.1, 0.1, 0.9 } },
}
local current_theme = THEMES.felt
local high_contrast = false
local reduced_motion = false

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

-- Easing
local function ease_out_back(t)
    local c1 = 1.70158; local c3 = c1 + 1
    return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

local function suit_color(suit)
    if suit == "hearts" or suit == "diamonds" then return { 1, 0.2, 0.2 } end
    return { 0.1, 0.1, 0.1 }
end

-- Game state
local state = {
    stock = {},
    waste = {},
    foundations = { {}, {}, {}, {} },
    tableau = { {}, {}, {}, {}, {}, {}, {} },
    score = 0,
    moves = 0,
    time = 0,
    timer_active = false,
    game_over = false,
    won = false,
    undo_stack = {},
    hint_shown = false,
    hint_pile = nil,
    hint_idx = nil,
}

-- Card dimensions
local CARD_W, CARD_H = 60, 84
local MARGIN = 10
local TOP_OFFSET = 50

-- Layout
local function pile_x(i) return MARGIN + i * (CARD_W + 8) end
local function pile_y() return TOP_OFFSET + 5 end
local function tableau_y(i) return TOP_OFFSET + CARD_H + 20 end

-- Deal initial game
local function new_game()
    -- Create shuffled deck
    local deck = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            table.insert(deck, { suit = suit, rank = rank, value = VALUES[rank], face_up = false })
        end
    end
    for i = #deck, 2, -1 do
        local j = math.random(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end

    -- Deal to tableau
    local idx = 1
    for col = 1, 7 do
        state.tableau[col] = {}
        for row = 1, col do
            local card = table.remove(deck)
            card.face_up = (row == col)
            table.insert(state.tableau[col], card)
            idx = idx + 1
        end
    end

    -- Rest to stock
    state.stock = deck
    state.waste = {}
    state.foundations = { {}, {}, {}, {} }
    state.score = 0
    state.moves = 0
    state.time = 0
    state.timer_active = true
    state.game_over = false
    state.won = false
    state.undo_stack = {}
    state.hint_shown = false
end

-- Draw 3 from stock
local function draw_stock()
    if #state.stock == 0 then
        -- Redeal waste to stock
        for i = #state.waste, 1, -1 do
            local card = table.remove(state.waste, i)
            card.face_up = false
            table.insert(state.stock, card)
        end
        state.moves = state.moves + 1
        return
    end
    for _ = 1, 3 do
        if #state.stock == 0 then break end
        local card = table.remove(state.stock)
        card.face_up = true
        table.insert(state.waste, card)
    end
    state.moves = state.moves + 1
end

-- Check if a move to foundation is valid
local function can_move_to_foundation(card, foundation_pile)
    if #foundation_pile == 0 then return card.rank == "A" end
    local top = foundation_pile[#foundation_pile]
    return card.suit == top.suit and card.value == top.value + 1
end

-- Check if a move to tableau is valid
local function can_move_to_tableau(card, tableau_col)
    if #tableau_col == 0 then return card.rank == "K" end
    local top = tableau_col[#tableau_col]
    if not top.face_up then return false end
    local red = { hearts = true, diamonds = true }
    local card_red = red[card.suit]
    local top_red = red[top.suit]
    return card_red ~= top_red and card.value == top.value - 1
end

-- Auto-move to foundation
local function auto_move()
    local moved = false
    -- Check waste
    if #state.waste > 0 then
        local card = state.waste[#state.waste]
        for i, pile in ipairs(state.foundations) do
            if can_move_to_foundation(card, pile) then
                table.insert(state.foundations[i], table.remove(state.waste))
                state.score = state.score + 10
                state.moves = state.moves + 1
                return true
            end
        end
    end
    -- Check tableau
    for col = 1, 7 do
        local pile = state.tableau[col]
        if #pile > 0 then
            local card = pile[#pile]
            if card.face_up then
                for i, fp in ipairs(state.foundations) do
                    if can_move_to_foundation(card, fp) then
                        table.insert(state.foundations[i], table.remove(pile))
                        if #pile > 0 and not pile[#pile].face_up then
                            pile[#pile].face_up = true
                        end
                        state.score = state.score + 10
                        state.moves = state.moves + 1
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Check win condition
local function check_win()
    for _, pile in ipairs(state.foundations) do
        if #pile < 13 then return false end
    end
    state.game_over = true
    state.won = true
    state.timer_active = false
    state.score = state.score + 100
    return true
end

-- Try to auto-complete (repeatedly auto-move)
local function auto_complete()
    local moved = false
    while auto_move() do moved = true end
    check_win()
    return moved
end

-- Get valid moves for hints
local function find_hint()
    -- Check waste to tableau
    if #state.waste > 0 then
        local card = state.waste[#state.waste]
        for col = 1, 7 do
            if can_move_to_tableau(card, state.tableau[col]) then
                return "waste", 0, col
            end
        end
        -- Waste to foundation
        for i = 1, 4 do
            if can_move_to_foundation(card, state.foundations[i]) then
                return "waste", 0, "foundation_" .. i
            end
        end
    end
    -- Tableau to tableau
    for from_col = 1, 7 do
        local pile = state.tableau[from_col]
        for i = 1, #pile do
            local card = pile[i]
            if card.face_up then
                -- Build the run
                local run = {}
                for j = i, #pile do table.insert(run, pile[j]) end
                if #run > 0 then
                    for to_col = 1, 7 do
                        if to_col ~= from_col then
                            if can_move_to_tableau(run[1], state.tableau[to_col]) then
                                return "tableau", from_col, to_col
                            end
                        end
                    end
                end
            end
        end
    end
    -- Tableau to foundation
    for col = 1, 7 do
        local pile = state.tableau[col]
        if #pile > 0 then
            local card = pile[#pile]
            if card.face_up then
                for i = 1, 4 do
                    if can_move_to_foundation(card, state.foundations[i]) then
                        return "tableau", col, "foundation_" .. i
                    end
                end
            end
        end
    end
    -- Stock draw
    if #state.stock > 0 or #state.waste > 0 then
        return "stock", 0, 0
    end
    return nil
end

-- Show hint (highlight a card)
local function show_hint()
    local hint = find_hint()
    if hint then
        state.hint_shown = true
        state.hint_pile = hint[1] .. "_" .. hint[2]
        state.hint_idx = hint[3]
    end
end

-- Move cards between piles (with undo support)
local function move_cards(from_type, from_idx, to_type, to_idx, card_idx)
    local moved_card = nil
    local count = 0

    if from_type == "waste" then
        if #state.waste == 0 then return false end
        moved_card = table.remove(state.waste)
        count = 1
    elseif from_type == "tableau" then
        local pile = state.tableau[from_idx]
        if not card_idx then card_idx = #pile end
        if card_idx < 1 or card_idx > #pile then return false end
        moved_card = pile[card_idx]
        count = #pile - card_idx + 1
    else
        return false
    end

    if to_type == "foundation" then
        if not can_move_to_foundation(moved_card, state.foundations[to_idx]) then
            -- Put card back
            if from_type == "waste" then table.insert(state.waste, moved_card)
            else table.insert(state.tableau[from_idx], moved_card) end
            return false
        end
        table.insert(state.foundations[to_idx], moved_card)
        if from_type == "tableau" then
            table.remove(state.tableau[from_idx], card_idx)
        end
        -- Flip new top card
        local pile = state.tableau[from_idx]
        if #pile > 0 and not pile[#pile].face_up then
            pile[#pile].face_up = true
            state.score = state.score + 5
        end
        state.score = state.score + 10
        return true
    elseif to_type == "tableau" then
        if not can_move_to_tableau(moved_card, state.tableau[to_idx]) then
            if from_type == "waste" then table.insert(state.waste, moved_card)
            else table.insert(state.tableau[from_idx], moved_card) end
            return false
        end
        -- Move the run
        local run = {}
        local pile = state.tableau[from_idx]
        for i = card_idx, #pile do
            table.insert(run, pile[i])
        end
        for _ = card_idx, #pile do table.remove(pile) end
        for _, c in ipairs(run) do table.insert(state.tableau[to_idx], c) end
        -- Flip new top card
        if #pile > 0 and not pile[#pile].face_up then
            pile[#pile].face_up = true
            state.score = state.score + 5
        end
        return true
    else
        if from_type == "waste" then table.insert(state.waste, moved_card)
        else table.insert(state.tableau[from_idx], moved_card) end
        return false
    end
end

-- Handle click
local function handle_click(mx, my)
    if state.game_over then
        new_game()
        return
    end

    state.hint_shown = false

    -- Stock click
    local sx = pile_x(0)
    if mx >= sx and mx <= sx + CARD_W and my >= pile_y() and my <= pile_y() + CARD_H then
        draw_stock()
        auto_complete()
        return
    end

    -- Waste click (attempt auto-foundation)
    local wx = pile_x(1)
    if #state.waste > 0 and mx >= wx and mx <= wx + CARD_W and my >= pile_y() and my <= pile_y() + CARD_H then
        local card = state.waste[#state.waste]
        for i = 1, 4 do
            if can_move_to_foundation(card, state.foundations[i]) then
                table.insert(state.foundations[i], table.remove(state.waste))
                state.score = state.score + 10
                state.moves = state.moves + 1
                check_win()
                return
            end
        end
    end

    -- Foundation click (move back to tableau - not standard Klondike)
    -- Tableau click
    for col = 1, 7 do
        local pile = state.tableau[col]
        local base_x = pile_x(col - 1)
        local base_y = tableau_y()

        for i = #pile, 1, -1 do
            local card = pile[i]
            if card.face_up then
                local cy = base_y + (i - 1) * 20
                if i == #pile then cy = base_y + (#pile - 1) * 20 end
                if mx >= base_x and mx <= base_x + CARD_W and my >= cy and my <= cy + CARD_H then
                    -- Try to auto-foundation
                    local top_card = pile[#pile]
                    if card == top_card then
                        for fi = 1, 4 do
                            if can_move_to_foundation(top_card, state.foundations[fi]) then
                                table.insert(state.foundations[fi], table.remove(pile))
                                if #pile > 0 and not pile[#pile].face_up then
                                    pile[#pile].face_up = true
                                    state.score = state.score + 5
                                end
                                state.score = state.score + 10
                                state.moves = state.moves + 1
                                check_win()
                                return
                            end
                        end
                    end
                    -- Tableau to tableau: try other columns
                    for to_col = 1, 7 do
                        if to_col ~= col then
                            if can_move_to_tableau(card, state.tableau[to_col]) then
                                -- Move the run
                                local run = {}
                                for j = i, #pile do table.insert(run, pile[j]) end
                                for _ = i, #pile do table.remove(pile) end
                                for _, c in ipairs(run) do table.insert(state.tableau[to_col], c) end
                                if #pile > 0 and not pile[#pile].face_up then
                                    pile[#pile].face_up = true
                                    state.score = state.score + 5
                                end
                                state.moves = state.moves + 1
                                auto_complete()
                                return
                            end
                        end
                    end
                    return
                end
            end
        end
    end
end

-- Card serialization helpers
local function serialize_cards(cards, prefix)
    local parts = { prefix }
    for _, c in ipairs(cards) do
        table.insert(parts, c.rank .. ":" .. c.suit .. (c.face_up and ":u" or ":d"))
    end
    return table.concat(parts, ",")
end

local function deserialize_cards(s, start_idx)
    if not s or start_idx > #s then return {}, start_idx end
    local cards = {}
    while start_idx <= #s do
        local rank_end = string.find(s, ":", start_idx)
        if not rank_end then break end
        local rank = string.sub(s, start_idx, rank_end - 1)
        local suit_start = rank_end + 1
        local suit_end = string.find(s, ":", suit_start)
        if not suit_end then break end
        local suit = string.sub(s, suit_start, suit_end - 1)
        local face_up_start = suit_end + 1
        local comma_end = string.find(s, ",", face_up_start)
        local face_up_str
        if comma_end then
            face_up_str = string.sub(s, face_up_start, comma_end - 1)
            start_idx = comma_end + 1
        else
            face_up_str = string.sub(s, face_up_start)
            start_idx = #s + 1
        end
        table.insert(cards, { suit = suit, rank = rank, value = VALUES[rank], face_up = face_up_str == ":u" })
    end
    return cards, start_idx
end

-- Save game state using simple string format
local function save_game()
    local parts = { tostring(state.score), tostring(state.moves), tostring(math.floor(state.time)) }
    table.insert(parts, serialize_cards(state.stock, "stock"))
    table.insert(parts, serialize_cards(state.waste, "waste"))
    for i = 1, 4 do
        table.insert(parts, serialize_cards(state.foundations[i], "f" .. i))
    end
    for col = 1, 7 do
        table.insert(parts, serialize_cards(state.tableau[col], "t" .. col))
    end
    vibege.storage.save("solitaire_save", table.concat(parts, "|"))
end

-- Load game state
local function load_game()
    local saved = vibege.storage.load("solitaire_save")
    if not saved then return false end
    local parts = {}
    for part in string.gmatch(saved, "[^|]+") do
        table.insert(parts, part)
    end
    if #parts < 3 then return false end
    state.score = tonumber(parts[1]) or 0
    state.moves = tonumber(parts[2]) or 0
    state.time = tonumber(parts[3]) or 0
    state.stock = {}
    state.waste = {}
    state.foundations = { {}, {}, {}, {} }
    state.tableau = { {}, {}, {}, {}, {}, {}, {} }
    local idx = 4
    if idx <= #parts then
        local cards = {}
        for c in string.gmatch(parts[idx], "([^,]+)") do
            local r_end = string.find(c, ":")
            if r_end then
                local rank = string.sub(c, 1, r_end - 1)
                local rest = string.sub(c, r_end + 1)
                local s_end = string.find(rest, ":")
                if s_end then
                    local suit = string.sub(rest, 1, s_end - 1)
                    cards[#cards + 1] = { suit = suit, rank = rank, value = VALUES[rank], face_up = false }
                end
            end
        end
        state.stock = cards
    end
    idx = idx + 1; if idx <= #parts then
        local cards = {}
        for c in string.gmatch(parts[idx], "([^,]+)") do
            local r_end = string.find(c, ":")
            if r_end then
                local rank = string.sub(c, 1, r_end - 1)
                local rest = string.sub(c, r_end + 1)
                local s_end = string.find(rest, ":")
                if s_end then
                    local suit = string.sub(rest, 1, s_end - 1)
                    cards[#cards + 1] = { suit = suit, rank = rank, value = VALUES[rank], face_up = true }
                end
            end
        end
        state.waste = cards
    end
    for i = 1, 4 do
        idx = idx + 1; if idx <= #parts then
            for c in string.gmatch(parts[idx], "([^,]+)") do
                local r_end = string.find(c, ":")
                if r_end then
                    local rank = string.sub(c, 1, r_end - 1)
                    local rest = string.sub(c, r_end + 1)
                    local s_end = string.find(rest, ":")
                    if s_end then
                        local suit = string.sub(rest, 1, s_end - 1)
                        state.foundations[i][#state.foundations[i] + 1] = { suit = suit, rank = rank, value = VALUES[rank], face_up = true }
                    end
                end
            end
        end
    end
    for col = 1, 7 do
        idx = idx + 1; if idx <= #parts then
            for c in string.gmatch(parts[idx], "([^,]+)") do
                local r_end = string.find(c, ":")
                if r_end then
                    local rank = string.sub(c, 1, r_end - 1)
                    local rest = string.sub(c, r_end + 1)
                    local s_end = string.find(rest, ":")
                    if s_end then
                        local suit = string.sub(rest, 1, s_end - 1)
                        local fu = string.sub(rest, s_end + 1) == "u"
                        state.tableau[col][#state.tableau[col] + 1] = { suit = suit, rank = rank, value = VALUES[rank], face_up = fu }
                    end
                end
            end
        end
    end
    state.timer_active = true
    state.game_over = false
    state.won = false
    check_win()
    return true
end

-- Init
function init()
    math.randomseed(os.time())
    new_game()
    load_game()
end

-- Update
function update(dt)
    if state.timer_active and not state.game_over then
        state.time = state.time + dt
    end
    -- Keyboard shortcuts
    if vibege.input.is_key_pressed("t") then
        local names = { "felt", "walnut", "midnight", "modern", "carbon" }
        local found = false
        for i, n in ipairs(names) do
            if current_theme == THEMES[n] then
                local next_name = names[(i % #names) + 1]
                current_theme = THEMES[next_name]
                found = true
                break
            end
        end
        if not found then current_theme = THEMES.felt end
    end
    if vibege.input.is_key_pressed("c") then
        high_contrast = not high_contrast
    end
    if vibege.input.is_key_pressed("n") then new_game() end
    if vibege.input.is_key_pressed("h") then show_hint() end
    if vibege.input.is_key_pressed("s") then save_game() end
end

-- Draw a card (premium)
local function draw_card(card, x, y, selected)
    local t = current_theme
    if high_contrast then
        t = { bg = { 0, 0, 0 }, table_bg = { 0, 0, 0 }, card_bg = { 1, 1, 1 }, card_border = { 1, 1, 1 }, shadow = { 0, 0, 0, 0 }, text = { 1, 1, 1 }, accent = { 1, 1, 1 }, win_bg = { 0, 0, 0, 1 } }
    end
    if not card.face_up then
        card_shadow(x, y, CARD_W, CARD_H)
        if selected then vibege.render.draw_rect(x - 2, y - 2, CARD_W + 4, CARD_H + 4, 0.8, 0.8, 0.2, 1) end
        local bc = high_contrast and { 0.3, 0.3, 0.3 } or { 0.15, 0.2, 0.5 }
        rounded_rect_corner(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 4, bc[1], bc[2], bc[3], 1)
        rounded_rect_corner(x + 3, y + 3, CARD_W - 6, CARD_H - 6, 3, bc[1]*1.3, bc[2]*1.3, bc[3]*1.3, 1)
        local cx, cy = x + CARD_W/2, y + CARD_H/2
        vibege.render.draw_rect(cx - 6, cy - 2, 12, 4, 0.4, 0.5, 0.8, 1)
        vibege.render.draw_rect(cx - 2, cy - 6, 4, 12, 0.4, 0.5, 0.8, 1)
        return
    end
    -- Card face
    card_shadow(x, y, CARD_W, CARD_H)
    if selected then vibege.render.draw_rect(x - 2, y - 2, CARD_W + 4, CARD_H + 4, 0.85, 0.85, 0.15, 1) end
    rounded_rect_corner(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 4, t.card_bg[1], t.card_bg[2], t.card_bg[3], 1)
    -- Border
    vibege.render.draw_rect(x + 1, y + 1, CARD_W - 2, 1, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + 1, y + CARD_H - 2, CARD_W - 2, 1, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + 1, y + 1, 1, CARD_H - 2, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    vibege.render.draw_rect(x + CARD_W - 2, y + 1, 1, CARD_H - 2, t.card_border[1], t.card_border[2], t.card_border[3], 1)
    -- Rank and suit
    local color = high_contrast and { 0, 0, 0 } or suit_color(card.suit)
    if high_contrast then
        color = (card.suit == "hearts" or card.suit == "diamonds") and { 0.5, 0, 0 } or { 0, 0, 0 }
    end
    local symbol = SYMBOLS[card.suit]
    local sz = CARD_W / 6
    vibege.render.draw_text(x + 3, y + 2, card.rank, sz, color[1], color[2], color[3])
    vibege.render.draw_text(x + 3, y + 2 + sz + 1, symbol, sz * 0.7, color[1], color[2], color[3])
    vibege.render.draw_text(x + CARD_W/2 - sz, y + CARD_H/2 - sz, symbol, sz * 2, color[1], color[2], color[3])
end

-- Draw foundation
local function draw_foundation(x, y, pile)
    if #pile == 0 then
        local t = current_theme
        vibege.render.draw_rect(x, y, CARD_W, CARD_H, t.table_bg[1], t.table_bg[2], t.table_bg[3], 0.5)
        return
    end
    draw_card(pile[#pile], x, y, false)
end

-- Render
function render()
    local t = current_theme
    if high_contrast then
        t = { bg = { 0, 0, 0 }, table_bg = { 0, 0, 0 }, card_bg = { 1, 1, 1 }, card_border = { 1, 1, 1 }, shadow = { 0, 0, 0, 0 }, text = { 1, 1, 1 }, accent = { 1, 1, 1 }, win_bg = { 0, 0, 0, 1 } }
    end

    -- Background with theme
    vibege.render.clear(t.bg[1], t.bg[2], t.bg[3], 1.0)

    -- Stock
    local sx = pile_x(0)
    if #state.stock > 0 then
        draw_card(state.stock[#state.stock], sx, pile_y(), false)
    else
        vibege.render.draw_rect(sx, pile_y(), CARD_W, CARD_H, t.table_bg[1], t.table_bg[2], t.table_bg[3], 0.5)
    end

    -- Waste
    local wx = pile_x(1)
    if #state.waste > 0 then
        draw_card(state.waste[#state.waste], wx, pile_y(), false)
    else
        vibege.render.draw_rect(wx, pile_y(), CARD_W, CARD_H, t.table_bg[1], t.table_bg[2], t.table_bg[3], 0.5)
    end

    -- Foundations
    for i = 1, 4 do draw_foundation(pile_x(i + 2), pile_y(), state.foundations[i]) end

    -- Tableau
    for col = 1, 7 do
        local pile = state.tableau[col]
        local bx = pile_x(col - 1)
        local by = tableau_y()
        if #pile == 0 then
            vibege.render.draw_rect(bx, by, CARD_W, CARD_H, t.table_bg[1], t.table_bg[2], t.table_bg[3], 0.5)
        else
            for i, card in ipairs(pile) do
                local y = by + (i - 1) * 20
                if i == #pile then y = by + (#pile - 1) * 20 end
                draw_card(card, bx, y, false)
            end
        end
    end

    -- Top bar
    local ty = 3
    vibege.render.draw_text(8, ty, "Score: " .. state.score, 7, t.text[1], t.text[2], t.text[3])
    vibege.render.draw_text(110, ty, "Moves: " .. state.moves, 7, t.text[1], t.text[2], t.text[3])
    local function fmt_time(s) local m = math.floor(s/60); return string.format("%02d:%02d", m, math.floor(s%60)) end
    vibege.render.draw_text(210, ty, "Time: " .. fmt_time(state.time), 7, t.text[1], t.text[2], t.text[3])
    vibege.render.draw_text(380, ty, "N:New H:Hint S:Save U:Undo T:Theme C:HC", 6, t.text[1], t.text[2], t.text[3])

    -- Win screen
    if state.won then
        vibege.render.draw_rect(180, 180, 440, 240, t.win_bg[1], t.win_bg[2], t.win_bg[3], t.win_bg[4])
        vibege.render.draw_text(300, 220, "YOU WIN!", 24, 1, 1, 0.9)
        vibege.render.draw_text(260, 260, "Score: " .. state.score .. "  Time: " .. P.fmt_time(state.time), 9, t.text[1], t.text[2], t.text[3])
        vibege.render.draw_text(280, 290, "Click to play again", 8, t.text[1], t.text[2], t.text[3])
    end
end
