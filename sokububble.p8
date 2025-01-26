pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
level_defs={{
 name="bubbles",
 mapdef={0,8,7,7},
 ini_bubble=0
},{
 name="targets",
 mapdef={7,8,7,7},
 ini_bubble=0
},{
 name="stripes",
 mapdef={16,0,8,8},
 ini_bubble=0
},{
 name="hidden",
 mapdef={0,0,8,8},
 ini_bubble=0
},{
 name="corners",
 mapdef={8,0,8,8},
 ini_bubble=0
},{
 name="tiny",
 mapdef={14,8,7,7},
 ini_bubble=0
},{
 name="stripes-2",
 mapdef={21,8,8,7},
 ini_bubble=0
},{
 name="cross",
 mapdef={24,0,8,8},
 ini_bubble=0
},{
 name="the end",
 mapdef={29,8,7,6},
 ini_bubble=1,
 no_bg=true
}}

--sprite flags
flag_player=0
flag_wall=1
flag_box=2
flag_tgt=3
flag_bub=4

colors={9,8,3,1}
colors[0]=0

function delta_rot(r1,r2)
 local d=r2-r1
 if d>180 then
  d-=360
 elseif d<=-180 then
  d+=360
 end
 return d
end

function box_color(si)
 return si\16-3
end

function tgt_color(si)
 local col=si%16
 if si==77 or col==8 then
  return -1
 end
 if col==5 then
  return si\16-3
 end
 return col-8
end

function bub_color(si)
 local col=si%16
 if col<=4 then
  return col
 else
  return si\16-3
 end
end

function box_at(x,y,state)
 for box in all(state.boxes) do
  if box:is_at(x,y) then
   return box
  end
 end
 return nil
end

--wrap coroutine with a name to
--facilitate debugging crashes
function cowrap(
 name,coroutine,...
)
 return {
  name=name,
  coroutine=cocreate(coroutine),
  args={...}
 }
end

--returns true when routine died
function coinvoke(wrapped_cr)
 local cr=wrapped_cr.coroutine
 if not coresume(
  cr,
  wrapped_cr.args
 ) then
  printh(
   "coroutine "
   ..wrapped_cr.name
   .." crashed"
  )
  while true do end
 end
 return costatus(cr)=="dead"
end

function no_draw()
end

function wait(steps)
 for i=1,steps do
  yield()
 end
end

function printbig(s,x0,y0,c)
 print(s,x0,y0,c)
 for y=4,0,-1 do
  local yd=y0+y*2
  for x=#s*4-1,0,-1 do
   local xd=x0+x*2
   rectfill(
    xd,yd,xd+1,yd+1,
    pget(x0+x,y0+y)
   )
  end
 end
end

function draw_dialog(txt,y)
 local hw=#txt*4+2
 rectfill(64-hw,y,63+hw,y+17,13)
 printbig(txt,67-hw,y+4,6)
end

function drop(obj,ymax,bounce)
 local a=0.03
 local v=0

 while true do
  v+=a
  obj.y+=v
  if obj.y>ymax then
   obj.y=ymax
   if v>0.5 and bounce then
    v=-v*0.5
    sfx(1)
   else
    return
   end
  end

  yield()
 end
end

function level_done_anim(args)
 local dialog=args[1]
 wait(30)
 dialog.show=true
 sfx(4)
 wait(90)
 start_level(state.level.idx+1)
 yield() --allow anim swap
end

function animate_level_done()
 local dialog={show=false}
 local anim=cowrap(
  "level_done",
  level_done_anim,
  dialog
 )
 anim.draw=function()
  if dialog.show then
   draw_dialog("solved!",58)
  end
 end
 return anim
end

function retry_anim()
 sfx(2)
 wait(30)
 if state.view_all then
  --start completely afresh
  show_title()
 else
  start_level(state.level.idx)
 end
 yield() --allow anim swap
end

function animate_retry()
 local anim=cowrap(
  "retry",retry_anim
 )
 anim.draw=no_draw
 return anim
end
-->8
box={}
function box:new(x,y,c)
 local o=setmetatable({},self)
 self.__index=self

 o.sx=x*8
 o.sy=y*8
 o.c=c

 return o
end

function box:is_at(x,y)
 return (
  self.sx==x*8 and self.sy==y*8
 )
end

function box:on_tgt(level)
 if (
  self.sx%8!=0 or self.sy%8!=0
 ) then
  return false
 end
 local tgt=level:tgt_at(
  self.sx\8,self.sy\8
 )
 return tgt==-1 or tgt==self.c
end

function box:_push(mov)
 self.sx+=mov.dx
 self.sy+=mov.dy
end
-->8
--player

player={}
function player:new(x,y)
 local o=setmetatable({},self)
 self.__index=self

 o.sx=x*8
 o.sy=y*8
 o.sd=0
 o.dx=0
 o.dy=0
 o.rot=180
 o.tgt_rot=nil
 o.retry_cnt=0

 return o
end

function player:_rotate(state)
 local drot=delta_rot(
  self.rot,self.tgt_rot
 )
 drot=max(min(drot,10),-10)

 self.rot=(self.rot+drot)%360
 if abs(drot)<1 then
  self.tgt_rot=nil
 end
end

function player:_forward(mov)
 self.sx+=mov.dx
 self.sy+=mov.dy
 self.sd=(
  self.sd+3+mov.dx+mov.dy
 )%3
end

function player:_backward(mov)
 self.sx-=mov.dx
 self.sy-=mov.dy
 self.sd=(
  self.sd+3-mov.dx-mov.dy
 )%3
end

function blocked_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 for i=1,mov.blocked do
  plyr:_forward(mov)
  yield()
 end

 sfx(1)
 yield()

 for i=1,mov.blocked do
  plyr:_backward(mov)
  yield()
 end
end

function plain_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 for i=1,8 do
  plyr:_forward(mov)
  if i!=8 then yield() end
 end
end

function push_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 local start=1
 if (
  plyr.sx%8!=0 or plyr.sy%8!=0
 ) then
  --continuing prev push move
  start=3
 end

 for i=start,10 do
  plyr:_forward(mov)
  if i==2 then
   sfx(0)
  elseif i>2 then
   mov.push_box:_push(mov)
  end
  if i!=10 then yield() end
 end

 if (
  plyr.movq!=nil
  and plyr.movq.blocked==0
  and plyr.movq.rot==plyr.rot
 ) then
  --continue into next move
  plyr:_start_queued_move(state)
  yield() --allow anim swap
 else
  --retreat after placing box
  for i=1,2 do
   plyr:_backward(mov)
   yield()
  end
 end
end

function player:_move(state)
 if coinvoke(self.mov.anim) then
  self.mov=nil
 end

 if (
  self.sx%8==0 and self.sy%8==0
 ) then
  local bub=state.level:bubble(
   self.sx\8,self.sy\8
  )
  if (
   bub!=nil
   and bub!=state.bubble
  ) then
   state.bubble=bub
   sfx(5)
  end
 end
end

--checks if move is blocked
--if so, returns num pixels
--that player can move. returns
--zero otherwise
function player:_is_blocked(
 mov,state
)
 local x1=mov.tgt_x
 local y1=mov.tgt_y

 local lvl=state.level
 local ws=lvl:wall_size(x1,y1)
 if ws!=0 then
  return 5-ws\2
 end

 local box=box_at(x1,y1,state)
 if (
  box==nil
  and self.mov!=nil
  and self.mov.rot==mov.rot
 ) then
  --pushed box is not (always)
  --bound by box_at
  box=self.mov.push_box
 end

 if box!=nil then
  if box.c!=state.bubble then
   --cannot move this box color
   return 2
  end
  local x2=x1+mov.dx
  local y2=y1+mov.dy
  if (
   lvl:is_wall(x2,y2)
   or box_at(x2,y2,state)!=nil
  ) then
   --no room to push box
   return 2
  end
 end

 return 0
end

function player:_check_move(
 mov,state
)
 local x,y
 if self.mov!=nil then
  x=self.mov.tgt_x
  y=self.mov.tgt_y
 else
  x=self.sx\8
  y=self.sy\8
 end

 local x1=x+mov.dx
 local y1=y+mov.dy
 mov.tgt_x=x1
 mov.tgt_y=y1

 mov.blocked=self:_is_blocked(
  mov,state
 )
 if mov.blocked!=0 then
  mov.tgt_x=x
  mov.tgt_y=y
 end

 return mov
end

function player:_start_queued_move(
 state
)
 assert(self.movq!=nil)
 local mov=self.movq
 self.movq=nil

 mov.push_box=box_at(
  mov.tgt_x,mov.tgt_y,state
 )

 if mov.blocked!=0 then
  mov.anim=cowrap(
   "blocked_move",
   blocked_move_anim,
   mov,self
  )
 elseif mov.push_box!=nil then
  mov.anim=cowrap(
   "push_move",
   push_move_anim,
   mov,self
  )
  state.mov_cnt+=1
 else
  mov.anim=cowrap(
   "plain_move",
   plain_move_anim,
   mov,self
  )
  state.mov_cnt+=1
 end

 self.mov=mov
 state.view_all=false

 if mov.rot!=self.rot then
  if (
   mov.rot%180==self.rot%180
  ) then
   --skip 180-turn
   self.rot=mov.rot
  else
   self.tgt_rot=mov.rot
  end
 end
end

function player:update(state)
 --allow player to queue a move
 local req_mov=nil
 if btnp(➡️) then
  req_mov={rot=90,dx=1,dy=0}
 elseif btnp(⬅️) then
  req_mov={rot=270,dx=-1,dy=0}
 elseif btnp(⬆️) then
  req_mov={rot=0,dx=0,dy=-1}
 elseif btnp(⬇️) then
  req_mov={rot=180,dx=0,dy=1}
 end
 if req_mov!=nil then
  self.movq=self:_check_move(
   req_mov,state
  )
 end

 --handle level retry
 if btn(❎) then
  self.retry_cnt+=1
  if self.retry_cnt>30 then
   state.anim=animate_retry()
  end
  return
 else
  self.retry_cnt=0
 end

 if (
  self.movq!=nil
  and self.mov==nil
 ) then
  self:_start_queued_move(state)
 end

 if self.tgt_rot then
  self:_rotate()
 elseif self.mov then
  self:_move(state)
 end
end

function player:draw(state)
 local lvl=state.level
 local subrot=self.rot%90
 local row=(self.rot%180)\90
 local si
 if subrot==0 then
  si=16+row*16+self.sd
 else
  local d=(subrot+15)\30
  if d==0 or d==3 then
   si=16+((row+d\3)%2)*16+self.sd
  else
   si=16+row*16+2+d
  end
 end

 local idx=state.bubble
 if self.retry_cnt>0 then
  idx=self.retry_cnt\2%#colors
 end
 pal(1,colors[idx])

 spr(
  si,
  lvl.sx0+self.sx,
  lvl.sy0+self.sy
 )
 pal()
end

-->8
--level

level={}
function level:new(
 lvl_index
)
 local o=setmetatable({},self)
 self.__index=self

	local lvl_def=level_defs[
	 lvl_index
	]
	o.idx=lvl_index
	o.name=lvl_def.name
 o.x0=lvl_def.mapdef[1]
 o.y0=lvl_def.mapdef[2]
 o.ncols=lvl_def.mapdef[3]
 o.nrows=lvl_def.mapdef[4]
 o.sx0=64-4*o.ncols
 o.sy0=67-4*o.nrows
 o.ini_bubble=lvl_def.ini_bubble
 o.no_bg=lvl_def.no_bg

 return o
end

function level:_sprite(mx,my)
 return mget(
  self.x0+mx,self.y0+my
 )
end

function level:_cellhasflag(
 mx,my,flag
)
 return fget(
  self:_sprite(mx,my),flag
 )
end

function level:is_wall(x,y)
 return self:_cellhasflag(
  x,y,flag_wall
 )
end

function level:wall_size(x,y)
 local si=self:_sprite(x,y)
 local row=si\16
 if row==3 then
  return 8
 elseif row==2 and si>36 then
  return 6
 else
  return 0
 end
end

function level:tgt_at(x,y)
 local si=self:_sprite(x,y)
 if fget(si,flag_tgt) then
  return tgt_color(si)
 end
 return nil
end

function level:bubble(x,y)
 local si=self:_sprite(x,y)
 if fget(si,flag_bub) then
  return bub_color(si)
 end
 return nil
end

function level:update_state(s)
 s.level=self
 s.bubble=self.ini_bubble
 s.view_all=true
 s.boxes={}
 s.box_cnt=0
 s.mov_cnt=0
 s.push_box=nil
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   if fget(si,flag_player) then
    s.player=player:new(x,y)
   elseif fget(si,flag_box) then
    add(
     s.boxes,
     box:new(x,y,box_color(si))
    )
   end
  end
 end

 return s
end

function level:_draw_fixed(state)
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   local dsi=0
   if fget(si,flag_wall) then
    dsi=si
   elseif fget(si,flag_tgt) then
    local c=tgt_color(si)
    local viz=(
     state.view_all
     or state.bubble==c
     or c==-1
    )
    if self:_box_on_tgt_at(
     x,y,state
    ) then
     if c==-1 then
      dsi=109
     elseif viz then
      dsi=c*16+62
     else
      dsi=125
     end
    elseif viz then
     dsi=si
    elseif fget(si,flag_bub) then
     c=bub_color(si)
     dsi=c*16+45
    else
     dsi=93
    end
   elseif fget(si,flag_bub) then
    local c=bub_color(si)
    dsi=c*16+54
   end
   if dsi!=0 then
    spr(
     dsi,
     self.sx0+x*8,
     self.sy0+y*8
    )
   end
  end
 end
end

function level:_draw_boxes(state)
 for box in all(state.boxes) do
  local si=79
  if (
   state.view_all
   or state.bubble==box.c
  ) then
   si=48+box.c*16
  end
  spr(
   si,
   self.sx0+box.sx,
   self.sy0+box.sy
  )
 end
end

function level:draw(state)
 pal(15,0)

 if self.no_bg==nil then
  rectfill(
   self.sx0+4,
   self.sy0+4,
   self.sx0+8*self.ncols-5,
   self.sy0+8*self.nrows-5,
   5
  )
 end
 self:_draw_fixed(state)
 self:_draw_boxes(state)

 rectfill(0,0,127,6,1)
 print(
  self.name.."  "..state.mov_cnt,
  1,1,0
 )
end

function level:_box_on_tgt_at(
 x,y,state
)
 for box in all(state.boxes) do
  if (
   box:is_at(x,y)
   and box:on_tgt(self)
  ) then
   return true
  end
 end

 return false
end

function level:is_done(state)
 local old_cnt=state.box_cnt
 state.box_cnt=0

 for box in all(state.boxes) do
  if box:on_tgt(self) then
   state.box_cnt+=1
  end
 end

 if state.box_cnt>old_cnt then
  sfx(3)
 end

 return state.box_cnt==#state.boxes
end

-->8
--main

function start_level(idx)
 local lvl=level:new(idx)
 state=lvl:update_state({})
end

function _init()
 show_title()
end

function start_game()
 _draw=game_draw
 _update60=game_update
 start_level(1)
end

function show_title()
 title={
  car={
   x=60,
   dx=0.5,
   c=1
  },
  boxr={
   x=116
  },
  boxl={
   x=-8
  }
 }
 _draw=title_draw
 _update60=title_update
end

function title_update()
 if btnp(🅾️) then
  start_game()
  return
 end

 local car=title.car
 car.x+=car.dx
 if car.dx>0 then
  if car.x>122 then
   car.dx=-car.dx
  elseif car.x>110 then
   local box=title.boxr
   box.x=car.x+6
   if not box.touched then
    box.touched=true
    sfx(0)
   end
  elseif car.x>88 then
   if car.c!=2 then sfx(5) end
   car.c=2
  elseif car.x>64 then
   title.boxl.x=4
   title.boxl.touched=false
  end
 else
  if car.x<7 then
   car.dx=-car.dx
  elseif car.x<19 then
   local box=title.boxl
   box.x=car.x-14
   if not box.touched then
    box.touched=true
    sfx(0)
   end
  elseif car.x<40 then
   if car.c!=1 then sfx(5) end
   car.c=1
  elseif car.x<64 then
   title.boxr.x=116
   title.boxr.touched=false
  end
 end
end

function title_draw()
 cls()
 rect(29,17,97,66,15)
 rect(30,18,98,67,2)
 rectfill(30,18,97,66,13)

 map(1,17,32,28,8,3)

 spr(133,79,50,2,2)
 spr(130,73,50,1,2)
 spr(128,65,50,2,2)
 spr(128,57,50,2,2)
 spr(131,49,50,2,2)
 spr(128,41,50,2,2)

 print(
  "eriban presents",34,20,1
 )

 print(
  "⬅️➡️⬆️⬇️ move",38,75,1
 )
 print(
  "❎(hold) retry",38,83,1
 )

 rectfill(0,120,127,127,5)
 print(
  "press 🅾️ to start",30,122,0
 )

 --draw bubbles
 spr(182,30,105)
 spr(166,91,105)

 --draw car
 local car=title.car
 pal(1,colors[car.c])
 spr(
  160+2*((car.x%3)\1),
  car.x-8,104,
  2,2
 )

 --draw boxes
 pal(colors[3-car.c],5)
 spr(
  167,title.boxr.x,112
 )
 spr(
  183,title.boxl.x,112
 )
 pal()
end

function game_draw()
 cls()
 state.level:draw(state)
 state.player:draw(state)

 if state.anim!=nil then
  state.anim.draw()
 end
end

function game_update()
 if state.anim then
  if coinvoke(state.anim) then
   state.anim=nil
  end
 elseif btnp(🅾️) then
  start_level(
   state.level.idx
   %#level_defs+1
  )
 else
  state.player:update(state)

  if state.level:is_done(state) then
   state.anim=animate_level_done()
  end
 end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000004000000004000000000000000006666000000655555555555555f5555555f0000000000000000000000000000000000000000
0411114004111140021111200041110000241100000000000000065555500000655555555555555f5555555f0000000000000000000000000000000000000000
041111400211112004111140021111100411111000000000000065555555000005555555555555f0555555f00000000000000000000000000000000000000000
02165120041651400416514004165114411651100000000000065555555550000055555555555f0055555f000000000000000000000000000000000000000000
0415514004155140021551204115514001155114000000000065555555555500000555555555f000555555000000000000000000000000000000000000000000
041111400211112004111140011111200111114000000000065555555555555000005555555f0000555555500000000000000000000000000000000000000000
021111200411114004111140001114000011420000000000655555555555555f0000055555f000005555555f0000000000000000000000000000000000000000
000000000000000000000000000040000004000000000000655555555555555f000000ffff0000005555555f0000000000000000000000000000000000000000
000000000000000000000000000400000000400000000000666666f0000000000666666f6666666f000000000000000000000000000000000000000000000000
044244200424424002442440001142000011140000666600655555f06666666f0655555f6555555f000000000000000000000000000000000000000000999900
0111111001111110011111100111114001111120065555f0655555f06555555f0655555f6555555f000000000000000000000000000000000000000009444420
0116511001165110011651100116511441165140065555f0655555f06555555f0655555f6555555f000000000000000000000000000000000000000009444420
0115511001155110011551104115511004155114065555f0655555f06555555f0655555f6555555f000000000000000000000000000000000000000009444420
0111111001111110011111100411111002111110065555f0655555f06555555f0655555f6555555f000000000000000000000000000000000000000009444420
044244200424424002442440002411000041110000ffff00655555f06555555f0655555fffffffff000000000000000000000000000000000000000000222200
000000000000000000000000000040000004000000000000fffffff0ffffffff0fffffff00000000000000000000000000000000000000000000000000000000
6666666f666666666666666f6555555f6555555f6555555f666666666666666f6666666f6555555f66666666666666666555555f6555555f6555555f00000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500000000
ffffffff6555555ff555555fffffffffffffffff6555555fffffffff6555555ffffffffffffffffffffffffff555555ff555555fffffffff6555555f00000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009990099900000000
00aaaa00099999900999999009999990099999900990099000000000044004400660066009900990088008800330033001100110066006609990099900999900
0a999940090000900900009009000090090000900900009000099000040990400609906009099090080990800309903001099010060000609900009909444420
0a9999400909909009088090090330900901109000000000009a9900009a9900009a9900009a9900009a9900009a9900009a9900000000000000000009444420
0a999940090990900908809009033090090110900000000000999900009999000099990000999900009999000099990000999900000000000000000009444420
0a999940090000900900009009000090090000900900009000099000040990400609906009099090080990800309903001099010060000609900009909444420
00444400099999900999999009999990099999900990099000000000044004400660066009900990088008800330033001100110066006609990099900222200
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009990099900000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008880088800000000
00eeee00088888800888888008888880088888800880088000000000044004400660066009900990088008800330033001100110044004408880088800000000
0e888820080000800800008008000080080000800800008000088000040880400608806009088090080880800308803001088010040000408800008800000000
0e888820080990800808808008033080080110800000000000898800008988000089880000898800008988000089880000898800000000000000000000000000
0e888820080990800808808008033080080110800000000000888800008888000088880000888800008888000088880000888800000000000000000000000000
0e888820080000800800008008000080080000800800008000088000040880400608806009088090080880800308803001088010040000408800008800000000
00222200088888800888888008888880088888800880088000000000044004400660066009900990088008800330033001100110044004408880088800000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008880088800000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666006663330033300000000
00bbbb00033333300333333003333330033333300330033000000000044004400660066009900990088008800330033001100110666006663330033300000000
0b333310030000300300003003000030030000300300003000033000040330400603306009033090080330800303303001033010660000663300003300000000
0b3333100309903003088030030330300301103000000000003b3300003b3300003b3300003b3300003b3300003b3300003b3300000000000000000000000000
0b333310030990300308803003033030030110300000000000333300003333000033330000333300003333000033330000333300000000000000000000000000
0b333310030000300300003003000030030000300300003000033000040330400603306009033090080330800303303001033010660000663300003300000000
00111100033333300333333003333330033333300330033000000000044004400660066009900990088008800330033001100110666006663330033300000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666006663330033300000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444004441110011100000000
00dddd00011111100111111001111110011111100110011000000000044004400660066009900990088008800330033001100110444004441110011100000000
0d1111f0010000100100001001000010010000100100001000011000040110400601106009011090080110800301103001011010440000441100001100000000
0d1111f00109901001088010010330100101101000000000001d1100001d1100001d1100001d1100001d1100001d1100001d1100000000000000000000000000
0d1111f0010990100108801001033010010110100000000000111100001111000011110000111100001111000011110000111100000000000000000000000000
0d1111f0010000100100001001000010010000100100001000011000040110400601106009011090080110800301103001011010440000441100001100000000
00ffff00011111100111111001111110011111100110011000000000044004400660066009900990088008800330033001100110444004441110011100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444004441110011100000000
00dd00000000000000dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d112000000000000d11200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d111120000000000d111120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d111120000000000d1111200000000dd00000000000ddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
d111120000000000d111120000dd0d112000000000d1111120000000000000000000000000000000000000000000000000000000000000000000000000000000
d111122200000000d11112000d112111120000000d11111112000000000000000000000000000000000000000000000000000000000000000000000000000000
d111211120000000d1111200d111121112000000d111121112000000000000000000000000000000000000000000000000000000000000000000000000000000
d111111112000000d1111200d111121112000000d1112d1112000000000000000000000000000000000000000000000000000000000000000000000000000000
d111111112000000d1111200d111121112000000d111111120000000000000000000000000000000000000000000000000000000000000000000000000000000
d111221112000000d111dd20d111121112000000d111111120000000000000000000000000000000000000000000000000000000000000000000000000000000
d1112d1112000000d1111112d111121112000000d111122212000000000000000000000000000000000000000000000000000000000000000000000000000000
111111112000000011111112d111111112000000d111111112000000000000000000000000000000000000000000000000000000000000000000000000000000
111111112000000011111112d111111120000000d111111120000000000000000000000000000000000000000000000000000000000000000000000000000000
01111122000000000111112001111122000000000111112200000000000000000000000000000000000000000000000000000000000000000000000000000000
00222200000000000022220000222200000000000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000888000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000008888800044444440000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000088988820084848480000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000088888820084848480000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000088888820084848480000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000008888200084848480000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000222000084848480000000000000000000000000000000000000000000000000000000000000000
00000006600000000000000660000000000000066000000000000000044444440000000000000000000000000000000000000000000000000000000000000000
00000076660000000000007666000000000000766600000000999000000000000000000000000000000000000000000000000000000000000000000000000000
00000766666000000000076666600000000007666660000009999900444444400000000000000000000000000000000000000000000000000000000000000000
01111111111111100111111111111110011111111111111099a99940949494900000000000000000000000000000000000000000000000000000000000000000
01414414414414100144144144144110011441441441441099999940949494900000000000000000000000000000000000000000000000000000000000000000
04555111111555400155511111155540045551111115551099999940949494900000000000000000000000000000000000000000000000000000000000000000
01505111111505100450511111150540045051111115054009999400949494900000000000000000000000000000000000000000000000000000000000000000
04555000000555400455500000055500005550000005554000444000949494900000000000000000000000000000000000000000000000000000000000000000
00404404404404000004404404404400004404404404400000000000444444400000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000001010100000002020202020000000000010101000002020202020000000000020202020202020202020202020202020004141414140810181818181818080802041414141408101818181818180808000414141414081018181818181808080004141414140810181818181818080800
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
31363636363636323136363636363632313636363636363216363636363636173a3b38373731380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35100000000000353555000025006535351000000000003535460045450056350035103e3c3e380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3500000000000035350010600000003535000000000000353500107070000035003900393933380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3500005000602f35352500567640003535655066566055353565500000605535313831173117370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35000060000000353500506646002535356550665660553535655000006055353e3835353535390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3500005300655535350000007000003535000000000000353500004040000035333839393319300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3556002f00556535354500250000753535000000000000353566007575007635454545004040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3336363636363634333636363636363433363636363636341836363636363619000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30293030302930313636363636323030303030303031363636363636323a3b38373731380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
264d6066004d28356600005546353010000000003035100000000000350035103e3c3e380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3000000000403035456000400035300060004000303500000000000035003900393933380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3076001000463035000010000035300050660056303565506656605535313831173117370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3070000000003035007000506535300070004d4d2835655066566055353e3835353535390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
264d0056504d2835767500005635300000764d48283500000000000035333839393319400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3027303030273033363636363634303030302727303336363636363634000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0031383132373731320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00333235353e1a35350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003a343334393933340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080848580808283000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0090949590909293000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001a0501a020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001400001c05018050100501005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000295502d550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c72026730307403075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001e5102b5411e5110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
