pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
level_defs={{
 name="intro 1",
 mapdef={0,0,8,8},
},{
 name="intro 2",
 mapdef={7,0,8,8}
}}

--sprite flags
flag_player=0
flag_wall=1
flag_box=2
flag_tgt=3
flag_bub=4

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
 return si\16
end

function tgt_color(si)
 local col=si%16
 if col==9 then
  return si\16
 end
 if col==11 then
  return -1
 end
 return col-12
end

function bub_color(si)
 local col=si%16
 if col<=8 then
  return col-5
 else
  return si\16
 end
end

function box_at(sx,sy,state)
 for box in all(state.boxes) do
  if (
   box.sx==sx and box.sy==sy
  ) then
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
 rectfill(64-hw,y,63+hw,y+17,1)
 printbig(txt,67-hw,y+4,4)
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

function show_dialog_anim(args)
 local dialog=args[1]
 drop(dialog,54,true)
 wait(60)
 drop(dialog,128)
end

function show_dialog(txt)
 local dialog={y=-32}
 local anim=cowrap(
  "show_dialog",
  show_dialog_anim,
  dialog
 )
 anim.draw=function()
  draw_dialog(txt,dialog.y)
 end
 return anim
end

function level_done_anim()
 wait(30)
 start_level(state.level.idx+1)
 yield() --allow anim swap
end

function animate_level_done()
 local anim=cowrap(
  "level_done",
  level_done_anim
 )
 anim.draw=function()
  draw_dialog("solved!",58)
 end
 return anim
end

function retry_anim()
 sfx(2)
 wait(30)
 start_level(state.level.idx)
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
player={}
function player:new(x,y)
 local o=setmetatable({},self)
 self.__index=self

 o.sx=x*8
 o.sy=y*8
 o.sd=0
 o.dx=0
 o.dy=0
 o.rot=0
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

function player:_move(state)
 local done=false
 local mov=self.mov
 mov.step+=1
 if mov.step<=10 then
  self.sx+=mov.dx
  self.sy+=mov.dy
  self.sd=(
   self.sd+3+mov.dx+mov.dy
  )%3

  if state.push_box==nil then
   done=mov.step==8
  elseif mov.step>2 then
   state.push_box.sx+=mov.dx
   state.push_box.sy+=mov.dy
  end
 elseif (
  self.movq!=nil
  and self.movq.rot==self.rot
 ) then
  --continue into next move
  self:_start_queued_move(state)
 else
  --retreat after placing box
  self.sx-=mov.dx
  self.sy-=mov.dy
  self.sd=(
   self.sd+3-mov.dx-mov.dy
  )%3
  done=self.mov.step==12
 end

 if (
  self.sx%8==0 and self.sy%8==0
 ) then
  local bub=state.level:bubble(
   self.sx\8,self.sy\8
  )
  if bub!=nil then
   state.view=bub
  end
 end

 if done then
  self.mov=nil
  state.push_box=nil
 end
end

function player:_check_move(
 mov,state
)
 local sx=self.sx
 local sy=self.sy
 if self.mov!=nil then
  sx=self.mov.tgt_sx
  sy=self.mov.tgt_sy
 end

 local sx1=sx+mov.dx*8
 local sy1=sy+mov.dy*8

 local lvl=state.level
 if lvl:is_wall(sx1\8,sy1\8) then
  --cannot enter wall
  sfx(0)
  return
 end

 local box=box_at(sx1,sy1,state)
 if box!=nil then
  if box.c!=state.view then
   --cannot move this box color
   sfx(0)
   return
  end
  local sx2=sx1+mov.dx*8
  local sy2=sy1+mov.dy*8
  if (
   lvl:is_wall(sx2\8,sy2\8)
   or box_at(sx2,sy2,state)!=nil
  ) then
   --no room to push box
   sfx(0)
   return
  end
 end

 mov.tgt_sx=sx1
 mov.tgt_sy=sy1
 return mov
end

function player:_start_queued_move(
 state
)
 assert(self.movq!=nil)
 local mov=self.movq
 self.movq=nil

 if self.mov!=nil then
  local dsx=abs(
   self.mov.tgt_sx-self.sx
  )
  local dsy=abs(
   self.mov.tgt_sy-self.sy
  )

  assert(dsx<=2)
  assert(dsy<=2)
  mov.step=max(dsx,dsy)
 else
  mov.step=0
 end

 self.mov=mov
 state.push_box=box_at(
  mov.tgt_sx,
  mov.tgt_sy,
  state
 )

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

 if self.tgt_rot then
  self:_rotate()
 elseif self.mov then
  self:_move(state)
 elseif self.movq!=nil then
  self:_start_queued_move(state)
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

 spr(
  si,
  lvl.sx0+self.sx,
  lvl.sy0+self.sy
 )
end


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
 o.sy0=64-4*o.nrows

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

function level:bubble(x,y)
 local si=self:_sprite(x,y)
 if fget(si,flag_bub) then
  return bub_color(si)
 end
 return nil
end

function level:update_state(s)
 s.level=self
 s.view=0
 s.boxes={}
 s.box_cnt=0
 s.push_box=nil
 for ix=0,self.ncols-1 do
  for iy=0,self.nrows-1 do
   local si=self:_sprite(ix,iy)
   if fget(si,flag_player) then
    s.player=player:new(ix,iy)
   elseif fget(si,flag_box) then
    add(
     s.boxes,{
      sx=ix*8,
      sy=iy*8,
      c=box_color(si)
     }
    )
   end
  end
 end

 return s
end

function level:_draw_fixed(state)
 for ix=0,self.ncols-1 do
  for iy=0,self.nrows-1 do
   local si=self:_sprite(ix,iy)
   local dsi=0
   if fget(si,flag_wall) then
    dsi=si
   elseif fget(si,flag_tgt) then
    local c=tgt_color(si)
    if c==state.view then
     dsi=si
    elseif fget(si,flag_bub) then
     dsi=(si\16)*16+12
    else
     dsi=9
    end
   elseif fget(si,flag_bub) then
    local c=bub_color(si)
    dsi=c*16+10
   end
   if dsi!=0 then
    spr(
     dsi,
     self.sx0+ix*8,
     self.sy0+iy*8
    )
   end
  end
 end
end

function level:_draw_boxes(state)
 for box in all(state.boxes) do
  local si=5
  if box.c==state.view then
   si+=box.c*16
  end
  spr(
   si,
   self.sx0+box.sx,
   self.sy0+box.sy
  )
 end
end

function level:draw(state)
	self:_draw_fixed(state)
	self:_draw_boxes(state)
end

function level:is_done(state)
 state.box_cnt=0

 for box in all(state.boxes) do
  if box!=state.push_box then
   local si=self:_sprite(
    box.sx\8,box.sy\8
   )
   if not fget(si,flag_tgt) then
    return
   end
   local c=tgt_color(si)
   if c!=-1 and c!=box.c then
    return
   end
   state.box_cnt+=1
  end
 end

 return state.box_cnt==#state.boxes
end
-->8
function start_level(idx)
 local lvl=level:new(idx)
 state=lvl:update_state({})
 --state.anim=show_dialog(
 -- lvl.name
 --)
end

function _init()
 start_level(1)
end

function _draw()
 cls()
 state.level:draw(state)
 state.player:draw(state)

 if state.anim!=nil then
  state.anim.draw()
 end
end

function _update()
 if state.anim then
  if coinvoke(state.anim) then
   state.anim=nil
  end
 else
  state.player:update(state)

  if state.level:is_done(state) then
   state.anim=animate_level_done()
  end
 end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999500000000
00000000000000000000000000000000000000000999995000000000000000000000000004400440000000000990099000000000000000009444444509999950
00700700000000000000000000000000000000000944445000000000000000000000000004000040000440000900009000000000000000009444444509444450
00077000000000000000000000000000000000000944445000000000000000000000000000000000004944000000000000000000000000009444444509444450
00077000000000000000000000000000000000000944445000000000000000000000000000000000004444000000000000000000000000009444444509444450
00700700000000000000000000000000000000000944445000000000000000000000000004000040000440000900009000000000000000009444444509444450
00000000000000000000000000000000000000000555555000000000000000000000000004400440000000000990099000000000000000009444444505555550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555500000000
00000000000000000000000000040000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04ffff4004ffff4002ffff20004fff000024ff000eeeee2008888880088888800888888008800880000000000990099004400440088008800330033001100110
04ffff4002ffff2004ffff4002fffff004fffff00e88882008000080080000800800008008000080000880000908809004088040080880800308803001088010
02f76f2004f76f4004f76f4004f76ff44ff76ff00e88882008088080080330800801108000000000008988000089880000898800008988000089880000898800
04f66f4004f66f4002f66f204ff66f400ff66ff40e88882008088080080330800801108000000000008888000088880000888800008888000088880000888800
04ffff4002ffff2004ffff400fffff200fffff400e88882008000080080000800800008008000080000880000908809004088040080880800308803001088010
02ffff2004ffff4004ffff4000fff40000ff42000222222008888880088888800888888008800880000000000990099004400440088008800330033001100110
00000000000000000000000000004000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000040000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04424420042442400244244000ff420000fff4000bbbbb1003333330033333300333333003300330000000000990099004400440088008800330033001100110
0ffffff00ffffff00ffffff00fffff400fffff200b33331003000030030000300300003003000030000330000903309004033040080330800303303001033010
0ff76ff00ff76ff00ff76ff00ff76ff44ff76f400b33331003088030030330300301103000000000003b3300003b3300003b3300003b3300003b3300003b3300
0ff66ff00ff66ff00ff66ff04ff66ff004f66ff40b33331003088030030330300301103000000000003333000033330000333300003333000033330000333300
0ffffff00ffffff00ffffff004fffff002fffff00b33331003000030030000300300003003000030000330000903309004033040080330800303303001033010
0442442004244240024424400024ff00004fff000111111003333330033333300333333003300330000000000990099004400440088008800330033001100110
00000000000000000000000000004000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000ddddd2001111110011111100111111001100110000000000990099004400440088008800330033001100110
00000000000000000000000000000000000000000d11112001000010010000100100001001000010000110000901109004011040080110800301103001011010
00000000000000000000000000000000000000000d11112001088010010330100101101000000000001c1100001c1100001c1100001c1100001c1100001c1100
00000000000000000000000000000000000000000d11112001088010010330100101101000000000001111000011110000111100001111000011110000111100
00000000000000000000000000000000000000000d11112001000010010000100100001001000010000110000901109004011040080110800301103001011010
00000000000000000000000000000000000000000222222001111110011111100111111001100110000000000990099004400440088008800330033001100110
__gff__
0000000000040000000810000000020201010100000414141408101818181818010101000004141414081018181818180000000000041414140810181818181800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e1000000000290e1000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0000000015000e0000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0000003a00000e00001500250f0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00002a1a00000e0000250000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0035000025000e0000170029190e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e1900000000390e1a000f0019290e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001e05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001a05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001400001c05018050100501005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
