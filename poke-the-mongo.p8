pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- poke the mongo, v0.4
-- <me@lmorchard.com>

-- todos:
-- sound effects
-- music
-- better baddie placement
-- better baddie ai with chase mode if detected
-- disruptive power ups
--   gps scramble,
--   server ddos,
--   lure module
-- better map
-- grass rustling?
-- baddies with frustration < 25% can spawn new baddies via recommendation
-- random pauses in dodge ball throws, so player can fire off abilities
-- p*kestops
--   attract players, they gravitate toward them when out of balls
--   can spawn a lure module, spawns a bunch of temporary short-lived baddies

scenes = {
 overworld=1,
 encounter=2,
 encounter_start=3,
 encounter_end=4,
 encounter_escape=5,
 encounter_free=6,
 game_over=7,
 title_screen=8,
 game_won=9
}

current_scene = scenes.title_screen

challenge = {
 encounter_hurt=3,
 escape_hurt_per_tick=0.2,
 dodge_hurt=-2,
 bounce_hurt=-5,
 escape_chance=0.05,
 encounter_stun=60,
 no_balls_frustration=10,
 escape_frustration=10,
 encounter_end_frustration=5,
 dodge_frustration=10,
 bounce_frustration=20
}

map_x_max = 128 * 8
map_y_max = 32 * 8

baddie_layers = {
 {73,74,75,76},
 {68,69,70},
 {71,72}
}

frustration_factors = {
 s73=1.5,
 s74=1.25,
 s75=1.25,
 s76=1.0
}

ball_throws = {
 {3,6},
 {0,1,2},
 {4,5}
}

sprites = {
 player=64,
	ball=67,
 balloon=93,
 title=128
}

directions = {
 { 0,-1}, -- n
 { 1, 0}, -- e
 { 0, 1}, -- s
 {-1, 0}  -- w
}

tiledirections = {4,5,6,7}

stun_colors = {8,14}
hurt_colors = {9,8}
frustration_colors = {8,9,10}
smoke_colors = {7, 6, 13, 5, 1}

dodgex_pos = {0,28,58}
dodgey_pos = {64,96,118}

cam_x = 0
cam_y = 0

ball = {}
baddies = {}

baddie_scan_range = 14

quitting_steps_start = 30
quitting_colors = {0,5,13,6,7}
quitting_replace_colors = {1,2,4,9,8,10,12,15}

function _init()
 reset_player()
 init_baddies()
 // current_scene = scenes.title_screen
 current_scene = scenes.overworld
end

function _update()
 if current_scene == scenes.overworld then
  update_overworld()
 elseif current_scene == scenes.encounter then
 	update_encounter()
 elseif current_scene == scenes.encounter_start then
 	update_encounter_start()
 elseif current_scene == scenes.encounter_end then
 	update_encounter_end()
 elseif current_scene == scenes.encounter_escape then
 	update_encounter_escape()
 elseif current_scene == scenes.encounter_free then
 	update_encounter_free()
 elseif current_scene == scenes.game_over then
 	update_game_over()
 elseif current_scene == scenes.title_screen then
 	update_title_screen()
 elseif current_scene == scenes.game_won then
 	update_game_won()
 end
end

function _draw()
 if current_scene == scenes.overworld then
 	draw_overworld()
 elseif current_scene == scenes.encounter then
 	draw_encounter()
 elseif current_scene == scenes.encounter_start then
 	draw_encounter_start()
 elseif current_scene == scenes.encounter_end then
 	draw_encounter_end()
 elseif current_scene == scenes.encounter_escape then
 	draw_encounter_escape()
 elseif current_scene == scenes.encounter_free then
 	draw_encounter_free()
 elseif current_scene == scenes.game_over then
 	draw_game_over()
 elseif current_scene == scenes.title_screen then
 	draw_title_screen()
 elseif current_scene == scenes.game_won then
 	draw_game_won()
 end
end

function reset_player()
	player = {
 	x=64,
  y=64,
  dx=0,
  dy=0,
  dfriction=0.15,
  sprite_idx=0,
  moving=0,
  facing=false,
 	health=75,
  hurt=0,
 	dodgeh=2,
  dodgev=2
	}
end

function init_baddies()
 make_baddie(12, 12)
 make_baddie(24, 12)
 make_baddie(36, 12)
 make_baddie(48, 12)
 make_baddie(12, 24)
 make_baddie(12, 36)
 make_baddie(12, 48)
end

function make_baddie(x,y)
 local dir = pick(directions)
 local t = {
  x=x, y=y,
  dx=dir[1], dy=dir[2],
  spd=0.4, ttm=rnd(30),
 	cr=rnd(9), stun=0,
 	sf=0,
 	sprites={},
 	balls=flr(rnd(6)),
  frustration=0,
  frustration_anim_steps=0,
  quitting=false,
  quitting_steps=0
 }

 for l = 1,count(baddie_layers) do
 	add(t.sprites, pick(baddie_layers[l]))
 end

 t.frustration_factor = frustration_factors['s' .. t.sprites[1]]

 add(baddies, t)
 return t
end

function update_baddie(t)
 local ox = t.x
 local oy = t.y

 if t.quitting then
  if t.quitting_steps > 0 then
   t.quitting_steps -= 1
  else
   del(baddies, t)
  end
  return
 end

 t.x = min(128, max(0, t.x + t.dx*t.spd))
 t.y = min(128, max(0, t.y + t.dy*t.spd))

 update_baddie_scan(t)

 if not can_go(t.x,t.y) then
 	t.x = ox
 	t.y = oy
 end

 t.ttm -= 1
 if t.ttm < 1 then
 	t.ttm = rnd(30) + 90

 	local options = {}
 	for idx = 1,4 do
   if fget(find_tile_under(t.x,t.y), tiledirections[idx]) then
   	add(options, directions[idx])
			end
 	end

	 local d = pick(options)
		if d then
		 t.dx = d[1]
		 t.dy = d[2]
	 end
 end
end

function draw_baddie(t)
 if t.quitting then
  local perc = t.quitting_steps / quitting_steps_start
  local clr = quitting_colors[flr(count(quitting_colors) * perc) + 1]
  for idx = 1,count(quitting_replace_colors)  do
   pal(quitting_replace_colors[idx],clr)
  end
 end
 for idx = 1,count(t.sprites) do
   spr(t.sprites[idx], t.x, t.y, 1, 2, false, false)
 end
 if t.quitting then
  pal()
 end
end

function update_baddie_scan(t)
 if t.stun > 0 then
 	t.stun -= 1
 	t.balls = flr(rnd(6))
 else
  t.cr = ((t.cr + 0.3) % 12)
	end
end

function draw_baddie_scan(t)
 if t.quitting then
  return
 end

 local cx = t.x+3
 local cy = t.y+13

 if t.stun > 0 then
  local clr = stun_colors[flr(1+((t.stun/6)%count(stun_colors)))]
  circ(cx,cy,5,clr)
 else
  local clr = (t.cr < 9) and 5 or 7
  circ(cx,cy,t.cr,clr)
 end
end

function update_player()
	local opx = player.x
	local opy = player.y

 if btn(0) then
  player.dx = -1
  player.facing = false
 elseif btn(1) then
  player.dx = 1
  player.facing = true
 end

 if btn(2) then
  player.dy = -1
 elseif btn(3) then
  player.dy = 1
 end

 if player.dx < 0 then player.dx += player.dfriction end
 if player.dx > 0 then player.dx -= player.dfriction end
 player.dx = round10(player.dx)

 if player.dy < 0 then player.dy += player.dfriction end
 if player.dy > 0 then player.dy -= player.dfriction end
 player.dy = round10(player.dy)

 player.moving = (player.dx != 0 or player.dy != 0) and 0.2 or 0

 player.x = max(0, min(map_x_max, player.x + player.dx))
 player.y = max(0, min(map_y_max, player.y + player.dy))

 if not can_go(player.x,player.y) then
 	player.x = opx
 	player.y = opy
 end

 for idx = 1,count(baddies) do
  baddie = baddies[idx]
 	if baddie_in_range(baddie, player.x+4, player.y+4) then
 	 init_encounter_start(baddie)
 	 break
 	end
 end

end

function draw_player()
 player.sprite_idx = (player.sprite_idx + player.moving) % 3
 spr(sprites.player + flr(player.sprite_idx),
     player.x, player.y,
     1, 1,
     player.facing, false)
end

function draw_map()
 map(0, 0, 0, 0, 128, 32)
end

function move_camera_with_player()
 cam_x = min(895, max(0, player.x-64))
 cam_y = min(127, max(0, player.y-64))
 camera(cam_x, cam_y)
end

function draw_hud()
 camera()
 draw_hud_health()
end

function draw_hud_health()
 rect(1,1,126,4,0)
 local clr
 if player.hurt > 0 then
 	player.hurt -= 1
 	clr = hurt_colors[flr(rnd(count(hurt_colors))+1)]
	else
	 clr = hurt_colors[1]
 end
 rectfill(2,2,125*(player.health/100),3,clr)
end

cloud_colors = {7, 6, 13, 5, 1, 0}

game_rnd_seed = rnd(100000)
sky_rnd_seed = rnd(100)

function draw_clouds()
 camera()

 cam_x = min(895, max(0, player.x-64) / 7)
 cam_y = min(127, max(0, player.y-64) / 7)
 camera(cam_x, cam_y)

 game_rnd_seed = rnd(100000)
 srand(sky_rnd_seed)

 for x=1,128,4 do
  for y=1,128,4 do
   if (rnd(100) < 2) then
    local width = 5 + rnd(15)

    line(x+2, y,   x+width,   y,   6)
    line(x+1, y+1, x+width+1, y+1, 6)
    line(x+3, y+2, x+width-1, y+2, 6)

    line(x+2, y-2, x+width-2, y-2, 7)
    line(x+1, y-1, x+width-1, y-1, 7)
    line(x,   y,   x+width,   y,   7)
    line(x+2, y+1, x+width-2, y+1, 7)
   end
  end
 end

 srand(game_rnd_seed)
end

function update_overworld()
 foreach(baddies, update_baddie)
	update_player()
 if count(baddies) == 0 then
  init_game_won()
 end
end

function draw_overworld()
 cls()
 move_camera_with_player()
 draw_map()
 foreach(baddies, draw_baddie_scan)
 foreach(baddies, draw_baddie)
 draw_player()
 draw_clouds()
 draw_hud()
end

encounter = {}

function init_encounter_start(baddie)
	encounter.baddie = baddie
 hurt_player(challenge.encounter_hurt)
 encounter.step = -16
 if (encounter.baddie.balls < 1) then
  pick_baddie_speech('outofballs')
  frustrate_baddie(encounter.baddie, challenge.no_balls_frustration)
 else
  pick_baddie_speech('start')
 end
 current_scene = scenes.encounter_start
end

function update_encounter_start()
 encounter.step += 1
 update_encounter_player()
 if encounter.step > 30 then
  init_encounter()
 end
end

function draw_encounter_start()
 if encounter.step < 0 then
  draw_encounter_splash()
 else
  camera()
  draw_encounter_backdrop()
  draw_encounter_baddie()
  draw_encounter_player()
  draw_baddie_speech()
  draw_encounter_hud()
 end
end

function init_encounter()
 current_scene = scenes.encounter
 throw_ball()
end

function update_encounter()
 update_encounter_player()
 update_ball()
 if encounter.baddie.frustration >= 100 then
  init_encounter_end()
 end
end

function draw_encounter()
 camera()
 draw_encounter_backdrop()
 draw_encounter_baddie()
 draw_baddie_speech()
 draw_encounter_hud()
 draw_ball()
 draw_encounter_player()
end

function update_encounter_player()
 if btn(0) then player.dodgeh = 1
 elseif btn(1) then player.dodgeh = 3
 else	player.dodgeh = 2 end

 if btn(2) then player.dodgev = 1
 elseif btn(3) then player.dodgev = 3
 else player.dodgev = 2 end

 if not ball.bouncing and ball.target == 2 and btn(2) then
  if ball.pos > 80 and ball.pos < 95 then
   -- Tap up exactly when the ball is 80-95% down the middle, it will bounce!
   bounce_ball()
  elseif ball.pos > 50 and ball.pos < 80 then
   -- But, tap up too early, and you get captured.
   init_encounter_escape()
  end
 end
end

function draw_encounter_player()
 zspr(sprites.player,
 			  1, 1,
      dodgex_pos[player.dodgeh],
      dodgey_pos[player.dodgev],
      8)
end

function draw_encounter_backdrop()
 rectfill(0, 0, 128, 42, 12)
 rectfill(0, 42, 128, 63, 11)
 rectfill(0, 63, 128, 128, 3)
end

function throw_ball()
 if encounter.baddie.balls < 1 then
	 init_encounter_end()
 else
  encounter.baddie.balls -= 1
  ball.pos = 0
  ball.bouncing = false
  ball.target = flr(rnd(3)) + 1
  ball.throw = pick(ball_throws[ball.target])
  pick_baddie_speech('throw')
 end
end

function update_ball()
 if ball.bouncing then
  ball.bouncing_step -= 3
  if ball.bouncing_step <= 0 then
   resolve_ball()
  end
 else
  ball.pos += 3
  if ball.pos >= 100 then
   resolve_ball()
  end
 end
end

function bounce_ball()
 ball.bouncing = true
 ball.bouncing_step = 85
 ball.bouncing_dir = flr(rnd(3))
 hurt_player(challenge.bounce_hurt)
 frustrate_baddie(encounter.baddie, challenge.bounce_frustration)
end

function resolve_ball()
 if ball.bouncing and ball.bouncing_step <= 0 then
  ball_dodged()
 elseif ball.target == 1 and player.dodgeh != 3 then
  init_encounter_escape()
 elseif ball.target == 2 and player.dodgev != 3 then
  init_encounter_escape()
 elseif ball.target == 3 and player.dodgeh != 1 then
  init_encounter_escape()
 else
  ball_dodged()
 end
end

function ball_dodged()
 frustrate_baddie(encounter.baddie, challenge.dodge_frustration)
 hurt_player(challenge.dodge_hurt)
 throw_ball()
end

function draw_ball()
 local perc
 if ball.bouncing then
  perc = ball.bouncing_step/100
 else
  perc = ball.pos/100
 end

 local bx = 66 - sin(0.5 * perc*0.25) * 28
 local by = 50 + (sin(0.125 + (perc*0.5)) - sin(0.125)) * 66
 local bz = sin(0.5 * perc*0.25) * 8

 if ball.bouncing then
  if ball.bouncing_dir <= 1 then
   bx += (sin(0.25 + perc*0.25)) * 48
  else
   bx += (sin(0.75 + perc*0.25)) * 48
  end
 elseif ball.throw == 0 then
  -- straight middle
	elseif ball.throw == 1 then
  -- curve left to middle
  bx += sin(perc*0.5) * 48
	elseif ball.throw == 2 then
  -- curve right to middle
  bx += sin(0.5 + perc*0.5) * 48
	elseif ball.throw == 3 then
  -- curve left to left
  bx += sin(perc*0.125) * 56
	elseif ball.throw == 4 then
  -- curve right to right
  bx += (1+sin(0.25 + perc*0.25)) * 56
	elseif ball.throw == 5 then
  -- curve left to right
  bx += sin(perc*0.75) * 56
	elseif ball.throw == 6 then
  -- curve right to left
  bx += (sin(1-(perc*0.75))) * 56
 end

 zspr(sprites.ball, 1, 1, bx, by, bz)
end

function draw_encounter_baddie()
 t = encounter.baddie

 -- Baddies shake with frustration!
 local df = 12 * (t.frustration / 100)
 local bx = 56
 local by = 30
 if t.frustration_anim_steps > 0 then
  t.frustration_anim_steps -= 1

 	bx += (df/2) - rnd(df)
 	by += (df/2) - rnd(df)
 end

 for idx = 1,count(t.sprites) do
		 zspr(t.sprites[idx], 1, 2, bx, by, 2)
 end
end

function init_encounter_escape()
 encounter.escape_x = 32
 encounter.escape_y = 92
 encounter.escape_chance = challenge.escape_chance
 pick_baddie_speech('escape')
 current_scene = scenes.encounter_escape
end

function update_encounter_escape()
 hurt_player(challenge.escape_hurt_per_tick)

 local escaping = false

 if btn(0) then
  encounter.escape_x = 32 - rnd(16)
  escaping = true
 elseif btn(1) then
  encounter.escape_x = 32 + rnd(16)
  escaping = true
 else
  encounter.escape_x = 32
 end

 if btn(2) then
  encounter.escape_y = 92 - rnd(8)
  escaping = true
 elseif btn(3) then
  encounter.escape_y = 92 + rnd(8)
  escaping = true
 else
  encounter.escape_y = 92
 end

 if escaping and rnd(1) < encounter.escape_chance then
  frustrate_baddie(encounter.baddie, challenge.escape_frustration)
  init_encounter_free()
 end
end

function draw_encounter_escape()
 camera()
 draw_encounter_backdrop()
 draw_encounter_baddie()
 draw_baddie_speech()
 draw_encounter_hud()
 zspr(sprites.ball, 1, 1, encounter.escape_x, encounter.escape_y, 8)
end

function init_encounter_free()
 current_scene = scenes.encounter_free
 encounter.step = 0
 encounter.smoke = {}
 for idx = 1,8+flr(rnd(16)) do
  make_encounter_smoke(64, 100)
 end
 pick_baddie_speech('free')
end

function update_encounter_free()
 encounter.step += 1
 foreach(encounter.smoke, update_smoke)
 if encounter.step > 45 then
  throw_ball()
  current_scene = scenes.encounter
 end
end

function draw_encounter_free()
 draw_encounter_backdrop()
 draw_encounter_baddie()
 draw_baddie_speech()
 draw_encounter_hud()
 zspr(sprites.ball, 1, 1, encounter.escape_x, encounter.escape_y, 8)
 foreach(encounter.smoke, draw_smoke)
end

function init_encounter_end()
 ball.target = 0
 encounter.end_step = 0
 encounter.baddie.cr = 0
 encounter.baddie.stun = challenge.encounter_stun
 encounter.smoke = {}
 for idx = 1,3+flr(rnd(10)) do
  make_encounter_smoke(60, 120)
 end
 frustrate_baddie(encounter.baddie, challenge.encounter_end_frustration)
 pick_baddie_speech('theend')
	current_scene = scenes.encounter_end
end

function update_encounter_end()
 encounter.end_step += 1
 foreach(encounter.smoke, update_smoke)
 if encounter.end_step > 30 then
  current_scene = scenes.overworld
 end
end

function draw_encounter_end()
 camera()
 draw_encounter_backdrop()
 draw_encounter_baddie()
 draw_baddie_speech()
 foreach(encounter.smoke, draw_smoke)
 draw_encounter_hud()
end

function make_encounter_smoke(bx, by)
 local s = {
  x=bx  + (5-rnd(10)),
  y=by - rnd(5),
  r=rnd(15),
  active=true,
  ttl=rnd(40),
  c=pick(smoke_colors)
 }
 add(encounter.smoke, s)
 return s
end

function update_smoke(s)
 if not s.active then
  return
 end
 s.x += 2 - rnd(4)
 s.y += 2 - rnd(4)
 s.r += 2 - rnd(4)
 s.ttl -= 1
 if s.ttl <= 0 then
  s.active = false
 end
end

function draw_smoke(s)
 if (s.active) then
  circfill(s.x, s.y, s.r, s.c)
 end
end

function draw_baddie_speech()
 rectfill(2, 7, 125, 27, 7)
 zspr(sprites.balloon, 1, 1, 72, 20, 2)
 print(encounter.baddie_speech, 6, 12, 0)
end

function draw_encounter_splash()
 move_camera_with_player()
 local step = encounter.step + 16
 local cx = encounter.baddie.x+3
 local cy = encounter.baddie.y+13
 if step < 8 then
  circ(cx,cy,step*3,8)
 else
  circ(cx,cy,(step-8)*3,7)
 end
 draw_hud()
end

function draw_encounter_hud_balls()
 local nb = encounter.baddie.balls
 local bx = 56 - (5 * nb)
 local by = 44
 for idx=1,nb do
  spr(sprites.ball, bx + (10 * idx), by)
 end
end

function draw_encounter_hud()
 draw_hud()
 draw_encounter_hud_balls()
end

function pick_baddie_speech(kind)
 levels = speech[kind]
 msgs = levels[flr((encounter.baddie.frustration/100) * count(levels)) + 1]
 if msgs then
  encounter.baddie_speech = pick(msgs)
 end
end

game_over = {step=0}

function init_game_over()
 game_over.step = 0
 current_scene = scenes.game_over
end

function update_game_over()
 game_over.step += 1
 if btn(5) or btn(4) then
  _init()
 end
end

function draw_game_over()
 cls()
 print('you were caught. \nrest awhile, then x to try again', 1, 1)
end

title_screen = {step=0}

function init_title_screen()
 title_screen.step = 0
 current_scene = scenes.title_screen
end

function update_title_screen()
 title_screen.step += 1
 if btn(5) or btn(4) then
  reset_player()
  current_scene = scenes.overworld
 end
end

function draw_title_screen()
 cls()
 zspr(sprites.title, 4, 4, 16, 4, 3)
 print('x to start', 48, 110)
end

game_won = {step=0}

function init_game_won()
 game_won.step = 0
 current_scene = scenes.game_won
end

function update_game_won()
 game_won.step += 1
 if btn(5) or btn(4) then
  _init()
 end
end

function draw_game_won()
 cls()
 print('you won! this screen sucks!', 1, 1)
end

function baddie_in_range(t,x,y)
 if t.stun > 0 then
 	return false
 end
 dist = (x - (t.x + 3))^2 +
        (y - (t.y + 13))^2
 range = t.cr^2
 return (dist - range) < 7
end

function hurt_player(amt)
 player.health -= amt
	player.hurt = 25
 if player.health <= 0 then
  player.health = 0
  init_game_over()
 elseif player.health > 100 then
  player.health = 100
 end
end

function frustrate_baddie(t, amt)
 t.frustration += amt * t.frustration_factor
 t.frustration_anim_steps = 30
 if t.frustration >= 100 then
  t.frustration = 100
  t.quitting = true
  t.quitting_steps = quitting_steps_start
 end
end

function find_tile_under(x,y)
 return mget((x+4)/8,(y+8)/8)
end

function can_go(x, y)
 return fget(find_tile_under(x,y),3)
end

-- http://pico-8.wikia.com/wiki/draw_zoomed_sprite_(zspr)
function zspr(n,w,h,dx,dy,dz)
 sx = 8 * (n % 16)
 sy = 8 * flr(n / 16)
 sw = 8 * w
 sh = 8 * h
 dw = sw * dz
 dh = sh * dz
 sspr(sx,sy,sw,sh, dx,dy,dw,dh)
end

function pick(items)
	return items[flr(rnd(count(items))) + 1]
end

function round10(num)
 return ((num>0) and flr(num * 100) or -flr(-num * 100)) / 100
end

speech = {
 start={
  {"i haven't seen you before!",
   "interesting, a new critter!",
   "wow, you're adorable!",
   "so cute! can i keep it?"},
  {"another chance to catch you!",
   "let's try this again."},
  {"this one is hard to catch.",
   "you're slippery!"},
  {"ugh, you again."},
  {"this #$%^ thing is impossible!"}
 },
 outofballs={
  {"i need something to throw",
   "i should collect items"},
  {"guess i ran out of balls",
   "where are my balls?"},
  {"caught me empty handed!",
   "did you know i was out?"},
  {"now you're just taunting me!",
   "ugh, go away."},
  {"this game is rigged!",
   "pay to win garbage"}
 },
 throw={
  {"am i doing this right?",
   "how about this angle?",
   "do i throw it like this?"},
  {"practice makes perfect!",
   "i think i might be improving!",
   "wow, nice moves!"},
  {"playing hard to get?",
   "should it move like that?",
   "okay, now that's not fair!"},
  {"take this!",
   "get in the ball!",
   "stop moving so i can hit you!",
   "stop cheating!"},
  {"nobody can hit this thing!",
   "omg hax!",
   "@#$%^&*! @#$%^&*! @#$%^&*!"}
 },
 escape={
  {"i hope it stays in there!"},
  {"maybe it'll stay this time?"},
  {"c'mon c'mon c'mon \ndon't bust out!"},
  {"that's right! \nyou stay in there!"},
  {"stay in there, you #$%^er"}
 },
 free={
  {"oh no, it got out?"},
  {"guess i'll just keep trying!"},
  {"escaped again?!"},
  {"is there some trick to this?"},
  {"$%^&! it broke out!"}
 },
 theend={
  {"oh well, maybe next time."},
  {"crud, it got away!"},
  {"get back here!"},
  {"didn't want it anyway."},
  {"@#$% this game!",
   "this game is boring anyway",
   "game over, man!"}
 }
}

__gfx__
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000000bbbbbbbbaaaaaaaaaaaaaaaabbbbbaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbaaaaaabbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaabbbbbaaaaaaaaaaaaaaaa
00000000bbbbbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
00000000bbbbbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
b3b3b3b3bbbbbb3b3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
3b3b3b3bb3bbbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
b3b3b3b3bbb3b3bbaaaaaaaaaaaaaaaabbbbba3333aaaaaaaaaaaa3333abbbbbbbbbba3333abbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaabbbbbaaaaaa3333aaaaaa
3b3b3b3bb3bbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbb
b3b3b3b3bbbbbb3bbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbb
3b3b3b3bb3bb3bbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbb
b3b3b3b3bb3bbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbb
3b3b3b3bbbbbb3bbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbba3333abbbbb
bbbbba3333abbbbbaaaaaa3333aaaaaabbbbba3333aaaaaaaaaaaa3333abbbbbbbbbba3333abbbbbbbbbba3333aaaaaaaaaaaa3333abbbbbaaaaaa3333aaaaaa
bbbbba3333abbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
bbbbba3333abbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
bbbbba3333abbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
bbbbba3333abbbbb3333333333333333bbbbba33333333333333333333abbbbbbbbbba3333abbbbbbbbbba33333333333333333333abbbbb3333333333333333
bbbbba3333abbbbbaaaaaa3333aaaaaabbbbbaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbaaaaaabbbbbbbbbba3333aaaaaaaaaaaa3333abbbbbaaaaaaaaaaaaaaaa
bbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbb
bbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbbbbbbba3333abbbbbbbbbbbbbbbbbbbbb
000aaaa9000aaaa9000aaaa90088880008888800011111000aaaaa00000000000000000000ffff00004444000999990005555500000000000000000000000000
00aaaa9000aaaa9000aaaa90088888808888888811111111aaaaaaaa00000000000000000ffffff0044444409999fff055554440000000000000000000000000
0a1aa1a90a1aa1a90a1aa1a9888558888880000011100000aaa0000000000000000000000ffff3f00444414099fff3f055444340000000000000000000000000
0aaaaaa90aaaaaa90aaaaaa9885775888000000010000000a000000000000000000000000ffffff0044444409ffffff054444440000000000000000000000000
00a11a9000a11a9000a11a907757757700000000000000000000000000000000000000000ffffff0044444409ffffff054444440000000000000000000000000
000aa900000aa900000aa90077755777000000000000000000000000000000000000000000ffff000044440099ffff0055444400000000000000000000000000
000a9a9000a90a9000a9a9000777777000000000000000000000000000020200000c0c00000fff0000044400990fff0055044400000000000000000000000000
00aa9aa90aa90aa90aa9aa9000777700000000000000000000000000022600600cc60060000fff0000044400090fff0005044400000000000000000000000000
0000000000000000000000000000000000008800000011000000aa0022260060ccc6006000000000000000000000000000000000777777770000000000000000
0000000000000000000000000000000000008800000011000000aa0022260060ccc6006000000000000000000000000000000000777777770000000000000000
0000000000000000000000000000000000008800000011000000aa0022220020cccc00c000000000000000000000000000000000777777770000000000000000
0000000000000000000000000000000000000000000000000000000029999990c444444000000000000000000000000000000000777777770000000000000000
000000000000000000000000000000000000000000000000000000000111111001111110f000000040000000f000000040000000777777770000000000000000
00000000000000000000000000000000000000000000000000000000010001000100010000000000000000000000000000000000007777000000000000000000
00000000000000000000000000000000000000000000000000000000010001000100010000000000000000000000000000000000007770000000000000000000
00000000000000000000000000000000000000000000000000000000010001000100010000000000000000000000000000000000077700000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333333333333
bb333333333333bbb3333333333333bbbb333333333333bbb33333bbbbbbbbbbbbbbbbbbb33333bbb33333bbb33333bbb3333333333333bb3333333333333333
bb3333333333331bb33333333333331bbb3333333333331bb333331bb33333bbb33333bbb33333bbb333331bb333331bb33333333333331b3333333333333333
bb3333333333331bb33333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
bb3333333333331bb33333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
bb3333333333331bb33333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
bbb111111111111bbb1111111111111bbbb111111111111bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
b3333333333333bbbb333333333333bbbb333333333333bbb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
b33333333333331bbb3333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
b33333333333331bbb3333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
b33333333333331bbb3333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
b33333333333331bbb3333333333331bbb3333333333331bb333331bb333331bb333331bb333331bb333331bb333331bb33333333333331b3333333333333333
bb1111111111111bbbb111111111111bbbb111111111111bbb11111bbb11111bbb11111bbb11111bbb11111bbb11111bbb1111111111111b3333333333333333
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1aaaaaaaaa1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1aaaaaaaaaa110001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
111aaa1111aa10001aa1111a10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001aaa1001aa100011a111a110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001aaa1111aa100001a11aa100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001aaaaaaaa1100001aa1a1101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001aaaaa1100111111aa1a1011aaa100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001aaa1110011aaa11aaaa101a111a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0011aa100011a11aa1aa11101aaaaa10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001aa10001aa111a1aaa1111aa11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011110001aa01aa11aaaa11aa11a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000011000001aaaa111a111a1aaaaaa1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000011111101100111aaaa111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000001111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666660600606666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006000600606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006000666606666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006000600606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006000600606666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c10000c10ccc10c100c100cc000ccc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc000cc1c100c0cc00c10c11c1c100c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c0c1c1c100c1c1c1c1c10000c100c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c10c10c1c100c1c10cc1c10cc1c100c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c10000c1c100c1c100c10c00c1c100c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c10000c10ccc10c100c100cc100ccc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
00f8a8a86868c8c8484828288888e8e8f8f8a8a86868c8c8484828288888e8e85858f8f83838989818187878d8d8b8b85858f8f83838989818187878d8d8b8b802020202000000000000000000020202020002000000000000000000000202020000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
04050607666768696a6b6667666711111101016c6d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14151617767778797a7b7677767711111101017c7d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
24252223222322232223222322230e0f0607016c6d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34353233323332333233323332331e1f1617017c7d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10102021666768696a68696668692a2b2c2d016c6d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10103031767778797a78797678793a3b3c3d017c7d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10102a2b0e0f02030203020302032c2d2021016c6d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10103a3b1e1f12131213121312133c3d3031017c7d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0b2e2f2e2f02030203020202032e2f2627016c6d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1a1b3e3f3e3f12131213121212133e3f3637017c7d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d6c6d6c6d6c6d6c6d6c6d6c6d6c6d6c6d6c6d6c6d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7d7c7d7c7d7c7d7c7d7c7d7c7d7c7d7c7d7c7d7c7d0101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
