pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- sokobubble v1.0 beta
-- (c) 2025 eriban

level_defs={{
 name="bubbles",
 mapdef={0,8,7,7},
 id=1
},{
 name="targets",
 mapdef={7,8,7,7},
 id=2
},{
 name="order",
 mapdef={7,15,8,6},
 id=3
},{
 name="overlap",
 mapdef={0,0,8,8},
 id=4
},{
 name="swap",
 mapdef={16,0,8,8},
 id=5
},{
 name="barrier",
 mapdef={44,8,8,7},
 id=6
},{
 name="espresso",
 mapdef={36,8,8,7},
 id=7,
 score_dx=-16
},{
 name="enclosed",
 mapdef={48,0,8,8},
 id=8,
 score_dx=-8
},{
 name="swap 2",
 mapdef={21,8,8,7},
 id=9
},{
 name="coffee",
 mapdef={59,8,8,7},
 id=16,
 score_dx=-8
},{
 name="packed",
 mapdef={88,0,8,8},
 ini_bubble=1,
 ini_pos={x=1,y=1},
 id=17,
 score_dx=-8
},{
 name="rgb",
 mapdef={56,0,8,8},
 id=10
},{
 name="rgb plus",
 mapdef={14,8,7,7},
 id=11
},{
 name="skull",
 mapdef={80,0,8,8},
 id=15,
 score_dx=-24
},{
 name="squares",
 mapdef={8,0,8,8},
 id=12
},{
 name="center",
 mapdef={40,0,8,8},
 id=14,
 score_dx=-16
},{
 name="cross",
 mapdef={24,0,8,8},
 id=13
},{
 name="windmill",
 mapdef={96,0,8,8},
 id=18,
 score_dx=-16
},{
 name="whirly",
 mapdef={64,0,8,8},
 id=19,
 score_dx=-8
},{
 name="the end",
 mapdef={0,15,7,6},
 id=99,
 ini_bubble=1,
 no_floor=true,
 score_dx=99,
},
--{
-- name="wip",
-- mapdef={64,0,8,8}
--}
}
max_level_id=#level_defs

--sprite flags
flag_player=0
flag_wall=1
flag_box=2
flag_tgt=3
flag_bub=4

bub_pals={
 {[4]=4,[9]=9,[10]=10},--yellow
 {[4]=2,[9]=8,[10]=14},--red
 {[4]=1,[9]=3,[10]=11},--green
 {[4]=1,[9]=12,[10]=6} --blue
}

box_colors={
 [77]=1,[93]=1,[109]=3,[125]=3,
 [94]=1,[124]=3
}
tgt_colors={
 [77]=1,[93]=3,[109]=1,[125]=3,
 [108]=-1,[94]=3,[124]=2
}
bub_colors={
 [94]=3
}

--sprite size
ss=16

track_anim_colors={4,2,13}

easymode=true

function level_id(level_idx)
 --level id allows reset of
 --level progress after level
 --changed

 return (
  level_defs[level_idx].id
  or level_idx
 )
end

function bubble_pal(idx)
 if idx==nil then
  --reset bub_pal changes
  pal(bub_pals[1])
 elseif idx==-1 then
  --any color (target only)
  pal(9,6)
 elseif idx<=4 then
  --normal color
  pal(bub_pals[idx])
 elseif idx<=8 then
  --darkened
  local p=bub_pals[idx-4]
  pal(10,p[9])
  pal(9,p[4])
  pal(4,p[4])
 else
  --hidden
  pal(10,9)
  pal(9,4)
  pal(4,2)
 end
end

function score_str(
 lvl_idx,score
)
 local s=""

 if score!=nil then
  s..=score.."/"
 end

 local hi=stats:get_hi(lvl_idx)
 if hi>0 then
  s..=hi
 else
  s..="-"
 end

 return s
end

function draw_level_info(
 lvl_idx,y
)
 rectfill(0,y,127,y+6,5)

 if (
  lvl_idx==#level_defs
 ) then
  print("stats",1,y+1,0)
  return
 end

 print(
  "l"..lvl_idx..":"
  ..level_defs[lvl_idx].name,
  1,y+1,0
 )

 local s="#="..score_str(lvl_idx)
 print(s,128-#s*4,y+1,0)
end

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
 return (
  box_colors[si] or si\16-3
 )
end

function tgt_color(si)
 local c=tgt_colors[si]
 if (c) then return c end

 local col=si%16
 if col==7 then
  return -1
 elseif col==5 then
  return si\16-3
 end
 return col-7
end

function bub_color(si)
 local c=bub_colors[si]
 if (c) then return c end

 local col=si%16
 if col<=4 then
  return col
 else
  return si\16-3
 end
end

function box_at(x,y,game)
 for box in all(game.boxes) do
  if box:is_at(x,y) then
   return box
  end
 end
end

function new_object(class)
 local obj=setmetatable(
  {},class
 )
 class.__index=class
 return obj
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

function do_nothing()
end

function wait(steps)
 for i=1,steps do
  yield()
 end
end

function shallow_copy(t)
 local t2={}
 for k,v in pairs(t) do
  t2[k]=v
 end
 return t2
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

function rect3d(
 x,y,x2,y2,c,chi,clo
)
 rect(x-1,y-1,x2+1,y2+1,clo)
 rect(x-1,y-1,x2,y2,chi)
 rectfill(x,y,x2,y2,c)
end

dialog={}
function dialog:new(txt)
 local o=new_object(self)

 o.txt=txt

 o.hw=0
 o.ymin=127
 o.ymax=0

 for t in all(txt) do
  local s=t.big and 2 or 1
  o.ymin=min(o.ymin,t.y-4)
  o.ymax=max(o.ymax,t.y+s*5+4)
  o.hw=max(o.hw,#t.s*2*s+2)
 end

 return o
end

function dialog:draw()
 rect3d(
  63-self.hw,self.ymin,
  64+self.hw,self.ymax,5,6,0
 )

 for t in all(self.txt) do
  local dx=t.dx or 0
  if t.big then
   printbig(
    t.s,65-#t.s*4+dx,t.y,0
   )
  else
   print(t.s,64-#t.s*2,t.y,0)
  end
 end
end

function level_start_anim()
 wait(30)
 sfx(6)
 wait(90)
end

function animate_level_start(
 lvl_idx
)
 local dialog=dialog:new({
  {
   s="level "..lvl_idx,
   y=54
  },{
   s=level_defs[lvl_idx].name,
   y=63,
   big=true
  }
 })
 local anim=cowrap(
  "level_start",
  level_start_anim
 )
 anim.draw=function()
  dialog:draw()
 end
 return anim
end

function level_done_anim(args)
 local state=args[1]
 wait(30)
 state.dialog=dialog:new({
  {
   s="solved!",
   y=54,dx=1,
   big=true
  },{
   s="in "..state.mov_cnt.." moves",
   y=70
  }
 })
 sfx(4)
 wait(120)

 if state.new_hi then
  state.dialog=dialog:new(
   {{s="new hi!",y=58,big=true}}
  )
  sfx(8)
  wait(90)
 end

 start_level(_game.level.idx+1)
 yield() --allow anim swap
end

function animate_level_done(
 mov_cnt,new_hi
)
 local state={
  dialog=nil,
  new_hi=new_hi,
  mov_cnt=mov_cnt
 }
 local anim=cowrap(
  "level_done",
  level_done_anim,
  state
 )
 anim.draw=function()
  if state.dialog then
   state.dialog:draw()
  end
 end
 return anim
end

function retry_anim()
 sfx(2)
 wait(30)
 if _game.mov_cnt==0 then
  --start completely afresh
  scene=_title
 else
  start_level(_game.level.idx)
 end
 yield() --allow anim swap
end

function animate_retry()
 local anim=cowrap(
  "retry",retry_anim
 )
 anim.draw=do_nothing
 return anim
end
-->8
stats={}
vmajor=0
vminor=1

function stats:new()
 local o=new_object(self)

 cartdata("eriban_sokobubble")
 if (
  dget(0)!=vmajor or
  dget(1)<vminor
 ) then
  --reset incompatible data
  for l=1,max_level_id do
   dset(1+l,0)
  end
 end

 dset(0,vmajor)
 dset(1,vminor)

 --find the maximum level the
 --player can play
 o.max_lvl_idx=1
 while (
  o:is_done(o.max_lvl_idx)
 ) do
  o.max_lvl_idx+=1
 end

 o:_update_total()

 return o
end

function stats:_update_total()
 self.total=0
 for i=1,#level_defs do
  self.total+=(
   self:get_hi(i) or 0
  )
 end
end

function stats:mark_done(
 lvl_idx,num_moves
)
 local hi=self:get_hi(lvl_idx)
 if hi==0 or num_moves<hi then
  dset(
   1+level_id(lvl_idx),
   num_moves
  )

  self:_update_total()

  if (
   lvl_idx==self.max_lvl_idx
  ) then
   self.max_lvl_idx+=1
  end

  return true
 end
end

function stats:is_done(lvl_idx)
 return self:get_hi(lvl_idx)>0
end

function stats:get_hi(lvl_idx)
 return dget(1+level_id(lvl_idx))
end

levelmenu={}
function levelmenu:new()
 local o=new_object(self)

 o.ncols=4
 o.nrows=(
  #level_defs+o.ncols-1
 )\o.ncols
 o.cx=0
 o.cy=0

 return o
end

function levelmenu:_lvl_idx(x,y)
 local idx=1+y*4+x
 if idx>#level_defs then
  idx=nil
 end
 return idx
end

function levelmenu:update()
 local cx=self.cx
 local cy=self.cy

 if btnp(➡️) then
  cx=(cx+1)%self.ncols
 elseif btnp(⬅️) then
  cx=(cx+self.ncols-1)%self.ncols
 elseif btnp(⬆️) then
  cy=(cy+self.nrows-1)%self.nrows
 elseif btnp(⬇️) then
  cy=(cy+1)%self.nrows
 else
  if btnp(❎) then
   local lvl_idx=self:_lvl_idx(
    cx,cy
   )
   if lvl_idx<#level_defs then
    start_level(lvl_idx)
   else
    scene=_statsview
   end
  end
  return
 end

 local lvl_idx=self:_lvl_idx(
  cx,cy
 )
 if lvl_idx==nil then
  sfx(1)
  return
 end
 if (
  lvl_idx<=_stats.max_lvl_idx
 ) then
  sfx(0)
  self.cx=cx
  self.cy=cy
 else
  sfx(1)
  return
 end
end

function levelmenu:draw()
 cls()

 spr(134,32,0,8,2)

 for i=1,#level_defs do
  local row=(i-1)\self.ncols
  local col=(i-1)%self.ncols

  local x=col*24+16
  local y=row*20+20
  local focus=(
   col==self.cx and row==self.cy
  )

  rect3d(x,y,x+17,y+13,1,13,2)

  local s=""..i
  local c=0
  if i==_stats.max_lvl_idx then
   c=2
  elseif i<_stats.max_lvl_idx then
   c=12
  end
  if i<#level_defs then
   printbig(s,x+10-#s*4,y+2,c)
  else
   pal(5,c)
   spr(142,x+1,y+1,2,2)
   pal()
  end
  if focus then
   draw_level_info(i,120)
   rect(x,y,x+17,y+13,8)
  end
 end
end

statsview={}
function statsview:new()
 local o=new_object(self)

 return o
end

function statsview:update()
 if btnp(❎) then
  scene=_levelmenu
 end
end

function statsview:draw()
 cls()

 spr(134,32,0,8,2)

 rect3d(1,22,126,107,1,13,2)

 for i=1,#level_defs-1 do
  local x=((i-1)\12)*64
  local y=((i-1)%12)*7+24
  print(
   ""..i.."."..
   level_defs[i].name,
   x+6-(i\10)*4,y,13
  )
  local s="".._stats:get_hi(i)
  print(s,x+62-#s*4,y,13)
 end

 local s="".._stats.total
 printbig(s,127-8*#s,95,12)
 print("total",67,94,12)
 print("moves",67,101,12)
end

box={}
function box:new(x,y,c)
 local o=new_object(self)

 o.sx=x*ss
 o.sy=y*ss
 o.c=c

 return o
end

function box:is_at(x,y)
 return (
  self.sx==x*ss
  and self.sy==y*ss
 )
end

function box:on_tgt(level)
 if (
  self.sx%ss!=0 or self.sy%ss!=0
 ) then
  return false
 end
 local tgt=level:tgt_at(
  self.sx\ss,self.sy\ss
 )
 return tgt==-1 or tgt==self.c
end

function box:_push(mov)
 self.sx+=mov.dx
 self.sy+=mov.dy
end

undo_stack={}
function undo_stack:new(cap)
 local o=new_object(self)

 o.cap=cap
 o.head=1
 o.size=0

 o.items={}
 for i=1,cap do
  add(o.items,0)
 end

 return o
end

function undo_stack:push(obj)
 self.items[self.head]=obj
 self.size=min(
  self.cap,self.size+1
 )
 self.head=1+self.head%self.cap
end

function undo_stack:pop()
 if self.size==0 then
  return nil
 end
 self.head=1+(
  self.head+self.cap-2
 )%self.cap
 self.size-=1
 local obj=self.items[self.head]

 --allow gc but do not change
 --list size
 self.items[self.head]=0

 return obj
end

-->8
--player

player={}
function player:new(x,y,bubble)
 local o=new_object(self)

 o.sx=x*ss
 o.sy=y*ss
 o.bubble=bubble
 o.sd=0
 o.rot=180
 o.tgt_rot=nil
 o.undo_stack=undo_stack:new(8)

 return o
end

function player:_rotate()
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

 for i=1,ss do
  plyr:_forward(mov)
  if i!=ss then yield() end
 end
end

function push_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 local start=1
 if (
  plyr.sx%ss!=0 or plyr.sy%ss!=0
 ) then
  --continuing prev push move
  start=5
 end

 for i=start,ss+4 do
  plyr:_forward(mov)
  if i==4 then
   sfx(0)
  elseif i>4 then
   mov.push_box:_push(mov)
  end
  if i!=ss+4 then yield() end
 end

 if (
  plyr.movq!=nil
  and plyr.movq.blocked==0
  and plyr.movq.rot==plyr.rot
 ) then
  --continue into next move
  plyr:_start_move(
   plyr.movq,_game
  )
  plyr.movq=nil
  yield() --allow anim swap
 else
  --retreat after placing box
  for i=1,4 do
   plyr:_backward(mov)
   yield()
  end
 end
end

function player:_move(game)
 if coinvoke(self.mov.anim) then
  self.mov=nil
 end

 if (
  self.sx%ss==0
  and self.sy%ss==0
 ) then
  local bub=game.level:bubble(
   self.sx\ss,self.sy\ss
  )
  if (
   bub!=nil and bub!=self.bubble
  ) then
   self.bubble=bub
   sfx(5)
  end
 end
end

--checks if move is blocked
--if so, returns num pixels
--that player can move. returns
--zero otherwise
function player:_is_blocked(
 mov,game
)
 local x1=mov.dst_x
 local y1=mov.dst_y

 local lvl=game.level
 local ws=lvl:wall_size(x1,y1)
 if ws!=0 then
  return 2+(ss-ws)\2
 end

 local box=box_at(x1,y1,game)
 if (
  box==nil
  and self.mov!=nil
  and self.mov.rot==mov.rot
 ) then
  --pushed box is not (always)
  --found by box_at
  box=self.mov.push_box
 end

 if box!=nil then
  if box.c!=mov.src_c then
   --cannot move this box color
   return 4
  end
  local x2=x1+mov.dx
  local y2=y1+mov.dy
  if (
   lvl:is_wall(x2,y2)
   or box_at(x2,y2,game)!=nil
  ) then
   --no room to push box
   return 4
  end
 end

 mov.push_box=box
 return 0
end

function player:_check_move(
 mov,game
)
 if self.mov!=nil then
  mov.src_x=self.mov.dst_x
  mov.src_y=self.mov.dst_y
  mov.src_c=self.mov.dst_c
 else
  mov.src_x=self.sx\ss
  mov.src_y=self.sy\ss
  mov.src_c=self.bubble
 end

 mov.dst_x=mov.src_x+mov.dx
 mov.dst_y=mov.src_y+mov.dy

 mov.blocked=self:_is_blocked(
  mov,game
 )
 if mov.blocked!=0 then
  mov.dst_x=mov.src_x
  mov.dst_y=mov.src_y
 end
 mov.dst_c=game.level:bubble(
  mov.dst_x,mov.dst_y
 ) or mov.src_c

 return mov
end

function player:_start_move(
 mov,game
)
 mov.ini_rot=self.rot
 mov.ini_bubble=self.bubble

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
 else
  mov.anim=cowrap(
   "plain_move",
   plain_move_anim,
   mov,self
  )
 end

 if mov.blocked==0 then
  game.mov_cnt=min(
   game.mov_cnt+1,999
  )
  if easymode then
   self.undo_stack:push(mov)
  end
 end

 self.mov=mov

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

function player:_undo(game)
 local mov=self.undo_stack:pop()
 if mov==nil then
  return false
 end

 self.sx=mov.src_x*ss
 self.sy=mov.src_y*ss
 self.rot=mov.ini_rot
 self.bubble=mov.ini_bubble
 game.mov_cnt-=1
 if mov.push_box then
  mov.push_box.sx=mov.dst_x*ss
  mov.push_box.sy=mov.dst_y*ss
 end

 return true
end

_btn_mov_lookup={
 [➡️]={rot=90,dx=1,dy=0},
 [⬅️]={rot=270,dx=-1,dy=0},
 [⬆️]={rot=0,dx=0,dy=-1},
 [⬇️]={rot=180,dx=0,dy=1}
}

function player:update(game)
 --allow player to queue a move
 for b,mov in pairs(
  _btn_mov_lookup
 ) do
  if (
   btnp(b) or (btn(b) and (
    self.movq==nil
    or self.movq_expiry<=2
   ))
  )
  then
   --queue move
   self.movq=self:_check_move(
    shallow_copy(mov),game
   )

   --button hold only queues
   --a short-lived move request
   --to prevent that the player
   --moves a unit too far. it
   --still needs to persist an
   --entire update cycle so
   --that it is visible to an
   --ongoing push animation
   self.movq_expiry=(
    btnp(b) and 99 or 2
   )
  end
 end

 --handle level retry
 if btn(❎) then
  if self.retry_cnt then
   self.retry_cnt+=1
   if self.retry_cnt>30 then
    game.anim=animate_retry()
   end
  end
  return
 else
  if (
   self.retry_cnt
   and self.retry_cnt>0
  ) then
   if self:_undo(game) then
    sfx(7)
   else
    sfx(1)
   end
  end

  self.retry_cnt=0
 end

 if self.movq then
  if self.mov==nil then
   self:_start_move(
    self.movq,game
   )
   self.movq=nil
  else
   self.movq_expiry-=1
   if self.movq_expiry<=0 then
    --remove short-lived move
    --request
    self.movq=nil
   end
  end
 end

 if self.tgt_rot then
  self:_rotate()
 elseif self.mov then
  self:_move(game)
 end
end

function player:draw(game)
 local lvl=game.level
 local d=(self.rot%90+15)\30
 local o=(self.rot%180)\90
 local si
 if d%3==0 then
  si=164+2*((o+d\3)%2)
  for i=1,3 do
   pal(
    track_anim_colors[i],
    (i+self.sd)%3==0 and 2 or 4
   )
  end
 else
  si=168+(o*2+d-1)*2
 end

 local idx=self.bubble
 if (
  self.retry_cnt
  and self.retry_cnt>0
 ) then
  idx=1+(self.retry_cnt\2)%4
 end
 pal(1,0)
 if idx>0 then
  local p=bub_pals[idx]
  pal(5,p[9])
  pal(6,p[10])
 end

 spr(
  si,
  lvl.sx0+self.sx,
  lvl.sy0+self.sy,
  2,2
 )
 pal()
end

-->8
--level

level={}
function level:new(lvl_index)
 local o=new_object(self)

 local lvl_def=level_defs[
  lvl_index
 ]
 o.idx=lvl_index
 o.x0=lvl_def.mapdef[1]
 o.y0=lvl_def.mapdef[2]
 o.ncols=lvl_def.mapdef[3]
 o.nrows=lvl_def.mapdef[4]
 o.sx0=64-8*o.ncols
 o.sy0=64-8*o.nrows
 o.score_x=(
  61+8*o.ncols
  +(lvl_def.score_dx or 0)
 )
 o.score_y=(
  54+8*o.nrows
  +(lvl_def.score_dy or 0)
 )
 o.lvl_def=lvl_def

 o.id=level_id(lvl_index)

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
 return (
  self:is_wall(x,y) and 14 or 0
 )
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

function level:add_objects(game)
 local bubble=(
  self.lvl_def.ini_bubble or 0
 )
 local p=self.lvl_def.ini_pos
 if p then
  game.player=player:new(
   p.x,p.y,bubble
  )
 end
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   if fget(si,flag_player) then
    game.player=player:new(
     x,y,bubble
    )
   elseif fget(si,flag_box) then
    add(
     game.boxes,
     box:new(x,y,box_color(si))
    )
   end
  end
 end

 return s
end

function level:_draw_floor(game)
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local sx=self.sx0+x*16
   local sy=self.sy0+y*16

   local si=self:_sprite(x,y)
   if si==34 then
    --clear floor on outside,
    --use padding to also fix
    --nearby beveled corners
    rectfill(
     sx-8,sy-8,sx+24,sy+24,0
    )
   elseif fget(si,flag_tgt) then
    local c=tgt_color(si)
    local viz=(
     game.mov_cnt==0
     or game.player.bubble==c
     or c==-1
    )
    if viz or easymode then
     bubble_pal(c)
    else
     bubble_pal(9)
    end
    spr(162,sx,sy,2,2)
    bubble_pal()
   end
  end
 end
end

function level:_draw_walls()
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local sx=self.sx0+x*ss
   local sy=self.sy0+y*ss

   local si=self:_sprite(x,y)
   if fget(si,flag_wall) then
    if si>=48 then
     local col=(si-48)%8
     local row=(si-48)\8
     spr(
      192+col*2+row*32,sx,sy,2,2
     )
    else
     local col=(si-16)%16
     local row=(si-16)\16
     spr(
      19+col*2+row*4,sx,sy,2,2
     )
    end
   end
  end
 end
end

function level:_draw_score(game)
 local s=score_str(
  self.idx,game.mov_cnt
 )
 print(
  s,
  self.score_x-#s*4,
  self.score_y,
  1
 )
end

function level:_draw_boxes(game)
 for box in all(game.boxes) do
  local c
  if (
   game.mov_cnt==0
   or game.player.bubble==box.c
  ) then
   c=box.c
  elseif easymode then
   c=box.c+4
  else
   c=9
  end
  bubble_pal(c)
  spr(
   160,
   self.sx0+box.sx,
   self.sy0+box.sy,
   2,2
  )
 end
 bubble_pal()
end

function level:draw_bubbles()
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   if fget(si,flag_bub) then
    bubble_pal(bub_color(si))
    spr(
     12,
     self.sx0+x*ss+4,
     self.sy0+y*ss+4
    )
   end
  end
 end
end

function level:draw(game)
 pal(15,1)
 if (
  not self.lvl_def.no_floor
 ) then
  rectfill(
   self.sx0+8,
   self.sy0+8,
   self.sx0+self.ncols*ss-8,
   self.sy0+self.nrows*ss-8,
   5
  )
 end
 self:_draw_floor(game)
 self:_draw_walls()
 self:_draw_score(game)
 self:_draw_boxes(game)
 pal()

 spr(134,34,0,8,2)

end

function level:_box_on_tgt_at(
 x,y,game
)
 for box in all(game.boxes) do
  if (
   box:is_at(x,y)
   and box:on_tgt(self)
  ) then
   return true
  end
 end

 return false
end

function level:is_done(game)
 local old_cnt=game.box_cnt
 game.box_cnt=0

 for box in all(game.boxes) do
  if box:on_tgt(self) then
   game.box_cnt+=1
  end
 end

 if game.box_cnt>old_cnt then
  sfx(3)
 end

 return game.box_cnt==#game.boxes
end

-->8
--main

function _init()
 _title=title:new()
 _levelmenu=levelmenu:new()
 _stats=stats:new()
 _statsview=statsview:new()

 --disable btnp auto-repeat
 --to use custom hold logic
 poke(0x5f5c,255)

 scene=_title
 --start_level(19)
end

function _update60()
 scene:update()
end

function _draw()
 scene:draw()
end

function start_level(idx)
 _game=game:new(idx)
 scene=_game
 _game.anim=animate_level_start(
  idx
 )
end

title={}
function title:new()
 local o=new_object(self)

 o.car={x=60,dx=0.5,c=2}
 o.boxr={x=116,c=4}
 o.boxl={x=4,c=2}
 o.boxes={o.boxr,o.boxl}
 o.tick=0

 return o
end

function title:update()
 self.tick=(self.tick+1)%1
 if self.tick!=0 then
  return
 end

 if btnp(❎) then
  scene=_levelmenu
  return
 elseif btnp(⬅️) or btnp(➡️) then
  easymode=not easymode
 end

 local car=self.car
 car.x+=car.dx
 if car.dx>0 then
  if car.x>120 then
   car.dx=-car.dx
  elseif car.x>=108 then
   local box=self.boxr
   box.x=car.x+8
   if not box.touched then
    box.touched=true
    sfx(0)
   end
  elseif car.x>78 then
   if car.c!=4 then sfx(5) end
   car.c=4
  elseif car.x>32 then
   local box=self.boxl
   if box.touched then
    sfx(1)
    box.x=4
    box.touched=false
   end
  end
 else
  if car.x<8 then
   car.dx=-car.dx
  elseif car.x<=20 then
   local box=self.boxl
   box.x=car.x-16
   if not box.touched then
    box.touched=true
    sfx(0)
   end
  elseif car.x<50 then
   if car.c!=2 then sfx(5) end
   car.c=2
  elseif car.x<95 then
   local box=self.boxr
   if box.touched then
    sfx(1)
    box.x=116
    box.touched=false
   end
  end
 end
end

function title:draw()
 cls()

 print("eriban's",48,5,13)
 pal(15,1)
 pal(5,12)
 pal(6,13)
 map(0,21,32,12,8,3)
 for x=0,5 do
  for y=0,1 do
   spr(128+x+y*16,x*8+40,y*8+33)
  end
 end
 pal()

 rect3d(34,56,93,95,1,13,1)
 print(
  easymode and "easy" or "hard",
  48,58,13
 )
 print("◆◆",72,58,13)
 print("[    ] ⬅️➡️",44,58,0)
 local y=69+(
  easymode and 0 or 7
 )
 print("◆◆◆◆ move",37,y,13)
 print("⬅️➡️⬆️⬇️",37,y,0)
 y+=7
 if easymode then
  print("◆       undo",37,y,13)
  print("❎",37,y,0)
  y+=7
 end
 print("◆       retry",37,y,13)
 print("❎(hold)",37,y,0)
 y+=6
 print(" exit",73,y,13)
 print("/",73,y,0)

 rectfill(0,121,127,127,5)
 print(
  "press ❎ to start",30,122,0
 ) 

 palt(15,true)
 palt(0,false)

 --draw bubbles
 spr(10,40,106)
 spr(9,81,106)

 --draw boxes
 local car=self.car
 for box in all(self.boxes) do
  local p=box.c
  if car.c!=box.c then
   p=easymode and (p+4) or 9
  end
  bubble_pal(p)
  spr(11,box.x,113)
 end
 bubble_pal()

 --draw car
 spr(
  2+2*(flr(car.x%3)),
  car.x-8,113,
  2,1
 )
 pal(6,bub_pals[car.c][9])
 pal(7,bub_pals[car.c][10])
 spr(8,car.x-4,106)
 pal()
end

game={}
function game:new(level_idx)
 local o=new_object(self)

 o.box_cnt=0
 o.mov_cnt=0
 o.boxes={}
 o.level=level:new(level_idx)
 o.level:add_objects(o)

 return o
end

function game:draw()
 cls(0)

 self.level:draw(self)
 self.player:draw(self)
 self.level:draw_bubbles()

 if self.anim!=nil then
  self.anim.draw()
 end
end

function game:update()
 local lvl=self.level
 if self.anim then
  if coinvoke(self.anim) then
   self.anim=nil
  end
 elseif btnp(🅾️) then
  --start_level(
  -- lvl.idx%#level_defs+1
  --)
  --self.anim=animate_level_done(
  -- self.mov_cnt,new_hi
  --)
 else
  self.player:update(self)

  if lvl:is_done(self) then
   local new_hi=_stats:mark_done(
    lvl.idx,self.mov_cnt
   )
   self.anim=animate_level_done(
    self.mov_cnt,new_hi
   )
  end
 end
end
__gfx__
0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccfffff888fff0aaaaaa000999900000000000000000000000000
0000000000000000f55555555555555ff55555555555555ff55555555555555ffffffffffc6cccfff8e888ffa999999409aa9990000000000000000000000000
0070070088778877555555555555555555555555555555555555555555555555ffffffffc676cc1f8e7e882fa99999949a7aa994000000000000000000000000
0007700088778877554544544544545555445445445445555554454454454455ffffffffcc6ccc1f88e8882fa99999949aaaa994000000000000000000000000
0007700000000000546665555556664555666555555666455466655555566655ffffffffcccccc1f8888882fa999999499aa9994000000000000000000000000
0070070000000000556065555556065ff46065555556064ff46065555556064ffff66ffffcccc1fff88882ffa999999499999944000000000000000000000000
0000000000000000f4666ffffff6664ff4666ffffff666ffff666ffffff6664fff7666ffff111fffff222fffa999999409999440000000000000000000000000
0000000000000000ff4f44f44f44f4fffff44f44f44f44ffff44f44f44f44ffff776666fffffffffffffffff0444444000444400000000000000000000000000
ffffff6666ffffff5555555f0000000000000000000000000000000006555555555555f006555555555555f00000000000000000000000000000000000000000
fffff655555fffff5555555f0000000000066666666660000000000006555555555555f666555555555555f00000000000000000000000000000000000000000
ffff65555555ffff555555f000000000066555555555555000000000065555555555555555555555555555f00000000000000000000000000000000000000000
fff6555555555fff55555f0000000000655555555555555500000000065555555555555555555555555555f00000000000000000000000000000000000000000
ff655555555555ff5555550000000006555555555555555550000000065555555555555555555555555555f00000000000000000000000000000000000000000
f65555555555555f555555500000006555555555555555555500000000555555555555555555555555555f000000000000000000000000000000000000000000
655555555555555f5555555f0000065555555555555555555550000000555555555555555555555555555f000000000000000000000000000000000000000000
655555555555555f5555555f000065555555555555555555555500000005555555555555555555555555f0000000000000000000000000000000000000000000
655555555555555fffffffff00065555555555555555555555555000000055555555555555555555555f00000000000000000000000000000000000000000000
655555555555555fffffffff0065555555555555555555555555550000000555555555555555555555f000000000000000000000000000000000000000000000
f5555555555555ffffffffff006555555555555555555555555555000000005555555555555555555f0000000000000000000000000000000000000000000000
ff55555555555fffffffffff065555555555555555555555555555f0000000055555555555555555f00000000000000000000000000000000000000000000000
fff555555555ffffffffffff065555555555555555555555555555f000000000555555555555555f000000000000000000000000000000000000000000000000
ffff5555555fffffffffffff065555555555555555555555555555f0000000000555555555555ff0000000000000000000000000000000000000000000000000
fffff55555ffffffffffffff06555555555555ffff555555555555f000000000000ffffffffff000000000000000000000000000000000000000000000000000
ffffffffffffffffffffffff06555555555555f506555555555555f0000000000000000000000000000000000000000000000000000000000000000000000000
6666666f06666666666666606555555f6555555f6555555f6666666606666660666666606555555f06666666666666666555555f6555555f6555555f00000000
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500666600
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f5555555565555555065555f0
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f5555555565555555065555f0
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f5555555565555555065555f0
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f5555555565555555065555f0
6555555f655555555555555f655555555555555f6555555f555555556555555f5555555f6555555f65555555555555555555555f555555556555555500ffff00
ffffffff6555555ff555555f0ffffffffffffff06555555fffffffff6555555ffffffff00ffffff00ffffffff555555ff555555fffffffff6555555f00000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffff000000000000000000000000
00aaaa0000aaaa0000aaaa0000aaaa0000aaaa000990099000000000066006600990099008800880033003300cc00cc0ffaaaaff09aaaa900000000000000000
0a9999400a9a99400a9e89400a9b39400a96c94009000090000a9000060a9060090a9090080a9080030a90300c0a90c0fa99994f0a9999400000000000000000
0a9999400aa7a9400ae7e8400ab7b3400a676c400000000000a7a90000a7a90000a7a90000a7a90000a7a90000a7a900fa99994f0a9999400000000000000000
0a9999400a9a99400a8e88400a3b33400ac6cc4000000000009a9900009a9900009a9900009a9900009a9900009a9900fa99994f0a9999400000000000000000
0a9999400a9999400a9889400a9339400a9cc9400900009000099000060990600909909008099080030990300c0990c0fa99994f0a9999400000000000000000
00444400004444000044440000444400004444000990099000000000066006600990099008800880033003300cc00cc0ff4444ff094444900000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffff000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eeee0000eeee0000eeee0000eeee0000eeee000880088000000000066006600990099008800880033003300cc00cc00411114003aaaa3003aaaa3000000000
0e8888200e8a98200e8e88200e8b38200e86c82008000080000e8000060e8060090e8090080e8080030e80300c0e80c0041111400a9999400a9b394000000000
0e8888200ea7a9200ee7e8200eb7b3200e676c200000000000e7e80000e7e80000e7e80000e7e80000e7e80000e7e800021651200a9999400ab7b34000000000
0e8888200e9a99200e8e88200e3b33200ec6cc2000000000008e8800008e8800008e8800008e8800008e8800008e8800041551400a9999400a3b334000000000
0e8888200e8998200e8888200e8338200e8cc8200800008000088000060880600908809008088080030880300c0880c0041111400a9999400a93394000000000
00222200002222000022220000222200002222000880088000000000066006600990099008800880033003300cc00cc002111120034444300344443000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbbb0000bbbb0000bbbb0000bbbb0000bbbb000330033000000000066006600990099008800880033003300cc00cc00660066009bbbb900000000000000000
0b3333100b3a93100b3e83100b3b33100b36c31003000030000b3000060b3060090b3090080b3080030b30300c0b30c0060000600b3333100000000000000000
0b3333100ba7a9100be7e8100bb7b3100b676c100000000000b7b30000b7b30000b7b30000b7b30000b7b30000b7b300000000000b3333100000000000000000
0b3333100b9a99100b8e88100b3b33100bc6cc1000000000003b3300003b3300003b3300003b3300003b3300003b3300000000000b3333100000000000000000
0b3333100b3993100b3883100b3333100b3cc3100300003000033000060330600903309008033080030330300c0330c0060000600b3333100000000000000000
00111100001111000011110000111100001111000330033000000000066006600990099008800880033003300cc00cc006600660091111900000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666600006666000066660000666600006666000cc00cc000000000066006600990099008800880033003300cc00cc008bbbb8003bbbb300000000000000000
06cccc1006ca9c1006ce8c1006cb3c1006c6cc100c0000c00006c0000606c0600906c0900806c0800306c0300c06c0c00b3333100b3333100000000000000000
06cccc1006a7a91006e7e81006b7b31006676c100000000000676c0000676c0000676c0000676c0000676c0000676c000b3333100b3333100000000000000000
06cccc10069a9910068e8810063b331006c6cc100000000000c6cc0000c6cc0000c6cc0000c6cc0000c6cc0000c6cc000b3333100b3333100000000000000000
06cccc1006c99c1006c88c1006c33c1006cccc100c0000c0000cc000060cc060090cc090080cc080030cc0300c0cc0c00b3333100b3333100000000000000000
00111100001111000011110000111100001111000cc00cc000000000066006600990099008800880033003300cc00cc008111180031111300000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ee00000000000000ee000000ee000000ee000000000000dddddd00dddddd00dd10dd10dddddd0000000000000000000000000000000000000000000000000
00e882000000000000e8820000e8820000e8820000000000dcccccc1dcccccc1dcc1dcc1dcccccc1000000000000000000000000000000000055555555555500
0e888820000000000e8888200e8888200e88882000000000dcccccc1dcccccc1dcc1dcc1dcccccc10ee00000000ee000ee000ee0000000000055555555555500
0e888820000000000e8888200e8888200e88882000000000dccc1110dcccccc1dcc1ccc1dcccccc1e880000000e8800e8800e882000000000000000000000000
0e8888200000000eee8888200e8888200e88882000eeee00dccc1dd0dcc11cc1dcccccc1dcc11cc1e88000ee0ee8800e8800e8820ee000000055555000005500
0e888822200ee0e8822888222e8888222e8888200e888820dcccccc1dcc1dcc1dccccc10dcc1dcc1e88ee08808828eee88eee882e88800000000000000000000
0e88828882e88288882882888288828882888820e8888882dcccccc1dcc1dcc1dccccc10dcc1dcc1e88888282882888828888282882820000055555550005500
0e8888888828882888288888882888888828882e888288820111ccc1dcc1dcc1dcccccc1dcc1dcc1e88888282882888828888282888820000000000000000000
0e8888888828882888288888882888888828882e882e88820dddccc1dcccccc1dcc1ccc1dcccccc1e88288282882828828288282882200000055555000005500
0e8882288828882888288228882882288828882288888820dcccccc1dcccccc1dcc1dcc1dcccccc1e88888288882888828888288288820000000000000000000
0e8882e888288828882882e8882882e88828828828822282dcccccc1dcccccc1dcc1dcc1dcccccc1088882888828888288882888288820000055555500005500
0e888888828888888828888882888888828888882888888201111110011111100111011101111110002220022200222002220022022200000000000000000000
0e888888828888888288888882888888828888882888882000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888882200888822088888220888882208888828888220000000000000000000000000000000000000000000000000000000000000000000000000000000000
00022220000022200002222000022220000222202222000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000999000000009990000000000000000000000000000000000000044000000000000000424000000000000004240000000000000004400000
0000aaaaaaaa00000990000000000990000001111110000000042d42d42d40000000244111000000000004442110000000000112444000000000001114420000
000aaaaaaaaa90000900000000000090004411111111440000042d42d42d40000004421111110000000442411111000000001111142440000000111111244000
00aa9999999944000000000000000000002211111111220000011111111110000004411111111000002442111111100000011111112442000001111111144000
00aa999999994400000000000000000000dd11111111dd0000111111111111000042211111111100044211111111100000011111111124400011111111122400
00aa9999999944000000000000000000004411165111440000111116511111000444111651111100044111165111110000111116511114400011111651114440
00aa9999999944000000000000000000002211666511220000111166651111000241116665111240001111666511110000111166651111000421116665111420
00aa999999994400000000000000000000dd11565511dd0000111156551111000421115655111420001111565511110000111156551111000241115655111240
00aa9999999944000000000000000000004411155111440000111115511111000011111551114440001111155111144004411115511111000444111551111100
00aa9999999944000000000000000000002211111111220000111111111111000011111111122400000111111111244004421111111110000042211111111100
00aa999999994400000000000000000000dd11111111dd0000011111111110000001111111144000000111111124420000244211111110000004411111111000
00094444444440000900000000000090004411111111440000042d42d42d40000000111111244000000011111424400000044241111100000004421111110000
00004444444400000990000000000990000001111110000000042d42d42d40000000001114420000000001124440000000000444211000000000244111000000
00000000000000000999000000009990000000000000000000000000000000000000000004400000000000042400000000000042400000000000044000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000006555555555555f006555555555555f006555555555555f000000000000000000000000000000000
00666666666666000066666666666666666666666666660006555555555555f666555555555555f006555555555555f066666666666666660066666666666600
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
06555555555555f0065555555555555555555555555555f0065555555555555555555555555555f006555555555555f0555555555555555506555555555555f0
00ffffffffffff0006555555555555ffff555555555555f000ffffffffffffffffffffffffffff0006555555555555f0ffffffffffffffff06555555555555f0
000000000000000006555555555555f006555555555555f00000000000000000000000000000000006555555555555f0000000000000000006555555555555f0
000000000000000006555555555555f00000000000000000000000000000000006555555555555f006555555555555f006555555555555f05555555555555555
666666666666660006555555555555f00066666666666666666666666666666666555555555555f066555555555555f606555555555555f65555555555555555
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f0555555555555555506555555555555555555666666665555
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555555666666666f555
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555556655555555ff55
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f055555555555555550655555555555555555ffffffffff555
55555555555555f006555555555555f00655555555555555555555555555555555555555555555f0555555555555555506555555555555555555ffffffff5555
ffffffffffffff0000ffffffffffff0000ffffffffffffffff555555555555ffff555555555555f0ffffffffffffffff06555555555555ff5555555555555555
00000000000000000000000000000000000000000000000006555555555555f006555555555555f0000000000000000006555555555555f05555555555555555
__label__
00ddddddddddddddddddddddddddddd100dddddddddddddddddddddddddddd00ddddddddddddddd1ddddddddddddddd100dddddddddddddddddddddddddddd00
0ddddddddddddddddddddddddddddd110ddddddddddddddddddddddddddddd10dddddddddddddd11dddddddddddddd110ddddddddddddddddddddddddddddd10
dddccccccccccccccccccccccccccc11dddcccccccccccccccccccccccccc111ddcccccccccccc11ddcccccccccccc11dddcccccccccccccccccccccccccc111
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccc111111111111111111ddcccccccccccc1111cccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc1111cccccccccccc11
ddcccccccccccc111111111111111111ddcccccccccccc111dcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc111dcccccccccccc11
ddcccccccccccc11dddddddddddddd00ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11dccccccccccccc11ddcccccccccccc11ddcccccccccccc11
ddcccccccccccc1ddddddddddddddd10ddcccccccccccc11ddcccccccccccc11ddcccccccccccc1dcccccccccccccc11ddcccccccccccc11ddcccccccccccc11
ddccccccccccccccccccccccccccc111ddcccccccccccc11ddcccccccccccc11ddcccccccccccc1ccccccccccccccc11ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddccccccccccccccccccccccccccc110ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccc1100ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddccccccccccccccccccccccccc11000ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccc110000ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccc100000ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddccccccccccccccccccccccccc00000ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddccccccccccccccccccccccccccc000ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc00ddcccccccccccc11ddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc10ddcccccccccccc11ddcccccccccccc11
dd1ccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc1ccccccccccccccc11ddcccccccccccc11ddcccccccccccc11
011111111111111111cccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11cccccccccccccc11ddcccccccccccc11ddcccccccccccc11
00111111111111111dcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11dccccccccccccc11ddcccccccccccc11ddcccccccccccc11
ddddddddddddddddddcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc11
ddddddddddddddddddcccccccccccc11ddcccccccccccc1dddcccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccc1dddcccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccccccccccc11ddcccccccccccccccccccccccccccc11ddcccccccccccc11ddcccccccccccc11ddcccccccccccccccccccccccccccc11
ddcccccccccccccccccccceeeecccc11ddcccccccccccccccccccceeeecccc11ddcccceeeecccc11ddcccceeeecccc11ddcccccccccccccccccccccccccccc11
ddccccccccccccccccccceee888cc111dd1cccccccccccccccccceee888cc111ddccceee888ccc11ddccceee888ccc11dd1cccccccccccccccccccccccccc111
d1111111111111111111eee88882211001111111111111111111eee888822110d111eee888822111d111eee88882211101111111111111111111111111111110
1111111111111111111eee88888822000011111111111111111eee8888882200111eee8888882211111eee888888221100111111111111111111111111111100
0000000000000000000ee888888822000000000000000000000ee88888882200000ee88888882200000ee8888888220000000000000000000000000000000000
000000000000000000eee88888882200000000000000000000eee8888888220000eee8888888220000eee8888888220000000000000000000000000000000000
000000000000000000ee88888888220000000000000000eeeeee88888888220000ee88888888220000ee8888888822000000000eeeeeeee00000000000000000
000000000000000000ee8888888822000000000000000ee888ee88888888220000ee88888888220000ee88888888220000000eeee88888880000000000000000
000000000000000000ee888888882200000000eeee00ee88888e88888888220000ee88888888220000ee8888888822000000eee8888888882000000000000000
000000000000000000e888888888220000000ee88880e888888888888888220000e888888888220000e8888888882200000eee88888888888200000000000000
000000000000000000e88888888822000000ee8888828888888828888888220000e888888888220000e888888888220000eee888888888888820000000000000
000000000000000000e88888888222eee200e8888888288888882288888222eee2e88888888222eee2e88888888822000eee8888888888888822000000000000
000000000000000000e88888882228888822e888888822888888228888222888882288888822288888228888888822000ee88888882888888822000000000000
000000000000000000e88888882288888882288888882288888822888822888888822888882288888882288888882200eee88888822288888822000000000000
000000000000000000e88888888888888888228888882288888822888888888888882288888888888888228888882200ee888888222e88888822000000000000
000000000000000000e88888888888888888228888882288888822888888888888882288888888888888228888882200ee88888882e888888222000000000000
000000000000000000e88888888888888888228888882288888822888888888888882288888888888888228888882200e8888888888888888220000000000000
000000000000000000e88888888888888888228888882288888822888888888888882288888888888888228888882200e8888888888888882220000000000000
000000000000000000e88888888228888888228888882288888822888882288888882288888228888888228888882ee2e8888888888888882200000000000000
000000000000000000e8888888222288888822888888228888882288882222888888228888222288888822888882888228888888888888222200000000000000
000000000000000000e8888888222e8888882288888822888888228888222e888888228888222e88888822888888888822888888222222288820000000000000
000000000000000000e888888882e8888882228888882888888222888882e888888222888882e888888222888888888882288888882288888822000000000000
000000000000000000e8888888888888888222888888888888822288888888888882228888888888888222888888888882288888888888888822000000000000
000000000000000000e8888888888888882228888888888888222888888888888822288888888888882228888888888882288888888888888822000000000000
000000000000000000e8888888888888882228888888888888222888888888888822288888888888882228888888888822288888888888888222000000000000
00000000000000000008888888888888822288888888888882228888888888888222888888888888822288888888888822288888888888888220000000000000
00000000000000000008888888888888222088888888888822208888888888882220888888888888222088888888888222888888888888882220000000000000
00000000000000000000888888888822220088888888882222008888888888222200888888888822220088888888882220888888888888222200000000000000
00000000000000000000088888882222000008888888222200000888888822220000088888882222000008888888222200088888888822220000000000000000
00000000000000000000002222222200000000222222220000000022222222000000002222222200000000222222220000002222222222000000000000000000
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
000000000000000000000000000000000000000000000000000000000000000000ccccc100000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000ccccccccc1000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000cc66cccccc1100000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000c6776cccccc100000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000cc6766cccccc110000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000ccc66ccccccc110000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000cccccccccccc110000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000cccccccccccc110000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000ccccccccccc1110000000000000000000000000000000000000000000000000000
000000000000000000000000000008888882200000000000000000000000001cccccccccc1110000000000000000000000000000000000000000000000000000
000000000000000000000000000888888888822000000000000000000000000ccccccccc11100000000000000000000000000000000000000000000000000000
00000000000000000000000000888888888888220000000000000000000000011ccccc1111100000000000000000000000000000000000000000000000000000
000000000000000000000000088eee88888888822000000000000000000000001111111111000000000000000000000000000000000000000000000000000000
00000000000000000000000088e76ee8888888882200000000000000000000000011111100000000000000000000000000000000000000000000000000000000
00000000000000000000000088e66ee8888888882200000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000888eeeee8888888888220000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000008888eee88888888888220000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000888888888888888888220000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000888888888888888888220000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000666666666666666666666666666666666666666666666666666600000000000000000000000000000000000000000000ccccccccccccccccc00000000
000000655555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000ccccccccccccccccccc0000000
00000655555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000cccccccccccccccccccc1000000
0000655555555555555555555555555555555555555555555555555555555200000000000000000000000000000000000000cccccccccccccccccccc11100000
0000655555555555559999995555559999995555559999995555555555555200000000000000000000000000000000000000cccc111111111111111111100000
0000655555555555594444442555594444442555594444442555555555555200000000000000000000000000000000000000cccc111111111111111111100000
0000655559994555594444442555594444442555594444442555599945555200000000000000000000000000000000000000cccc111111111111111111100000
0000655594442555552222225555552222225555552222225555594444555200000000000000000000000000000000000000cccc111111111111111111100000
0000655944422666655555555555555555555555555555555666644444455200000000000000000000000000000000000000cccc111111111111111111100000
0000655944266666666555555555555555555555555555566666666444255200000000000000000000000000000000000000cccc111111111111111111100000
0000655942666666666655555555555555555555555555666666666644255200000000000000000000000000000000000000cccc111111111111111111100000
0000655422666666666655555555555555555555555555666666666642255200000000000000000000000000000000000000cccc111111111111111111100000
0000655556666600666665555555555555555555555556666600666665555200000000000000000000000000000000000000cccc111111111111111111100000
0000055556666000066665555555555555555555555556666000066665552000000000000000000000000000000000000000cccc111111111111111111100000
0000005556666000066665555555555555555555555556666000066665520000000000000000000000000000000000000000cccc111111111111111111100000
0000000226666600666662222222222222222222222226666600666662200000000000000000000000000000000000000000cccc111111111111111111100000
0000000994666666666600000000000000000000000000666666666699400000000000000000000000000000000000000000cccc111111111111111111100000
0000000944666666666600000000000000000000000000666666666694200000000000000000000000000000000000000000cccc111111111111111111100000
0000000944466666666000000000000000000000000000066666666944200000000000000000000000000000000000000000cccc111111111111111111100000
0000000444444666600000000000000000000000000000000666699444200000000000000000000000000000000000000000cccc111111111111111111100000
0000000044442000009999990000009999990000009999990000094442000000000000000000000000000000000000000000cccc111111111111111111100000
00000000022220000944444420000944444420000944444420000422200000000000000000000000000000000000000000000cc1111111111111111111000000
00000000000000000944444420000944444420000944444420000000000000000000000000000000000000000000000000000011111111111111111110000000
00000000000000000022222200000022222200000022222200000000000000000000000000000000000000000000000000000001111111111111111100000000

__gff__
00000000000000000000000000000000020202020202020202020200000000000202020202020202020202000000000002020202020202020202020202020202041414141408101818181818060c0000041414141408101818181818010c1c00041414141408101818181818080c00000414141414081018181818180c0c0000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202000002020202020202020202020202020000
__map__
313636363636363231363636363636323136363636363632313636363636363210363636363636112231363636363222103636363636361131363636363636321036363636363611103636010136361110363636363636111036363636363611373a363636363638313636010136363200000000000000000000000000000000
355c000000000035355500003f006535355c0000000000353546004545005635353f000046003f3531340000460033323575000000007535355c000000006a353545480000006a35355c000000000035355c00000000003535484d00400065353500005b004500373545454600006a3500000000000000000000000000000000
350000000000003535005c6000000035350000000000003539005c7070000039355c600101700035355c60000070003535005570705500353500505070706535355c00507000653535007000005000353500400000700035355e6065004600353575005000000035355c00604000653500000000000000000000000000000000
3500005000703f35353f00567640003535755076567055353765500000605537350000697800003535000055450000353500705c565000353500000000003a3c3500600000700035350070000050003535006200005400353545656d00606035355c004050607835350070000040003500000000000000000000000000000000
35000070000000353500506646003f35357550765670553539655000006055393500007565000035333276756566003535007076005000353e3800606000003535004000005000353500007656000035350000000000003535654d5d60000035354a407066000035350050000060003500000000000000000000000000000000
3500005400755535350000007000003535000000000000353700004040000037350040000050003522354000005000353500755050750035357500000000003535750040600000352032005575003121203275554565312135614500004000353500000070005535357500507000003500000000000000000000000000000000
3556003f005575353545003f0000753535000000000000353566007575007635353f005600003f3522350000560031343555000000005535357b000037555935357b000000595535223500557500352222350046660035223500450040000035390065007c000035357b00005655553500000000000000000000000000000000
3336363636363634333636363636363433363636363636343336383a383a3634203636363636362122333636363634222036363636363621333636363d36363420363636363636212220363636362122222036363636212220363636363636213a36363636363839333636363636363400000000000000000000000000000000
3136363636363231363b363b3632313636363636323136363636363632000000000000003136363636363632313636363222222231363636363632313636363636363231363601363632000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
350056000000353575397639753535000000000035355c00000000003500000000000000355c0000000000353500000033363632355c0000707535355c000000000035354b0040005835000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
350037003770353500000000003535005c50400035357550765670553500000000000000350070595b500035350000500000753535750000700035350070595b500035355c4b40580035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
355c3576356c353570005c00503535006056006635357550765670553500000000000000350070797b5000353e38763056563a3c35760101707535350070797b50003535707000505035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
350033363d363c35000000000035350070006c6c353500000000000035000000000000003500000000000035355c50007000553535750000700035350070557550003535007a60690035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35005000006c3535553756375535350000766c473535000000000000350000000000000020320000000031213500000000005535350000007075353500707555500035357a0060006935000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3336363636363433363d363d3634333636363636343336363636363634000000000000002233363636363422333636363636363433363636363634203636363636362133363636363634000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3a3b383737313831363636363636320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22355c3e3c3e3835590050007075350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
223945393933383e3800005c003a3c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31383111311137357b0050007055350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e38353535353935000000000000350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3338393933214c33363636363636340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3138313237373132000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
333235353e123535000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3a34333439393334000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001a0501a020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001400001c05018050100501005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000295502d550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001c7201c720267302673030742307423073230722307252670030702307020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001e5102b5411e5110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001813018131181311813500100001001c1401c1411c1411c1311d1311d1311d1311d1211d1211d1251d100001000010000100001000010000100001000010000100001000010000100001000010000100
0104000023144171510b1450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001c7501c7501c7501c7551d7501d7501d7501d7551f7621f7621d7521d7521f7521f7521f7521f75500700007000070000700007000070000700007000070000700007000070000700007000070000700
