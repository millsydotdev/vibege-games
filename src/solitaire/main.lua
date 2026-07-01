-- Solitaire (Klondike) for VibeGE — AAA Polish Edition
-- Uses: card_shared (themes, drawing, particles, serialization, clone, deck)

local cs = require("lib.card_shared")

-- ─── State ───

local t = { hc = false, draw3 = true, seed = os.time() }
local game = nil
local anim = { cards = {}, flip = {}, deal = {}, particles = {} }
local drag = { active = false, from = nil, idx = nil, ox = 0, oy = 0, valid_zones = {} }
local sw, sh = 0, 0

-- ─── Config ───

local CW, CH = 64, 88
local MG = 8
local TOP = 56
local STOCK_Y = 12

-- ─── Helpers ───

cs.current_theme = cs.themes.felt
cs.hc = false
cs.card_back = 1

function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function lerp(a, b, t_) return a + (b - a) * t_ end

function px(i) return MG + i * (CW + 6) end

function tableau_card_pos(col, idx)
    return px(col - 1), TOP + (idx - 1) * 18
end

-- ─── Animation System ───

function anim_card(id, sx, sy, ex, ey, dur)
    anim.cards[id] = { sx=sx, sy=sy, ex=ex, ey=ey, t=0, dur=dur or 0.15, active=true }
end

function anim_flip(id, x, y, face_up)
    anim.flip[id] = { x=x, y=y, face_up=face_up, t=0, active=true }
end

function spawn_particles(x, y, count, color)
    cs.spawn_particles(anim.particles, x, y, count or 20, color)
end

function update_animations(dt)
    for k, v in pairs(anim.cards) do
        v.t = v.t + dt / v.dur
        if v.t >= 1 then v.t = 1; v.active = false end
    end
    for k, v in pairs(anim.flip) do
        v.t = v.t + dt / 0.2
        if v.t >= 1 then v.t = 1; v.active = false end
    end
    cs.update_particles(anim.particles, dt)
end

function get_card_pos(key)
    local a = anim.cards[key]
    if a and a.active then
        local t_ = a.t * (2 - a.t)
        return lerp(a.sx, a.ex, t_), lerp(a.sy, a.ey, t_)
    end
    return nil, nil
end

function get_flip_progress(key)
    local f = anim.flip[key]
    if f and f.active then return f.t end
    return nil
end

-- ─── Game Logic ───

function new_game()
    local d = cs.new_deck()
    t.seed = t.seed + os.time() % 7919
    cs.shuffle(d, t.seed)

    game = {
        stock = {}, waste = {},
        foundations = {{},{},{},{}},
        tableau = {{},{},{},{},{},{},{}},
        score = 0, moves = 0, time = 0, won = false, game_over = false,
        timer_active = true, draw_count = t.draw3 and 3 or 1,
        undo_stack = {}, redeals = 0, max_redeals = 2,
    }

    local idx = 1
    for col = 1, 7 do
        for row = 1, col do
            local c = d[idx]; idx = idx + 1
            if row == col then c.face_up = true end
            game.tableau[col][#game.tableau[col]+1] = c
        end
    end

    for i = idx, #d do game.stock[#game.stock+1] = d[i] end

    anim.cards = {}; anim.flip = {}; anim.particles = {}
    local deal_idx = 0
    for col = 1, 7 do
        for row = 1, col do
            deal_idx = deal_idx + 1
            local sx, sy = px(0), STOCK_Y
            local ex, ey = tableau_card_pos(col, row)
            if row == 1 then ey = TOP end
            anim_card("deal" .. deal_idx, sx, sy, ex, ey, 0.05 + deal_idx * 0.03)
        end
    end
end

function can_move_to_foundation(c, pile)
    if not c then return false end
    if #pile == 0 then return c.rank == "A" end
    local top = pile[#pile]
    return c.suit == top.suit and c.value == top.value + 1
end

function can_move_to_tableau(c, pile)
    if not c then return false end
    if #pile == 0 then return c.rank == "K" end
    local top = pile[#pile]
    return cs.red[c.suit] ~= cs.red[top.suit] and c.value == top.value - 1
end

function is_sequence(cards, idx)
    if idx >= #cards then return true end
    for i = idx, #cards-1 do
        local a, b = cards[i], cards[i+1]
        if not a.face_up or not b.face_up then return false end
        if cs.red[a.suit] == cs.red[b.suit] then return false end
        if a.value ~= b.value + 1 then return false end
    end
    return true
end

function save_state() return cs.clone(game) end

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
        for i = #game.waste, 1, -1 do
            game.waste[i].face_up = false
            game.stock[#game.stock+1] = game.waste[i]
        end
        game.waste = {}; game.redeals = game.redeals + 1; return
    end
    if #game.stock == 0 then return end
    local n = math.min(game.draw_count, #game.stock)
    for i = 1, n do
        local c = table.remove(game.stock)
        c.face_up = true
        game.waste[#game.waste+1] = c
    end
    game.moves = game.moves + 1
end

function waste_to_foundation()
    if #game.waste == 0 then return false end
    local c = game.waste[#game.waste]
    for i, f in ipairs(game.foundations) do
        if can_move_to_foundation(c, f) then
            push_undo(); table.remove(game.waste); f[#f+1] = c
            game.score = game.score + 10; game.moves = game.moves + 1; check_win()
            if game.won then spawn_particles(px(3+i), STOCK_Y, 50, {1,0.8,0.2}) end
            return true
        end
    end
    return false
end

function tableau_to_foundation(col)
    local pile = game.tableau[col]
    if not pile or #pile == 0 then return false end
    local c = pile[#pile]
    if not c.face_up then return false end
    for i, f in ipairs(game.foundations) do
        if can_move_to_foundation(c, f) then
            push_undo(); table.remove(pile); f[#f+1] = c
            if #pile > 0 then pile[#pile].face_up = true end
            game.score = game.score + 10; game.moves = game.moves + 1; check_win()
            if game.won then spawn_particles(px(3+i), STOCK_Y, 50, {1,0.8,0.2}) end
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
        local top = dst[#dst]; local c = src[from_idx]
        if cs.red[c.suit] == cs.red[top.suit] then return false end
        if c.value ~= top.value - 1 then return false end
    end
    push_undo()
    local count = #src - from_idx + 1
    for i = from_idx, #src do dst[#dst+1] = src[i] end
    for i = 1, count do table.remove(src) end
    if #src > 0 then src[#src].face_up = true end
    game.moves = game.moves + 1
    return true
end

function check_win()
    for _, f in ipairs(game.foundations) do if #f < 13 then return end end
    game.won = true; game.game_over = true; game.timer_active = false
    spawn_particles(sw/2, sh/2, 100, {1,0.9,0.3})
    spawn_particles(sw/2-100, sh/2, 80, {1,0.5,0.2})
    spawn_particles(sw/2+100, sh/2, 80, {0.3,0.8,1})
end

-- ─── Hints ───

function find_hints()
    local hints = {}
    if #game.waste > 0 then
        local c = game.waste[#game.waste]
        for col = 1, 7 do if can_move_to_tableau(c, game.tableau[col]) then hints[#hints+1]={type="waste_tableau",col=col} end end
        for _, f in ipairs(game.foundations) do if can_move_to_foundation(c, f) then hints[#hints+1]={type="waste_foundation"}; break end end
    end
    for col = 1, 7 do
        local pile = game.tableau[col]
        if #pile > 0 and pile[#pile].face_up then
            for _, f in ipairs(game.foundations) do
                if can_move_to_foundation(pile[#pile], f) then hints[#hints+1]={type="tableau_foundation",col=col}; break end
            end
        end
    end
    for from_col = 1, 7 do
        local src = game.tableau[from_col]
        for from_idx = 1, #src do
            local c = src[from_idx]
            if c.face_up and is_sequence(src, from_idx) then
                for to_col = 1, 7 do if from_col ~= to_col then
                    local dst = game.tableau[to_col]
                    if #dst == 0 then
                        if c.rank == "K" then hints[#hints+1]={type="move",from=from_col,idx=from_idx,to=to_col} end
                    else
                        local top = dst[#dst]
                        if cs.red[c.suit]~=cs.red[top.suit] and c.value==top.value-1 then hints[#hints+1]={type="move",from=from_col,idx=from_idx,to=to_col} end
                    end
                end end
            end
        end
    end
    return hints
end

function apply_hint(hint)
    if hint.type=="waste_foundation" then waste_to_foundation() end
    if hint.type=="tableau_foundation" then tableau_to_foundation(hint.col) end
    if hint.type=="waste_tableau" then
        if can_move_to_tableau(game.waste[#game.waste], game.tableau[hint.col]) then
            push_undo(); local c=table.remove(game.waste); game.tableau[hint.col][#game.tableau[hint.col]+1]=c; game.moves=game.moves+1
        end
    end
    if hint.type=="move" then move_cards(hint.from,hint.idx,hint.to) end
end

function auto_complete()
    for _=1,200 do
        local moved=false
        for col=1,7 do
            local pile=game.tableau[col]
            if pile and #pile>0 and pile[#pile].face_up then
                for _,f in ipairs(game.foundations) do
                    if can_move_to_foundation(pile[#pile],f) then
                        push_undo(); local c=table.remove(pile); f[#f+1]=c
                        if #pile>0 then pile[#pile].face_up=true end
                        game.score=game.score+10; moved=true; check_win(); break
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
        local h=find_hints()
        if #h==0 then break end
        local ok=false
        for _,v in ipairs(h) do if v.type=="waste_foundation" or v.type=="tableau_foundation" then apply_hint(v); ok=true; break end end
        if not ok then break end
    end
end

-- ─── Save / Load ───

function do_save()
    local ok,str=pcall(cs.serialize, game)
    if ok then pcall(function() vibege.save.save("solitaire",str) end) end
end

-- ─── Input ───

function handle_input()
    local mx,my=vibege.input.mouse_position()
    local clicked=vibege.input.is_mouse_pressed("left")
    local released=vibege.input.is_mouse_released("left")

    if vibege.input.is_key_pressed("z")and(vibege.input.is_key_down("lctrl")or vibege.input.is_key_down("rctrl"))then undo() end
    if vibege.input.is_key_pressed("h")then local h=find_hints();if #h>0 then apply_hint(h[1])end end
    if vibege.input.is_key_pressed("d")then auto_complete() end
    if vibege.input.is_key_pressed("a")then auto_complete_all() end
    if vibege.input.is_key_pressed("n")or vibege.input.is_key_pressed("r")then new_game() end
    if vibege.input.is_key_pressed("s")then do_save() end
    if vibege.input.is_key_pressed("u")then undo() end
    if vibege.input.is_key_pressed("1")then t.draw3=false;new_game() end
    if vibege.input.is_key_pressed("3")then t.draw3=true;new_game() end
    if vibege.input.is_key_pressed("t")then cs.cycle_theme() end
    if vibege.input.is_key_pressed("c")then cs.hc=not cs.hc; t.hc=cs.hc end
    if vibege.input.is_key_pressed("b")then cs.card_back=cs.card_back%5+1 end
    if vibege.input.is_key_pressed("escape")then game.game_over=true end

    if game.won or game.game_over then
        if vibege.input.is_key_pressed("n")or vibege.input.is_key_pressed("space")then new_game() end
        return
    end

    drag.valid_zones={}
    if drag.active then
        for col=1,7 do
            local pile=game.tableau[drag.from]
            if pile and drag.idx then
                local c=pile[drag.idx]
                if c then
                    local dst=game.tableau[col]
                    local valid=false
                    if #dst==0 then valid=c.rank=="K"
                    else local t_=dst[#dst];valid=cs.red[c.suit]~=cs.red[t_.suit]and c.value==t_.value-1 end
                    if valid then drag.valid_zones[col]=true end
                end
            end
        end
    end

    if clicked then
        local sx,sy=px(0),STOCK_Y
        if cs.pt_in_rect(mx,my,sx,sy,CW,CH)and #game.stock>0 then draw_from_stock();return end
        if #game.waste>0 then
            local wx,wy=px(1),STOCK_Y
            if cs.pt_in_rect(mx,my,wx,wy,CW,CH)then if waste_to_foundation()then return end end
        end
    end

    if clicked then
        for col=7,1,-1 do
            local pile=game.tableau[col]
            if #pile>0 then
                for i=#pile,1,-1 do
                    local c=pile[i]
                    if c.face_up or i==#pile then
                        local cy=TOP+(i-1)*18
                        if cs.pt_in_rect(mx,my,px(col-1),cy,CW,CH+18)then
                            if released or vibege.input.is_key_down("lshift")then
                                if tableau_to_foundation(col)then return end
                            end
                            if is_sequence(pile,i)then
                                drag.active=true;drag.from=col;drag.idx=i
                                drag.ox=mx-px(col-1);drag.oy=my-cy;return
                            end
                        end
                    end
                end
            end
        end
    end

    if released and drag.active then
        for col=1,7 do
            local ey=TOP
            if #game.tableau[col]>0 then ey=TOP+(#game.tableau[col]-1)*18 end
            if cs.pt_in_rect(mx,my,px(col-1),ey,CW,CH+18)then
                if move_cards(drag.from,drag.idx,col)then drag.active=false;return end
            end
        end
        drag.active=false
    end
end

-- ─── Main Loop ───

function init()
    sw,sh=vibege.runtime.screen_size().width,vibege.runtime.screen_size().height
    new_game()
    local ok,data=pcall(function()return vibege.save.load("solitaire")end)
    if ok and data then
        local g=cs.deserialize(data)
        if g and g.tableau then game=g end
    end
end

function update(dt)
    sw,sh=vibege.runtime.screen_size().width,vibege.runtime.screen_size().height
    if not game then return end
    if game.timer_active and not game.paused then game.time=game.time+dt end
    update_animations(dt)
    handle_input()
    if vibege.input.is_key_pressed("space")and not game.won then draw_from_stock()end
end

function render()
    local tc=cs.current_theme
    vibege.render.clear(tc.bg[1],tc.bg[2],tc.bg[3],1)
    if not game then return end

    -- Stock
    local sc=#game.stock>0 and{0.3,0.3,0.3}or{0.2,0.2,0.2}
    vibege.render.draw_rect(px(0),STOCK_Y,CW,CH,sc[1],sc[2],sc[3],0.5)
    if #game.stock>0 then vibege.render.draw_text(px(0)+20,STOCK_Y+35,tostring(#game.stock),8,0.7,0.7,0.7)end

    -- Waste
    if #game.waste>0 then cs.draw_card(game.waste[#game.waste],px(1),STOCK_Y,CW,CH)end

    -- Foundations
    for i=1,4 do
        local x=px(3+i)
        if #game.foundations[i]>0 then
            cs.draw_card(game.foundations[i][#game.foundations[i]],x,STOCK_Y,CW,CH)
        else
            local c=tc.card_border
            vibege.render.draw_rect(x,STOCK_Y,CW,CH,c[1],c[2],c[3],0.2)
            vibege.render.draw_text(x+20,STOCK_Y+35,({"♠","♥","♣","♦"})[i],10,c[1],c[2],c[3])
        end
    end

    -- Tableau
    for col,pile in ipairs(game.tableau)do
        for i,c in ipairs(pile)do
            local x,y=px(col-1),TOP+(i-1)*18
            if drag.valid_zones[col] and i==#pile then
                vibege.render.draw_rect(px(col-1),y-2,CW,CH+4,tc.accent[1],tc.accent[2],tc.accent[3],0.15)
            end
            cs.draw_card(c,x,y,CW,CH)
        end
    end

    -- Drag ghost
    if drag.active and game.tableau[drag.from]then
        local mx,my=vibege.input.mouse_position()
        local dx,dy=mx-drag.ox,my-drag.oy
        for i=drag.idx,#game.tableau[drag.from]do
            cs.draw_card(game.tableau[drag.from][i],dx,dy+(i-drag.idx)*18,CW,CH,0.75)
        end
    end

    -- Particles
    cs.draw_particles(anim.particles)

    -- HUD
    local hud_y=sh-20
    vibege.render.draw_text(10,hud_y,string.format("Score:%d Moves:%d Time:%s Undo:%d",game.score,game.moves,cs.format_time(game.time),#game.undo_stack),8,tc.text[1],tc.text[2],tc.text[3])
    local tm="[T]heme:"..cs.current_theme_name.." [B]back:"..cs.card_back
    if cs.hc then tm=tm.." [C]HC" end
    vibege.render.draw_text(sw-10-#tm*7,2,tm,7,0.5,0.5,0.5)

    -- Win screen
    if game.won then
        vibege.render.draw_rect(0,0,sw,sh,tc.bg[1],tc.bg[2],tc.bg[3],0.7)
        vibege.render.draw_text(sw/2-80,sh/2-20,"You Win!",24,1,0.8,0.2)
        vibege.render.draw_text(sw/2-100,sh/2+20,string.format("Score:%d Moves:%d Time:%s",game.score,game.moves,cs.format_time(game.time)),10,1,1,1)
        vibege.render.draw_text(sw/2-80,sh/2+50,"[Space] New Game",8,0.7,0.7,0.7)
    end
end
