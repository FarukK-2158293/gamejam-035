import "events"
clear

globals.hover = file.loadSound("assets/sounds/hover.wav")

gfx.clear
gfx.fillRect 0,0,960,640, color.maroon

addEvent = function(x, y, path, scale1=1, scale2=1)
    sprite = new events.EventSprite
    sprite.image = file.loadImage(path)
    sprite.x = x
    sprite.y = y
    sprite.scale = [scale1, scale2]
    display(4).sprites.push sprite
    return sprite
end function

default = addEvent(240, 160, "assets/map/default.png")
jungle = addEvent(720, 160, "assets/map/jungle.png")
treasure = addEvent(480, 480, "assets/map/treasure.png")

jungle.onMouseOver = function
    self.tint = color.silver
    globals.hover.play
end function
jungle.onMouseExit = function
    self.tint = color.white
end function
jungle.onDrag = function
    if self.contains(mouse) then
        self.tint = color.rgb(128,128,128)
    else
        self.tint = color.white
    end if
end function
jungle.onDragEnd = function
    if self.tint == color.rgb(128,128,128) then
        text.clear
        text.color = color.white
        text.row = 24
        print "not available"
    end if
end function
default.onMouseOver = function
    self.tint = color.silver
    globals.hover.play
end function
default.onMouseExit = function
    self.tint = color.white
end function
default.onDrag = function
    if self.contains(mouse) then
        self.tint = color.rgb(128,128,128)
    else
        self.tint = color.white
    end if
end function
default.onDragEnd = function
    if self.tint == color.rgb(128,128,128) then
        load "gameDefault"
        run
    end if
end function

treasure.onMouseOver = function
    self.tint = color.silver
    globals.hover.play
end function
treasure.onMouseExit = function
    self.tint = color.white
end function
treasure.onDrag = function
    if self.contains(mouse) then
        self.tint = color.rgb(128,128,128)
    else
        self.tint = color.white
    end if
end function
treasure.onDragEnd = function
    if self.tint == color.rgb(128,128,128) then
        load "gameTreasure"
        run
    end if
end function

jungle.start
default.start
treasure.start

events.eventLoop.run