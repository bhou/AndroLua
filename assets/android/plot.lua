local G = luajava.package 'android.graphics'
local L = luajava.package 'java.lang'
local V = luajava.package 'android.view'
local array = require 'android.array'
local append = table.insert

local Plot = { array = array }

-- OOP support
local function make_object (obj,T)
    T.__index = T
    return setmetatable(obj,T)
end

local function make_callable (type,ctor)
    setmetatable(type,{
        __call = function(_,...) return ctor(...) end
    })
end

local function union (A,B)
    if A.left > B.left then A.left = B.left end
    if A.bottom > B.bottom then A.bottom = B.bottom end
    if A.right < B.right then A.right = B.right end
    if A.top < B.top then A.top = B.top end
end

local FILL,STROKE = G.Paint_Style.FILL,G.Paint_Style.STROKE
local WHITE,BLACK = G.Color.WHITE, G.Color.BLACK

local function PC (clr,default)
    return android.parse_color(clr or default)
end

local function stroke ()
    local style = G.Paint()
    style:setStyle(STROKE)
    return style
end

local function set_color(style,clr)
    style:setColor(PC(clr))
end

local function fill_paint (clr)
    local style = G.Paint()
    style:setStyle(FILL)
    set_color(style,clr)
    return style
end

local function stroke_paint (clr,width,effect)
    local style = stroke()
    set_color(style,clr)
    if width then
        style:setStrokeWidth(width)
        style:setAntiAlias(true)
    end
    if effect then
        style:setPathEffect(effect)
    end
    return style
end

local function text_paint (size,clr)
    local style = stroke()
    style:setTextSize(size)
    if clr then
        set_color(style,clr)
    end
    style:setAntiAlias(true)
    return style
end

local Series,Axis,Legend,Anot = {},{},{},{}

--local colours = {G.Color.BLACK,G.Color.BLUE,G.Color.RED}

function Plot.new (t)
    local self = make_object({},Plot)
    self.background = fill_paint(t.background or WHITE)
    self.area = fill_paint(t.fill or WHITE)
    self.color = t.color or BLACK
    self.axis_paint = stroke_paint(self.color)
    self.aspect_ratio = t.aspect_ratio or 1
    self.margin = {}
    self.series = {}
    self.grid = t.grid
    self.xaxis = Axis.new(self,t.xaxis or {})
    self.xaxis.horz = true
    self.yaxis = Axis.new(self,t.yaxis or {})

    local W = android.me.metrics.widthPixels

    local defpad = W/30
    if t.padding then
        defpad = t.padding
    end
    self.padding = {defpad,defpad,defpad,defpad}
    self.pad = defpad

    -- this is the Flot theme...
    self.colours = {PC"#edc240", PC"#afd8f8", PC"#cb4b4b", PC"#4da74d", PC"#9440ed"}

    if #t == 0 then error("must provide at least one Series!") end -- relax this later??

    for _,s in ipairs(t) do
        local series = Series.new (self,s)
        append(self.series,series)
        if s.tag then
            self.series[s.tag] = s
        end
    end

    if t.legend ~= false then
        self.legend = Legend.new(self,t.legend)
    end

    self.annotations = {}
    if t.annotations then
        for _,a in ipairs(t.annotations) do
            append(self.annotations,Anot.new(self,a))
        end
    end

    return self
end

make_callable(Plot,Plot.new)

function Plot:calculate_bounds_if_needed ()
    local xaxis, yaxis = self.xaxis, self.yaxis
    -- have to update Axis bounds if they haven't been set...
    if not xaxis:has_bounds() or not yaxis:has_bounds() then
        local huge = math.huge
        local bounds = {left=huge,right=-huge,bottom=huge,top=-huge}
        for _,s in ipairs(self.series) do
            union(bounds,s:bounds())
        end
        if not xaxis:has_bounds() then
            xaxis:set_bounds(bounds.left,bounds.right)
        end
        if not yaxis:has_bounds() then
            yaxis:set_bounds(bounds.bottom,bounds.top)
        end
    end
end

function Plot.init (plot)
    local padding,xaxis,yaxis = plot.padding,plot.xaxis,plot.yaxis

    plot:calculate_bounds_if_needed()

    xaxis:init()
    yaxis:init()

    -- we now know the extents of the axes and can size our plot area
    plot.boxwidth = plot.width - padding[1] - padding[3] - yaxis.thick
    plot.boxheight = plot.aspect_ratio*plot.boxwidth

    plot.margin = {
        left = padding[1] + yaxis.thick,
        top = padding[2],
        right = padding[3],
        bottom = padding[4] + yaxis.thick
    }

    plot.total_height = plot.boxheight + xaxis.thick + 2*padding[2]

    -- we have the exact plot area dimensions and can now scale data properly
    xaxis:setup_scale()
    yaxis:setup_scale()

    local M = 7
    plot.outer_margin = {left=M,top=M,right=M,bottom=M} --outer

    plot.initialized = true

end

function Plot:next_colour ()
    return self.colours [#self.series % #self.colours + 1]
end

function Plot.resized(plot,w,h)
    plot.width = w
    plot.height = h
end

function Plot.draw(plot,c)
    if not plot.initialized then
        plot:init()
    end
    c:drawPaint(plot.background)

    c:save()
    c:translate(plot.margin.left,plot.margin.top)
    local bounds = G.Rect(0,0,plot.boxwidth,plot.boxheight)
    if plot.area then
        c:drawRect(bounds,plot.area)
    end
    c:drawRect(bounds,plot.axis_paint)
    c:clipRect(bounds)
    for _,s in ipairs(plot.series) do
        s:draw(c)
    end
    for _,a in ipairs(plot.annotations) do
        a:draw(c)
    end
    c:restore()
    plot.xaxis:draw(c)
    plot.yaxis:draw(c)
    c:translate(plot.margin.left,plot.margin.top)
    if plot.legend then
        plot.legend:draw(c)
    end
end

function Plot:onMeasure (wspec,hspec)
    local MeasureSpec = V.View_MeasureSpec
    local pwidth = MeasureSpec:getSize(wspec)
    local pheight = MeasureSpec:getSize(hspec)
    local hmode = MeasureSpec:getMode(hspec)
    local wmode = MeasureSpec:getMode(wspec)
    if not self.initialized then
        if not self.width then
            self.width = pwidth
        end
        self:init()
    end
    self.view:measuredDimension(pwidth,self.total_height)
end

function Plot.view (plot,me)
    plot.me = me
    me.plot = plot
    plot.view = me:luaView {
        onDraw = function(c) plot:draw(c) end,
        onSizeChanged = function(w,h) plot:resized(w,h) end,
        onMeasure = function(wspec,hspec) plot:onMeasure(wspec,hspec); return true end
    }
    return plot.view
end

function Plot:corner (cnr,width,height,M)
    local WX,HY = self.boxwidth,self.boxheight
    M = M or self.outer_margin
    local H,V = cnr:match '(.)(.)'
    local x,y
    if H == 'L' then
        x = M.left
    else
        x = WX - (width + M.right)
    end
    if V == 'T' then
        y = M.top
    else
        y = HY - (height + M.bottom)
    end
    return x,y
end

------ Axis class ------------

function Axis.new (plot,self)
    make_object(self,Axis)
    self.plot = plot
    self.grid = self.grid or plot.grid

    self.label_size = android.me:parse_size(self.label_size or '12sp')
    self.label_paint = text_paint(self.label_size,plot.color)

    if self.grid then
        self.grid = stroke_paint('#50000000')
    end
    return self
end

function Axis:has_explicit_ticks ()
    return type(self.ticks)=='table' and #self.ticks > 0
end

function Axis:has_bounds ()
    return self.min and self.max or self:has_explicit_ticks()
end

function Axis:set_bounds (min,max)
    self.min = min
    self.max = max
end

function Axis:init()
    local plot = self.plot

    if not self:has_explicit_ticks() then
        local W = plot.width
        if not self.horz then W = plot.aspect_ratio*W end
        self.ticks = require 'android.plot.intervals' (self,W)
    end
    local ticks = self.ticks

    -- how to convert values to strings for labels;
    -- format can be a string (for `string.format`) or a function
    local format = ticks.format
    if type(format) == 'string' then
        local fmt = format
        format = function(v) return fmt:format(v) end
    elseif not format then
        format = tostring
    end

    local wlabel = ''
    -- We have an array of ticks. Ensure that it is an array of {value,label} pairs
    for i = 1,#ticks do
        local tick = ticks[i]
        local label
        if type(tick) == 'number' then
            label = format(tick)
            ticks[i] = {tick,label}
        else
            label = tick[2]
        end
        if #label > #wlabel then
            wlabel = label
        end
    end

    -- adjust our bounds to match ticks, and give some vertical space for series
    local start_tick, end_tick = ticks[1][1], ticks[#ticks][1]

    if not self.horz then
        if self.max ~= 0 and self.max == end_tick then
            local D = (self.max - self.min)/20
            self.max = self.max + D
        end
        if self.min ~= 0 and self.min == start_tick then
            local D = (self.max - self.min)/20
            self.min = self.min - D
        end
    end

    if not self.min or self.min > start_tick then
        self.min = start_tick
    end
    if not self.max or self.max < end_tick then
        self.max = end_tick
    end

    --- finding our 'thickness', which is the extent in the perp. direction
    -- (we'll use this to adjust our plotting area size and position)
    self.label_width = self:get_label_extent(wlabel)
    if not self.horz then
        -- cool, have to find width of y-Axis label on the left...
        self.thick = self.label_width + 7
    else
        self.thick = self.label_size
    end
    self.tick_width = self.label_size
end

function Axis:get_label_extent(wlabel,paint)
    local rect = G.Rect()
    paint = paint or self.label_paint
    -- work with a real Java string to get the actual length of a UTF-8 string!
    local str = L.String(wlabel)
    paint:getTextBounds(wlabel,0,str:length(),rect)
    return rect:width(),rect:height()
end

function Axis:setup_scale ()
    local horz,plot = self.horz,self.plot
    local W = horz and plot.boxwidth or plot.boxheight
    local delta = self.max - self.min
    local m,c
    if horz then
        m = W/delta
        c = -self.min*W/delta
    else
        m = -W/delta
        c = self.max*W/delta
    end

    self.scale = function(v)
        return m*v + c
    end
end

function Axis:draw (c)
    if not self.ticks then return end -- i.e, we don't want to draw ticks or gridlines etc

    local tpaint,apaint,size,scale = self.label_paint,self.plot.axis_paint,self.label_size,self.scale
    local boxheight = self.plot.boxheight
    local margin = self.plot.margin
    local twidth = self.tick_width
    local lw = self.label_width
    if self.horz then
        c:save()
        c:translate(margin.left,margin.top + boxheight)
        for _,tick in ipairs(self.ticks) do
            local x = scale(tick[1])
            --c:drawLine(x,0,x,twidth,apaint)
            if tpaint then
                lw = self:get_label_extent(tick[2],tpaint)
                c:drawText(tick[2],x-lw/2,size,tpaint)
            end
            if self.grid then
                c:drawLine(x,0,x,-boxheight,self.grid)
            end
        end
        c:restore()
    else
        c:save()
        local boxwidth = self.plot.boxwidth
        c:translate(margin.left,margin.top)
        for _,tick in ipairs(self.ticks) do
            local y = scale(tick[1])
            --c:drawLine(-twidth,y,0,y,apaint)
            if tpaint then
                c:drawText(tick[2],-lw,y,tpaint) -- y + sz !
            end
            if self.grid then
                c:drawLine(0,y,boxwidth,y,self.grid)
            end
        end
        c:restore()
    end
end

------- Series class --------

local function unzip (data)
    data = array(data)
    local xdata = data:map '_[1]'
    local ydata = data:map '_[2]'
    return xdata,ydata
end

function Series.new (plot,t)
    t.plot = plot
    t.xaxis = plot.xaxis
    t.yaxis = plot.yaxis
    t.path = G.Path()
    local clr = t.color or plot:next_colour()
    if not t.points and not t.lines then
        t.lines = true
    end
    if t.lines then
        t.linestyle = stroke_paint(clr,t.width)
        --local dash = G.DashPathEffect(L.Float{20,5},1)
    end
    if t.points then
        t.pointstyle = stroke_paint(clr,t.pointwidth or t.width)
        local cap = t.points == 'circle' and G.Paint_Cap.ROUND or G.Paint_Cap.SQUARE
        t.pointstyle:setStrokeCap(cap)
    end
    if t.data then -- Flot-style data
        t.xdata, t.ydata = unzip(t.data)
    elseif not t.xdata and not t.ydata then
        error("must provide both xdata and ydata for series")
    else
        t.xdata, t.ydata = array(t.xdata),array(t.ydata)
    end
    if t.points then
        t.xpoints, t.ypoints = t.xdata, t.ydata
    end
    return make_object(t,Series)
end


function Series:bounds ()
    if self.cached_bounds then
        return self.cached_bounds
    end
    --self.xdata[1],self.xdata[#self.xdata] -- a simplification for now
    local xmin,xmax = array.minmax(self.xdata)
    local ymin,ymax = array.minmax(self.ydata)
    self.cached_bounds = {left=xmin,top=ymax,right=xmax,bottom=ymin}
    return self.cached_bounds
end

local function draw_poly (self,c,xdata,ydata,pathstyle)
    local scalex,scaley,path = self.xaxis.scale, self.yaxis.scale, self.path
    path:reset()
    path:moveTo(scalex(xdata[1]),scaley(ydata[1]))
    for i = 2,#xdata do
        path:lineTo(scalex(xdata[i]),scaley(ydata[i]))
    end
    c:drawPath(path,pathstyle)
end

function Series:draw(c)

--~     if self.is_anot then
--~         print('lines',self.xdata,self.ydata,self.linestyle)
--~         print('points',self.xpoints,self.ypoints,self.pointstyle)
--~     end

    if self.linestyle then
        draw_poly (self,c,self.xdata,self.ydata,self.linestyle)
    end
    if self.fillstyle then
        draw_poly (self,c,self.xfill,self.yfill,self.fillstyle)
    end

    if self.pointstyle then
        local scalex,scaley = self.xaxis.scale, self.yaxis.scale
        local xdata,ydata = self.xpoints,self.ypoints
        for i = 1,#xdata do
            c:drawPoint(scalex(xdata[i]),scaley(ydata[i]),self.pointstyle)
        end
    end
end

function Series:draw_sample(c,x,y,sw)
    if self.linestyle then
        c:drawLine(x,y,x+sw,y,self.linestyle)
    else
        c:drawPoint(x,y,self.pointstyle)
    end
end

function Series:get_x_intersection (x)
    local idx = self.xdata:find(x)
    if not idx then error("no intersection with this series possible") end
    local y = self.ydata:at(idx)
    return y,idx
end

function Series:get_data_range (idx1,idx2)
    local data = array()
    local xx,yy = self.xdata,self.ydata
    local y1,y2,x,exact

    -- the end indices may refer to interpolated points,
    -- in which case we need to add them to complete the path
    y1,exact = yy:at(idx1)
    if not exact then
        data:append {idx1.x,y1}
        idx1 = idx1[1]+1
    end
    y2,exact = yy:at(idx2)
    if not exact then
        x = idx2.x
        idx2 = idx2[1]+1
    end
    for i = idx1,idx2 do
        data:append {xx[i],yy[i]}
    end
    if x then
        data:append {x, y2}
    end
    return data
end

-- the bounds are usually not known at object creation time,
-- so we use these chaps as placeholders and fix them up later!
local UPPER,LOWER = math.huge, -math.huge

local function fixup (t,axis)
    for i, v in ipairs(t) do
        if v == UPPER then t[i] = axis.max
        elseif v == LOWER then t[i] = axis.min
        end
    end
end

function Anot.new(plot,t)
    local lines = array()

    if t.series then
        t.series = plot.series[t.series]  -- array index _or_ tag
    end

    local fill = t.x1 ~= nil
    local top

    if fill then
        fill = fill_paint(t.color or '#30000000')
        if not t.series then
            lines:append {t.x1,LOWER}
            lines:append {t.x1,UPPER}
            lines:append {t.x2,UPPER}
            lines:append {t.x2,LOWER}
        else
            local top1,i1 = t.series:get_x_intersection(t.x1)
            local top2,i2 = t.series:get_x_intersection(t.x2)
            lines:append {t.x1,LOWER}
            lines:extend(t.series:get_data_range(i1,i2))
            lines:append {t.x2,LOWER}
        end
    else -- line annotation
        lines:append {t.x,LOWER}
        if not t.series then
            lines:append {t.x,UPPER}
        else
            top = t.series:get_x_intersection(t.x)
            lines:append {t.x,top}
            lines:append {LOWER,top}
        end

        t.width = 1
        if t.points then t.pointwidth = 7  end
        t.lines = true
    end
    t.data = lines
    t.color = '#40000000'

    local self = Series.new(plot,t)

    -- maybe add a point to the intersection?
    if t.points and t.series then
        self.xpoints = array{t.x}
        self.ypoints = array{top}
    end
    if fill then
        self.fillstyle = fill
        self.linestyle = nil
        self.xfill, self.yfill = self.xdata, self.ydata
    end
    self.is_anot = true

    make_object(self,Anot)
    return self
end

function Anot:draw(c)
    fixup(self.ydata,self.yaxis)
    fixup(self.xdata,self.xaxis)
    Series.draw(self,c)
end

----- Legend class ----------
function Legend.new (plot,t)
    if type(t) == 'string' then
        t = {corner = t}
    elseif t == nil then
        t = {}
    end
    local self = make_object(t or {},Legend)
    self.plot = plot
    self.cnr = self.corner or 'RT'

    local P = t.padding or plot.pad/2
    self.padding = {P,P,P,P} --inner
    self.sample_width = t.sample_width or 2*plot.pad

    self.stroke = plot.axis_paint
    self.label_paint = plot.xaxis.label_paint
    self.background = fill_paint(t.fill or WHITE)
    return self
end

local empty_margin = {left=0,top=0,right=0,bottom=0}

function Legend:draw (c)
    local plot = self.plot
    local P = self.padding

    -- get all series with labels, plus the largest label
    local series = {}
    local wlabel = ''
    for _,s in ipairs(plot.series) do if s.label then
        append(series,s)
        if #s.label > #wlabel then
            wlabel = s.label
        end
    end end

    -- can now calculate our bounds and ask for our position
    local sw = self.sample_width
    local w,h = plot.xaxis:get_label_extent(wlabel)
    local W,H
    local dx,dy,n = P[1],P[2],#series
    if not self.across then
        W = P[1] + sw + dx + w + dx
        H = P[2] + n*(dy+h) - h/2
    else
        W = P[1] + n*(sw+w+2*dx)
        H = P[2] + h + dy
    end
    local margin
    local draw_box = self.box == nil or self.box == true
    if not draw_box then margin = empty_margin end
    local xs,ys = plot:corner(self.cnr,W,H,margin)

    -- draw the box
    if draw_box then
        local bounds = G.Rect(xs,ys,xs+W,ys+H)
        if self.background then
            c:drawRect(bounds,self.background)
        end
        c:drawRect(bounds,self.stroke)
    end
    self.width = W
    self.height = H

    -- draw the entries (ask series to give us a 'sample')
    local y = ys + P[2] + h/2
    local offs = h/2
    local x = xs + P[1]
    local yspacing = P[2]/2
    if self.across then y = y + h/2 end
    for _,s in ipairs(series) do
        s:draw_sample(c,x,y-offs,sw)
        x = x+sw+P[1]
        c:drawText(s.label,x,y,self.label_paint)
        if not self.across then
            y = y + h + yspacing
            x = xs + P[1]
        else
            x = x + w/2 + 2*P[1]
        end
    end

end

-- we export this for now
_G.Plot = Plot
return Plot
