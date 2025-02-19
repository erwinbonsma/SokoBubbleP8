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
},{
 name="enclosed",
 mapdef={48,0,8,8},
 id=8,
},{
 name="swap 2",
 mapdef={21,8,8,7},
 id=9
},{
 name="coffee",
 mapdef={59,8,8,7},
 id=16,
},{
 name="cramped",
 mapdef={88,0,8,8},
 ini_bubble=1,
 ini_pos={x=1,y=1},
 id=17,
},{
 name="rgb",
 mapdef={29,8,7,7},
 id=21,
},{
 name="rgb2",
 mapdef={56,0,8,8},
 id=10
},{
 name="foursome",
 mapdef={14,8,7,7},
 id=11
},{
 name="skull",
 mapdef={80,0,8,8},
 id=15,
},{
 name="spiral",
 mapdef={8,0,8,8},
 id=12
},{
 name="center",
 mapdef={40,0,8,8},
 id=14,
 ini_pos={x=4,y=3}
},
{
 name="squares",
 mapdef={72,0,8,8},
 id=20,
},{
 name="cross",
 mapdef={24,0,8,8},
 id=13
},{
 name="windmill",
 mapdef={96,0,8,8},
 id=18,
},{
 name="whirly",
 mapdef={64,0,8,8},
 id=19,
 ini_pos={x=1,y=1}
},{
 name="3x3",
 mapdef={104,0,8,8},
 id=22
},{
 name="the end",
 mapdef={0,15,7,6},
 id=99,
 ini_bubble=1,
 no_floor=true,
 hide_score=true
}}
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
music_on=true

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

function ease(x)
 return (
  x<=0.5 and x*x*2 or 1-ease(1-x)
 )
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

function centerprint(s,y,c)
 print(s,64-#s*2,y,c)
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

function roundrect(
 x1,y1,x2,y2,c
)
 rectfill(x1,y1+1,x2,y2-1,c)
 line(x1+1,y1,x2-1,y1)
 line(x1+1,y2,x2-1,y2)
end

function level_start_anim(
 args
)
 local state=args[1]

 if state.lvl_old then
  for i=0,60 do
   state.offset=ease(i/60)*128
   yield()
  end
  wait(30)
 else
  state.offset=128
 end

 state.lvl_new.hide_score=false

 sfx(6)
end

function animate_level_start(
 lvl_new,lvl_old
)
 local anim
 local state={
  offset=lvl_old and 0 or 128,
  lvl_new=lvl_new,
  lvl_old=lvl_old
 }
 lvl_new.hide_score=true

 anim=cowrap(
  "level_start",
  level_start_anim,
  state
 )
 anim.draw=function()
  local offset=state.offset
  if lvl_old then
   lvl_old:draw(-offset)
  end
  lvl_new:draw(128-offset)
    spr(134,34-offset,0,8,2)
  draw_lvl_name(
   lvl_new,128-offset,4
  )
 end

 return anim
end

function level_done_anim(args)
 local lvl=args[1]

 wait(30)
 sfx(4)
 wait(120)

 if stats:is_hi(
  lvl.idx,lvl.mov_cnt
 ) then
  sfx(8)
  for i=1,90 do
   lvl.force_show_score=(
    (i\30)%2
   )==0
   yield()
  end
 end

 _stats:mark_done(
  lvl.idx,lvl.mov_cnt
 )

 start_level(lvl.idx+1,lvl)
 yield() --allow anim swap
end

function animate_level_done(
 lvl
)
 local anim=cowrap(
  "level_done",
  level_done_anim,
  lvl
 )
 return anim
end

function retry_anim(args)
 local lvl=args[1]

 sfx(2)
 wait(60)
 if lvl.idx==#level_defs then
  --from end go to stats
  scene=_statsview
 elseif lvl.mov_cnt==0 then
  --start completely afresh
  scene=_title
 else
  start_level(lvl.idx)
 end
 yield() --allow anim swap
end

function animate_retry(lvl)
 local anim=cowrap(
  "retry",retry_anim,lvl
 )
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

function stats:all_solved()
 return (
  self.max_lvl_idx==#level_defs
 )
end

function stats:is_hi(
 lvl_idx,num_moves
)
 local hi=self:get_hi(lvl_idx)
 return hi==0 or num_moves<hi
end

function stats:mark_done(
 lvl_idx,num_moves
)
 if self:is_hi(
  lvl_idx,num_moves
 ) then
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
 end
end

function stats:is_done(lvl_idx)
 return self:get_hi(lvl_idx)>0
end

function stats:get_hi(lvl_idx)
 return dget(1+level_id(lvl_idx))
end

function draw_lvl_name(
 lvl,x_offset,y
)
 local s=(
  ""..lvl.idx.."."
  ..lvl.lvl_def.name
 )
 local xmin=64-#s*2+x_offset
 local xmax=62+#s*2+x_offset
 roundrect(
  xmin-2,y,xmax+2,y+8,13
 )
 print(s,xmin,y+2,1)
end

function level_switch_anim(args)
 local state=args[1]

 sfx(1)

 for i=0,60 do
  if i<10 then
   state.name_y=3-i
  elseif i>50 then
   state.name_y=i-57
  else
   state.name_y=nil
  end

  state.offset=ease(i/60)*128
  yield()
 end
end

function animate_lvl_switch(
 lvl_l,lvl_r,l2r
)
 local state={offset=0}
 local anim=cowrap(
  "level_switch",
  level_switch_anim,
  state
 )
 anim.draw=function()
  local offset=(
   l2r and state.offset
   or 128-state.offset
  )

  lvl_l:draw(-offset)
  lvl_r:draw(128-offset)

  if state.name_y then
   local lvl=(
    offset<64 and lvl_l or lvl_r
   )
   draw_lvl_name(
    lvl,0,state.name_y
   )
  end
 end

 return anim
end

levelmenu={}
function levelmenu:new()
 local o=new_object(self)

 o:set_lvl(_stats.max_lvl_idx)

 return o
end

function levelmenu:set_lvl(
 lvl_idx
)
 self.lvl=level:new(lvl_idx)
end

function levelmenu:update()
 if self.anim then
  if coinvoke(self.anim) then
   self.anim=nil
  end
  return
 end

 local max_idx=_stats.max_lvl_idx

 if max_idx==1 or btnp(❎) then
  if (
   self.lvl.idx<#level_defs
  ) then
   start_level(self.lvl.idx)
   return
  else
   sfx(1)
  end
 end

 if btnp(➡️) then
  local nxt_lvl=level:new(
   1+(self.lvl.idx)%max_idx
  )
  self.anim=animate_lvl_switch(
   self.lvl,nxt_lvl,true
  )
  self.lvl=nxt_lvl
 elseif btnp(⬅️) then
  local nxt_lvl=level:new(
   1+(
    self.lvl.idx+max_idx-2
   )%max_idx
  )
  self.anim=animate_lvl_switch(
   nxt_lvl,self.lvl,false
  )
  self.lvl=nxt_lvl
 end
 self.lvl.hide_score=true
end

function levelmenu:draw()
 cls()

 if self.anim then
  self.anim:draw()
  return
 end

 self.lvl:draw()
 draw_lvl_name(self.lvl,0,4)

 spr(142,4,56,1,2)
 spr(143,115,56,1,2)

 if (
  self.lvl.idx==#level_defs
 ) then
  return
 end

 local s="press ❎ to play"
 local w=#s*2+4
 roundrect(64-w,118,63+w,126,13)
 rectfill(92-w,121,94-w,123,12)
 print(s,66-w,120,1)
end

statsview={}
function statsview:new()
 local o=new_object(self)

 return o
end

function statsview:update()
 if btnp(❎) then
  scene=_title
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
   x+6-(i>=10 and 4 or 0),y,13
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
 o.mov_history=""

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
 local lvl=args[3]

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
   plyr.movq,lvl
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

function player:_move(lvl)
 if coinvoke(self.mov.anim) then
  self.mov=nil
 end

 if (
  self.sx%ss==0
  and self.sy%ss==0
 ) then
  local bub=lvl:bubble(
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
 mov,lvl
)
 local x1=mov.dst_x
 local y1=mov.dst_y

 local ws=lvl:wall_size(x1,y1)
 if ws!=0 then
  return 2+(ss-ws)\2
 end

 local box=lvl:box_at(x1,y1)
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
   or lvl:box_at(x2,y2)!=nil
  ) then
   --no room to push box
   return 4
  end
 end

 mov.push_box=box
 return 0
end

function player:_check_move(
 mov,lvl
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
  mov,lvl
 )
 if mov.blocked!=0 then
  mov.dst_x=mov.src_x
  mov.dst_y=mov.src_y
 end
 mov.dst_c=lvl:bubble(
  mov.dst_x,mov.dst_y
 ) or mov.src_c

 return mov
end

function player:_start_move(
 mov,lvl
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
   mov,self,lvl
  )
 else
  mov.anim=cowrap(
   "plain_move",
   plain_move_anim,
   mov,self
  )
 end

 if mov.blocked==0 then
  if lvl.mov_cnt<999 then
   lvl.mov_cnt+=1
   self.mov_history..=mov.button
  end
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

function player:_undo(lvl)
 local mov=self.undo_stack:pop()
 if mov==nil then
  return false
 end

 self.sx=mov.src_x*ss
 self.sy=mov.src_y*ss
 self.rot=mov.ini_rot
 self.bubble=mov.ini_bubble
 self.mov_history=sub(
  self.mov_history,0,
  #self.mov_history-1
 )
 lvl.mov_cnt-=1
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

function player:update(lvl)
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
    shallow_copy(mov),lvl
   )
   self.movq.button=b

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
    return animate_retry(lvl)
   end
  end
 else
  if (
   self.retry_cnt
   and self.retry_cnt>0
  ) then
   if self:_undo(lvl) then
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
    self.movq,lvl
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
  self:_move(lvl)
 end
end

function player:draw(x0,y0)
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
  si,x0+self.sx,y0+self.sy,2,2
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
 o.lvl_def=lvl_def

 o.mov_cnt=0
 o.box_cnt=0
 o:add_objects()

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

function level:box_at(x,y)
 for box in all(self.boxes) do
  if box:is_at(x,y) then
   return box
  end
 end
end

function level:bubble(x,y)
 local si=self:_sprite(x,y)
 if fget(si,flag_bub) then
  return bub_color(si)
 end
 return nil
end

function level:add_objects()
 local bubble=(
  self.lvl_def.ini_bubble or 0
 )
 local p=self.lvl_def.ini_pos
 if p then
  self.player=player:new(
   p.x,p.y,bubble
  )
 end
 self.boxes={}
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   if fget(si,flag_player) then
    self.player=player:new(
     x,y,bubble
    )
   elseif fget(si,flag_box) then
    add(
     self.boxes,
     box:new(x,y,box_color(si))
    )
   end
  end
 end

 return s
end

function level:_draw_floor(
 x0,y0
)
 local xmax=x0+self.ncols*16-1
 local ymax=y0+self.nrows*16-1
 for x=0,self.ncols-1 do
  local sx=x0+x*16
  for y=0,self.nrows-1 do
   local sy=y0+y*16

   local si=self:_sprite(x,y)
   if si==34 then
    --clear floor on outside,
    --use padding to also fix
    --nearby beveled corners
    rectfill(
     max(x0,sx-8),
     max(y0,sy-8),
     min(xmax,sx+24),
     min(ymax,sy+24),0
    )
   elseif fget(si,flag_tgt) then
    local c=tgt_color(si)
    local viz=(
     self.mov_cnt==0
     or self.player.bubble==c
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

function level:_draw_walls(
 x0,y0
)
 for x=0,self.ncols-1 do
  local sx=x0+x*ss
  for y=0,self.nrows-1 do
   local sy=y0+y*ss

   local si=self:_sprite(x,y)
   if fget(si,flag_wall) then
    if si>=48 then
     local col=(si-48)%8
     local row=(si-48)\8
     spr(
      192+col*2+row*32,sx,sy,2,2
     )
    elseif si!=34 then
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

function level:_draw_score(
 x_offset
)
 if self.lvl_def.hide_score then
  return
 end

 local s=self.mov_cnt
 local x=67+x_offset
 local y=53+8*self.nrows

 local hi=stats:get_hi(self.idx)
 pal(6,13)
 pal(5,1)
 if (
  hi and hi>=s
  and not self.force_show_score
 ) then
  pal(7,12)
  s=hi-s
 else
  pal(7,13)
 end

 for i=1,3 do
  local digit=s%10
  spr(
   27+digit%5+16*(digit\5),x,y
  )
  x-=7
  s\=10
 end
 pal()
end

function level:_draw_boxes(
 x0,y0
)
 for box in all(self.boxes) do
  local c
  if (
   self.mov_cnt==0
   or self.player.bubble==box.c
  ) then
   c=box.c
  elseif easymode then
   c=box.c+4
  else
   c=9
  end
  bubble_pal(c)
  spr(
   160,x0+box.sx,y0+box.sy,2,2
  )
 end
 bubble_pal()
end

function level:_draw_bubbles(
 x0,y0
)
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   if fget(si,flag_bub) then
    bubble_pal(bub_color(si))
    spr(12,x0+x*ss+4,y0+y*ss+4)
   end
  end
 end
end

function level:draw(x_offset)
 x_offset=x_offset or 0
 local x0=self.sx0+x_offset
 local y0=self.sy0
 pal(15,1)
 if (
  not self.lvl_def.no_floor
 ) then
  rectfill(
   x0+8,y0+8,
   x0+self.ncols*ss-8,
   y0+self.nrows*ss-8,
   5
  )
 end
 self:_draw_floor(x0,y0)
 self:_draw_walls(x0,y0)
 if not self.hide_score then
  self:_draw_score(x_offset)
 end
 self:_draw_boxes(x0,y0)
 self.player:draw(x0,y0)
 self:_draw_bubbles(x0,y0)
 pal()
end

function level:is_done()
 local box_cnt=0

 for box in all(self.boxes) do
  if box:on_tgt(self) then
   box_cnt+=1
  end
 end

 if box_cnt>self.box_cnt then
  sfx(3)
 end
 self.box_cnt=box_cnt

 return box_cnt==#self.boxes
end

function level:update()
 local anim=self.player:update(
  self
 )

 if self:is_done() then
  printh(
   "solved "..self.lvl_def.name
   .." in "..self.mov_cnt
   .." moves\n"
   ..self.player.mov_history
  )
  anim=animate_level_done(self)
 end

 return anim
end

-->8
--main

function _init()
 _title=title:new()
 _stats=stats:new()
 _levelmenu=levelmenu:new()
 _statsview=statsview:new()

 --disable btnp auto-repeat
 --to use custom hold logic
 poke(0x5f5c,255)

 scene=_title
 music(0)
 --start_level(19)
end

function _update60()
 scene:update()
end

function _draw()
 scene:draw()
end

function start_level(
 idx,old_lvl
)
 _levelmenu:set_lvl(idx)
 _game=game:new(idx)
 _game.anim=animate_level_start(
  _game.level,old_lvl
 )
 scene=_game
end

title={}
function title:new()
 local o=new_object(self)

 o.car={x=60,dx=0.5,c=2}
 o.boxr={x=116,c=4}
 o.boxl={x=4,c=2}
 o.boxes={o.boxr,o.boxl}

 o.item_idx=1
 o.help=false

 return o
end

function title:_change_option()
 if self.item_idx==2 then
  easymode=not easymode
 elseif self.item_idx==3 then
  music_on=not music_on
  if music_on then
   music(0)
  else
   music(-1)
  end
 elseif self.item_idx==4 then
  self.help=not self.help
 end
end

function title:update()
 local max_idx=(
  _stats:all_solved() and 5 or 4
 )

 if btnp(❎) then
  if self.item_idx==1 then
   scene=_levelmenu
   return
  elseif self.item_idx==5 then
   scene=_statsview
  else
   self:_change_option()
  end
 elseif btnp(⬆️) then
  self.item_idx=1+(
   self.item_idx+max_idx-2
  )%max_idx
 elseif btnp(⬇️) then
  self.item_idx=1+(
   self.item_idx
  )%max_idx
 elseif btnp(⬅️) or btnp(➡️) then
  self:_change_option()
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

function title:_draw_logo()
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
end

function title:_draw_help()
 rect3d(35,56,91,96,1,13,2)

 local y=59
 centerprint("help",y,12)
 y+=10

 print("◆◆◆◆ move",37,y,13)
 print("⬅️➡️⬆️⬇️",37,y,0)
 y+=7

 print("◆",37,y,13)
 print("❎",37,y,0)
 print(
  "undo",73,y,
  easymode and 13 or 0
 )
 y+=7

 print("retry",71,y,13)
 y+=3
 print("◆",37,y,13)
 print("❎(hold)",37,y,0)
 y+=3
 print("exit",73,y,13)
end

menu_items={
 "start",
 "mode [    ]",
 "music [   ]",
 "help",
 "stats"
}

function title:_draw_menu()
 rect3d(35,56,91,96,1,13,2)

 local y=50+8*self.item_idx
 print(
  "\^:0103070301000000",37,y,12
 )
 print(
  "\^:0406070604000000",87,y,12
 )

 for i=1,#menu_items do
  local c=(
   self.item_idx==i and 12 or 13
  )
  if (
   i==5
   and not _stats:all_solved()
  ) then
   c=0
  end
  centerprint(
   menu_items[i],50+8*i,c
  )
 end

 print("[    ]",62,66,0)
 print(
  easymode and "easy" or "hard",
  66,66,13
 )
 local s=(
  music_on and "on" or "off"
 )
 print("[   ]",66,74,0)
 print(s,76-#s*2,74,13)
end

function title:draw()
 cls()

 self:_draw_logo()
 if self.help then
  self:_draw_help()
 else
  self:_draw_menu()
 end

 rectfill(0,121,127,127,5)

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

 o.level=level:new(level_idx)

 return o
end

function game:draw()
 cls(0)

 if (
  self.anim and self.anim.draw
 ) then
  self.anim.draw()
 else
  self.level:draw()

  spr(134,34,0,8,2)
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
  self.anim=lvl:update()
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
ffffff6666ffffff5555555f0000000000000000000000000000000006555555555555f006555555555555f00077770000077000007777000077770000770770
fffff655555fffff5555555f0000000000066666666660000000000006555555555555f666555555555555f00766666000766500076666600766666000765665
ffff65555555ffff555555f000000000066555555555555000000000065555555555555555555555555555f00765566500666500005556650765566507655665
fff6555555555fff55555f0000000000655555555555555500000000065555555555555555555555555555f00765066500066500000666550055665507666665
ff655555555555ff5555550000000006555555555555555550000000065555555555555555555555555555f00765066500066500007655500765566000555665
f65555555555555f555555500000006555555555555555555500000000555555555555555555555555555f000766666500766650076666600766666500000665
655555555555555f5555555f0000065555555555555555555550000000555555555555555555555555555f000066665000666650066666650066665500000665
655555555555555f5555555f000065555555555555555555555500000005555555555555555555555555f0000005550000055550005555550005555000000055
655555555555555fffffffff00065555555555555555555555555000000055555555555555555555555f00000777777000777770077777700077770000777700
655555555555555fffffffff0065555555555555555555555555550000000555555555555555555555f000000766666507666665076666650766666007666660
f5555555555555ffffffffff006555555555555555555555555555000000005555555555555555555f0000000765555507655555005556650765566507655665
ff55555555555fffffffffff065555555555555555555555555555f0000000055555555555555555f00000000766660007666600000066550066665500666665
fff555555555ffffffffffff065555555555555555555555555555f000000000555555555555555f000000000055566007655660000066500765566000555665
ffff5555555fffffffffffff065555555555555555555555555555f0000000000555555555555ff0000000000766666507666665000665500766666507666665
fffff55555ffffffffffffff06555555555555ffff555555555555f000000000000ffffffffff000000000000066665500666655000665000066665500666655
ffffffffffffffffffffffff06555555555555f506555555555555f0000000000000000000000000000000000005555000055550000055000005555000055550
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
00e882000000000000e8820000e8820000e8820000000000dcccccc1dcccccc1dcc1dcc1dcccccc1000000000000000000000000000000000000000000000000
0e888820000000000e8888200e8888200e88882000000000dcccccc1dcccccc1dcc1dcc1dcccccc10ee00000000ee000ee000ee0000000000000000000000000
0e888820000000000e8888200e8888200e88882000000000dccc1110dcccccc1dcc1ccc1dcccccc1e880000000e8800e8800e882000000000dddddd00dddddd0
0e8888200000000eee8888200e8888200e88882000eeee00dccc1dd0dcc11cc1dcccccc1dcc11cc1e88000ee0ee8800e8800e8820ee00000ddddd1dddd1ddddd
0e888822200ee0e8822888222e8888222e8888200e888820dcccccc1dcc1dcc1dccccc10dcc1dcc1e88ee08808828eee88eee882e8880000dddd11dddd11dddd
0e88828882e88288882882888288828882888820e8888882dcccccc1dcc1dcc1dccccc10dcc1dcc1e8888828288288882888828288282000ddd111dddd111ddd
0e8888888828882888288888882888888828882e888288820111ccc1dcc1dcc1dcccccc1dcc1dcc1e8888828288288882888828288882000dd1111dddd1111dd
0e8888888828882888288888882888888828882e882e88820dddccc1dcccccc1dcc1ccc1dcccccc1e8828828288282882828828288220000ddd111dddd111ddd
0e8882288828882888288228882882288828882288888820dcccccc1dcccccc1dcc1dcc1dcccccc1e8888828888288882888828828882000dddd11dddd11dddd
0e8882e888288828882882e8882882e88828828828822282dcccccc1dcccccc1dcc1dcc1dcccccc108888288882888828888288828882000ddddd1dddd1ddddd
0e888888828888888828888882888888828888882888888201111110011111100111011101111110002220022200222002220022022200000dddddd00dddddd0
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
313636363636363231363636363636323136363636363632313636363636363210363636363636112231363636363222103636363636361131363636363636321036363636363611103636363636361110363636363636111036363636363611373a36363636363831383a3636383a3200000000000000000000000000000000
355c000000000035355500003f006535355c0000000000353546004545005635353f000046003f3531340000460033323575000000007535355c000000006a353545480000006a35355c000000000035355c00000000003535484d0040006535355c005b004500373959550000757b3900000000000000000000000000000000
350000000000003535005c6000000035350000000000003539005c7070000039355c600101700035350060000070003535005570705500353500505070706535350000507000653535006046700000353500400000700035355e6065004600353575005000000035375500606000753700000000000000000000000000000000
3500005000703f35353f00567640003535755076567055353765500000605537350000697800003535000055450000353500705c565000353500000000003a3c3500600000700035350076005600003535006200005400353545656d0060603535000040506078353500005c6000003500000000000000000000000000000000
35000070000000353500506646003f35357550765670553539655000006055393500007565000035333276756566003535007076005000353e3800606000003535004000005000353500506640000035350000000000003535654d5d60000035354a407066000035350070700050003500000000000000000000000000000000
3500005400755535350000007000003535000000000000353700004040000037350040000050003522354000005000353500755050750035357500000000003535750040600000353500000000455535203275554565312135614500004000353500000070005535390070655050003900000000000000000000000000000000
3556003f005575353545003f0000753535000000000000353566007575007635353f005600003f3522350000560031343555000000005535357b000037555935357b000000595535350000000065753522350046660035223500450040000035390065007c0000353700006a6500003700000000000000000000000000000000
3336363636363634333636363636363433363636363636343336383a383a3634203636363636362122333636363634222036363636363621333636363d36363420363636363636212036363636363621222036363636212220363636363636213a3636363636383933383a3636383a3400000000000000000000000000000000
3136363636363231363b363b3632313636363636323136363636363632313636363636323136363636363632313636363222222231363636363632313636363636363231363601363632000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
350056000000353575397639753535000000000035355c00000000003535000056756535355c0000000000353500000033363632355c0000707535355c000000000035354b0040005835000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
350037003770353500000000003535005c50400035357550765670553535000000005535350070595b500035350000500000753535750000700035350070595b500035355c4b40580035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
355c3576356c353570005c0050353500605600663535755076567055353500505c006635350070797b5000353e38763056563a3c35760101707535350070797b50003535707000505035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
350033363d363c35000000000035350070006c6c353500000000000035350060700000353500000000000035355c50007000553535750000700035350070557550003535007a60690035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35005000006c3535553756375535350000766c473535000000000000353576000000003520320000000031213500000000005535350000007075353500707555500035357a0060006935000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3336363636363433363d363d3634333636363636343336363636363634333636363636342233363636363422333636363636363433363636363634203636363636362133363636363634000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
001000002e6002d6002d6002c6002c6002c60027600276002860028600286002d6002d6002d6002d6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
911600000903300000000000000004620046100461500000000000000004615000000462004610046150000009043000000000000000046200461004615000000000000000046150000004620046100461500000
911600000905009050090410903109021000020705007050070410703107021070210000000000000000000207050070500704107031070210000209050090500904109031090210902100002000000000000000
a91600001c5401c5401c5401c5401c5321c5321c5321c5321c5321c5221c5221c5221c5121c5121a5401854017540175401753017532175221752215540155401554215532155321552215522155120000000000
791600002474524715000002874528715000002674526715000000000000000000000000000000000000000026745267150000028745287150000024745247150000000000000000000000000000000000000000
a91600001c5401c5401c5401c5401c5421c5321c5321c5321c5221c5221c5221c5121c5121c5121a5401a5401c5401c5301c5321f5401f5401f53221540215402154221532215322152221522215120000000000
79160000247452471500000287452871500000267452671500000000000000000000000000000000000000002874528715000002b7452b715000002d7452d7150000000000000000000000000000000000000000
a91600002154021540215322153221522215121f5401f5401f5321f5321f5221f5121c5401c5421c5321c5221a5401a5401a5321a5321a5221a5121c5301c5301c5321c5221c5221c51200002000020000200002
7916000000000000000000028745287152b745267452671500000000000000000000000000000000000000000000000000000002674526715287452d7452d71500000000000000000000307452f7452d7452d715
511600000904300000000000000004635000000904300000000000000000000000001063500000090330000009043000000000000000046350000009043000000000000000000000000010635000000903300000
91160000050500505005041050310502100002020500205102041020310202100002000020000200002000020b0500b0510b0410b0310b021000020c0500c0510c0410c0310c0210000200002000020000200002
a91600000505005050050410503105021000020705007051070410703107021000020000200002000020000204050040510404104031040210000209050090510904109031090210000200002000020000200002
191600001154015530115301c54000000115301a54000000000000000000000115301a5401853017530155301354017530135301a540000001353018540000000000000000000000000000000000000000000000
191600001154015530115301c54000000115301a5400000000000000001a530185201754018530175301552010540135301053017540000001053015540000000000000000000000000000000000000000000000
79160000247452d7452d7152d70000000247452d7452d715267452f7452f7150000000000000000000000000267452f7452f7150000000000267452f7452f7152874530745307150000000000000000000000000
111600000904300000000000402304635090230904300000000000000009033000001063509013090330000009043000000000004023046350902309043000000000000000090330000010635090130903300000
05160000090500000010040150400900015040070600705507000070400e04007040130400e040130400000007050000000e04007040000001304009050090550900009040100400904015040100401504000000
611600001c540005001a5401854017540185401754000500005001554013540155400050017540005000050017540005001554013540155401754010540005001c500005001a5001850017500185001750000500
611600001c540005001a5401854017540185401754000500005001554013540155400050017540005000050017540005001554013540155401854015540005000050000500005000050000500005000050000500
79160000247452d745247452d7452d7152d745267452f7452f7152f7452f715267452f745267452f7452f715267452f745267452f7452f7152f74528745307453071530745307152874530745307153074530715
111600000904315615090330403304645090330904315625090331561509033156151064509023090330402309043156150903304033046450903309043156250903315615090331561510645090230903304023
05160000050500c030050301104000000110300205000000000000203009030020300e0400903002030090300b030070300b0301304017000130300c0500700000030070200c030000200c040070200003007000
05160000050500c03005030110400000011030070500000000000070300e03007030130400e0300703000000040500b030040301004000000100300905000000000000903010030090200b0400c0300e03010030
__music__
00 0a0b0c0d
00 0a0b0e0f
00 0a0b100d
00 0a0b100f
00 0a0b0c11
00 0a0b0e11
00 12130c11
00 12140e11
01 12131011
00 12141011
00 12131511
00 12141611
00 12131517
00 12141617
00 18191517
00 18191617
00 18191a17
00 18191b17
00 1819151c
00 1819161c
00 1d1e151c
00 1d1f161c
00 1d1e1a17
00 1d1f1b17
00 1d1e1a1c
02 1d1f1b1c

