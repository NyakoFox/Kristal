local Camera = Class()

function Camera:init(parent, x, y, width, height, keep_in_bounds)
    self.parent = parent

    self.x = x or 0
    self.y = y or 0
    self.width = width or SCREEN_WIDTH
    self.height = height or SCREEN_HEIGHT

    -- Camera offset
    self.ox = 0
    self.oy = 0

    -- Camera zoom
    self.zoom_x = 1
    self.zoom_y = 1

    -- Camera bounds (for clamping)
    self.bounds = nil
    -- Whether the camera should stay in bounds
    self.keep_in_bounds = keep_in_bounds ~= false

    -- Camera pan target (for automatic panning)
    self.pan_target = nil

    -- Update position
    self:keepInBounds()
end

function Camera:getBounds()
    if not self.bounds then
        if self.parent then
            return 0, 0, self.parent.width, self.parent.height
        else
            return 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT
        end
    else
        return self.bounds.x, self.bounds.y, self.bounds.width, self.bounds.height
    end
end

function Camera:setBounds(x, y, width, height)
    if x then
        self.bounds = {x = x, y = y, width = width, height = height}
    else
        self.bounds = nil
    end
end

function Camera:getRect()
    return self.x + self.ox - (self.width / self.zoom_x / 2), self.y + self.oy - (self.height / self.zoom_y / 2), self.width / self.zoom_x, self.height / self.zoom_y
end

function Camera:getPosition() return self.x, self.y end
function Camera:setPosition(x, y)
    self.x = x
    self.y = y
    self:keepInBounds()
end

function Camera:getOffset() return self.ox, self.oy end
function Camera:setOffset(ox, oy)
    self.ox = ox
    self.oy = oy
end

function Camera:getZoom() return self.zoom_x, self.zoom_y end
function Camera:setZoom(x, y)
    self.zoom_x = x or 1
    self.zoom_y = y or x or 1
    self:keepInBounds()
end

function Camera:approach(x, y, amount)
    self.x = Utils.approach(self.x, x, amount)
    self.y = Utils.approach(self.y, y, amount)
    self:keepInBounds()
end

function Camera:approachLinear(x, y, amount)
    local angle = Utils.angle(self.x, self.y, x, y)
    self.x = Utils.approach(self.x, x, math.abs(math.cos(angle)) * amount)
    self.y = Utils.approach(self.y, y, math.abs(math.sin(angle)) * amount)
    self:keepInBounds()
end

function Camera:panTo(x, y, time, ease, after)
    if type(x) == "string" then
        after = ease
        ease = time
        time = y
        x, y = Game.world.map:getMarker(x)
    end

    local min_x, min_y = self:getMinPosition()
    local max_x, max_y = self:getMaxPosition()

    if x then
        x = Utils.clamp(x, min_x, max_x)
    end
    if y then
        y = Utils.clamp(y, min_y, max_y)
    end

    if time == 0 then
        self:setPosition(x or self.x, y or self.y)
        if after then
            after()
        end
        return false
    end

    if time == 0 or not ((x and self.x ~= x) or (y and self.y ~= y)) then
        if after then
            after()
        end
        return false
    else
        self.pan_target = {x = x, y = y, time = time, timer = 0, start_x = self.x, start_y = self.y, ease = ease or "linear", after = after}
        return true
    end
end

function Camera:panToSpeed(x, y, speed, after)
    if type(x) == "string" then
        after = speed
        speed = y
        x, y = Game.world.map:getMarker(x)
    end

    local min_x, min_y = self:getMinPosition()
    local max_x, max_y = self:getMaxPosition()

    if x then
        x = Utils.clamp(x, min_x, max_x)
    end
    if y then
        y = Utils.clamp(y, min_y, max_y)
    end

    if (x and self.x ~= x) or (y and self.y ~= y) then
        self.pan_target = {x = x, y = y, speed = speed, after = after}
        return true
    else
        return false
    end
end

function Camera:getMinPosition()
    local x, y, w, h = self:getBounds()
    return x + (self.width / self.zoom_x) / 2, y + (self.height / self.zoom_y) / 2
end

function Camera:getMaxPosition()
    local x, y, w, h = self:getBounds()
    return x + w - (self.width / self.zoom_x) / 2, y + h - (self.height / self.zoom_y) / 2
end

function Camera:keepInBounds()
    if self.keep_in_bounds then
        local min_x, min_y = self:getMinPosition()
        local max_x, max_y = self:getMaxPosition()

        self.x = Utils.clamp(self.x, min_x, max_x)
        self.y = Utils.clamp(self.y, min_y, max_y)
    end
end

function Camera:update()
    if self.pan_target then
        local min_x, min_y = self:getMinPosition()
        local max_x, max_y = self:getMaxPosition()

        local target_x = self.pan_target.x and Utils.clamp(self.pan_target.x, min_x, max_x) or self.x
        local target_y = self.pan_target.y and Utils.clamp(self.pan_target.y, min_y, max_y) or self.y

        if self.pan_target.time then
            self.pan_target.timer = Utils.approach(self.pan_target.timer, self.pan_target.time, DT)

            if self.pan_target.x then
                self.x = Utils.ease(self.pan_target.start_x, target_x, self.pan_target.timer / self.pan_target.time, self.pan_target.ease)
            end
            if self.pan_target.y then
                self.y = Utils.ease(self.pan_target.start_y, target_y, self.pan_target.timer / self.pan_target.time, self.pan_target.ease)
            end
        else
            self:approachLinear(target_x, target_y, self.pan_target.speed * DTMULT)
        end

        if self.x == target_x and self.y == target_y then
            local after = self.pan_target.after

            self.pan_target = nil

            if after then
                after()
            end
        end
    end

    self:keepInBounds()
end

function Camera:getParallax(px, py, ox, oy)
    local x, y, w, h = self:getRect()

    x = x + self.ox
    y = y + self.oy

    local parallax_x, parallax_y

    if ox then
        parallax_x = (x - (ox - w/2)) * (1 - px)
    else
        parallax_x = x * (1 - px)
    end

    if oy then
        parallax_y = (y - (oy - h/2)) * (1 - py)
    else
        parallax_y = y * (1 - py)
    end

    return parallax_x, parallax_y
end

function Camera:applyTo(transform, ceil_x, ceil_y)
    transform:scale(self.zoom_x, self.zoom_y)

    local tx = -self.x - self.ox + (self.width / self.zoom_x / 2)
    local ty = -self.y - self.oy + (self.height / self.zoom_y / 2)

    if ceil_x then
        ceil_x = ceil_x / self.zoom_x
        ceil_y = ceil_y / self.zoom_y
        transform:translate(Utils.ceil(tx, ceil_x), Utils.ceil(ty, ceil_y))
    else
        transform:translate(tx, ty)
    end
end

function Camera:getTransform()
    local transform = love.math.newTransform()
    self:applyTo(transform)
    return transform
end

function Camera:canDeepCopy()
    return true
end
function Camera:canDeepCopyKey(key)
    return key ~= "parent"
end

return Camera