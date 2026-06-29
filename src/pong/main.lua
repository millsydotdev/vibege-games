-- Pong — Reference implementation for VibeGE
-- Validates: input, render, game loop, collision, scoring

local player_y = 250
local ai_y = 250
local ball_x = 400
local ball_y = 300
local ball_vx = 300
local ball_vy = 150
local paddle_height = 100
local paddle_width = 15
local ball_size = 10
local player_score = 0
local ai_score = 0
local screen_w = 800
local screen_h = 600

function init()
    print("Pong started!")
end

function update(dt)
    -- Player movement
    if vibege.input.is_key_down("w") then
        player_y = player_y - 400 * dt
    end
    if vibege.input.is_key_down("s") then
        player_y = player_y + 400 * dt
    end

    -- AI movement
    local ai_target = ball_y - paddle_height / 2
    local ai_speed = 250
    if ai_y + paddle_height / 2 < ball_y then
        ai_y = ai_y + ai_speed * dt
    elseif ai_y + paddle_height / 2 > ball_y then
        ai_y = ai_y - ai_speed * dt
    end

    -- Ball movement
    ball_x = ball_x + ball_vx * dt
    ball_y = ball_y + ball_vy * dt

    -- Ball wall collision
    if ball_y <= ball_size or ball_y >= screen_h - ball_size then
        ball_vy = -ball_vy
    end

    -- Ball paddle collision (player)
    if ball_x <= paddle_width + ball_size
        and ball_y >= player_y
        and ball_y <= player_y + paddle_height
        and ball_vx < 0 then
        ball_vx = -ball_vx * 1.1
        ball_vy = ball_vy + (ball_y - (player_y + paddle_height / 2)) * 50
    end

    -- Ball paddle collision (AI)
    if ball_x >= screen_w - paddle_width - ball_size
        and ball_y >= ai_y
        and ball_y <= ai_y + paddle_height
        and ball_vx > 0 then
        ball_vx = -ball_vx * 1.1
        ball_vy = ball_vy + (ball_y - (ai_y + paddle_height / 2)) * 50
    end

    -- Scoring
    if ball_x < 0 then
        ai_score = ai_score + 1
        ball_x = screen_w / 2
        ball_y = screen_h / 2
        ball_vx = 300
        ball_vy = 150
    elseif ball_x > screen_w then
        player_score = player_score + 1
        ball_x = screen_w / 2
        ball_y = screen_h / 2
        ball_vx = -300
        ball_vy = -150
    end

    -- Clamp paddles
    player_y = math.max(0, math.min(screen_h - paddle_height, player_y))
    ai_y = math.max(0, math.min(screen_h - paddle_height, ai_y))
end

function render()
    vibege.render.clear(0, 0, 0, 1)

    -- Centre line
    vibege.render.draw_rect(screen_w / 2 - 2, 0, 4, screen_h, 0.3, 0.3, 0.3, 1)

    -- Paddles
    vibege.render.draw_rect(10, player_y, paddle_width, paddle_height, 1, 1, 1, 1)
    vibege.render.draw_rect(screen_w - paddle_width - 10, ai_y, paddle_width, paddle_height, 1, 1, 1, 1)

    -- Ball
    vibege.render.draw_rect(ball_x - ball_size / 2, ball_y - ball_size / 2, ball_size, ball_size, 1, 1, 1, 1)

    -- Score
    -- (Text rendering to be added in a future update)
end
