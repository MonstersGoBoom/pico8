pico-8 cartridge // http://www.pico-8.com
version 14
__lua__
----------------------------------------------------------------------------------------------------------------------------------
-- globals 
----------------------------------------------------------------------------------------------------------------------------------
_timescale_ = 1 -- this kinda works 
_gravity_ = 0.09
----------------------------------------------------------------------------------------------------------------------------------
-- create a string of the table , so we can print it out 
----------------------------------------------------------------------------------------------------------------------------------
function dump(o)
    if type(o) == 'table' then
        local s = ''
        for k,v in pairs(o) do
            if type(v)== "boolean" then
                if v==true then
                    s = s .. k .. " true "
                else
                    s = s .. k .. " false "
                end
            elseif type(v)== "string" then
                s = s .. k .. ":" .. v
            elseif type(v)== "number" then
                s = s .. k .. ":" .. v
            elseif type(v)== "function" then
                s = s .. k
            else
                s = s .. k .. ":\n" .. dump(v)
            end            
            s = s .. '\n'
        end
        return s
    else
        return o
    end
end
----------------------------------------------------------------------------------------------------------------------------------
-- handy sort table function 
----------------------------------------------------------------------------------------------------------------------------------
table = {}
function table.sort (arr, comp)
  if not comp then
    comp = function (a, b)
      return a < b
    end
  end
  local function partition (a, lo, hi)
      pivot = a[hi]
      i = lo - 1
      for j = lo, hi - 1 do
        if comp(a[j], pivot) then
          i = i + 1
          a[i], a[j] = a[j], a[i]
        end
      end
      a[i + 1], a[hi] = a[hi], a[i + 1]
      return i + 1
    end
  local function quicksort (a, lo, hi)
    if lo < hi then
      p = partition(a, lo, hi)
      quicksort(a, lo, p - 1)
      return quicksort(a, p + 1, hi)
    end
  end
  return quicksort(arr, 1, #arr)
end

----------------------------------------------------------------------------------------------------------------------------------
-- palette stuff
----------------------------------------------------------------------------------------------------------------------------------
palette = 
{
    set = "default",
    ["default"]     = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
    ["red_scheme"]  = {0,2,2,3,4,5,6,7,8,9,10,11,8,13,14,15},
    ["wet"]         = {0,2,2,3,0,5,6,7,8,9,10,11,13,13,13,15},
    ["dark"]        = {0,2,0,1,2,0,5,6,2,5,9,4,13,1,8,14},
};
function palette:scheme(set)
    if set~=palette.set then 
        for i=0,15 do
            pal(i, palette[set][i+1])
        end
        palette.set = set
    end        
end
----------------------------------------------------------------------------------------------------------------------------------
--  transform ( transform ) class
--  basic position and movement 
--  not directly drawable
--  share component for a lot of things
----------------------------------------------------------------------------------------------------------------------------------
transform = {}
transform.__index = transform
-- create a fresh transform
function transform.new()
	local new_tr =
    {
        x = 0,
        y = 0,
        dx = 0,
        dy = 0,
        fx = 1,
        fy = 1,
        below = 0,
        left = 0,
        right = 0,
        gravity = 1.0,
        bits = 0,
        oldbits = 0,
        flipped = false,
        onbitset = {nil,nil,nil,nil,nil,nil,nil,nil},
        onbitclr = {nil,nil,nil,nil,nil,nil,nil,nil},
        onbit = {nil,nil,nil,nil,nil,nil,nil,nil},
    }
	setmetatable(new_tr,transform)
    new_tr.x = 0;
    new_tr.y = 0;
    new_tr.dx = rnd(4)-2;
    new_tr.dy = rnd(4)-2;
	return new_tr
end
-- apply movement
function transform:update()
    self.x = self.x + (self.dx * _timescale_)
    self.y = self.y + (self.dy * _timescale_)
    self.dy = self.dy + ((_gravity_ * self.gravity) * _timescale_);		
	self.dx = self.dx * self.fx;		
	self.dy = self.dy * self.fy;
end
-- update map under and left and right
function transform:checkmap()

-- some logic to see if a bit has changed ( per tile collision )

    self.oldbits = self.bits
    self.bits = fget(mget(self.x/8,(self.y-8)/8))

    for b=0,7 do 
        local newbit = band(shr(self.bits,b),1)
        local oldbit = band(shr(self.oldbits,b),1)

        if ((newbit==0) and (oldbit == 1)) then     -- the bit was cleared
            if self.onbitclr[b+1]~=nil then 
                self.onbitclr[b+1]()
            end
        end
        if ((newbit==1) and (oldbit == 0)) then     -- the bit was set 
            if self.onbitset[b+1]~=nil then 
                self.onbitset[b+1]()
            end
        end
        if ((newbit==1) and (oldbit == 1)) then     -- the bit is still on 
            if self.onbit[b+1]~=nil then 
                self.onbit[b+1]()
            end
        end
    end

--  check positions around us for above , below , left, and right
    self.above = fget(mget(self.x/8,(self.y-16)/8),1);
    self.below = fget(mget(self.x/8,self.y/8),1);
	self.left = fget(mget((self.x-8)/8,(self.y-4)/8),1);
	self.right = fget(mget((self.x+8)/8,(self.y-4)/8),1);
end
-- force a clamp
function transform:clamp(x,y,w,h)
--	clamp	
	if (self.x < x) then
        self.x = x
        self.dx = 0
    end
	if (self.x > x + w) then
        self.x = x + w
        self.dx = 0
    end
	if (self.y < y) then
        self.y = y
        self.dy = 0
    end
	if (self.y > y+h) then
        self.y = y+h
        self.dy = 0
    end
end
--	apply force to the object. 
function transform:applyforce(fx,fy)
	self.dx = self.dx + fx;
	self.dy = self.dy + fy;
end
function transform:applyforce_x(fx)
	self.dx = self.dx + fx;
end
--	apply force to the object. 
function transform:applyforce_y(fy)
	self.dy = self.dy + fy;
end
--	set force to the object. 
function transform:setforce(fx,fy)
	self.dx = fx;
	self.dy = fy;
end
function transform:setforce_x(fx)
	self.dx = fx;
end
function transform:setforce_y(fy)
	self.dy = fy;
end
--  copy transform from another
function transform:copy(t)
    self.x = t.x;
    self.y = t.y;
    self.dx = t.dx;
    self.dy = t.dy;
    self.fx = t.fx;
    self.fy = t.fy;
end
-- untested
function transform:distance(tr)
-- 	return math.sqrt((self.x - tr.x)^2 + (self.y - tr.y)^2)
end
function transform:in_circle(t,r)
  dx = abs(self.x-t.x)
  dy = abs(self.y-t.y)
  if ((dx+dy)<=r) then
    return true
  elseif (dx>r) then
    return false
  elseif dy>r then
    return false
  elseif ( (dx*dx) + (dy*dy) <= r*r ) then
    return true
  else
    return false
  end
end

----------------------------------------------------------------------------------------------------------------------------------
-- collider component 
-- this is pixel offsets from transform 
-- note this is locked to an 8x8 grid at runtime 
-- calls the function if it hits
----------------------------------------------------------------------------------------------------------------------------------

collider = {}
function collider:new(rad,x,y,call,bit)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o.rad = rad
    o.xoff = x
    o.yoff = y
    o.call = call
    o.bits = bit
    return o
end

function collider:update(tr)
    self.cell = mget(   (tr.x+self.xoff)/8,
                        (tr.y+self.yoff)/8);

    if self.bits ~= nil then
        self.hit = fget(self.cell,self.bits)
    else
        self.hit = fget(self.cell)
    end

    if self.hit==true then 
        if self.call~=nil then 
            self:call()
        end
    end
end

function collider:draw(tr)
    local c = 7
    if self.hit==true then 
        c = 8
    end
    pset(   flr((tr.x + self.xoff)/8)*8,
            flr((tr.y + self.yoff)/8)*8,
            c)
end

--
-- animatable sprite
--

animatable = {}
function animatable:new(name)
    o = {}
    setmetatable(o, self)
    self.__index = self

    o.anims = {}
    o.spr = 1
    o.width = 1
    o.height = 1
    o.pivot_x = 0.5
    o.pivot_y = 1.0
    o.animtick = 0
    o.curframe = 0
    o.anim = ""
    o.nextanim = ""
    return o
end

function animatable:draw(tr)
    xoff = shl(self.width,3) * self.pivot_x;
    yoff = shl(self.height,3) * self.pivot_y;
    spr(self.spr,
        tr.x - xoff,
        tr.y - yoff,
        self.width,
        self.height,
        tr.flipped)
end

function animatable:update()
    if self.anims[self.anim] ~= nil then
        self.animtick-=1
        if self.animtick<=0 then
            self.curframe+=1
            local a=self.anims[self.anim]
            self.animtick=a.ticks
            if self.curframe>#a.frames then
                self.curframe=1
            end
            self.spr = a.frames[self.curframe]
            self.width = a.width
            self.height = a.height
        end
    end
end

function animatable:setanim(name)
    self.anim = name;
end

------------------------------------------------
-- entity class
--	contains a transform and stuff
------------------------------------------------
entities = {}
_entities_dirty_ = true;
entity = {}
-- new entity , and add to table of entities
function entity:new(name)
    o = {}
    setmetatable(o, self)
    self.__index = self
    add(entities,o)
    _entities_dirty_ = true;
    o.transform = transform:new();
    o.layer = 50;    --  default to 50 
    o.name = name or ""
    o.colliders = {}
    o.animatables = {}
    o.debug = ""
    return o
end
-- remove from our global table of entities
function entity:del()
    del(entities,self)
    _entities_dirty_ = true;
end
-- move 
function entity:baseupdate()
    self.transform:update();
    for p in all(self.colliders) do
        p:update(self.transform);
    end
    for p in all(self.animatables) do
        p:update();
    end
end
-- draw
function entity:basedraw()
    for p in all(self.animatables) do
        p:draw(self.transform);
    end
end
-- set all animatables attached to "name"
function entity:setanim(name)
    for p in all(self.animatables) do
        p:setanim(name)
    end
end

---------------------------------------------------------------------------------------------------------------------------
-- our particle system
-- is a single entity , with however many particles inside it 
-- this is neater than treating each particle as an entity 
---------------------------------------------------------------------------------------------------------------------------
particles = entity:new("particles")
particles.layer = 69;   --  above regular entities
particles.particles = {}
-- particle class
particle = {}
particle.__index = particle
-- new entity , and add to table of entities
function particle:new(tc)
    o = {}
    setmetatable(o, self)
    o.transform = transform:new();
    o.life = 32;
    o.color = 7;
    o.collide = true;
    o.frame = 0;
    o.animspeed = 0.1;
    o.loop = false;
    if tc~=nil then
     o.transform:copy(tc);
    end
    add(particles.particles,o);
    return o
end
-- remove from our global table of entities
function particle:del()
    del(particles.particles,self)
end

function particles.update()
    particles.debug = "" .. #particles.particles 

    for p in all(particles.particles) do

        if (p.collide == true) then 
            p.transform:checkmap();
            if p.transform.below == true then
                if p.transform.dy > 0 then
                    p.transform.y = (flr(p.transform.y/8)) * 8;
                    p.transform.dy = -p.transform.dy * 0.5
                end
            end
            if p.transform.dx <0 then
                if p.transform.left == true then
                    p.transform.dx= -p.transform.dx * 0.6
                end 
            end
            if p.transform.dx >0 then
                if p.transform.right == true then
                    p.transform.dx= -p.transform.dx * 0.6 
                end
            end
        end
 
        p.transform:update();
 
        p.life = p.life - (1*_timescale_);
        if (p.life <= 0) then
            if p.ondelete ~= nil then
                p.ondelete(p.transform);
            end
            p:del();
        end
    end
end    
-- particles can only be 8x8 or pixels and sequentially animated 1
function particles.draw()
    for p in all(particles.particles) do
        if (p.cells~=0) then

            spr(p.cell  + p.frame
                        ,p.transform.x-4,p.transform.y-8);
            
            if p.frame <= p.cells then 
                p.frame = p.frame + p.animspeed
            end
            if p.frame > p.cells then 
                if p.loop == true then 
                    p.frame = 0;
                end
            end
        else
            pset(p.transform.x, p.transform.y, p.color)
        end                        
    end
end
--  a colorful pop ov pixels
function particles.pop(t)
--    printh("particles.pop");
    local oy = rnd(32);
	for ly=0,18 do
    	p = particle:new(t);
		p.life = 64;
        p.transform:setforce(cos((ly+oy) / 18),sin((ly+oy)/18))
        p.transform.gravity = 0.0;
		p.cells = 0;
        p.collide = false;
		p.color = rnd(15)
	end
end

function particles.splash(t)
--    printh("particles.pop");
    local ly = 0;
	for ly=0,7 do
    	p = particle:new(t);
		p.life = 32;
        p.transform:setforce(cos(ly / 18),0)
        p.transform.gravity = 0.0;
        p.transform.y = t.y - 8;
        p.transform.x = t.x + (p.transform.dx * 8);
		p.cells = 0;
        p.collide = false;
		p.color = 7
	end
end

-- a floating bubble that will pop when it's dead
function particles.bubble(x,y,f)
--    printh("particles.bubble " .. f);
	p = particle:new();
	p.life = 128;
	p.transform:setforce( f , -1.5)
    p.transform.gravity = 1.0;
    p.transform.x = x
    p.transform.y = y
	p.cell = 2
	p.cells = 3;
    p.animspeed = 0.02     
    p.collide = true;
	p.ondelete = particles.pop;
end

-- a drip drop, will spawn another on death
function particles.drop()
 --   printh("particles.drop ");
	p = particle:new();
	p.life = rnd(128);
    p.transform.gravity = 0.0;
    p.transform.x = hero.transform.x + (64-rnd(128))
    p.transform.y = hero.transform.y - 90
    p.transform.dx = 0;
    p.transform.dy = rnd(255) / 255.0
	p.cell = 5
	p.cells = 0;
    p.animspeed = 0.02     
    p.collide = false;
	p.ondelete = particles.drop;
end

-- this is a simple animated 8x8 sprite with slow movement for when entities hit the ground 
function particles.dust(t)
--    printh("particles.dust ");
	p = particle:new(t);
	p.life = 32;
	p.transform:setforce( 0.4 , -0.15)
	p.cell = 16
	p.cells = 3;
    p.animspeed = 0.2
    p.transform.gravity = 0.0;
    p.collide = false;
end

--[[
---------------------------------------------------------------------------------------------------------------------------
-- simple enemy
---------------------------------------------------------------------------------------------------------------------------

enemy = {}
function enemy.bouncer()
    o = entity:new("bouncer");
    o.transform.x = rnd(128);
    o.transform.y = 32;
    o.update = enemy.bouncer_update;
    o.draw = enemy.bouncer_draw;

    o.onhitabove = enemy.onhitabove;
    o.onhitbelow = enemy.onhitbelow;
    o.onhitleft = enemy.onhitleft;
    o.onhitright = enemy.onhitright;
end

function enemy:onhitleft()
    if self.transform.dx < -0.1 then
        self.transform.dx = 0;
        self.transform.x = (1+flr(self.transform.x/8)) * 8;
    end
end

function enemy:onhitright()
    if self.transform.dx > 0.1 then
        self.transform.dx = 0;
        self.transform.x = (flr(self.transform.x/8)) * 8;
    end
end

function enemy:onhitabove()

    if (self.transform.dy<0) then 
        self.transform.dy = 0;
        self.transform.y = flr(self.transform.y/8) * 8;
    end
end

function enemy:onhitbelow()
    print("here");
    if self.transform.dy > 0 then -- falling
        self.transform.dy = -rnd(2.0);
        self.transform.y = flr(self.transform.y/8) * 8;
        particles.dust(self.transform);
    end
end

function enemy:onhitleft()
        self.transform.dy = -1 -rnd(2.0);
end
function enemy:onhitright()
        self.transform.dy = -1 -rnd(2.0);
end

function enemy:bouncer_update()
    self:baseupdate();
    --  bounce the edges of the map 
    if (self.transform.x <0) then
        self.transform.dx = - self.transform.dx;
    end
    if (self.transform.x >128*8) then
        self.transform.dx = - self.transform.dx;
    end
    if self.transform.dx>0 then
        self.transform.flipped = false;
    else
        self.transform.flipped = true; 
    end
end
function enemy:bouncer_draw()
    self:basedraw();
end

]]--
-- our game camera , note it uses transforms too
gamemap = entity:new("gamemap")
gamemap.layer = 0;

function gamemap.update()
    gamemap.transform:setforce(( (hero.transform.x - 64) -gamemap.transform.x)*0.075 , ( (hero.transform.y - 100) -gamemap.transform.y)*0.075)
    gamemap.transform:update();
    gamemap.transform:clamp(0,0,112*8,128);
end

function gamemap.draw()
    palt(11, false) -- beige color as transparency is true
    palt(0, true) -- black color as transparency is false
	camera (0,0)
--  draw our gamescene
	camera (gamemap.transform.x,gamemap.transform.y)
	mapdraw (   gamemap.transform.x/8,
                gamemap.transform.y/8,
                flr(gamemap.transform.x/8)*8,
                flr(gamemap.transform.y/8)*8,
                17,
                17)
    palt(11, true) -- beige color as transparency is true
    palt(0, false) -- black color as transparency is false
end

---------------------------------------------------------------------------------------------------------------------------
-- our hero 
---------------------------------------------------------------------------------------------------------------------------
hero = entity:new("hero")
function hero:init()
    hero.layer = 55 -- infront of all others
    hero.transform.x = 32
    hero.transform.y = 32
    hero.transform.dx = 0;
    hero.transform.dy = 0
    hero.transform.fx = 0.95

    hero.scheme = "default"

    hero.abovehit = collider:new(4,0,-12,hero.onhitabove,1)
    hero.belowhit = collider:new(4,0,0,hero.onhitbelow,1)
    hero.lefthit = collider:new(4,-8,-4,hero.onhitleft,1)
    hero.righthit = collider:new(4,8,-4,hero.onhitright,1)
    
    add(hero.colliders,hero.abovehit)
    add(hero.colliders,hero.belowhit)
    add(hero.colliders,hero.lefthit)
    add(hero.colliders,hero.righthit)

    hero.body = animatable:new();
    hero.body.anims = 
    {
        ["walk"] =
        {
            ticks = 4,
            width = 2,
            height = 1,
            xpivot = 0.5,
            ypivot = 1.0,
            frames = {112,114,116,118,120}
        },
        ["fall"] =
        {
            ticks = 4,
            width = 2,
            height = 1,
            xpivot = 0.5,
            ypivot = 1.0,
            frames = {122,124}
        },
        ["idle"] =
        {
            ticks = 1,
            width = 2,
            height = 1,
            xpivot = 0.5,
            ypivot = 1.0,
            frames = {112}
        },
    }
    hero.body.anim = "walk"
    add(hero.animatables,hero.body);

    hero.face = animatable:new();
    hero.face.anims = 
    {
        ["walk"] =
        {
            ticks = 4,
            width = 2,
            height = 2,
            xpivot = 0.5,
            ypivot = 1.0,
            frames = {64}
        },
        ["fall"] =
        {
            ticks = 1,
            width = 2,
            height = 2,
            xpivot = 0.5,
            ypivot = 1.0,
            frames = {66}
        },
        ["idle"] =
        {
            ticks = 12,
            width = 2,
            height = 2,
            xpivot = 0.5,
            ypivot = 1.0,
            frames = {64,66}
        },
    }
    add(hero.animatables,hero.face);

    hero:setanim("walk")

    hero.transform.onbitset[8] = hero.enterwet;
    hero.transform.onbitclr[8] = hero.leavewet;
    hero.transform.onbitset[7] = hero.enterdark;
    hero.transform.onbitclr[7] = hero.leavedark;
--    hero.transform.onbit[8] = hero.insidewet;
end

-- hit a wall, on the left , stop 
function hero:onhitleft()
    if hero.transform.dx < -0.1 then
        hero.transform.dx = 0;
        hero.transform.x = (1+flr(hero.transform.x/8)) * 8;
    end
end

-- hit a wall, on the right , stop 
function hero:onhitright()
    if hero.transform.dx > 0.1 then
        hero.transform.dx = 0;
        hero.transform.x = (flr(hero.transform.x/8)) * 8;
    end
end

-- hit a wall above. 
function hero:onhitabove()
    if (hero.transform.dy<0) then 
        hero.transform.dy = 0;
        hero.transform.y = flr((hero.transform.y+8)/8) * 8;
    end
end

-- let the bodies hit the floor 
function hero:onhitbelow()
    if hero.transform.dy > 0 then -- falling
        if hero.ground==false then
            hero.body.anim = "walk"
            particles.dust(hero.transform);
        end
        hero.ground = true;
        hero.transform.dy = 0;
        hero.transform.y = flr(hero.transform.y/8) * 8;
    end
end

function hero:enterwet()
    particles.splash(hero.transform);
    hero.transform.gravity = -0.8
    hero.transform.fy = 0.98
    hero.scheme = "wet"
end

function hero:leavewet()
    hero.transform.fy = 1.0
    hero.transform.gravity = 1.0
    hero.scheme = "default"
end

function hero:enterdark()
    hero.scheme = "dark"
end

function hero:leavedark()
    hero.scheme = "default"
end

function hero:draw()
    palette:scheme(hero.scheme)
    hero:basedraw();
    palette:scheme("default");

--[[
  --  local debugbits = self.transform.bits;--bor(self.transform.bits,self.transform.oldbits)
    local debugbits = bxor(self.transform.bits,self.transform.oldbits)
    for lx = 0,7 do 
        if band(shr(debugbits,lx),1) == 0 then
            print("0",self.transform.x - 16 + (lx*4),self.transform.y -24)
        else
            print("1",self.transform.x - 16 + (lx*4),self.transform.y - 24)
        end
    end
]]--
end

function hero:update()
    --  move it move it
    --  left and right keys
    if btn(0) then
        self.transform:applyforce(-0.1,0.0)
        self.transform.flipped = true;
    elseif btn(1) then
        self.transform:applyforce(0.1,0.0)
        self.transform.flipped = false;
    end
    -- walk or idle animation
    if abs(self.transform.dx)<=0.1 then 
        if self.body.anim == "walk" then
            hero:setanim("idle")	
        end
    else
        if self.body.anim == "idle" then 
            hero:setanim("walk")	
        end
    end
    
    self:baseupdate();
    self.transform:clamp(8,0,127*8,256);
    self.transform:checkmap();
    --  shoot the bubble
    if (btnp(5)) then
        if self.transform.flipped == false then 
            particles.bubble(self.transform.x,self.transform.y - 8,1.2 + self.transform.dx);
        end
        if self.transform.flipped == true then 
            particles.bubble(self.transform.x,self.transform.y - 8,-1.2 + self.transform.dx);
        end
    end        

	if hero.transform.below == false then 
		hero.ground = false;
		if hero.transform.dy > 0.1 then
            hero:setanim("fall")	
			--hero.anim = "fall"
		end
	end

	if hero.transform.dy>=0 then
		if btnp(4) then
			hero.transform:setforce_y(-2);
			if hero.ground==true then 
                particles.dust(hero.transform);
			end 
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------
-- screen overlay
---------------------------------------------------------------------------------------------------------------------------
ui = entity:new("ui")
ui.layer = 100;     --  above everything
function ui.update()
end
function ui.draw()
	camera (0,0)
    cursor();
    color(7);
    for p in all(entities) do
        print(p.name .. ":" .. p.debug);
    end
    print('mem:'..stat(0))
    print('cpu:'..stat(1))

end

---------------------------------------------------------------------------------------------------------------------------
-- stuff
---------------------------------------------------------------------------------------------------------------------------

function _init()
    hero:init();

--[[
    enemy.bouncer();
    enemy.bouncer();
    enemy.bouncer();
    enemy.bouncer();
    enemy.bouncer();
    enemy.bouncer();
    enemy.bouncer();
    enemy.bouncer();
]]--
    
end

function _update60()
    --  sort by layer , only do this when the table has changed to be fasto 
    --  eg ui is always on top 
    if (_entities_dirty_ == true) then
        _entities_dirty_ = false;
        table.sort( entities,function(a, b) return a.layer < b.layer end)
    end

    for p in all(entities) do
        p:update();
    end
end

function _draw()
    cls();
    for p in all(entities) do
        p:draw()
    end

end

__gfx__
bbbbbbbbbb7777bbb5c77c5bbbbbbbbbbbbbbbbbbbbbbbbb00000000000020000000200002242442000000000000100000001000011d1dd11dd1d11000000000
bbbbbbbbb777777b5775bcc5b5777c5bbbbbbbbbbbbfbbbb020000020020000020000020244222420100000100100000100000101dd111d11d111dd100282000
bbbbbbbb77777777c775bbccbc77bccbbb57c5bbbbbfbbbb000022002200022022220000242242220000110011000110111100001d11d111111d11d102888020
bbbbbbbb77777777755bbbb7b75bbb7bbb77bcbbbbbfbbbb00022222220222222222200042222222000111111101111111111000d11111111111111d28888022
bbbbbbbb777777777bbbbbb7b7bbbb7bbbcbbcbbbbb7bbbb00022222222222242222200022222222000111111111111d11111000111111111111111128888282
bbbbbbbb77777777ccbbbbccbccbbccbbb5cc5bbbbb7bbbb002222222222422222222200442202000011111111d1d11111111100dd110100001011dd88882282
bbbbbbbbb777777b5ccbbcc5b5c77c5bbbbbbbbbbbbbbbbb0002222244222442222220004222200200011111dd111dd111111000d11110011001111d28882888
bbbbbbbbbb7777bbb5c77c5bbbbbbbbbbbbbbbbbbbbbbbbb020222244424244242222020222200000101111ddd1d1dd1d1111010111100000000111128882882
bbbbbbbbbbbbbbbb75b5bbbbbbbbbbbbbbbbbbbbbbbbbbbb00022222002220002222200022222020000111110011100011111000111110100101111105e77e50
bb77bbbbb775b7bbb7bbbbb7bbbbbbbbbbbbbbbbbbbbbbbb02002244020002004422002044222000010011dd01000100ddd10010dd111000000111dd57750ee5
b577757bb777bb5bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00022244200000004422200042222200000111dd10000000dd111000d11111000011111de77500ee
b7777775b77bbbbbbbbbbbbbbbb5bbbbbbbbbbbbbbbbbbbb0022222220000000222222002242202000111111100000001111110011d1101001011d1175500007
57777775bbbb7bbb5bbbbbbbbbbbbbbbbbb22bbbbb2b2bbb002242242000000042242200422222220011d11d10000000d11d1100d11111111111111d70000007
57777775bbbbb77bbbbbbbbbbbbbb5bbbb2222bbb2b2b2bb00222242020000002422220024222222001111d1010000001d1111001d111111111111d1ee0000ee
b7b7775bb5b7b77bb7bbbb7bbbbbbbbbbb22222bbb2b2bbb02022244000000004422202024422422010111dd00000000dd1110101dd11d1111d11dd15ee00ee5
bbb555bb7bbbbbbbbbbbbbbbbbbbbbbbbbb222bbbbbbbbbb00022244000000004422200002242442000111dd00000000dd111000011d1dd11dd1d11005e77e50
bbbbbb1111111bbbbbbb1111111bbbbb1111111188888888020222244424244242222020244242200101111ddd1d1dd1d1111010888888888888888800361000
bbbb1111111111bbbb1111111111bbbb11111111888888880002222244222242222220002422244200011111dd1111d111111000888888888888888800361000
bbb111111111c71bb111111111c71bbb111111118888888800222222222242222222220022242242001111111111d11111111100888888888888888800361000
bbb111111111771bb111111111771bbb111111118888888800222222222222222222220022222224001111111111111111111100888888888888888800161000
bbb111111111701bb111111111701bbb111111118888888800022222222222222222200022222222000111111111111111111000888888888888888800161000
bbb111111111701bb111111111701bbb111111118888888800000200022002000220000000202244000001000110010001100000888888888888888800163000
bbb11111111170bbb1111111111abbbb111111118888888802000002000000022000002020022224010000010000000110000010888888888888888800163000
bbbb111111111abbbb1111111119abbb111111118888888800000000000000000000000000002222000000000000000000000000888888888888888800163000
bbbbb111111199abbbb111111199bbbb888888888888888844242dd11dd24244dd661dd602022222000000000000000000000000000000000000000088888888
bbbbbbbbb1bbbbbbbbbbbbb1bbbbbbbb8888888888888888441212d11d212144dd1111d100022244010101010000000101000000010101010101010188888888
bbbbbbbb1cccbbbbbbbbbb1cccbbbbbb88888888888888882222d211112d22221111d11100222224000000000000000000000000000000000000000088888888
bbbbbbb11ccccbbbbbbbb11ccccbbbbb888888888888888822212111111212221111111102022422101010100000101010101000000010101010100088888888
bbbbb111cccccbbbbb111c1ccccbbbbb888888888888888821221211112122121111111122222224000000000000000000000000000000000000000088888888
bbbbb11ccccccbbbbbcccc1ccccbbbbb888888888888888802200100001002200110010022222242010101010001010101010100000101010100000088888888
bbbbb111ccccbbbbbbb111ccccbbbbbb888888888888888800000001100000000000000122422442000000000000000000000000000000000000000088888888
bbbbbaaaac99bbbbbbbbb1cc999bbbbb888888888888888800000000000000000000000024424220101010101010101010101010000000101000000088888888
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbb4444444bbbbbbbbb4444444bbbbbbbbb4444444bbbbbbbbbaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbb2222222bbbbbbbbb1111111bbbbbbbbb1111111bbb
bbbb4444444444bbbbbb4444444444bbbbbb4444444444bbbbbbaaaaaaaaaabbbbbbbb2222222bbbbbbb2222222222bbbbbb1111111111bbbbbb1111111111bb
bbb4444444e4444bbbb4444444e4444bbbb4444444e4444bbbbaaaaaaaeaaaabbbbb2222222222bbbbb2222222e2222bbbb111111111111bbbb111111111111b
bb4444444eee444bbb4444444eee444bbb4444444eee444bbbaaaaaaaeeeaaabbbb2222222e2222bbb2222222eee222bbb111111dd1d111bbb1111111111111b
bb44444477e7e44bbb44444477e7e44bbb44444477e7e44bbbaaaaaa77e7eaabbb2222222eee222bbb22222277e7e22bbb11111d7717d11bbb11111d7717d11b
bb4ee4e770e074bbbb4ee4e777e774bbbb4ee4e777e774bbbbaeeae777e77abbbb22222277e7e22bbb2ee2e777e772bbbb111117701071bbbb111117771771bb
bbbee4e770e07ebbbbbee4e770e07ebbbbbee4e700e00ebbbbbeeae770e07ebbbb2ee2e770e072bbbbbee2e770e07ebbbbb11117701071bbbbb11117701071bb
bbbeeeee77e7eebbbbbeeeee70e07ebbbbbeeeee77e7eebbbbbeeeee70e07ebbbbbee2e770e07ebbbbbeeeee70e07ebbbbb1111d7788d1bbbbb1111d7088d1bb
bbbbbeeeee2eeebbbbbbbeeeee2eeebbbbbbbeeeee2eeebbbbbbbeeeee2eeebbbbbeeeee77e7eebbbbbbbeeeee2eeebbbbbbb111118811bbbbbbb111118811bb
bbbbbbeeeeeeebbbbbbbbbeeeeeeebbbbbbbbbeeeeeeebbbbbbbbbeeeeeeebbbbbbbbeeeee2eeebbbbbbbbeeeeeeebbbbbbbbb1111111bbbbbbbbb1111111bbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbeeeeeeebbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222227777777777777777
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222227777775555555777
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222227777555555555577
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222227775555555e55557
2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222775555555eee5557
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222227755555577e7e557
2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222775ee5e770e07577
2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222777ee5e770e07e77
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbeecbbbbbbbbbbbce777eeeee77e7ee77
bbcc1bbbbbbbbbcbbbc1bbbbbbbbbbbbbbb11bbbbbbbbbbbbbb11bbbbbbbbbbbbbbccbbbbbbbbbbbbbbc1bbbbbbbbbcbeecc1bbbbbbbbbce77885eeeeeeeee87
bcccc1bbbbbbb1ccbccc1bbbbbbbbbbbbbbcc1bbbbbbbbbbbbbcc11eeebbbbbbbbccc1bbbbbbb1bbbbccc1bbbbbbb1ccbcccc1bbbbbbb1cb788885eeeeeee588
beeecc1ccccc11ecbcccc1cccccc1eebbbccccee1ccccbbbbbbcccceeecccbbbbccce11ccccc11ebbeeccc1ccccc11eebbccc11ccccc11bb7eee8858888855e8
beee1111111111eebbceee1111111eebbbccccee11111ebbbbbbccceee111bbbbcceee1111111eeebeeecc11441144eebbb11111111111bb7eee5555555555ee
bbb411111111144bbbb4e11111111bbbbbbcccee11111ebbbbbb1111111144bbbbcce111111111eebeeb1114441444bbbbbb1111441144bb7774555555555447
bb4411111111444bbbb4411111111bbbbbbb111111111bbbbbb4411111144bbbbbbb1111111111bbbbbbb114441444bbbbbbb114441444bb7744555555554447
bb44411bbbbb44bbbbbbbbbb44444bbbbbbbb4444b444bbbbbb444bbbbbbbbbbbbb444444b4444bbbbbbbbbbbbbbbbbbbbbbbbb44bb44bbb7744455777774477
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000000000000000000000000000000000000
00000000000000000000000000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

__gff__
0000000000000303030303030303030100000000000003000303030003030300000000008000030303030303030000010000000000000303830341414141410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b1e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003d3a3a3e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000003a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003b3a3a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003a003d3c0000000d2b2b2b0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003a00003a000f001c001b002a0e00000000000000000000000000000927290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b2b2b2b2b2b2b2b2b2b2c0000000a1e00000000000009272727272727272800262727272727272727272727272727272727272727272727272727272729000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001b00000000000a0b1e2424242424242418001700000000000000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000001b00000000001b00001a24242424242424242418000000000000000000000000000000000000000000000000000000000000000000000000000016000900090009000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000001a24242424242424242418000a0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b09272727272727272900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000002a2b2b2b37272727272728001a00000000000000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b1e0000000000000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c
000000000000000000000000000000000000000000000000000000000000000000000000000009272729000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c
0000000000000000000000000000000000000000000000000000000000000000000000000000180000160000000000000000000000001f000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a0000000000003a00001c
0000000000000000000000000000000000000000000000000000000000000000000000000000180000160000000000000000000f00002f0000000000001800000000000009290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a0000003a3a001c
00000000000000000000000000000000000000000000000000000009272727272900000000001800001600000000000000000927272727290000000000180000000f000019390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a00003a3a001c
0000000000000000000000000000000000000000000000000000001800000000160000000000190707390000000000000000180000000016000000000018272909272909272900000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000003a3a3a3a3a3a3a3a1c
000000000000000000000000000000000000000000000000000000180000000016000000000000000000000000000000000018000000001600000000000d2b2b2b2b2b2b2b2b2b0e0000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000003a3a3a3a3a1c
0e00000000000000000000000000000000003b3a3c000000000000190707070739000000000000000000000000000000000019070707073900000000001d0b0b0b0b0b0b0b0b0b1e0000000000000000000000000000000000000000000000001f00000000003a3a000000000000000000000000000000000d2b2b2b2b2b2b2c
1a00000000000000000000000000000000003a3a3e000000000000000000000000000000000d2b2b2b2b2b2b2b2b2b0e0000000000000000000000000000000000000000000000000000000d0e00000000000000000000000000000000001f002f3a0000003a3a3a00000000000000000000000000000d2b2c00000000000000
1a3c0000000000000000000000000000003b3a3c00000000000000000000000000000000001c0000000000000000001a2424242424242424242424242424242424242424242424242424241c2a2b2b2b2b0e242424240d2b0e0000001f002f002f3a0000003a3a3a00000000000000000000000000001c000000000000000000
1a3a0000000000000000000000000000003a3a3a00000000000000000000000000000000001c0000000000000000001a2424242424242424242424242424242424242424242424242424241d0b0b0b0b0b1e242424241c001a0000002f0f2f002f3a003a3a3a3a3a000000000d2b2b2b2b2b2b2b2b2b2c000000000000000000
1a3a3c00000000000000003b3c000000003a3a3e0000000000000d2b2b2b2b2b2b2b2b2b2b2c0000000000000000001a24242424242424242424242424242424242424242424242424242424242424242424242424241c1b2a2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2c00000000000000000000000000000000000000
2a2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2c00000000000000000000000000000000000000001a24242424242424242424242424242424242424242424242424242424242424242424242424241c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a24242424242424242424242424242424242424242424242424242424242424242424242424241c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a2424242424242424242424242424242424242424242424242424240d383838383838383838382c0000001b00000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a383838383838383838383838383838383838383838380e2424240d2c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a2424241c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a2424241c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a2424241c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3838382c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

