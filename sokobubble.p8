pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- sokobubble v1.1.1
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
 name="barrier",
 mapdef={44,8,8,7},
 id=6
},{
 name="espresso",
 mapdef={36,8,8,7},
 id=7,
},{
 name="ribbon",
 mapdef={112,0,8,8},
 id=24
},{
 name="star",
 mapdef={67,8,7,7},
 id=27
},{
 name="enclosed",
 mapdef={48,0,8,8},
 id=8,
},{
 name="swap",
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
 name="reverse",
 mapdef={120,0,8,8},
 id=26
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
 {[4]=1,[9]=12,[10]=6},--blue
 {[4]=1,[9]=5,[10]=6},--hidden
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

track_anim_colors={4,2,13}

--sprite size
ss=16

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
  pal(bub_pals[5])
 end
end

function pad_str(s,len,rpad,ch)
 ch=ch or " "
 while #s<len do
  if rpad then
   s=s..ch
  else
   s=ch..s
  end
 end
 return s
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
 if col==7 or col==15 then
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

function new_object(class,ini)
 local obj=setmetatable(
  ini or {},class
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

--draws a vertically scrolling
--text. yoffset determines the
--scroll amount, range=[-6,6]
function draw_scrolling_str(
 s,x,y,yoffset,c
)
 local px={}
 for i=0,4 do
  local yr=i+yoffset
  if yr<-1 or yr>5 then
   for j=0,#s*4 do
    add(px,pget(x+j,y+yr))
   end
  end
 end

 print(s,x,y+yoffset,c)

 for i=4,0,-1 do
  local yr=i+yoffset
  if yr<-1 or yr>5 then
   for j=#s*4,0,-1 do
    pset(x+j,y+yr,deli(px))
   end
  end
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

function printsymbol(ch,x,y)
 print("◆",x,y,0)
 print(ch,x,y,13)
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

 if lvl:is_hi() then
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
 local give_up=args[2]

 sfx(2)
 wait(60)
 if lvl.idx==#level_defs then
  --from end go to stats
  show_stats(show_levelmenu)
 elseif give_up then
  show_levelmenu()
 else
  --retry
  start_level(lvl.idx)
 end
 yield() --allow anim swap
end

function animate_retry(
 lvl,give_up
)
 local anim=cowrap(
  "retry",retry_anim,
  lvl,give_up or lvl.mov_cnt==0
 )
 return anim
end

-->8
function store_name(s)
 --pad to ensure #s>=8
 s..="        "

 local s4_to_word=function(s)
  local v=0
  for i=1,4 do
   v|=(ord(s,i)>>16)<<(i-1)*8
  end
  return v
 end

 dset(62,s4_to_word(sub(s,1,4)))
 dset(63,s4_to_word(sub(s,5,8)))
end

function load_name(s)
 local word_to_s4=function(v)
  local s=""
  for i=1,4 do
   local ch=chr(
    (v>>(i-1)*8)<<16
   )
   if (
    (ch>="a" and ch<="z")
    or ch==" "
   ) then
    s..=ch
   end
  end
  return s
 end

 s=word_to_s4(dget(62))
 s..=word_to_s4(dget(63))

 --strip trailing space
 while #s>0 and s[#s]==" " do
  s=sub(s,1,#s-1)
 end

 return s
end

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
 --player has solved. there can
 --be gaps when the player used
 --a code, or new levels were
 --inserted after a version
 --update
 o.max_lvl_idx=#level_defs
 while (
  o.max_lvl_idx>1
  and not o:is_done(
   o.max_lvl_idx-1
  )
 ) do
  o.max_lvl_idx-=1
 end

 o:_update_total()
 o.coder=coder:new()

 return o
end

function stats:_update_total()
 self.total=0
 for i=1,#level_defs do
  self.total+=self:get_hi(i)
 end
end

function stats:first_unsolved()
 local i=1
 while self:is_done(i) do
  i+=1
 end
 return i
end

function stats:makecode(
 plyr_name
)
 return self.coder:code(
  self.max_lvl_idx,plyr_name
 )
end

function stats:evalcode(
 code,plyr_name
)
 return self.coder:decode(
  code,plyr_name
 )
end

function stats:mark_done(
 lvl_idx,num_moves
)
 if (
  num_moves<self:get_hi(lvl_idx)
 ) then
  dset(
   1+level_id(lvl_idx),
   num_moves
  )

  self:_update_total()

  if (
   lvl_idx>=self.max_lvl_idx
  ) then
   self.max_lvl_idx=lvl_idx+1
  end
 end
end

function stats:is_done(lvl_idx)
 return self:get_hi(lvl_idx)<999
end

function stats:get_hi(lvl_idx)
 local hi=dget(
  1+level_id(lvl_idx)
 )
 return hi>0 and hi or 999
end

coder={}
function coder:new()
 return new_object(self)
end

function coder:_reset()
 self.codes={7,23,4,19}
 self.p=1
end

function coder:_add(s)
 for i=1,#s do
  self.codes[self.p]=(
   self.codes[self.p]+ord(s[i])
  )%26
  self.p=1+self.p%4
 end
end

function coder:_code()
 local s=""
 for v in all(self.codes) do
  s..=chr(97+v)
 end
 return s
end

function coder:code(
 lvl_idx,plyr_name
)
 self:_reset()
 plyr_name..="skb"
 self:_add(plyr_name)
 for i=1,lvl_idx do
  self:_add(level_defs[i].name)
  self:_add(plyr_name)
 end
 return self:_code()
end

function coder:decode(
 code,plyr_name
)
 self:_reset()
 plyr_name..="skb"
 self:_add(plyr_name)
 for i=1,#level_defs do
  self:_add(level_defs[i].name)
  self:_add(plyr_name)
  if self:_code()==code then
   return i
  end
 end
 return 1
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
  xmin-2,y,xmax+2,y+8,1
 )
 print(s,xmin,y+2,
  _stats:is_done(lvl.idx)
  and 6 or 5
 )
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
 return new_object(self)
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

 local max_idx=self.max_lvl_idx

 if max_idx==1 or btnp(❎) then
  if (
   self.lvl.idx<#level_defs
  ) then
   start_level(self.lvl.idx)
   return
  else
   show_stats(show_levelmenu)
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

 local s
 if (
  self.lvl.idx==#level_defs
 ) then
  s="❎ stats"
 else
  s="❎ play"
 end

 local w=#s*2+4
 roundrect(64-w,115,63+w,123,1)
 print(s,66-w,117,12)
 printsymbol("❎",66-w,117)
end

statsview={}
function statsview:new()
 local o=new_object(self)

 o.view_idx=1

 return o
end

function statsview:update()
 if btnp(❎) then
  self.hide_callback()
 elseif btnp(⬅️) then
  self.view_idx=(
   1+(self.view_idx+2)%4
  )
 elseif btnp(➡️) then
  self.view_idx=(
   1+self.view_idx%4
  )
 end
end

function statsview:draw()
 cls()

 spr(134,32,0,8,2)

 rect3d(1,16,126,121,1,13,2)

 local make_entry=function(
  idx,name,score,score_len
 )
  return (
   pad_str(""..idx,2).."."..
   pad_str(name,8,true).." "..
   pad_str(""..score,score_len)
  )
 end

 if self.view_idx<4 then
  local total=0
  for i=1,#level_defs-1 do
   local name=level_defs[i].name
   local score
   if self.view_idx==1 then
    score=_stats:get_hi(i)
   elseif self.view_idx==2 then
    score=onl_lvl[i]
   else
    name=hof_lvl[i][1]
    score=hof_lvl[i][2]
   end
   local x=((i-1)\12)*64+2
   local y=((i-1)%12)*7+30
   print(
    make_entry(i,name,score,3),
    x,y,13
   )
   total+=score
  end

  print("total",78,115,12)
  local s=""..total
  print(s,126-4*#s,115)
 else
  local y=30
  for i,e in pairs(hof_tot) do
   if i<=3 and e[2]<10000 then
    printbig(sub(
     make_entry(i,e[1],e[2],4)
    ,2),4,y,13)
    y+=12
   else
    print(make_entry(
     i,e[1],e[2],5
    ),28,y,13)
    y+=8
   end
  end
 end

 print(
  self.view_idx<4
  and "level scores"
  or "total scores",44,20,12
 )

 spr(142,21,15,1,2)
 spr(143,94,15,1,2)
 spr(
  self.view_idx>1 and 11 or 10,
  32,19
 )
end

helpview={}
function helpview:new()
 local o=new_object(self)

 return o
end

function helpview:update()
 if btnp(❎) then
  show_mainmenu()
 end
end

function helpview:draw()
 cls()

 draw_big_logo()

 --draw iconographic help
 rectfill(24,51,103,105,5)
 local x=28
 local y=54
 pal(1,0)
 for i=0,2 do
  pal(5,max(5,4+i*4))
  spr(92,x-1,y+i*8)
  spr(92,x+40,y+i*8)
  if i==1 then
   spr(92,x+24,y)
  elseif i==2 then
   spr(92,x+65,y)
  end
 end

 map(125,8,x+16,y,1,6)
 map(127,8,x+57,y,1,6)
 pal({
  --green => red
  [11]=14,[3]=8,[1]=2,
  --yellow => blue
  [10]=6,[9]=12,[4]=1
 })
 map(124,8,x+7,y,1,6)
 map(126,8,x+48,y,1,6)
 pal()

 --show key legend
 rectfill(0,113,127,127,1)

 printsymbol("⬅️",2,118)
 printsymbol("➡️",16,118)
 printsymbol("⬆️",9,115)
 printsymbol("⬇️",9,121)
 print("move",25,118,12)

 printsymbol("❎",49,118)
 print(
  "undo",58,118,
  easymode and 12 or 0
 )

 print("hold",82,118,13)
 printsymbol("❎",98,118)
 print("retry",107,115,12)
 print("/exit",107,121,12)
end

-->8
--box, undo_stack & player

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
 o.mov_history={}

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
   if lvl.mov_cnt<480 then
    --limit move history, as
    --only short solves are
    --relevant
    add(
     self.mov_history,mov.button
    )
   end
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
 lvl.mov_cnt-=1
 if (
  lvl.mov_cnt<#self.mov_history
 ) then
  deli(self.mov_history)
 end
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

function player:freeze()
 self.frozen=true
 self.movq=nil
end

function player:is_moving()
 return self.mov!=nil
end

function player:_handle_input(
 lvl
)
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
end

function player:update(lvl)
 if not self.frozen then
  local anim=self:_handle_input(
   lvl
  )
  if anim then
   return anim
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
function level:new(lvl_idx)
 local o=new_object(self)

 local lvl_def=level_defs[
  lvl_idx
 ]
 o.idx=lvl_idx
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

 --hi-scores at start of level
 o.hi=_stats:get_hi(lvl_idx)
 o.global_hi=(
  hof and hof[lvl_idx][2] or 999
 )

 return o
end

function level:is_hi()
 return (
  self.mov_cnt<self.hi
  or (
   hof and
   self.mov_cnt<self.global_hi
  )
 )
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
     pal(9,1)
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

 local hi=self.hi
 if (
  self.global_hi!=999 and
  self.mov_cnt<=self.global_hi
 ) then
  --we may still beat the
  --global hi-score, so use
  --that as reference
  hi=self.global_hi
 end

 pal(6,13)
 pal(5,1)
 if (
  hi!=999 and s<=hi
  and not self.force_show_score
 ) then
  --show delta wrt to hi-score
  s=hi-s
  pal(7,12)

  spr(
   hi==self.global_hi
   and 11 or 10,x+5,y
  )
  x-=5
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
  self.player:freeze()
  if (
   not self.player:is_moving()
  ) then
   printh(
    "solved "..self.lvl_def.name
    .." in "..self.mov_cnt
    .." moves"
   )
   post_result(self)
   anim=animate_level_done(self)
  end
 end

 return anim
end

-->8
--main

function _init()
 _stats=stats:new()
 _mainmenu=mainmenu:new()
 _levelmenu=levelmenu:new()
 _levelmenu:set_lvl(
  _stats:first_unsolved()
 )
 _statsview=statsview:new()
 _helpview=helpview:new()
 _gpio=gpio:new(
  received_msg,post_levels
 )
 init_dummy_hof()
 
 music(0)

 show_mainmenu()
end

function _update60()
 _gpio:update()
 scene:update()
end

function _draw()
 scene:draw()
end

function init_dummy_hof()
 hof_lvl={}
 hof_tot={}
 onl_lvl={}
 for i=1,24 do
  add(hof_lvl,{"-", 999})
  add(onl_lvl,999)
  if i<=10 then
   add(hof_tot,{"-", 24000})
  end
 end
end

function start_level(
 idx,old_lvl
)
 _levelmenu:set_lvl(idx)
 _game=game:new(idx)
 _game.anim=animate_level_start(
  _game.level,old_lvl
 )

 menuitem(1,"level menu",
  function()
   _game.anim=animate_retry(
    _game.level,true
   )
  end
 )

 --disable btnp auto-repeat
 --to use custom hold logic
 poke(0x5f5c,255)

 scene=_game
end

function show_levelmenu()
 menuitem(1)
 menuitem(2,"main menu",
  show_mainmenu
 )

 _levelmenu.max_lvl_idx=max(
  _stats.max_lvl_idx,
  _mainmenu.code_lvl_idx
 )

 scene=_levelmenu
end

function show_mainmenu()
 menuitem(1)
 menuitem(2)

 _mainmenu:show()

 scene=_mainmenu
end

function show_stats(cb)
 menuitem(1)

 _statsview.hide_callback=cb

 --update player stats in case
 --name has changed
 post_playername()

 scene=_statsview
end

function show_help()
 menuitem(1)

 scene=_helpview
end

mainmenu={}
function mainmenu:new()
 local o=new_object(self)

 o.item_idx=1
 o.name_edit=textedit:new(
  load_name(),"player 1",{
   editlen=8,
   allowspace=true
  }
 )
 o.code_edit=textedit:new(
  "",
  "----",{
   editlen=4,
   allowspace=false
  }
 )
 o:_update_code()

 return o
end

function mainmenu:plyr_name()
 return self.name_edit:value()
end

function mainmenu:_eval_code()
 self.code_lvl_idx=_stats:evalcode(
  self.code_edit.s,
  self:plyr_name()
 )
end

function mainmenu:_update_code()
 self.code_edit.s=_stats:makecode(
  self:plyr_name()
 )
 self:_eval_code()
end

function mainmenu:_change_option()
 if self.item_idx==4 then
  easymode=not easymode
 elseif self.item_idx==5 then
  music_on=not music_on
  if music_on then
   music(0)
  else
   music(-1)
  end
 elseif self.item_idx==6 then
  self.name_edit.active=(
   not self.name_edit.active
  )
  if self.name_edit.active then
   self.name_edit:home()
  else
   store_name(self.name_edit.s)
   self:_update_code()
  end
 elseif self.item_idx==7 then
  self.code_edit.active=(
   not self.code_edit.active
  )
  if self.code_edit.active then
   self.code_edit:home()
  else
   self:_eval_code()
  end
 end
end

function mainmenu:show()
 --enable default button hold
 --(for editing name)
 poke(0x5f5c,0)

 printh(
  _stats.max_lvl_idx.."-"..
  self.code_lvl_idx
 )

 if (
  _stats.max_lvl_idx>
  self.code_lvl_idx
 ) then
  printh("updating code")
  self:_update_code()
 end
end

function mainmenu:update()
 local max_idx=7

 if btnp(❎) then
  if self.item_idx==1 then
   show_levelmenu()
   return
  elseif self.item_idx==2 then
   show_stats(show_mainmenu)
  elseif self.item_idx==3 then
   show_help()
  else
   self:_change_option()
  end
 elseif self.name_edit.active then
  self.name_edit:update()
 elseif self.code_edit.active then
  self.code_edit:update()
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
end

--x,w,h
bubble_specs={
 ["b"]={0,10,15},
 ["u"]={10,10,11},
 ["l"]={20,8,15},
 ["e"]={28,10,11}
}

function draw_big_logo()
 pal(15,1)
 pal(5,12)
 pal(6,13)
 map(0,21,32,9,8,3)
 pal()

 local bump=function(tmax)
  return max(
   0,2-abs(flr(t()*60)%180-tmax)
  )
 end

 palt(0,true)
 local str="bubble"
 local sx=87
 for i=#str,1,-1 do
  local ch=str[i]
  local bs=bubble_specs[ch]
  local x,w,h=bs[1],bs[2],bs[3]
  sx-=w-2
  local sy=45-h-bump(i*6)
  sspr(x,79-h,w,h,sx,sy)
 end
 pal()
end

menu_items={
 "start",
 "hall of fame",
 "help",
 "mode",
 "music",
 "name",
 "code"
}

function mainmenu:_draw_menu()
 rect3d(30,52,97,112,1,13,2)

 local arrow_r="\^:0103070301000000"

 local leftprint=function(s,y,c)
  print(s,37,y,c)
 end
 local ypos=function(i)
  return 50+8*i-(
   i<=3 and 4 or 0
  )
 end

 local y=ypos(self.item_idx)
 print(arrow_r,32,y,12)
 print(
  "\^:0406070604000000",93,y,12
 )
 for i=1,#menu_items do
  local c=(
   self.item_idx==i and 12 or 13
  )
  local print_fn=(
   i<=3 and centerprint or
   leftprint
  )
  print_fn(
   menu_items[i],ypos(i),c
  )
 end

 rectfill(58,81,74,87,13)
 print(
  easymode and "easy" or "hard",
  59,82,1
 )
 local s=(
  music_on and "on" or "off"
 )
 rectfill(58,89,70,95,13)
 print(s,65-#s*2,90,1)

 rectfill(
  58,97,90,103,
  self.name_edit.active
  and 12 or 13
 )
 self.name_edit:draw(59,98,1)

 rectfill(
  58,105,74,111,
  self.code_edit.active
  and 12 or 13
 )
 self.code_edit:draw(59,106,1)
 print(arrow_r,77,106,13)
 print(self.code_lvl_idx,82,106,13)
end

function mainmenu:draw()
 cls()

 draw_big_logo()
 self:_draw_menu()
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
-->8
textedit={}
function textedit:new(
 s,default,args
)
 local o=new_object(self,args)

 o.s=s
 o.default=default
 o.active=false

 o:home()

 return o
end

function textedit:value()
 return (
  #self.s!=0 and self.s
  or self.default
 )
end

function textedit:home()
 self.xpos=1
 self.blink=0
end

function textedit:_modchar(to)
 local s=self.s
 local from=sub(
  s,self.xpos,self.xpos
 )
 if from<"a" or from>"z" then
  from=nil
 end

 --never allow space as 1st char
 local allowspace=(
  self.allowspace and self.xpos>1
 )

 if to==⬆️ then
  if from==nil then
   to="a"
  elseif from=="z" then
   to=allowspace and " " or "a"
  else
   to=chr(ord(from)+1)
  end
 elseif to==⬇️ then
  if from==nil then
   to="z"
  elseif from=="a" then
   to=allowspace and " " or "z"
  else
   to=chr(ord(from)-1)
  end
 end

 local snew=""
 if self.xpos>1 then
  snew=sub(s,1,self.xpos-1)
 end
 if self.xpos<#s or to!=" " then
  snew..=to
 end
 if self.xpos<#s then
  snew..=sub(s,self.xpos+1)
 end
 return snew
end

function textedit:draw(x,y,c)
 local s=self.s
 if self.active then
  local xchar=x+self.xpos*4-4
  local ch=sub(
   s,self.xpos,self.xpos
  )
  if self.scroll then
   draw_scrolling_str(
    ch,
    xchar,y,
    self.scroll,
    c
   )
   draw_scrolling_str(
    self.oldchar,
    xchar,y,
    self.scroll-sgn(
     self.scroll
    )*6,
    c
   )
  else
   print(
    self.blink<30 and "_" or ch,
    xchar,y,c
   )
  end
  s=self:_modchar(" ")
 else
  s=self:value()
 end
 print(s,x,y,c)
end

function textedit:update()
 local t=self
 local s=t.s

 local max_xpos=t.max_xpos
 if not max_xpos then
  max_xpos=min(#s+1,t.editlen)
 end

 local ch=sub(s,t.xpos,t.xpos)
 if btnp(➡️) then
  t.xpos=t.xpos%max_xpos+1
  t.blink=0
 elseif btnp(⬅️) then
  if t.xpos==#s and ch==" " then
   s=sub(s,1,#s-1)
  end
  t.xpos=(
   t.xpos+max_xpos-2
  )%max_xpos+1
  t.blink=0
 elseif btnp(⬆️)
 and t.xpos<=t.editlen then
  t.oldchar=ch
  s=self:_modchar(⬆️)
  t.scroll=-6
 elseif btnp(⬇️)
 and t.xpos<=t.editlen then
  t.oldchar=ch
  s=self:_modchar(⬇️)
  t.scroll=6
 else
  t.blink+=1
  if t.blink>60 then
   t.blink=0
  end
  if t.scroll then
   t.scroll-=sgn(t.scroll)
   if (t.scroll==0) t.scroll=nil
  end
 end

 t.s=s
end

function parse_hof(s)
 local f=split(s)
 local hof={}
 for i=1,#f,2 do
  local nmov=tonum(f[i+1])
  add(hof,{f[i],nmov})
 end
 return hof
end

function parse_plyr(s)
 local f=split(s)
 local scores={}
 for i=1,#f do
  add(scores,tonum(f[i]))
 end
 return scores
end

function received_msg(s)
 printh("received: "..s)
 local hdr=sub(s,1,4)
 local body=sub(s,5)
 if hdr=="lvl:" then
  hof_lvl=parse_hof(body)
 elseif hdr=="tot:" then
  hof_tot=parse_hof(body)
 elseif hdr=="ply:" then
  onl_lvl=parse_plyr(body)
 end
end

function short_mov_str(hist)
 local mov=nil
 local mov_cnt=0
 local s=""
 local append_move=function()
  local moves="lrud"
  s..=moves[mov+1]
  if mov_cnt>1 then
   s..=mov_cnt
  end
 end

 for i=1,#hist do
  if mov and mov!=hist[i] then
   append_move()
   mov_cnt=0
  end
  mov=hist[i]
  mov_cnt+=1
 end
 append_move()

 return s
end

function post_playername()
 local n=_mainmenu:plyr_name()
 if (onl_name==n) return

 _gpio:output("player,"..n)
 onl_name=n
end

function post_levels()
 local s="levels"
 for i=1,#level_defs-1 do
  s..=","..level_defs[i].id
 end
 _gpio:output(s)
end

function post_result(lvl)
 local s=(
  "result,"..lvl.idx..","
  ..lvl.lvl_def.id..","
  .._mainmenu:plyr_name()..","
  ..lvl.mov_cnt..","
  ..short_mov_str(
   lvl.player.mov_history
  )
 )

 _gpio:output(s)
end

gpio_a_write=0x5f80
gpio_a_read=0x5fc0
gpio_blksize=63

gpio={}
function gpio:new(msg_cb,con_cb)
 local o=new_object(self)

 o.msg_callback=msg_cb
 o.con_callback=con_cb
 o.txt_out={}
 o.connected=false
 o.txt_in=""
 poke(gpio_a_read,0)
 poke(gpio_a_write,255)

 return o
end

function gpio:output(s)
 printh("gpio: "..s)
 if self.connected then
  add(self.txt_out,s)
 end
end

function gpio:_write()
 local s=self.txt_out[1]
 if #s==0 then
  --signal end of string
  poke(gpio_a_write,128)
  deli(self.txt_out,1)
 else
  local n=min(#s,gpio_blksize)
  for i=1,n do
   poke(
    gpio_a_write+i,ord(s[i])
   )
  end
  poke(gpio_a_write,n)
  self.txt_out[1]=sub(s,n+1)
 end
end

function gpio:_read()
 local n=peek(gpio_a_read)
 if n==128 then
  self.msg_callback(self.txt_in)
  self.txt_in=""
 elseif n<=gpio_blksize then
  for i=1,n do
   self.txt_in..=chr(peek(
    gpio_a_read+i
   ))
  end
 else
  printh(
   "unexpected read size"..n
  )
 end
 --release buffer for write
 poke(gpio_a_read,0)
end

function gpio:update()
 if peek(gpio_a_write)==0 then
  if not self.connected then
   self.connected=true
   self.con_callback()
  end
  if #self.txt_out>0 then
   self:_write()
  end
 end
 if peek(gpio_a_read)!=0 then
  self:_read()
 end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000003ccc0000999900000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc0003ccccc009aa9990000600000000030008000800
007007008877887700000000000000000000000000000000000000000000000000000000000000000cccccc0333ccccc9a7aa994000660000000330000808000
00077000887788770000000000000000000000000000000000000000000000000000000000000000cccccccc333ccc3c9aaaa994066666000303300000080000
000770000000000000000000000000000000000000000000000000000000000000000000000000000dddddd0c3cc3ccc99aa9994000660000333000000808000
007007000000000000000000000000000000000000000000000000000000000000000000000000000d00d0d0ccc333cc99999944000600000030000008000800
000000000000000000000000000000000000000000000000000000000000000000000000000000000d00d0d00cc33cc009999440000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000d00ddd000cccc0000444400000000000000000000000000
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
00000000000000000000000000000000000000000990099000000000066006600990099008800880033003300cc00cc0ffffffff099009900000000006600660
00aaaa0000aaaa0000aaaa0000aaaa0000aaaa00900000090000000060000006900000098000000830000003c000000cffaaaaff90aaaa090000000060aaaa06
0a9999400a9a99400a9e89400a9b39400a96c94090000009000a9000600a9006900a9009800a9008300a9003c00a900cfa99994f9a999949000000006a999946
0a9999400aa7a9400ae7e8400ab7b3400a676c400000000000a7a90000a7a90000a7a90000a7a90000a7a90000a7a900fa99994f0a999940000000000a999940
0a9999400a9a99400a8e88400a3b33400ac6cc4000000000009a9900009a9900009a9900009a9900009a9900009a9900fa99994f0a999940000000000a999940
0a9999400a9999400a9889400a9339400a9cc940900000090009900060099006900990098009900830099003c009900cfa99994f9a999949000000006a999946
0044440000444400004444000044440000444400900000090000000060000006900000098000000830000003c000000cff4444ff904444090000000060444406
00000000000000000000000000000000000000000990099000000000066006600990099008800880033003300cc00cc0ffffffff099009900000000006600660
00000000000000000000000000000000000000000880088000000000066006600990099008800880033003300cc00cc000000000033003300330033006600660
00eeee0000eeee0000eeee0000eeee0000eeee00800000080000000060000006900000098000000830000003c000000c0442442030aaaa0330aaaa0360eeee06
0e8888200e8a98200e8e88200e8b38200e86c82080000008000e8000600e8006900e8009800e8008300e8003c00e800c011111103a9999433a9b39436e888826
0e8888200ea7a9200ee7e8200eb7b3200e676c200000000000e7e80000e7e80000e7e80000e7e80000e7e80000e7e800011651100a9999400ab7b3400e888820
0e8888200e9a99200e8e88200e3b33200ec6cc2000000000008e8800008e8800008e8800008e8800008e8800008e8800011551100a9999400a3b33400e888820
0e8888200e8998200e8888200e8338200e8cc820800000080008800060088006900880098008800830088003c008800c011111103a9999433a9339436e888826
0022220000222200002222000022220000222200800000080000000060000006900000098000000830000003c000000c04424420304444033044440360222206
00000000000000000000000000000000000000000880088000000000066006600990099008800880033003300cc00cc000000000033003300330033006600660
00000000000000000000000000000000000000000330033000000000066006600990099008800880033003300cc00cc006600660099009900000000006600660
00bbbb0000bbbb0000bbbb0000bbbb0000bbbb00300000030000000060000006900000098000000830000003c000000c6000000690bbbb090000000060bbbb06
0b3333100b3a93100b3e83100b3b33100b36c31030000003000b3000600b3006900b3009800b3008300b3003c00b300c600000069b333319000000006b333316
0b3333100ba7a9100be7e8100bb7b3100b676c100000000000b7b30000b7b30000b7b30000b7b30000b7b30000b7b300000000000b333310000000000b333310
0b3333100b9a99100b8e88100b3b33100bc6cc1000000000003b3300003b3300003b3300003b3300003b3300003b3300000000000b333310000000000b333310
0b3333100b3993100b3883100b3333100b3cc310300000030003300060033006900330098003300830033003c003300c600000069b333319000000006b333316
0011110000111100001111000011110000111100300000030000000060000006900000098000000830000003c000000c60000006901111090000000060111106
00000000000000000000000000000000000000000330033000000000066006600990099008800880033003300cc00cc006600660099009900000000006600660
00000000000000000000000000000000000000000cc00cc000000000066006600990099008800880033003300cc00cc008800880033003300000000006600660
0066660000666600006666000066660000666600c000000c0000000060000006900000098000000830000003c000000c80bbbb0830bbbb030000000060666606
06cccc1006ca9c1006ce8c1006cb3c1006c6cc10c000000c0006c0006006c0069006c0098006c0083006c003c006c00c8b3333183b3333130000000066cccc16
06cccc1006a7a91006e7e81006b7b31006676c100000000000676c0000676c0000676c0000676c0000676c0000676c000b3333100b3333100000000006cccc10
06cccc10069a9910068e8810063b331006c6cc100000000000c6cc0000c6cc0000c6cc0000c6cc0000c6cc0000c6cc000b3333100b3333100000000006cccc10
06cccc1006c99c1006c88c1006c33c1006cccc10c000000c000cc000600cc006900cc009800cc008300cc003c00cc00c8b3333183b3333130000000066cccc16
0011110000111100001111000011110000111100c000000c0000000060000006900000098000000830000003c000000c80111108301111030000000060111106
00000000000000000000000000000000000000000cc00cc000000000066006600990099008800880033003300cc00cc008800880033003300000000006600660
00ee000000000000000000ee0000000000000000000000000dddddd00dddddd00dd10dd10dddddd0000000000000000000000000000000000000000000000000
0e8820000000000000000e88200000000000000000000000dcccccc1dcccccc1dcc1dcc1dcccccc1000000000000000000000000000000000000000000000000
e8888200000000000000e888820000000000000000000000dcccccc1dcccccc1dcc1dcc1dcccccc10ee00000000ee000ee000ee0000000000000000000000000
e8888200000000000000e888820000000000000000000000dccc1110dcccccc1dcc1ccc1dcccccc1e880000000e8800e8800e882000000000111111001111110
e888820000000000ee00e8888200000eeee0000000000000dccc1dd0dcc11cc1dcccccc1dcc11cc1e88000ee0ee8800e8800e8820ee0000011111d1111d11111
e88882220000ee0e8820e888820000e88888200000000000dcccccc1dcc1dcc1dccccc10dcc1dcc1e88ee08808828eee88eee882e88800001111dd1111dd1111
e8882888200e88288882e88882000e888888820000000000dcccccc1dcc1dcc1dccccc10dcc1dcc1e8888828288288882888828288282000111ddd1111ddd111
e888888882e888828882e8888200e88882888200000000000111ccc1dcc1dcc1dcccccc1dcc1dcc1e888882828828888288882828888200011dddd1111dddd11
e888888882e888828882e8888200e8882e888200000000000dddccc1dcccccc1dcc1ccc1dcccccc1e8828828288282882828828288220000111ddd1111ddd111
e888228882e888828882e8888220e8888882200000000000dcccccc1dcccccc1dcc1dcc1dcccccc1e88888288882888828888288288820001111dd1111dd1111
e8882e8882e888828882e8882882e8882228820000000000dcccccc1dcccccc1dcc1dcc1dcccccc10888828888288882888828882888200011111d1111d11111
e888888820e888888882e8888882e888888882000000000001111110011111100111011101111110002220022200222002220022022200000111111001111110
e8888888200888888820e88888820888888820000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888822000088882200088888200088882200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00222200000002220000002222000002220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000020202020202020202020200000000000202020202020202020202000000000002020202020202020202020202020202041414141408101818181818060c000c041414141408101818181818010c1c0c041414141408101818181818080c000c0414141414081018181818180c0c000c
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202000002020202020202020202020202020000
__map__
313636363636363231363636363636323136363636363632313636363636363210363636363636112231363636363222103636363636361131363636363636321036363636363611103636363636361110363636363636111036363636363611373a36363636363831383a3636383a3231363636363636323136363636363632
355c000000000035355500003f006535355c0000000000353546004545005635353f000046003f3531340000460033323575000000007535355c000000006a353545480000006a35355c000000000035355c00000000003535484d0040006535355c005b004500373959550000757b39355c000000000035355c000000000035
350000000000003535005c6000000035350000000000003539005c7070000039355c600101700035350060000070003535005570705500353500505070706535350000507000653535006046700000353500400000700035355e6065004600353575005000000035375500606000753735005060605000353500406070500035
3500005000703f35353f00567640003535755076567055353765500000605537350000697800003535000055450000353500705c565000353500000000003a3c3500600000700035350076005600003535006200005400353545656d0060603535000040506078353500005c6000003535665666566656353500567646660035
35000070000000353500506646003f35357550765670553539655000006055393500007565000035333276756566003535007076005000353e3800606000003535004000005000353500506640000035350000000000003535654d5d60000035354a407066000035350070700050003535566656665666353500466656760035
3500005400755535350000007000003535000000000000353700004040000037350040000050003522354000005000353500755050750035357500000000003535750040600000353500000000455535203275554565312135614500004000353500000070005535390070655050003935006555556500353500557565450035
3556003f005575353545003f0000753535000000000000353566007575007635353f005600003f3522350000560031343555000000005535357b000037555935357b000000595535350000000065753522350046660035223500450040000035390065007c0000353700006a6500003735000000000000353500000000000035
3336363636363634333636363636363433363636363636343336383a383a3634203636363636362122333636363634222036363636363621333636363d36363420363636363636212036363636363621222036363636212220363636363636213a3636363636383933383a3636383a3433363636363636343336363636363634
3136363636363231363b363b36323136363636363231363636363636323136363636363231363636363636323136363632222222313636363636323136363636363632313636363636323136363636363632000000000000000000000000000000000000000000000000000000000000000000000000000000000000660d460d
350056000000353575397639753535000000000035355c00000000003535000056756535355c0000000000353500000033363632355c0000707535355c0000000000353567006d006735355c000000000035000000000000000000000000000000000000000000000000000000000000000000000000000000000000600e400f
350037003770353500000000003535005c50400035357550765670553535000000005535350070595b500035350000500000753535750000700035350070595b500035355c46400000353500704060500035000000000000000000000000000000000000000000000000000000000000000000000000000000000000600f400e
355c3576356c353570005c0050353500605600663535755076567055353500505c006635350070797b5000353e38763056563a3c35760101707535350070797b500035355d6000605d3535004676665600350000000000000000000000000000000000000000000000000000000000000000000000000000000000006f0e4f0e
350033363d363c35000000000035350070006c6c353500000000000035350060700000353500000000000035355c5000700055353575000070003535007055755000353500004066003535005565754500350000000000000000000000000000000000000000000000000000000000000000000000000000000000007d0e5d0f
35005000006c3535553756375535350000766c4735350000000000003535760000000035203200000000312135000000000055353500000070753535007075555000353547006d00473535000000000000350000000000000000000000000000000000000000000000000000000000000000000000000000000000006d0f4d0e
3336363636363433363d363d3634333636363636343336363636363634333636363636342233363636363422333636363636363433363636363634203636363636362133363636363634333636363636363400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00 0a0b0c5b
00 0a0b0e5c
00 0a0b0c0d
00 0a0b0e0f
00 0a0b105d
00 0a0b105d
00 12131011
00 12141011
01 12131511
00 12141611
00 12131517
00 12141617
00 12130c5b
00 12140e5c
00 1213100d
00 1214100f
00 18190c5b
00 18190e5c
00 18191011
00 18191011
00 12191517
00 12191617
00 18191a17
00 18191b17
00 181e0c5d
00 181f0e5d
00 181e0c0d
00 181f0e0f
00 1d1e0c5d
00 1d1f0e5d
00 1d1e0c11
00 1d1f0e11
00 1d19151c
00 1d19161c
00 1d191a1c
00 1d191b1c
00 1d13100d
00 1d14100f
00 1d13105b
00 1d14105c
00 1213105d
00 1214105d
00 12131011
02 12141011

