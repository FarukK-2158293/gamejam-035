clear 
import "listUtil"
import "events"

// ===== CONFIGURATION VARIABLES =====
animSpeedW = 10
animSpeedFirebom = 10
state = ["idle", 0]
direction = "right"
attackCD = 1
lastShot = time
cards = []
cardCords = [[89,100],[245,100],[401,100]]
cardscale = 0.4
enemies = []
mushroomSpeed = 1
globals.map = "default"
globals.enemiespawnCD = 1
lastenemie = time
globals.selectedAbl = "firebom"
enemiesAmountToKill = 1
globals.enemieskilled = 0
globals.enemiesSpawned = 0
globals.level = 0
globals.wasDown = [false, false, false]
globals.selectedCard = -1  // Track which card is currently selected

// ===== LOAD ASSETS =====
// Firebom attack assets
firebomsheet = file.loadImage("assets/attackeffect/25.png")
firebomFrames = []
for i in range(0, 13)
    firebomFrames.push firebomsheet.getImage(i * 64, 512, 64, 64)
end for

// Fire sweep attack assets
fireSweepsheet = file.loadImage("assets/attackeffect/242.png")
fireSweepFrames = []
for i in range(0, 9)
    fireSweepFrames.push fireSweepsheet.getImage(i * 64, 512, 64, 64)
end for

// Wizard animation frames
wizardSheetIdle = file.loadImage("assets/wizard/idle.png")
wizardSheetAttack = file.loadImage("assets/wizard/Attack.png")
wizardSheetGetHit = file.loadImage("assets/wizard/Gethit.png")
wizardSheetDeath = file.loadImage("assets/wizard/Death.png")
idleFrames = []
attackFrames = []
gethitFrames = []
deathFrames = []
for i in range(0, 9)
    idleFrames.push wizardSheetIdle.getImage(i * 140, 0, 140, 140)
end for
for i in range(0, 12)
    attackFrames.push wizardSheetAttack.getImage(i * 140, 0, 140, 140)
end for
for i in range(0, 2)
    gethitFrames.push wizardSheetGetHit.getImage(i * 140, 0, 140, 140)
end for
for i in range(0, 17)
    deathFrames.push wizardSheetDeath.getImage(i * 140, 0, 140, 140)
end for

// Mushroom enemy assets
mushroomAttack = file.loadImage("assets/enemies/Mushroom-Attack.png")
mushroomDie = file.loadImage("assets/enemies/Mushroom-Die.png")
mushroomRun = file.loadImage("assets/enemies/Mushroom-Run.png")
mushroomHurt = file.loadImage("assets/enemies/Mushroom-Hit.png")
mushroomrunFrames = []
mushroomattackFrames = []
mushroomgethurtFrames = []
mushroomdeathFrames = []
for i in range(0, 7)
    mushroomrunFrames.push mushroomRun.getImage(i * 80, 0, 80, 64)
end for
for i in range(0, 9)
    mushroomattackFrames.push mushroomAttack.getImage(i * 80, 0, 80, 64)
end for
for i in range(0, 4)
    mushroomgethurtFrames.push mushroomHurt.getImage(i * 80, 0, 80, 64)
end for
for i in range(0, 14)
    mushroomdeathFrames.push mushroomDie.getImage(i * 80, 0, 80, 64)
end for

// ===== HELPER FUNCTIONS =====
// Create sprite for the wizard
wizard = new Sprite
wizard.x = 480
wizard.y = 320
display(4).sprites.push wizard

// Sprite isClicked helper function
Sprite.isClicked = function(item)
    if not item.localBounds then
        item.localBounds = new Bounds
        item.localBounds.width = item.image.width
        item.localBounds.height = item.image.height
    end if
    while mouse.button
        yield
    end while
    return item.contains(mouse)
end function

// Draw background
drawbg = function
    gfx.drawImage(file.loadImage("assets/map/default.png"),0,200,960,440)
    board = file.loadImage("assets/components/cardHolder.png")
    gfx.drawImage(board,0,0)
end function

// ===== ENEMY FUNCTIONS =====
// Create mushroom enemy
createmushroom = function 
    mushroom = new Sprite
    mushroom.image = mushroomrunFrames[0]
    pos = floor(rnd * 2)
    if pos == 1 then
        mushroom.x = 0
    else
        mushroom.x = 960
    end if
    mushroom.y = 330
    mushroom.localBounds = new Bounds
    mushroom.localBounds.width = mushroom.image.width
    mushroom.localBounds.height = mushroom.image.height
    display(4).sprites.push mushroom
    enemies.push([mushroom, "run", time])
end function

// Update mushroom enemies
updateMushroom = function 
    removelist = []
    c = 0
    for n in enemies
        if n[1] == "run" then
            n[0].image = mushroomrunFrames[time * animSpeedW % mushroomrunFrames.len]
        else if n[1] == "death" then
                frame = (time-n[2]) * animSpeedW % mushroomdeathFrames.len
                n[0].image = mushroomdeathFrames[frame]
                if floor(frame) >= 12 then
                    n[0].image = null
                    idx = display(4).sprites.indexOf(n[0])
                    display(4).sprites.remove idx
                    removelist.push c
                    globals.enemieskilled += 1
                end if
        end if

        if n[0].x < 480 then
            n[0].scale = [-1,1]
            if n[1] != "death" and n[1] != "hurt" then
                n[0].x = n[0].x + 1*mushroomSpeed
            end if
        else
            if n[1] != "death" and n[1] != "hurt" then
                n[0].x = n[0].x - 1*mushroomSpeed
            end if        
        end if
        c += 1
    end for
    globals.enemiespawnCD = floor(rnd * 10)+2

    removelist.reverse
    for i in removelist
        enemies.remove(i)
    end for
end function

// Create enemies based on map
createEnemies = function
    if globals.map == "default" and globals.enemiesSpawned < enemiesAmountToKill then
        createmushroom
        globals.enemiesSpawned += 1
    end if
end function

// Update enemies based on map
updateEnemies = function
    if globals.map == "default" then
        updateMushroom
    end if
end function

// ===== WIZARD FUNCTIONS =====
// Update wizard frame animation
frameupdate = function
    if globals.state[0] == "idle" then
            wizard.image = idleFrames[time * animSpeedW % idleFrames.len]
    else if globals.state[0] == "attack" then
            globals.state[1] = (time - lastShot) * 20 % attackFrames.len
            wizard.image = attackFrames[globals.state[1]]
            if globals.state[1] >= 12 then
                globals.state[1] = 0
                globals.state[0] = "idle"
            end if
    else if globals.state[0] == "hit" then
            wizard.image = gethitFrames[time * animSpeedW % gethitFrames.len]
    else if globals.state[0] == "death" then
            wizard.image = deathFrames[time * animSpeedW % deathFrames.len]
    end if
    
    if globals.direction == "left" then 
        wizard.scale = [-1, 1]
    else
        wizard.scale = [1, 1]
    end if
end function

// ===== CARD FUNCTIONS =====
// Elements for cards
elements = ["fire", "nature", "water"]

// Create a new card
createCard = function(type) 
    spots = [89, 245, 401];
    images = {0: "assets/cards/FireElement.png",1: "assets/cards/NatureElement.png",2: "assets/cards/WaterElement.png"}
    
    if (not images[type]) then
        return
    end if

    card = new Sprite()
    card.image = file.loadImage(images[type])
    card.x = spots[cards.len]
    card.y = 100
    card.scale = [0.4, 0.4]
    
    card.localBounds = new Bounds()
    card.localBounds.width = card.image.width
    card.localBounds.height = card.image.height
    card.type = elements[type]
    display(4).sprites.push(card)
    return card
end function

// Check for card interaction
checkcardpressed = function 
    isDown = mouse.button
    
    // Only exit if there are no cards
    if cards.len == 0 then
        return
    end if
    
    for i in range(0, cards.len-1)
        n = cards[i]
        if n then
            // Highlight card when hovered
            if n.contains(mouse) then
                // Only highlight with hover effect if not the selected card
                if i != globals.selectedCard then
                    n.tint = "#cacaeb"
                end if
                
                // Track press and release for each card
                if isDown and not globals.wasDown[i] then
                    // Mouse button was just pressed on this card
                    globals.wasDown[i] = true
                else if not isDown and globals.wasDown[i] then
                    // Mouse button was released while still over the card - this is a click!
                    // print "Sprite clicked!"
                    
                    // If clicking the already selected card, deselect it
                    if i == globals.selectedCard then
                        globals.selectedCard = -1
                        n.tint = color.white
                        globals.selectedAbl = "firebom"  // Reset to default ability
                    else
                        // Deselect previous card if any
                        if globals.selectedCard >= 0 and globals.selectedCard < cards.len then
                            cards[globals.selectedCard].tint = color.white
                        end if
                        
                        // Select new card
                        globals.selectedCard = i
                        n.tint = "#888888"  // Darker gray for selected state
                        globals.selectedAbl = n.type
                    end if
                    
                    globals.wasDown[i] = false
                end if
            else
                // Not hovering over card - keep selected card gray, others white
                if i != globals.selectedCard then
                    n.tint = color.white
                end if
                
                // If mouse moved away while button was down, cancel the potential click
                if globals.wasDown[i] and not isDown then
                    globals.wasDown[i] = false
                end if
            end if
        end if
    end for
    
    // Update global mouse state if all buttons are up
    if not isDown then
        for i in range(0, globals.wasDown.len-1)
            globals.wasDown[i] = false
        end for
    end if
end function

// ===== ATTACK FUNCTIONS =====
// Update active abilities
updateAbl = function
    count = 0
    rmlist = []
    for n in attacks 
        if n[2] >= (n[1].len-1) then
            n[0].image = null
            idx = display(4).sprites.indexOf(n[0])
            display(4).sprites.remove idx
            rmlist.push count
        end if
        n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
        n[0].image = n[1][n[2]]
        if n[0].x < 480 and n[0].name == "firesweep" then
            n[0].scale = [-2,2]
        end if
        count += 1
    end for
    rmlist.reverse
    for n in rmlist
        attacks.remove(n)
    end for
end function

// Create new attack based on selected ability
updateAttackList = function
    if globals.selectedAbl == "firebom" then
        sprite = new Sprite
        sprite.image = firebomFrames[0]
        sprite.y = 320
        sprite.x = floor(mouse.x)
        sprite.localBounds = new Bounds
        sprite.localBounds.width = sprite.image.width
        sprite.localBounds.height = sprite.image.height
        sprite.name = "firebom"
        globals.attacks.push [sprite,firebomFrames, 0, time]
        display(4).sprites.push sprite
    else if globals.selectedAbl == "fire" then
        sprite = new Sprite
        sprite.image = fireSweepFrames[0]
        sprite.scale = [2,2]
        sprite.y = 340
        sprite.x = floor(mouse.x)
        sprite.localBounds = new Bounds
        sprite.localBounds.width = sprite.image.width
        sprite.localBounds.height = sprite.image.height
        sprite.name = "firesweep"
        globals.attacks.push [sprite,fireSweepFrames, 0, time]
        display(4).sprites.push sprite 
    end if
end function

// ===== COLLISION FUNCTIONS =====
// Handle mushroom enemy collision
mushroomcollision = function(abl, unit)
    if abl[0].x < 480 then
        if (unit[0].x+8) > (abl[0].x-20) and (unit[0].x-8) < (abl[0].x+20) then
            unit[1] = "death"
            unit[2] = time
        end if
    else
        if (unit[0].x+8) > (abl[0].x-20) and (unit[0].x-8) < (abl[0].x+20) then
            unit[1] = "death"
            unit[2] = time
        end if
    end if
end function

// Check collision between attacks and enemies
checkCollision = function
    for n in attacks
        for i in enemies
            collision = n[0].overlaps(i[0])
            if collision and i[1] != "death" and i[1] != "hurt" then
                if map == "default" then
                    mushroomcollision(n,i)
                end if
            end if
        end for
    end for
end function

// ===== REWARD FUNCTIONS =====
listrewards = []

// Show reward elements after completing a level
showRewards = function
    elements = ["assets/cards/FireElement.png","assets/cards/NatureElement.png","assets/cards/WaterElement.png"]
    for x in range(0,2)
        elementsprite = new Sprite
        elementsprite.image = file.loadImage(elements[x])
        elementsprite.x = 240*(x+1)
        elementsprite.y = 320
        elementsprite.scale = [0.75,0.75]
        elementsprite.localBounds = new Bounds
		elementsprite.localBounds.width = elementsprite.image.width
		elementsprite.localBounds.height = elementsprite.image.height

        display(4).sprites.push elementsprite
        listrewards.push elementsprite
        elementsprite.ID = x
    end for
end function

// ===== GAME INITIALIZATION AND MAIN LOOP =====
drawbg()
globals.attacks = []
globals.LayerS = null
clickedElement = -1
picked = false

// Main game loop
while true
    if (time - lastenemie) > globals.enemiespawnCD and globals.enemieskilled < enemiesAmountToKill then
        createEnemies
        lastenemie = time
    end if

    // Update wizard character
    frameupdate
    
    // Update enemies
    updateEnemies
    
    // Update attack animations
    updateAbl
    
    // Check for collisions
    checkCollision

    // Handle card selection
    checkcardpressed
    
    // Handle player attacks
	if mouse.button then
        if mouse.y > 230 and (time - lastShot) > attackCD then
            globals.lastShot = time
            globals.state[0] = "attack"
            updateAttackList
            if mouse.x < 480 then
                globals.direction = "left"
            else 
                globals.direction = "right"
            end if 
        end if
	end if

    // Handle level completion and rewards
    if globals.enemieskilled >= enemiesAmountToKill then
        showRewards
        while not picked
            yield
            if mouse.button then
                for x in listrewards
                    if x.isClicked(x) then
                        clickedElement = x.ID
                        picked = true
                        card = createCard(x.ID)
                        cards.push card
                        break
                    end if
                end for
            end if
        end while
        
        // Clean up rewards and prepare for next level
        for x in listrewards 
            idx = display(4).sprites.indexOf(x)
            display(4).sprites.remove idx 
        end for
        listrewards = []
        globals.enemieskilled = 0
        globals.enemiesSpawned = 0
        picked = false
    end if
    yield
end while