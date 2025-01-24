pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
level_defs={{
 name="intro",
 mapdef={0,0,8,8},
}}

--sprite flags
flag_player=0
flag_wall=1
flag_box=2
flag_tgt=3
flag_bub=4

function box_color(si)
 return si\16
end

function tgt_color(si)
 local col=si%16
 if col==8 then
  return si\16
 end
 if col==10 then
  return -1
 end
 return col-11
end

function bub_color(si)
 local col=si%16
 if col<=6 then
  return col-3
 else
  return si\16
 end
end

function box_at(x,y,state)
 for box in all(state.boxes) do
  if box[1]==x and box[2]==y then
   return box
  end
 end
 return nil
end

player={}
function player:new(x,y)
 local o=setmetatable({},self)
 self.__index=self

 o.x=x
 o.y=y
 o.si=2

 return o
end

function player:update(state)
 local dx=0
 local dy=0
 if btnp(➡️) then
  dx=1
 elseif btnp(⬅️) then
  dx=-1
 elseif btnp(⬆️) then
  dy=-1
 elseif btnp(⬇️) then
  dy=1
 end

 if dx==0 and dy==0 then
  return
 end

 local lvl=state.level
	local x1=self.x+dx
	local y1=self.y+dy

 if lvl:is_wall(x1,y1) then
  --cannot enter wall
  sfx(0)
  return
 end

 local box=box_at(x1,y1,state)
 if box!=nil then
  local c=box[3]
  if c!=state.view then
   --cannot move this box color
   sfx(0)
   return
  end
  local x2=x1+dx
  local y2=y1+dy
  if (
   lvl:is_wall(x2,y2)
   or box_at(x2,y2,state)!=nil
  ) then
   --no room to push box
   sfx(0)
   return
  end

  --move box
  box[1]=x2
  box[2]=y2
 end

 self.x=x1
 self.y=y1

 --update sprite
 if dx!=0 then
  if dx>0 then
   self.si=2
  else
   self.si=1
  end
 end

 local bub=lvl:bubble(x1,y1)
 if bub!=nil then
  state.view=bub
 end
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

function level:ini_state()
 local state={}
 state.level=self
 state.view=0
 state.boxes={}
 for ix=0,self.ncols-1 do
  for iy=0,self.nrows-1 do
   local si=self:_sprite(ix,iy)
   if fget(si,flag_player) then
    state.player=player:new(ix,iy)
   elseif fget(si,flag_box) then
    add(
     state.boxes,
     {ix,iy,box_color(si)}
    )
   end
  end
 end

 return state
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
     dsi=(si\16)*16+14
    else
     dsi=8
    end
   elseif fget(si,flag_bub) then
    local c=bub_color(si)
    dsi=c*16+9
   end
   if dsi!=0 then
    spr(dsi,ix*8,iy*8)
   end
  end
 end
end

function level:_draw_boxes(state)
 for box in all(state.boxes) do
  local c=box[3]
  local si=3
  if c==state.view then
   si+=c*16
  end
  spr(si,box[1]*8,box[2]*8)
 end
end

function level:draw(state)
	self:_draw_fixed(state)
	self:_draw_boxes(state)

 local p=state.player
 spr(p.si,p.x*8,p.y*8)
end
-->8
function _init()
 lvl=level:new(1)
 state=lvl:ini_state()
end

function _draw()
 cls()
 lvl:draw(state)
end

function _update()
 if btnp(❎) then
  state.view=(state.view+1)%4
 end
 state.player:update(state)
end
__gfx__
00000000000aa000000aa00004444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aaaaaa00aaaaaa040444404000000000000000000000000000000000440044000000000099009900000000000000000000000000000000000000000
00700700022222200222222044044044000000000000000000000000000000000400004000044000090000900000000000000000000000000000000000000000
00077000a22a22aaaa22a22a44444444000000000000000000000000000000000000000000494400000000000000000000000000000000000000000000000000
00077000aaaaaaaaaaaaaaaa44444444000000000000000000000000000000000000000000444400000000000000000000000000000000000000000000000000
007007000a0000a00a0000a044044044000000000000000000000000000000000400004000044000090000900000000000000000000000000000000000000000
000000000aaaaaa00aaaaaa040444404000000000000000000000000000000000440044000000000099009900000000000000000000000000000000000000000
00000000000aa000000aa00004444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44044404000000000000000008888880088888800888888008888880000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000080888808808888088088880880888808000000000880088000000000099009900440044008800880033003300110011000000000
40444044000000000000000088088088880880888803308888011088000000000800008000088000090880900408804008088080030880300108801000000000
0000000000000000000000008888888888898888883b3388881c1188000000000000000000898800008988000089880000898800008988000089880000000000
44044404000000000000000088888888888888888833338888111188000000000000000000888800008888000088880000888800008888000088880000000000
00000000000000000000000088088088880880888803308888011088000000000800008000088000090880900408804008088080030880300108801000000000
40444044000000000000000080888808808888088088880880888808000000000880088000000000099009900440044008800880033003300110011000000000
00000000000000000000000008888880088888800888888008888880000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000003333330033333300333333003333330000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000030333303303333033033330330333303000000000330033000000000099009900440044008800880033003300110011000000000
00000000000000000000000033033033330880333303303333011033000000000300003000033000090330900403304008033080030330300103301000000000
0000000000000000000000003333333333898833333b3333331c11330000000000000000003b3300003b3300003b3300003b3300003b3300003b330000000000
00000000000000000000000033333333338888333333333333111133000000000000000000333300003333000033330000333300003333000033330000000000
00000000000000000000000033033033330880333303303333011033000000000300003000033000090330900403304008033080030330300103301000000000
00000000000000000000000030333303303333033033330330333303000000000330033000000000099009900440044008800880033003300110011000000000
00000000000000000000000003333330033333300333333003333330000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000001111110011111100111111001111110000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000010111101101111011011110110111101000000000110011000000000099009900440044008800880033003300110011000000000
00000000000000000000000011011011110880111103301111011011000000000100001000011000090110900401104008011080030110300101101000000000
0000000000000000000000001111111111898811113b3311111c11110000000000000000001c1100001c1100001c1100001c1100001c1100001c110000000000
00000000000000000000000011111111118888111133331111111111000000000000000000111100001111000011110000111100001111000011110000000000
00000000000000000000000011011011110880111103301111011011000000000100001000011000090110900401104008011080030110300101101000000000
00000000000000000000000010111101101111011011110110111101000000000110011000000000099009900440044008800880033003300110011000000000
00000000000000000000000001111110011111100111111001111110000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0001010400000000081000000000000002000004141414000810181818181800000000041414140008101818181818000000000414141400081018181818180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1002000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000001300231010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000002300000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000001500281810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1019001000182810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001e05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
