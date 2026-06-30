-- Overlay Test — 4 large white digits on dark blue background
-- Verifies: overlay window on top, rect rendering works, auto-close after 5s

local sw, sh = 800, 600
local code = {}
local elapsed = 0
local cell = 30  -- size of each pixel block in the font

-- 5x7 pixel font for digits 0-9
local font = {}
font[0] = {1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1}
font[1] = {0,0,1,0,0, 0,1,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0}
font[2] = {1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 1,1,1,1,1, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1}
font[3] = {1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 1,1,1,1,1}
font[4] = {1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 0,0,0,0,1}
font[5] = {1,1,1,1,1, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 1,1,1,1,1}
font[6] = {1,1,1,1,1, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1}
font[7] = {1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 0,0,0,0,1, 0,0,0,0,1, 0,0,0,0,1, 0,0,0,0,1}
font[8] = {1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1}
font[9] = {1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1, 0,0,0,0,1, 0,0,0,0,1, 1,1,1,1,1}

function init()
    math.randomseed(os.time())
    for i = 1, 4 do code[i] = math.random(0, 9) end
    local str = ""
    for i = 1, 4 do str = str .. code[i] end
    print("CODE: " .. str)
    print("Window: " .. sw .. "x" .. sh .. " overlay mode")
end

function draw_digit(d, x, y, sz)
    local pattern = font[d]
    for row = 0, 6 do
        for col = 0, 4 do
            if pattern[row * 5 + col + 1] == 1 then
                local px = x + col * sz
                local py = y + row * sz
                vibege.render.draw_rect(px, py, sz - 1, sz - 1, 1, 1, 1, 1)
            end
        end
    end
end

function update(dt)
    elapsed = elapsed + dt
    if elapsed > 5 then
        -- Signal exit by causing a Lua error that runtime handles
        error("auto-close", 0)
    end
end

function render()
    vibege.render.clear(0.05, 0.05, 0.15, 1)

    -- Draw "CODE:" label above the digits
    local label = "CODE:"
    local label_x = (sw - 5 * 5 * cell) / 2
    local label_y = sh / 2 - 4 * cell
    for i = 1, 5 do
        local c = string.byte(label, i)
        local idx = c - 48  -- '0' = 48 in ASCII, but 'C','O','D','E',':' are different
        -- Just draw label as a visual indicator
    end

    -- Draw code label using letter C
    local letter_c = {1,1,1,1,1, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1}
    local letter_o = {1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,1}
    local letter_d = {1,1,1,1,0, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 1,1,1,1,0}
    local letter_e = {1,1,1,1,1, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,1}
    local colon   = {0,0,0,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,0,0,0}

    local letters = {letter_c, letter_o, letter_d, letter_e, colon}
    local label_start_x = (sw - 5 * 5 * cell - 4 * cell) / 2
    local label_start_y = sh / 2 - 5 * cell

    for li = 1, 5 do
        local lx = label_start_x + (li - 1) * (5 * cell + cell)
        local lpat = letters[li]
        for row = 0, 6 do
            for col = 0, 4 do
                if lpat[row * 5 + col + 1] == 1 then
                    vibege.render.draw_rect(lx + col * cell, label_start_y + row * cell, cell - 1, cell - 1, 0.3, 0.5, 0.9, 1)
                end
            end
        end
    end

    -- Draw the 4 code digits below "CODE:"
    local digit_start_x = (sw - 4 * 5 * cell - 3 * cell) / 2
    local digit_start_y = sh / 2 + cell

    for i = 1, 4 do
        local dx = digit_start_x + (i - 1) * (5 * cell + cell)
        draw_digit(code[i], dx, digit_start_y, cell)
    end

    -- Bottom instruction line
    vibege.render.draw_rect(sw/2 - 80, sh - 30, 160, 3, 0.3, 0.5, 0.8, 1)
end
