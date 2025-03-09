import "events"
clear

globals.hover = file.loadSound("assets/sounds/hover.wav")

drawMenu = function 
    clear
    //gfx.drawImage file.loadImage("")

    startB = addEvent(320, 320, "assets/components/startWhite.png")
    htpB = addEvent(480, 160, "assets/components/htpWhite.png")

    startB.onMouseOver = function
        self.tint = color.silver
        globals.hover.play
    end function
    startB.onMouseExit = function
        self.tint = color.white
    end function
    startB.onDrag = function
        if self.contains(mouse) then
            self.tint = color.rgb(128,128,128)
        else
            self.tint = color.white
        end if
    end function
    startB.onDragEnd = function
        if self.tint == color.rgb(128,128,128) then
            sneakyLoadAndRun("game")
        end if
    end function

    htpB.onMouseOver = function
        self.tint = color.silver
        globals.hover.play
    end function
    htpB.onMouseExit = function
        self.tint = color.white
    end function
    htpB.onDrag = function
        if self.contains(mouse) then
            self.tint = color.rgb(128,128,128)
        else
            self.tint = color.white
        end if
    end function
    htpB.onDragEnd = function
        if self.tint == color.rgb(128,128,128) then
            sneakyLoadAndRun("menu")
        end if
    end function

    startB.start
    htpB.start
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

sneakyLoadAndRun = function(path)
    load path
    run
end function


drawMenu
events.eventLoop.run