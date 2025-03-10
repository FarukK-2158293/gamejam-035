import "events"
clear

globals.hover = file.loadSound("assets/sounds/hover.wav")

globals.counter = 0
items = ["fusions", "maps", "effects"]

drawMenu = function
    leftArrow = addEvent(50, 320, "assets/components/arrowW.png", 0.4, 0.3)
    rightArrow = addEvent(910, 320, "assets/components/arrowW.png", 0.4, 0.3)
    exit = addEvent(900, 600, "assets/components/exit.png", 0.2, 0.2)
    leftArrow.rotation = 180

    exit.onMouseOver = function
        self.tint = color.silver
        globals.hover.play
    end function
    exit.onMouseExit = function
        self.tint = color.white
    end function
    exit.onDrag = function
        if self.contains(mouse) then
            self.tint = color.rgb(128,128,128)
        else
            self.tint = color.white
        end if
    end function
    exit.onDragEnd = function
        if self.tint == color.rgb(128,128,128) then
            events.eventLoop.stop
            load "main"
            run
        end if
    end function

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
            globals.counter -= 1
            drawContent
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
            globals.counter += 1
            drawContent
        end if
    end function

    exit.start
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

drawContent = function 
    gfx.clear
    gfx.fillRect 0,0,960,640, color.maroon
    if items[abs(globals.counter%3)] == "fusions" then
        gfx.print "Fusion List", 348, 560, color.white, "large"
        gfx.drawImage(file.loadImage("assets/cards/FusionList.png"),120,50,720,480)
    else if items[abs(globals.counter%3)] == "maps" then
        gfx.print "Maps", 432, 560, color.white, "large"
        gfx.drawImage(file.loadImage("assets/map/maps.png"),120,50,720,480)
    else if items[abs(globals.counter%3)] == "effects" then
        //gfx.print "Ability Effects", 300, 560, color.white, "large"
        gfx.print "Work In Progress", 300, 560, color.white, "large"
    end if
end function

drawMenu
drawContent
events.eventLoop.run