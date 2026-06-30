--- Shared Card Framework for VibeGE Solitaire games.
-- Provides deck operations, rendering, hit testing, and animation.

local CardFramework = {}

-- Constants
CardFramework.SUITS = { "hearts", "diamonds", "clubs", "spades" }
CardFramework.RANK_NAMES = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
CardFramework.RANK_VALUES = { A = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["10"] = 10, J = 11, Q = 12, K = 13 }

local SUIT_SYMBOLS = { hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠" }

-- Card colors
local function suit_color(suit)
    if suit == "hearts" or suit == "diamonds" then return { 0.9, 0.1, 0.1 } end
    return { 0.1, 0.1, 0.1 }
end

--- Create a new card.
function CardFramework.new_card(suit, rank, face_up)
    return {
        suit = suit,
        rank = rank,
        value = CardFramework.RANK_VALUES[rank] or 0,
        face_up = face_up or false,
        id = suit .. "_" .. rank,
    }
end

--- Create a standard 52-card deck.
function CardFramework.new_deck(shuffled)
    local deck = {}
    for _, suit in ipairs(CardFramework.SUITS) do
        for _, rank in ipairs(CardFramework.RANK_NAMES) do
            table.insert(deck, CardFramework.new_card(suit, rank, false))
        end
    end
    if shuffled then CardFramework.shuffle(deck) end
    return deck
end

--- Fisher-Yates shuffle.
function CardFramework.shuffle(deck)
    for i = #deck, 2, -1 do
        local j = math.random(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

--- Deal a card from the top of a deck.
function CardFramework.deal(deck, face_up)
    if #deck == 0 then return nil end
    local card = table.remove(deck)
    if face_up ~= nil then card.face_up = face_up end
    return card
end

--- Peek at the top card without removing.
function CardFramework.peek(deck)
    return deck[#deck]
end

--- Draw the back of a card.
function CardFramework.draw_card_back(x, y, w, h)
    vibege.render.draw_rect(x, y, w, h, 0.2, 0.3, 0.6, 1.0)
    vibege.render.draw_rect(x + 2, y + 2, w - 4, h - 4, 0.25, 0.35, 0.7, 1.0)
    vibege.render.draw_rect(x + 4, y + 4, w - 8, h - 8, 0.3, 0.4, 0.8, 1.0)
    -- Inner diamond pattern
    local cx, cy = x + w / 2, y + h / 2
    vibege.render.draw_rect(cx - 8, cy - 2, 16, 4, 0.5, 0.6, 0.9, 1.0)
    vibege.render.draw_rect(cx - 2, cy - 8, 4, 16, 0.5, 0.6, 0.9, 1.0)
end

--- Draw a card (face up).
function CardFramework.draw_card(card, x, y, w, h, selected)
    if not card.face_up then
        CardFramework.draw_card_back(x, y, w, h)
        return
    end

    -- Card background
    local bg = 1.0
    if selected then
        vibege.render.draw_rect(x - 2, y - 2, w + 4, h + 4, 0.8, 0.8, 0.2, 1.0)
    end
    vibege.render.draw_rect(x, y, w, h, bg, bg, bg, 1.0)
    vibege.render.draw_rect(x, y, w, 1, 0.7, 0.7, 0.7, 1.0)
    vibege.render.draw_rect(x, y + h - 1, w, 1, 0.7, 0.7, 0.7, 1.0)

    -- Suit symbol + rank
    local color = suit_color(card.suit)
    local symbol = SUIT_SYMBOLS[card.suit]
    local rank_str = card.rank
    local sz = w / 6

    -- Top-left rank
    vibege.render.draw_text(x + 3, y + 2, rank_str, sz, color[1], color[2], color[3])
    -- Top-left suit
    vibege.render.draw_text(x + 3, y + 2 + sz + 1, symbol, sz * 0.7, color[1], color[2], color[3])
    -- Center suit (large)
    vibege.render.draw_text(x + w / 2 - sz, y + h / 2 - sz, symbol, sz * 2, color[1], color[2], color[3])
    -- Bottom-right (inverted)
    vibege.render.draw_text(x + w - sz * 3 - 3, y + h - sz - sz * 0.7 - 3, rank_str, sz, color[1], color[2], color[3])
    vibege.render.draw_text(x + w - sz * 3 - 3, y + h - sz - 3, symbol, sz * 0.7, color[1], color[2], color[3])
end

--- Draw an empty card slot.
function CardFramework.draw_empty_slot(x, y, w, h)
    vibege.render.draw_rect(x, y, w, h, 0.15, 0.15, 0.25, 0.5)
    vibege.render.draw_rect(x + 2, y + 2, w - 4, h - 4, 0.1, 0.1, 0.2, 0.3)
end

--- Hit test: check if a point is inside a card rectangle.
function CardFramework.hit_test(px, py, cx, cy, cw, ch)
    return px >= cx and px <= cx + cw and py >= cy and py <= cy + ch
end

--- Hit test for a pile (tableau column) where cards overlap vertically.
function CardFramework.hit_test_pile(px, py, cards, base_x, base_y, card_w, card_h, overlap_y)
    if #cards == 0 then
        if CardFramework.hit_test(px, py, base_x, base_y, card_w, card_h) then
            return 0 -- empty pile clicked
        end
        return -1
    end

    -- Check from top to bottom
    for i = #cards, 1, -1 do
        local cy = base_y + (i - 1) * overlap_y
        if i == #cards then cy = base_y + (#cards - 1) * overlap_y end
        if i == 1 then
            -- First card uses larger hit area when face down or up
            if CardFramework.hit_test(px, py, base_x, base_y, card_w, card_h + (#cards - 1) * overlap_y) then
                return i
            end
        elseif CardFramework.hit_test(px, py, base_x, cy, card_w, card_h) then
            return i
        end
    end
    return -1
end

--- Simple animation: return interpolated position.
function CardFramework.animate(t_start, duration, from_x, from_y, to_x, to_y)
    local elapsed = (vibege.runtime and vibege.runtime.tick and (os.clock() or 0) or 0) - t_start
    local t = math.min(elapsed / duration, 1)
    local eased = t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
    local cx = from_x + (to_x - from_x) * eased
    local cy = from_y + (to_y - from_y) * eased
    return cx, cy, t >= 1
end

return CardFramework
