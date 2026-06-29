-- Pong — VibeGE Reference Game
-- Validates: input, render, audio, suspension, game loop, particles

local player_y = 250
local ai_y = 250
local ball_x = 400
local ball_y = 300
local ball_vx = 300
local ball_vy = 150
local paddle_h = 100
local paddle_w = 15
local ball_sz = 10
local pl_score = 0
local ai_score = 0
local sw = 800
local sh = 600
local particles = {}
local shake = 0

function init()
    math.randomseed(os.time())
    print("Pong started — Escape to exit")
end

function update(dt)
    -- Player
    if vibege.input.is_key_down("w") then player_y = player_y - 400 * dt end
    if vibege.input.is_key_down("s") then player_y = player_y + 400 * dt end

    -- AI
    local target = ball_y - paddle_h / 2
    local speed = 250
    if ai_y + paddle_h / 2 < ball_y then ai_y = ai_y + speed * dt
    elseif ai_y + paddle_h / 2 > ball_y then ai_y = ai_y - speed * dt end

    -- Ball
    ball_x = ball_x + ball_vx * dt
    ball_y = ball_y + ball_vy * dt

    if shake > 0 then shake = shake - dt * 20 end

    -- Particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 500 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    -- Wall bounce
    if ball_y <= ball_sz or ball_y >= sh - ball_sz then
        ball_vy = -ball_vy
        emit(ball_x, ball_y, 3, 0.5, 0.7, 1.0)
        if vibege.audio and vibege.audio.play_bounce then vibege.audio.play_bounce() end
    end

    -- Player hit
    if ball_x <= paddle_w + ball_sz and ball_y >= player_y and ball_y <= player_y + paddle_h and ball_vx < 0 then
        ball_vx = -ball_vx * 1.08
        ball_vy = ball_vy + (ball_y - (player_y + paddle_h / 2)) * 60
        shake = 3; emit(ball_x, ball_y, 8, 1, 1, 1)
        if vibege.audio and vibege.audio.play_hit then vibege.audio.play_hit() end
    end

    -- AI hit
    if ball_x >= sw - paddle_w - ball_sz and ball_y >= ai_y and ball_y <= ai_y + paddle_h and ball_vx > 0 then
        ball_vx = -ball_vx * 1.08
        ball_vy = ball_vy + (ball_y - (ai_y + paddle_h / 2)) * 60
        shake = 3; emit(ball_x, ball_y, 8, 1, 1, 1)
        if vibege.audio and vibege.audio.play_hit then vibege.audio.play_hit() end
    end

    -- Scoring
    if ball_x < 0 then
        ai_score = ai_score + 1; reset(-300); emit(ball_x, ball_y, 20, 1, 0.3, 0.3); shake = 6
        if vibege.audio and vibege.audio.play_score then vibege.audio.play_score() end
    elseif ball_x > sw then
        pl_score = pl_score + 1; reset(300); emit(ball_x, ball_y, 20, 0.3, 1, 0.3); shake = 6
        if vibege.audio and vibege.audio.play_score then vibege.audio.play_score() end
    end

    player_y = math.max(0, math.min(sh - paddle_h, player_y))
    ai_y = math.max(0, math.min(sh - paddle_h, ai_y))
end

function render()
    local sx, sy = 0, 0
    if shake > 0 then
        if math.random(0, 1) == 0 then sx = -shake else sx = shake end
        if math.random(0, 1) == 0 then sy = -shake else sy = shake end
    end

    vibege.render.clear(0.05, 0.05, 0.12, 1)

    -- Centre line
    vibege.render.draw_rect(sw / 2 - 2 + sx, 0 + sy, 4, sh, 0.15, 0.15, 0.25, 1)

    -- Particles
    for _, p in ipairs(particles) do
        vibege.render.draw_rect(p.x + sx, p.y + sy, p.sz, p.sz, p.r, p.g, p.b, p.life)
    end

    -- Paddles
    vibege.render.draw_rect(10 + sx, player_y + sy, paddle_w, paddle_h, 1, 1, 1, 1)
    vibege.render.draw_rect(sw - paddle_w - 10 + sx, ai_y + sy, paddle_w, paddle_h, 1, 1, 1, 1)

    -- Ball
    vibege.render.draw_rect(ball_x - ball_sz / 2 + sx, ball_y - ball_sz / 2 + sy, ball_sz, ball_sz, 1, 1, 1, 1)
end

function suspend()
    vibege.render.clear(0, 0, 0, 1)
end

function resume() end
function restore_state(s) end

function get_state()
    return pl_score .. "," .. ai_score .. "," .. ball_x .. "," .. ball_y
end

function reset(dir)
    ball_x = sw / 2; ball_y = sh / 2; ball_vx = dir; ball_vy = math.random(1, 400) - 200
end

function emit(x, y, n, r, g, b)
    for i = 1, n do
        table.insert(particles, {
            x = x, y = y, vx = math.random(1, 400) - 200, vy = math.random(1, 400) - 200,
            sz = math.random(3, 6), life = math.random(20, 70) / 100, r = r, g = g, b = b
        })
    end
end
