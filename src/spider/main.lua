-- Spider Solitaire for VibeGE — Professional Edition
-- Supports 1 Suit, 2 Suit, and 4 Suit modes
-- Uses shared card framework from lib/card_shared.lua

local card = require("lib.card_shared")
local M = {}

local CW, CH = 56, 80
local MG = 4
local TOP = 44
local TABLEAU_COLS = 10

-- ─── Game State ───

local g = nil
local particles = {}
local drag = { active = false, from = nil, idx = nil, ox = 0, oy = 0 }
local sw, sh = 0, 0

function px(i) return MG + i * (CW + 4) end
function ty() return TOP end
function card_y(col, idx) return ty() + (idx - 1) * 22 end

-- ─── Deck Creation (Spider uses 2 × N suit decks = 104 × N/4 cards) ───

function make_decks(suit_count)
    local all = {}
    local suits_to_use = { card.suits[1] }
    if suit_count >= 2 then suits_to_use[2] = card.suits[2] end
    if suit_count >= 4 then suits_to_use = card.suits end
    for s = 1, suit_count do
        local suit = suit_count == 4 and card.suits[s] or card.suits[1]
        if suit_count == 2 and s == 2 then suit = card.suits[2] end
        for copy = 1, 2 do
            for _, rank in ipairs(card.ranks) do
                all[#all+1] = { suit = suit, rank = rank, value = card.values[rank], face_up = true }
            end
        end
    end
    return all
end

function new_game(suit_count)
    local sc = suit_count or 1
    local deck = make_decks(sc)
    card.shuffle(deck, os.time() * 7919 + sc * 1000)

    g = {
        tableau = {}, stock = {}, completed = 0, suits = sc,
        score = 500, moves = 0, time = 0, won = false, game_over = false,
        timer_active = true, undo_stack = {},
    }

    for col = 1, TABLEAU_COLS do
        g.tableau[col] = {}
        local count = col <= 4 and 6 or 5
        for _ = 1, count do table.insert(g.tableau[col], table.remove(deck)) end
    end
    g.stock = deck
    particles = {}
end

function save_state() return card.clone(g) end

function push_undo()
    if #g.undo_stack >= 200 then table.remove(g.undo_stack, 1) end
    g.undo_stack[#g.undo_stack+1] = save_state()
end

function undo()
    if #g.undo_stack == 0 then return false end
    g = table.remove(g.undo_stack)
    g.moves = g.moves + 1
    return true
end

-- ─── Rules ───

function is_descending_sequence(pile, idx)
    if idx >= #pile then return true end
    for i = idx, #pile - 1 do
        if pile[i].value ~= pile[i+1].value + 1 then return false end
    end
    return true
end

function is_complete_run(pile, idx)
    if #pile - idx + 1 < 13 then return false end
    for i = idx, #pile do
        if pile[i].suit ~= pile[idx].suit then return false end
        if pile[i].value ~= card.values["K"] - (i - idx) then return false end
    end
    return true
end

function check_completed_runs()
    for col = 1, TABLEAU_COLS do
        local pile = g.tableau[col]
        if #pile >= 13 then
            for i = 1, #pile - 12 do
                if is_complete_run(pile, i) then
                    for _ = i, #pile do table.remove(pile, i) end
                    g.completed = g.completed + 1
                    g.score = g.score + 100
                    card.spawn_particles(particles, px(col-1)+CW/2, ty()+50, 40, {1,0.9,0.3})
                    if g.completed == 8 then
                        g.won = true; g.game_over = true; g.timer_active = false
                        g.score = g.score + 200
                        card.spawn_particles(particles, sw/2, sh/2, 150, {1,0.9,0.3})
                    end
                    return true
                end
            end
        end
    end
    return false
end

function can_move_to(moving_card, target_col)
    local pile = g.tableau[target_col]
    if #pile == 0 then return true end
    local top = pile[#pile]
    return moving_card.suit == top.suit and moving_card.value == top.value - 1
end

function deal_stock()
    if #g.stock < TABLEAU_COLS then return end
    push_undo()
    for col = 1, TABLEAU_COLS do
        table.insert(g.tableau[col], table.remove(g.stock))
    end
    g.moves = g.moves + 1
    check_completed_runs()
end

function move_cards(from_col, from_idx, to_col)
    local src = g.tableau[from_col]
    if not src or from_idx > #src then return false end
    local dst = g.tableau[to_col]
    if #dst > 0 then
        local mc = src[from_idx]
        if mc.suit ~= dst[#dst].suit or mc.value ~= dst[#dst].value - 1 then return false end
    end
    push_undo()
    for i = from_idx, #src do table.insert(dst, src[i]) end
    for _ = from_idx, #src do table.remove(src, from_idx) end
    g.moves = g.moves + 1
    check_completed_runs()
    return true
end

-- ─── Hints ───

function find_hints()
    local hints = {}
    for col = 1, TABLEAU_COLS do
        local pile = g.tableau[col]
        for i = 1, #pile do
            if is_descending_sequence(pile, i) then
                for t = 1, TABLEAU_COLS do
                    if t ~= col then
                        if can_move_to(pile[i], t) then
                            hints[#hints+1] = { from=col, idx=i, to=t }
                            if #hints >= 3 then return hints end
                        end
                    end
                end
            end
        end
    end
    return hints
end

-- ─── Save / Load ───

function do_save()
    local ok, str = pcall(card.serialize, g)
    if ok then pcall(function() vibege.save.save("spider", str) end) end
end

-- ─── Input ───

function handle_input()
    local mx, my = vibege.input.mouse_position()
    local clicked = vibege.input.is_mouse_pressed("left")
    local released = vibege.input.is_mouse_released("left")

    if vibege.input.is_key_pressed("z") and (vibege.input.is_key_down("lctrl") or vibege.input.is_key_down("rctrl")) then undo() end
    if vibege.input.is_key_pressed("u") then undo() end
    if vibege.input.is_key_pressed("n") or vibege.input.is_key_pressed("r") then new_game(g and g.suits or 1) end
    if vibege.input.is_key_pressed("s") then do_save() end
    if vibege.input.is_key_pressed("h") then local h = find_hints(); if #h > 0 then move_cards(h[1].from, h[1].idx, h[1].to) end end
    if vibege.input.is_key_pressed("1") then new_game(1) end
    if vibege.input.is_key_pressed("2") then new_game(2) end
    if vibege.input.is_key_pressed("4") then new_game(4) end
    if vibege.input.is_key_pressed("t") then card.cycle_theme() end
    if vibege.input.is_key_pressed("c") then card.hc = not card.hc end
    if vibege.input.is_key_pressed("b") then card.card_back = card.card_back % 5 + 1 end
    if vibege.input.is_key_pressed("space") and not g.won then deal_stock() end

    if g and g.won then
        if clicked or vibege.input.is_key_pressed("space") then new_game(g and g.suits or 1) end
        return
    end

    -- Stock click
    if clicked and #g.stock > 0 then
        if card.pt_in_rect(mx, my, px(0), ty(), CW, CH) then deal_stock(); return end
    end

    -- Tableau
    if clicked then
        for col = TABLEAU_COLS, 1, -1 do
            local pile = g.tableau[col]
            for i = #pile, 1, -1 do
                local cy = card_y(col, i)
                if card.pt_in_rect(mx, my, px(col-1), cy, CW, CH) then
                    if i == #pile and released then
                        -- Move single card to foundation
                        -- In Spider, cards only move to tableau
                    end
                    if is_descending_sequence(pile, i) then
                        drag.active = true; drag.from = col; drag.idx = i
                        drag.ox = mx - px(col-1); drag.oy = my - cy; return
                    end
                end
            end
        end
    end

    if released and drag.active then
        for col = 1, TABLEAU_COLS do
            local ey = ty()
            if #g.tableau[col] > 0 then ey = card_y(col, #g.tableau[col]) end
            if card.pt_in_rect(mx, my, px(col-1), ey, CW, CH + 22) then
                if move_cards(drag.from, drag.idx, col) then drag.active = false; return end
            end
        end
        drag.active = false
    end
end

-- ─── Main Loop ───

function init()
    sw, sh = vibege.runtime.screen_size().width, vibege.runtime.screen_size().height
    new_game(1)
    local ok, data = pcall(function() return vibege.save.load("spider") end)
    if ok and data then
        local g2 = card.deserialize(data)
        if g2 and g2.tableau then g = g2 end
    end
end

function update(dt)
    sw, sh = vibege.runtime.screen_size().width, vibege.runtime.screen_size().height
    if not g then return end
    if g.timer_active and not g.game_over then g.time = g.time + dt end
    card.update_particles(particles, dt)
    handle_input()
end

function render()
    local tc = card.current_theme
    vibege.render.clear(tc.bg[1], tc.bg[2], tc.bg[3], 1)
    if not g then return end

    -- Stock
    local sc = #g.stock > 0 and {0.2,0.3,0.6} or {0.2,0.2,0.2}
    vibege.render.draw_rect(px(0), ty(), CW, CH, sc[1], sc[2], sc[3], 0.5)
    if #g.stock > 0 then
        vibege.render.draw_text(px(0)+15, ty()+30, tostring(math.ceil(#g.stock/10)), 10, 0.8,0.8,0.9)
    end

    -- Tableau
    for col, pile in ipairs(g.tableau) do
        if #pile == 0 then
            vibege.render.draw_rect(px(col-1), ty(), CW, CH, tc.card_border[1], tc.card_border[2], tc.card_border[3], 0.15)
        else
            for i, c in ipairs(pile) do
                local y = card_y(col, i)
                -- Drop zone highlight
                if drag.active and drag.from ~= col then
                    local mc = g.tableau[drag.from] and g.tableau[drag.from][drag.idx]
                    if mc and can_move_to(mc, col) and (i == #pile or #pile == 0) then
                        vibege.render.draw_rect(px(col-1), y-2, CW, CH+4, tc.accent[1], tc.accent[2], tc.accent[3], 0.15)
                    end
                end
                card.draw_card(c, px(col-1), y, CW, CH)
            end
        end
    end

    -- Drag ghost
    if drag.active and g.tableau[drag.from] then
        local mx, my = vibege.input.mouse_position()
        local dx, dy = mx - drag.ox, my - drag.oy
        for i = drag.idx, #g.tableau[drag.from] do
            card.draw_card(g.tableau[drag.from][i], dx, dy + (i - drag.idx) * 22, CW, CH, 0.75)
        end
    end

    -- Particles
    card.draw_particles(particles)

    -- HUD
    local hud_y = sh - 18
    local hud = string.format("Score:%d Moves:%d Time:%s Done:%d/8 Undo:%d %d-Suit",
        g.score, g.moves, card.format_time(g.time), g.completed, #g.undo_stack, g.suits)
    local tm = "[T]heme:" .. table.concat({"felt","walnut","midnight","modern","carbon"}, "/", 1, 5)
    if card.hc then tm = tm .. " [C]HC" end
    vibege.render.draw_text(6, hud_y, hud, 7, tc.text[1], tc.text[2], tc.text[3])
    vibege.render.draw_text(sw - 8 - #tm * 6, 2, tm, 6, 0.5, 0.5, 0.5)

    -- Win screen
    if g.won then
        vibege.render.draw_rect(0, 0, sw, sh, tc.bg[1], tc.bg[2], tc.bg[3], 0.7)
        vibege.render.draw_text(sw/2-80, sh/2-30, "You Win!", 28, 1, 0.85, 0.2)
        vibege.render.draw_text(sw/2-100, sh/2+20,
            string.format("Score:%d Moves:%d Time:%s", g.score, g.moves, card.format_time(g.time)), 9, 1,1,1)
        vibege.render.draw_text(sw/2-70, sh/2+55, "[Space] New Game", 8, 0.7,0.7,0.7)
    end
end
