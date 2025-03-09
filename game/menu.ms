import "events"
clear

globals.hover = file.loadSound("assets/sounds/hover.wav")

drawMenu = function
    leftArrow = addEvent(50, 320, "assets/components/arrowW.png", 0.4, 0.3)
    rightArrow = addEvent(910, 320, "assets/components/arrowW.png", 0.4, 0.3)
    leftArrow.rotation = 180

    gfx.fillRect 100, 200, 400, 150

    leftArrow.onMouseOver = function
        self.tint = color.silver
        globals.hover.play
    end function
    leftArrow.onMouseExit = function
        self.tint = color.white
    end function
    leftArrow.onDrag = function
        if self.contains(mouse) then
            self.tint = color.rgb(128,128,128)
        else
            self.tint = color.white
        end if
    end function
    leftArrow.onDragEnd = function
        if self.tint == color.rgb(128,128,128) then

        end if
    end function

    rightArrow.onMouseOver = function
        self.tint = color.silver
        globals.hover.play
    end function
    rightArrow.onMouseExit = function
        self.tint = color.white
    end function
    rightArrow.onDrag = function
        if self.contains(mouse) then
            self.tint = color.rgb(128,128,128)
        else
            self.tint = color.white
        end if
    end function
    rightArrow.onDragEnd = function
        if self.tint == color.rgb(128,128,128) then

        end if
    end function

    rightArrow.start
    leftArrow.start
end function

addComponent = function(x, y, path, scale1=1, scale2=1)
    sprite = new Sprite
    sprite.image = file.loadImage(path)
    sprite.x = x
    sprite.y = y
    sprite.scale = [scale1, scale2]
    display(4).sprites.push sprite
    return sprite
end function

addEvent = function(x, y, path, scale1=1, scale2=1)
    sprite = new events.EventSprite
    sprite.image = file.loadImage(path)
    sprite.x = x
    sprite.y = y
    sprite.scale = [scale1, scale2]
    display(4).sprites.push sprite
    return sprite
end function

drawMenu
events.eventLoop.run