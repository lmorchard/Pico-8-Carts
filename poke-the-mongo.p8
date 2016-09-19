pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- poke the mongo, v0.9
-- <me@lmorchard.com>

-- todos:
-- music
-- difficulty tuning & level select
-- better baddie ai with chase mode if detected
-- disruptive power ups
--   server ddos,
--   lure module
-- grass rustling?
-- baddies with frustration < 25% can spawn new baddies via recommendation
-- lightning-based ability during encounters
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

sounds = {
 candy_get=63,
 thunderstorm=62,
 encounter_start=61,
 ball_thrown=60,
 ball_bounce=59,
 ball_miss=58,
 captured=57,
 escaped=56,
 encounter_end=55,
 struggle=54
}

overworld_map_tiles_w = 32
overworld_map_tiles_h = 32

overworld_map_max_x = overworld_map_tiles_w * 8
overworld_map_max_y = overworld_map_tiles_h * 8

current_scene = scenes.title_screen

challenge = {
 min_baddies=10,
 max_baddies=20,
 encounter_hurt=2,
 escape_hurt_per_tick=0.1,
 dodge_hurt=-5,
 bounce_hurt=-10,
 escape_chance=0.05,
 encounter_stun=60,
 no_balls_frustration=10,
 escape_frustration=10,
 encounter_end_frustration=5,
 dodge_frustration=10,
 bounce_frustration=20,
 lightning_health_min=80,
 lightning_max_duration=3*30,
 lightning_health_cost=75/(3*30),
 lightning_frustration=20/(3*30),
 candy_hurt=-10,
 max_candy=3,
 candy_spawn_chance=1
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
 title=128,
 candy=83
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

cloud_target_num = 75 * 2
cloud_max_x = 256
cloud_max_y = 256
cloud_max_layers = 4
cloud_colors = {7, 6, 13, 5, 1, 0}
cloud_parallax = 2
cloud_wind = 1
cloud_layers = 2
clouds_per_health = 10
clouds_wind_per_health = 2

function _init()
 reset_player()
 init_candy()
 init_baddies()
 init_clouds()
 init_title_screen()
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
 local coords = pick_passable_tile()
	player = {
 	x=coords[1],
  y=coords[2],
  dx=0,
  dy=0,
  dfriction=0.15,
  accel=1.5,
  sprite_idx=0,
  moving=0,
  facing=false,
 	health=50,
  hurt=0,
 	dodgeh=2,
  dodgev=2,
	}
end

function init_baddies()
 place_baddies()
end

function place_baddies()
 local num_baddies = challenge.min_baddies + flr(rnd(challenge.max_baddies - challenge.min_baddies))
 for idx = 1,num_baddies do
  local coords = pick_passable_tile()
  make_baddie(coords[1] + 4, coords[2] + 4)
 end
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

 if lightning.active then
  frustrate_baddie(t, challenge.lightning_frustration)
  cause_lightning_stun(t)
 end

 t.x = min(overworld_map_max_x, max(0, t.x + t.dx*t.spd))
 t.y = min(overworld_map_max_y, max(0, t.y + t.dy*t.spd))

 update_baddie_scan(t)

 if not passable_tile_at(t.x,t.y) then
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
   spr(t.sprites[idx], t.x - 3, t.y - 15, 1, 2, false, false)
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

 local cx = t.x
 local cy = t.y

 if t.stun > 0 then
  local clr = stun_colors[flr(1+((t.stun/6)%count(stun_colors)))]
  circ(cx,cy,5,clr)
 else
  local clr = (t.cr < 9) and 5 or 7
  circ(cx,cy,t.cr,clr)
 end
end

lightning = {
 active=false,
 duration=0
}

function cause_lightning_stun(b)
  b.stun = challenge.encounter_stun / 2
end

function update_player()
	local opx = player.x
	local opy = player.y

 if btn(0) then
  player.dx = -player.accel
  player.facing = false
 elseif btn(1) then
  player.dx = player.accel
  player.facing = true
 end

 if btn(2) then
  player.dy = -player.accel
 elseif btn(3) then
  player.dy = player.accel
 end

 if lightning.active then
  lightning.duration -= 1
  hurt_player(challenge.lightning_health_cost)
  if lightning.duration <= 0 then
   lightning.active = false
   foreach(baddies, cause_lightning_stun)
  end
 elseif player.health > challenge.lightning_health_min and (btn(4) or btn(5)) then
  sfx(sounds.thunderstorm)
  lightning.duration = challenge.lightning_max_duration
  lightning.active = true
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

 if not passable_tile_at(player.x,player.y) then
 	player.x = opx
 	player.y = opy
 end

 for idx = 1,count(baddies) do
  baddie = baddies[idx]
 	if baddie_in_range(baddie, player.x, player.y) then
 	 init_encounter_start(baddie)
 	 break
 	end
 end
end

function draw_player()
 player.sprite_idx = (player.sprite_idx + player.moving) % 3
 spr(sprites.player + flr(player.sprite_idx),
     player.x - 3, player.y - 7,
     1, 1,
     player.facing, false)
end

function draw_map()
 pal()
 if lightning.active and rnd(100) < 80 then
  pal(3, 1)
  pal(11, 3)
 end
 map(0, 0, 0, 0, 32, 32)
end

function move_camera_with_player()
 cam_x = min(overworld_map_max_x-128, max(0, player.x-64))
 cam_y = min(overworld_map_max_y-128, max(0, player.y-64))
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

baddie_hud_radius = 12

function draw_hud_baddies()
 foreach(baddies, draw_one_hud_baddie)
end

function draw_one_hud_baddie(b)
 local r = atan2(b.y - player.y, b.x - player.x)
 local x = 0
 local y = 0 - baddie_hud_radius
 local rx = cos(r) * x - sin(r) * y
 local ry = sin(r) * x - cos(r) * y
 local color
 if b.quitting then
  color = rnd(1) < 0.5 and 0 or 1
 elseif b.stun > 0 then
  color = rnd(1) < 0.5 and 8 or 9
 else
  color = rnd(1) < 0.5 and 9 or 10
 end
 pset(rx + player.x, ry + player.y - 2, color)
end

function init_clouds()
 clouds = {}
 cloud_target_num = 150
 for i=1,cloud_target_num do
  place_cloud(false)
 end
end

function make_cloud(x,y,w,d)
 local c = {x=x, y=y, w=w, d=d}
 add(clouds, c)
 return c
end

function place_cloud(left_edge)
 local w = flr(rnd(10))+5
 local x
 if left_edge then
  x = 0 - w*2
 else
  x = flr(rnd(overworld_map_max_x * cloud_parallax))
 end
 local y = flr(rnd(overworld_map_max_y * cloud_parallax))
 local d = rnd(0.3)
 make_cloud(x, y, w, d)
end

function update_clouds()
 cloud_layers = (player.health / 100) * (cloud_max_layers+1)
 cloud_wind = (player.health / 100) * clouds_wind_per_health
 cloud_target_num = player.health * clouds_per_health
 if lightning.active then
  cloud_target_num *= 1.5
 end
 if count(clouds) < cloud_target_num and rnd(100) < 20 then
  place_cloud(true)
 end
 foreach(clouds, update_cloud)
end

function update_cloud(c)
 c.x += (cloud_wind * c.d)
 if c.x > (overworld_map_max_x*cloud_parallax + c.w) then
  if count(clouds) > cloud_target_num and rnd(100) < 50 then
   del(clouds, c)
  else
   c.x = 0 - c.w
  end
 end
end

function draw_clouds()
 camera()
 camera(cam_x * cloud_parallax, cam_y * cloud_parallax)
 foreach(clouds, draw_cloud)
end

function draw_cloud(c)
 local cloud_cam_x = cam_x * cloud_parallax
 local cloud_cam_y = cam_y * cloud_parallax

 -- skip off-camera clouds
 if c.x < cloud_cam_x - c.w or
    c.x > cloud_cam_x + 128 or
    c.y < cloud_cam_y or
    c.y > cloud_cam_y + 128 then
  return
 end

 pal()

 if lightning.active and rnd(1) < .1 then
  pal(7, 12)
  pal(6, 10)
  pal(5, 13)
  pal(13, 14)
 end

 local x = c.x
 local y = c.y
 local w = c.w
 local layers = cloud_layers

 if layers >= 3 then
  line(x+1, y-3, x+w-3, y-3, 13)
  line(x+0, y-2, x+w-2, y-2, 13)
  line(x-1, y-1, x+w-1, y-1, 13)
  line(x+1, y,   x+w-3, y,   13)
 end

 if layers >= 2 then
  line(x+2, y,   x+w,   y,   6)
  line(x+1, y+1, x+w+1, y+1, 6)
  line(x+3, y+2, x+w-1, y+2, 6)
 end

 if layers >= 1 then
  line(x+2, y-2, x+w-2, y-2, 7)
  line(x+1, y-1, x+w-1, y-1, 7)
  line(x,   y,   x+w,   y,   7)
  line(x+2, y+1, x+w-2, y+1, 7)
 end

 if layers >= 4 then
  line(x+1, y-2, x+w-2, y-2, 5)
  line(x+0, y-1, x+w-1, y-1, 5)
  line(x-1, y-0, x+w-0, y-0, 5)
  line(x+1, y+1, x+w-2, y+1, 5)
 end

 pal()
end

candy = {}

function make_candy(x,y)
 local c = { x=x, y=y, t=rnd(1), dt=0.03 }
 add(candy, c)
 return c
end

function init_candy()
end

function update_candy(c)
 if count(candy) < challenge.max_candy and rnd(100) < challenge.candy_spawn_chance then
  local coords = pick_passable_tile()
  make_candy(coords[1]+4, coords[2]+4)
 end
 foreach(candy, update_one_candy)
end

function update_one_candy(c)
 c.t = (c.t + c.dt) % 1
 if distk(c.x, c.y, player.x, player.y) < (8/1000) then
  sfx(sounds.candy_get)
  hurt_player(challenge.candy_hurt)
  del(candy, c)
 end
end

function draw_candy(c)
 spr(sprites.candy, c.x, c.y + (cos(c.t) * 1.5), 1, 1, false, false)
end

function init_overworld()
 current_scene = scenes.overworld
 music(0)
end

function update_overworld()
 update_candy()
 foreach(baddies, update_baddie)
	update_player()
 if count(baddies) == 0 then
  init_game_won()
 end
 update_clouds()
end

function draw_overworld()
 cls()
 move_camera_with_player()
 draw_map()

 foreach(candy, draw_candy)
 foreach(baddies, draw_baddie_scan)
 foreach(baddies, draw_baddie)
 draw_player()
 draw_hud_baddies()
 draw_clouds()
 draw_hud()
end

encounter = {}

function init_encounter_start(baddie)
 music(-1)  -- todo: need encounter music
 sfx(sounds.encounter_start)
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
  if ball.pos > 75 and ball.pos < 95 then
   -- tap up exactly when the ball is 75-95% down the middle, it will bounce!
   bounce_ball()
  elseif ball.pos > 50 and ball.pos < 65 then
   -- but, tap up too early, and you get captured.
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
  sfx(sounds.ball_thrown)
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
 sfx(sounds.ball_bounce)
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
 sfx(sounds.ball_miss)
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

 -- baddies shake with frustration!
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
 sfx(sounds.captured)
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

 if escaping and rnd(1) < 0.3 then
  sfx(sounds.struggle)
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
 sfx(sounds.escaped)
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
 sfx(sounds.encounter_end)
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
  init_overworld()
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
 local cx = encounter.baddie.x
 local cy = encounter.baddie.y
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
 camera()
 draw_hud_health()
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
 music(15)
end

function update_title_screen()
 title_screen.step += 1
 if btn(5) or btn(4) then
  reset_player()
  init_overworld()
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
 dist = distk(x, y, t.x, t.y)
 range = t.cr / 1000
 return dist < range
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
 return mget(x/8,y/8)
end

function passable_tile_at(x, y)
 return fget(find_tile_under(x,y),3)
end

function pick_passable_tile()
 local x = 0
 local y = 0
 repeat
  x = flr(rnd(overworld_map_max_x/8))*8
  y = flr(rnd(overworld_map_max_y/8))*8
 until passable_tile_at(x,y)
 return {x,y}
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

-- http://pico-8.wikia.com/wiki/known_bugs
function distk(x0,y0,x1,y1)
 local dx=x0/1000-x1/1000
 local dy=y0/1000-y1/1000
 local dsq=dx^2+dy^2

 if dsq>0 then
  return sqrt(dsq)
 elseif dsq==0 then
  return 0
 else
  --shouldn't happen
  return 32727
 end
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
000aaaa9000aaaa9000aaaa90088880008888800011111000aaaaa00000000000000000000ffff00004444000999990005555500000000003333333300000000
00aaaa9000aaaa9000aaaa90088888808888888811111111aaaaaaaa00000000000000000ffffff0044444409999fff055554440000000003333333300000000
0a1aa1a90a1aa1a90a1aa1a9888558888880000011100000aaa0000000000000000000000ffff3f00444414099fff3f055444340000000003333333300000000
0aaaaaa90aaaaaa90aaaaaa9885775888000000010000000a000000000000000000000000ffffff0044444409ffffff054444440000000003333333300000000
00a11a9000a11a9000a11a907757757700000000000000000000000000000000000000000ffffff0044444409ffffff054444440000000003333333300000000
000aa900000aa900000aa90077755777000000000000000000000000000000000000000000ffff000044440099ffff0055444400000000003333333300000000
000a9a9000a90a9000a9a9000777777000000000000000000000000000020200000c0c00000fff0000044400990fff0055044400000000003333333300000000
00aa9aa90aa90aa90aa9aa9000777700000000000000000000000000022600600cc60060000fff0000044400090fff0005044400000000003333333300000000
aaaaaaaa333333333333333300aaa90000008800000011000000aa0022260060ccc6006000000000000000000000000000000000777777770000000000000000
3333333333333333333333330aaaaa9000008800000011000000aa0022260060ccc6006000000000000000000000000000000000777777770000000000000000
333333333333333333333333aaeaeaa900008800000011000000aa0022220020cccc00c000000000000000000000000000000000777777770000000000000000
333333333333333333333333aeeeeea900000000000000000000000029999990c444444000000000000000000000000000000000777777770000000000000000
333333333333333333333333aaeeeaa90000000000000000000000000111111001111110f000000040000000f000000040000000777777770000000000000000
333333333333333333333333aaaeaaa9000000000000000000000000010001000100010000000000000000000000000000000000007777000000000000000000
3333333333333333333333330aaaaa90000000000000000000000000010001000100010000000000000000000000000000000000007770000000000000000000
33333333aaaaaaaa3333333300aaa900000000000000000000000000010001000100010000000000000000000000000000000000077700000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbba3333abbbbb
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
00f8a8a86868c8c8484828288888e8e8f8f8a8a86868c8c8484828288888e8e85858f8f83838989818187878d8d8b8b85858f8f83838989818187878d8d8b8b80202020200000000000000000002f802f8f8f8020000000000000000000202020000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
04050203020e0f0302030e050203020e0f0302030e0f0203020e0f0302030607000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14151213121e1f1312131e151213121e1f1312131e1f1213121e1f1312131617000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021666766202167666720216667662021676667303166676620216766672021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031767776303177767730317677763031777677202176777630317776773031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021666766202167666720216667662021676667303166676620216766672021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031767776303177767730317677763031777677202176777630317776773031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2b020302222303020322230203022e2f030203222302030222230302032c2d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
141512131232331312131e151213123e3f1312131e1f12131232331312131617000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021666766202167666720211111111111111111303166676620216766672021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031767776303177767730311111111111111111202176777630317776773031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20216667662829676667202111111111111111112a2b020c0d28290a02032c2d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30317677763839777677303111111111111111113a3b121c1d38391a12133c3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20216c6d6c6d6c6d6c6d20216c6d6c6d6c6d6c6d20216c6d660809666c6d2021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30317c7d7c7d7c7d7c7d30317c7d7c7d7c7d7c7d30317c7d761819767c7d3031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2e2f03020302030203022223020302030203020222230302032e2f0203022e2f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5151515151515151515151515151515151515151515151515151515151515151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5252525252525252525252525252525252525252525252525252525252525252000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e1f121312131213121332331213121213121312323312131213121312131e1f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20216c6d6c6d6c6d6c6d20216c6d6c6d6c6d6c6d20216c6d6c6d6c6d6c6d2021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30317c7d7c7d7c7d7c7d30317c7d7c7d7c7d7c7d30317c7d7c7d7c7d7c7d3031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2b030203020302030222230302030e0f020302222303020302030203022c2d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3a3b131213121312131232331312131e1f121312323313121312131213123c3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021666766676667666720216667662021676667303166676667666766672021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031767776777677767730317677763031777677202176777677767776773031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a2b030203020302030222230203022e2f03020322230203020e0f0302032c2d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3a3b121312131213121332331213123e3f13121332331213121e1f1312133c3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021111111111111111120216667666766676667303166676628296766672021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031111111111111111130317677767776777677202176777638397776773031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021111111111111111120216667666766676667303166676608096766672021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031111111111111111130317677767776777677202176777618197776773031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
242502030203020302032e2f02030203020302032e2f0203022e2f0302032627000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343512131213121312133e3f12131213121312133e3f1213123e3f1312133637000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010c00000005024000000502410000050243000005000200000502400000050241000005024300000500020000050240000005024100000502430000050002000005024000000502410000050243000005000200
010c00000a050000000a050000000a050000000a050090000a050000000a050000000a050000000a0500c0500a050000000a050000000a050000000a050090000a050000000a050000000a0500c0000a05009000
010c0000000501620000050241000005024300000500020000050240000005024100000500e000000500205000050000000005000100000500030000050002000005024000000502410000050243000005000200
010c00000805000000080500000008050000000805000000080500000008050000000805000000080500000008050000000805000000080500000008050000000805000000080500000008050000000805000000
010c00001825018250182501825018250182501325013250132501325013250132501325013250132501325013250132501325013250182501825018250182501d2501d2501d2501d2501c2501c2501c2501c250
010c00001d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501d2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c250
010c00001625016250162501625016250162501625016250162501625016250162501625016250162501625016250162501625016250162501625016250162501625016250162501625016250162501625016250
010c00000c053000030c0030c0030c0530000300003000030c0530000300003000030c0530000300003000030c0530000300003000030c0530000300003000030c0530000300003000030c053000030000300003
010c00001a2501a2501a2501a2501a2501a25015250152501525015250152501525015250152501525015250152501525015250152501a2501a2501a2501a2501f2501f2501f2501f2501e2501e2501e2501e250
010c00001f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501f2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e2501e250
010c00000205024000020502410002050243000205000200020502400002050241000205024300020500405002050240000205024100020502430002050002000205024000020502410002050243000205000200
010c00001c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c2501c250
010c00001322013220132201322013220132201022010220102201022010220102201022010220102201022010220102201022010220132201322013220132201d2201d2201d2201d2201c2201c2201c2201c220
010c00001622016220162201622016220162201622016220162201622016220162201622016220162201622018220182201822018220182201822018220182201822018220182201822018220182201822018220
010c00001322013220132201322013220132201322013220132201322013220132201322013220132201322013220132201322013220132201322013220132201322013220132201322013220132201322013220
010c00001522015220152201522015220152201222012220122201222012220122201222012220122201222012220122201222012220152201522015220152201f2201f2201f2201f2201e2201e2201e2201e220
010c0000182201822018220182201822018220182201822018220182201822018220182201822018220182201a2201a2201a2201a2201a2201a2201a2201a2201a2201a2201a2201a2201a2201a2201a2201a220
010c00001822018220182201822018220182201822018220182201822018220182201822018220182201822018220182201822018220182201822018220182201822018220182201822018220182201822018220
010c00000c05300003306030c003306253060300003000030c053000030000300003306250000300003000030c053000030000300003306250000300003000030c05300003306250000330603306033062500003
010c00000c05300003306030c003306253060300003000030c053000030000300003306250000300003000030c053000030000300003306250000300003000030c05300003306050000330625306033060500003
010c00001d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d33222332223322233222332223322233222332223322133221332213322133221332213322133221332
010c00001f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321c3321c3321c3321c3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f3321f332
010c00001d3521d3521d3521d3521d3521d3521d3521d3521d3521d3521d3521d3521d3521d3521d3521d35222352223522235222352223522235222352223522135221352213522135221352213522135221352
010c00001d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d3321d33222332223322233222332223322233222332223322133221332213322133222332223322233222332
010c000024332243322433224332243322433224332243322433224332243322433224332243322433224332223322233222332223322433224332223322233221332213321f3321f3321e3321e3321f3321f332
010c00002133221332213322133221332213322133221332213322133221332213322133221332213322133221332213322133221332213322133221332213322133221332213322133221332213322133221332
010c0000297452973526745267352974529735267452673529745297352674526735297452973526745267352e7452e73529745297352d7452d73526745267352974529735267452673529745297352674526735
010c00002b7352b73528735287352b7352b73528735287352b7352b73528735287352b7352b73528735287352b7352b73528735287352b7352b73528735287352b7352b73528735287352b7352b7352873528735
010c0000297352973526735267352973529735267352673529735297352673526735297352973526735267352e7352e73529735297352d7352d73526735267352974529735267452673529745297352674526735
010c000030735307352b7352b73530735307352b7352b73530735307352b7352b73530735307352b7352b73516250162501625016250182501825016250162501525015250132501325012250122501325013250
010c00001525015250152501525015250152501525015250152501525015250152501525015250152501525015240152401524015240152301523015230152301522015220152201522015210152101521015210
010c00000555005500055500000005550000000555000000055500000005550000000555000000055500000005550000000555000000055500000005550000000555000000055500000005550000000555000000
010c00000955000000095500000009550000000955000000095500000009550000000955000000095500000009550000000955000000095500000009550000000955000000095500000009550000000955000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
01020000180511d051180511d05124001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
011000000c65110641136311562118611000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300002d0512f0512d0512f05130051320513005132051000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000320513005132051300512f0512d0512f0512d051000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003062430625000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004
01080000187501c7511f7510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010f00002d7302874124741187410c741007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010e00001d213212130c6111062113631156511865134203182010020100201002010020100201002010020124201002010020100201002010020100201002010020100201002010020100201002010020100201
010f0000186501f6502d650246502f65018650216501865021650216502f650216502f6502f650306502165024650186502d650186502d6501865030650246503065018650246502d65021650186502f65024650
010800003015032150361503715037100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
__music__
01 02040c13
00 00050d12
00 02040c13
00 01060e12
00 0a080f13
00 00091012
00 0a080f13
00 020b1112
00 1f141a13
00 02151b12
00 1f171c13
00 02181d12
00 20191e13
02 00424312
00 41424344
01 00424313
02 02424312
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

