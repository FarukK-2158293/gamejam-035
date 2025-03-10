clear 
import "listUtil"
import "events"
import "mathUtil"

// is there a bgm playing?
if globals.hasIndex("bgm") and bgm != null then    
	bgm.loop = true
	bgm.adjust 0.15
else
	bgm = file.loadSound("assets/sounds/a-big-world-238961.wav")
	bgm.loop = true
	bgm.play 0.15
end if

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
globals.level = 1
globals.wasDown = [false, false, false]
globals.selectedCard = -1  // Track which card is currently selected
globals.hp = 10

// ===== CARD FUSION SYSTEM =====
// Elements for cards
elements = ["fire", "nature", "water", "light", "dark", "magma", "ultimatefire", "ultimatenature", "ultimatewater"]

// Fusion rules library
globals.fusionRules = {"nature+water": "light","nature+nature": "ultimatenature", "fire+fire": "ultimatefire","water+water": "ultimatewater","fire+nature": "magma", "fire+water": "dark"}

// Element ID mappings
globals.elementIds = {"fire": 0,"nature": 1,"water": 2,"light": 3, "dark": 4,"magma": 5,"ultimatefire": 6,"ultimatenature": 7,"ultimatewater": 8}

// Reverse mapping from ID to element name
globals.idToElement = {0: "fire", 1: "nature", 2: "water", 3: "light", 4: "dark", 5: "magma", 6: "ultimatefire", 7: "ultimatenature", 8: "ultimatewater"};

// Track card inventory for fusion
globals.inventory = {"fire": 0, "nature": 0, "water": 0}

// Update inventory when a card is acquired
updateInventory = function(elementType)
    // For base elements, increment count
    if elementType == "fire" or elementType == "nature" or elementType == "water" then
        globals.inventory[elementType] += 1
    end if
end function

// Check possible fusions based on current inventory
getPossibleFusions = function()
    possibleFusions = []
    
    // Check each fusion rule
    for rule in globals.fusionRules
        ingredients = rule.key.split("+")
        
        // Handle same-element fusions (e.g., fire+fire)
        if ingredients[0] == ingredients[1] then
            // Need at least 2 of the element
            if globals.inventory.hasIndex(ingredients[0]) and globals.inventory[ingredients[0]] >= 2 then
                possibleFusions.push(globals.fusionRules[rule.key])
            end if
        else
            // Check if we have both required elements
            hasAllIngredients = true
            for ingredient in ingredients
                if not globals.inventory.hasIndex(ingredient) or globals.inventory[ingredient] < 1 then
                    hasAllIngredients = false
                    break
                end if
            end for
            
            if hasAllIngredients then
                possibleFusions.push(globals.fusionRules[rule.key])
            end if
        end if
    end for
    
    return possibleFusions
end function

// Get ingredients needed for a fusion
getIngredientsForFusion = function(fusionResult)
    for rule in globals.fusionRules
        if globals.fusionRules[rule.key] == fusionResult then
            return rule.key.split("+")
        end if
    end for
    return []
end function

// Perform fusion and update inventory
performFusion = function(fusionResult)
    // Find which fusion rule produced this result
    for rule in globals.fusionRules
        if globals.fusionRules[rule.key] == fusionResult then
            ingredients = rule.key.split("+")
            
            // Consume ingredients
            if ingredients[0] == ingredients[1] then
                // Same element fusion (e.g., fire+fire)
                globals.inventory[ingredients[0]] -= 2
            else
                // Different elements fusion
                globals.inventory[ingredients[0]] -= 1
                if globals.inventory.hasIndex(ingredients[1]) then  // Handle 'air' element case
                    globals.inventory[ingredients[1]] -= 1
                end if
            end if
            
            break
        end if
    end for
end function

// Find cards to remove for fusion
findCardsForFusion = function(fusionResult)
    // Get needed ingredients
    ingredients = getIngredientsForFusion(fusionResult)
    if ingredients.len == 0 then return []
    
    // Track which cards to remove
    cardsToRemove = []
    neededIngredients = {}
    
    // Initialize needed ingredients count
    for ingredient in ingredients
        if not neededIngredients.hasIndex(ingredient) then
            neededIngredients[ingredient] = 1
        else
            neededIngredients[ingredient] += 1
        end if
    end for
    
    // Find matching cards
    for i in range(0, cards.len-1)
        card = cards[i]
        if card and neededIngredients.hasIndex(card.type) and neededIngredients[card.type] > 0 then
            cardsToRemove.push(i)
            neededIngredients[card.type] -= 1
        end if
    end for
    
    return cardsToRemove
end function

// Try to perform a fusion with current cards
tryFusion = function()
    // Get list of possible fusions
    possibleFusions = getPossibleFusions()
    if possibleFusions.len == 0 then
        return false  // No fusions possible
    end if
    
    // Choose a random fusion from possible ones
    fusionResult = possibleFusions[floor(rnd * possibleFusions.len)]
    
    // Find cards to remove for this fusion
    cardIndices = findCardsForFusion(fusionResult)
    
    // Remove cards used in fusion (reverse order to maintain indices)
    cardIndices.sort
    cardIndices.reverse
    for idx in cardIndices
        // Remove the card sprite from display
        if idx >= 0 and idx < cards.len then
            cardSprite = cards[idx]
            display(4).sprites.remove(display(4).sprites.indexOf(cardSprite))
            cards.remove(idx)
        end if
    end for
    
    // Update inventory
    performFusion(fusionResult)
    
    // Create the fusion card
    fusionId = globals.elementIds[fusionResult]
    card = createCard(fusionId)
    cards.push(card)
    
    return true
end function

// ===== ABILITY COOLDOWN SYSTEM =====
// Cooldown times for each ability in seconds
globals.cooldowns = { "firebom": 2, "fire": 4, "nature": 5, "water": 6, "ultimatefire": 4, "ultimatenature": 5, "ultimatewater": 6, "magma": 4, "dark": 5, "light": 6 }; 
globals.lastUsed = { "firebom": 0, "fire": 0, "nature": 0, "water": 0, "ultimatefire": 0, "ultimatenature": 0, "ultimatewater": 0, "magma": 0, "dark": 0, "light": 0 };

// Function to check if an ability is on cooldown
isOnCooldown = function(abilityType)
    currentAbility = abilityType
    // Using a more concise approach to check cooldowns
    if globals.cooldowns.hasIndex(currentAbility) and globals.lastUsed.hasIndex(currentAbility) then
        return (time - globals.lastUsed[currentAbility]) < globals.cooldowns[currentAbility]
    end if
    return false  // Default return if ability type is unknown
end function

// Function to mark an ability as used and start its cooldown
useAbility = function(abilityType)
    if globals.lastUsed.hasIndex(abilityType) then
        globals.lastUsed[abilityType] = time
    end if
end function

// Function to get remaining cooldown time
getRemainingCooldown = function(abilityType)
    if globals.cooldowns.hasIndex(abilityType) and globals.lastUsed.hasIndex(abilityType) then
        return mathUtil.max(0, globals.cooldowns[abilityType] - (time - globals.lastUsed[abilityType]))
    end if
    return 0  // Default return if ability type is unknown
end function

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

// Natures aura attack assets
NaturesAurasheet = file.loadImage("assets/attackeffect/06.png")
NaturesAuraFrames = []
for i in range(0, 14)
    NaturesAuraFrames.push NaturesAurasheet.getImage(i * 64, 320, 64, 64)
end for

// Water wave attack assets
waterWavesheet = file.loadImage("assets/attackeffect/126.png")
waterWaveFrames = []
for i in range(0, 10)
    waterWaveFrames.push waterWavesheet.getImage(i * 64, 384, 64, 64)
end for

// UltimateFire
UltimateFiresheet = file.loadImage("assets/attackeffect/427.png")
UltimateFireFrames = []
for i in range(0, 7)
    UltimateFireFrames.push UltimateFiresheet.getImage(i * 64, 512, 64, 64)
end for

// UltimateNature
UltimateNaturesheet = file.loadImage("assets/attackeffect/174.png")
UltimateNatureFrames = []
for i in range(0, 9)
    UltimateNatureFrames.push UltimateNaturesheet.getImage(i * 64, 320, 64, 64)
end for

// magma
magmasheet = file.loadImage("assets/attackeffect/529.png")
magmaFrames = []
for i in range(0, 12)
    magmaFrames.push magmasheet.getImage(i * 64, 512, 64, 64)
end for

// dark
darksheet = file.loadImage("assets/attackeffect/612.png")
darkFrames = []
for i in range(0, 14)
    darkFrames.push darksheet.getImage(i * 64, 0, 64, 64)
end for

// light
lightsheet = file.loadImage("assets/attackeffect/449.png")
lightFrames = []
for i in range(0, 8)
    lightFrames.push lightsheet.getImage(i * 64, 192, 64, 64)
end for

// UltimateWater
UltimateWatersheet = file.loadImage("assets/attackeffect/126.png")
UltimateWaterFrames = []
for i in range(0, 10)
    UltimateWaterFrames.push UltimateWatersheet.getImage(i * 64, 384, 64, 64)
end for

// Wizard animation frames
wizardSheetIdle = file.loadImage("assets/wizard/Idle.png")
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
wizard.image = idleFrames[0]
wizard.localBounds = new Bounds
wizard.localBounds.width = wizard.image.width
wizard.localBounds.height = wizard.image.height
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
    enemies.push([mushroom, "run", time, 2])
end function

printLevel = function
    text.clear
    text.color = color.white
    text.row = 25
    print "level: " + str(globals.level)
end function

printEnemiesAlive = function
    text.row = 24
    print "enemies alive: " + str(globals.enemiesAmountToKill-globals.enemieskilled)
end function

printHP = function 
    text.row = 23
    print "HP: " + str(globals.hp)
end function

globals.elementNicknames = { "fire": "Fire Wave", "nature": "Nature's Wrath", "water": "Tidal Surge", "light": "Holy Radiance", "dark": "Shadow Veil", "magma": "Molten Eruption", "ultimatefire": "Inferno Burst", "ultimatenature": "Verdant Cataclysm", "ultimatewater": "Ocean's Wrath" }
// Display cooldown information
printCooldowns = function
    count = 0
    text.row = 6
    text.column = 36

    value = floor(globals.cooldowns["firebom"] - (time - globals.lastUsed["firebom"]))
    if value <= 0 then
        text.color = color.green
        print "Passive" + " : READY"
    else
        text.color = color.red
        print "Passive" + " : " + str(value)
    end if

    for card in cards
        text.row = 5-count
        text.column = 36
        value = floor(globals.cooldowns[str(card.type)] - (time - globals.lastUsed[str(card.type)]))
        if value <= 0 then
            text.color = color.green
            print globals.elementNicknames[card.type] + " : READY"
        else
            text.color = color.red
            print globals.elementNicknames[card.type] + " : " + str(value)
        end if
        count += 1
    end for    
    // Reset text color to default
    text.color = color.white
end function

// Update mushroom enemies
// Update mushroom enemies to handle light slowing effect
updateMushroom = function 
    removelist = []
    c = 0
    for n in enemies
        // Calculate movement speed based on effects
        currentSpeed = mushroomSpeed
        
        // Check if enemy is affected by light (slowing)
        hasLightEffect = false
        for i in range(0, n.len-1)
            if n[i] == "light" then
                hasLightEffect = true
                break
            end if
        end for
        
        if hasLightEffect then
            currentSpeed = mushroomSpeed * 0.5  // 50% slower when affected by light
        end if
        
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
        else if n[1] == "hurt" then
            frame = (time-n[2]) * animSpeedW % mushroomgethurtFrames.len
            n[0].image = mushroomgethurtFrames[frame]
            if floor(frame) >= 4 then
                n[1] = "run"
                n[2] = time
            end if
        else if n[1] == "attack" then
            frame = (time-n[2]) * animSpeedW % mushroomattackFrames.len
            n[0].image = mushroomattackFrames[frame]
            if floor(frame) >= 9 then
                n[1] = "run"
                n[2] = time
            end if
        end if

        if n[0].x >= 481 then
            n[0].scale = [1,1]
            if n[1] != "death" and n[1] != "hurt" then
                n[0].x = n[0].x - 1 * currentSpeed  // Use adjusted speed
            end if
        else if n[0].x <= 479 then
            n[0].scale = [-1,1]
            if n[1] != "death" and n[1] != "hurt" then
                n[0].x = n[0].x + 1 * currentSpeed  // Use adjusted speed
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

makeretryButton = function
    button = new events.EventSprite
    button.image = file.loadImage("assets/components/restart.png")
    button.x = 480; button.y = 320
    button.onDrag = function
        if self.contains(mouse) then
            self.tint = color.silver
        else
            self.tint = color.white
        end if
    end function
    button.onDragEnd = function
        if self.tint == color.silver then
            self.tint = color.white
            events.eventLoop.stop
            reset; load "main"; run
        end if	
    end function
    button.start
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
            globals.state[1] = (time - globals.lastHit) * 8 % gethitFrames.len
            wizard.image = gethitFrames[time * animSpeedW % gethitFrames.len]
            if globals.state[1] >= 2 then
                globals.state[1] = 0
                globals.state[0] = "idle"
            end if
    else if globals.state[0] == "death" then        
            globals.state[1] = (time - globals.lastHit) * 20 % deathFrames.len
            wizard.image = deathFrames[time * animSpeedW % deathFrames.len]
            if globals.state[1] >= 17 then
                globals.state[1] = 0
                makeretryButton
                events.eventLoop.run
            end if
    end if
    
    if globals.direction == "left" then 
        wizard.scale = [-1, 1]
    else
        wizard.scale = [1, 1]
    end if
end function

// ===== CARD FUNCTIONS =====
// Elements for cards
elements = ["fire", "nature", "water", "light", "dark", "magma", "ultimatefire", "ultimatenature", "ultimatewater"]

// Create a new card
createCard = function(type) 
    // Define spot positions for cards
    spots = [89, 245, 401]
    images = {0: "assets/cards/FireElement.png",1: "assets/cards/NatureElement.png", 2: "assets/cards/WaterElement.png", 3: "assets/cards/LightElement.png", 4: "assets/cards/DarkElement.png", 5: "assets/cards/MagmaElement.png", 6: "assets/cards/UltimateFireElement.png", 7: "assets/cards/UltimateNatureElement.png",8: "assets/cards/UltimateWaterElement.png"}
    
    if (not images.hasIndex(type)) then
        return
    end if

    // Create a new card sprite
    card = new Sprite()
    card.image = file.loadImage(images[type])
    card.x = spots[cards.len % spots.len]  // Cycle through spots if more than 3 cards
    card.y = 100
    card.scale = [0.4, 0.4]
    
    card.localBounds = new Bounds()
    card.localBounds.width = card.image.width
    card.localBounds.height = card.image.height
    card.type = elements[type]
    display(4).sprites.push(card)
    
    // Update inventory for fusion
    if card.type == "fire" or card.type == "water" or card.type == "nature" then
        updateInventory(card.type)
    end if
    
    return card
end function

// Reorganize cards to fill empty slots
reorganizeCards = function()
    spots = [89, 245, 401]
    for i in range(0, cards.len-1)
        if cards[i] then
            cards[i].x = spots[i]
        end if
    end for
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
// In the updateAbl function, modify to handle new gimmicks
globals.childAttacks = []
updateAbl = function
    count = 0
    rmlist = []
    for n in attacks 
        // Handle animation cycling for Nature's Aura
        if n[0].name == "naturesaura" then
            // Add cycle counter if it doesn't exist yet
            if n.len <= 4 then
                n.push 0  // n[4] will track completed cycles (0, 1, 2 for 3 total)
            end if
            
            // Update the frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Check if we've completed a cycle
            if n[2] >= (n[1].len-1) then
                n[4] = n[4] + 1
                n[3] = time  // Reset animation timer
                
                // Remove after 3 cycles
                if n[4] >= 3 then
                    n[0].image = null
                    idx = display(4).sprites.indexOf(n[0])
                    display(4).sprites.remove idx
                    rmlist.push count
                end if
            end if
        // Handle movement for Water Wave
        else if n[0].name == "waterwave" then
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Move the sprite based on stored direction
            if n[0].x < 480 then
                n[0].x = n[0].x - 3  // Move left
                // Keep normal scale for left movement
                n[0].scale = [2,2]
            else
                n[0].x = n[0].x + 3  // Move right
                // Keep normal scale for right movement
                n[0].scale = [-2,2]
            end if
            
            // Remove if off screen
            if n[0].x < -50 or n[0].x > 1010 then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add Dark ability gimmick - large size and greater hit range
        else if n[0].name == "dark" then
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Make Dark ability larger for greater hit area
            n[0].scale = [3, 3]  // Larger scale than standard (2,2)
            
            // Remove when animation completes
            if n[2] >= (n[1].len-1) then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add Light ability gimmick - slow down nearby enemies
        else if n[0].name == "light" then
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Apply slowing effect to nearby enemies
            for enemy in enemies
                if enemy[1] != "death" and enemy[1] != "hurt" then
                    // Check if enemy is in range (100 pixels)
                    dx = abs(enemy[0].x - n[0].x)
                    if dx < 100 then
                        // Apply "light" tag to mark enemies for slowing
                        enemy.push "light"
                    end if
                end if
            end for
            
            // Remove when animation completes
            if n[2] >= (n[1].len-1) then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add Magma ability gimmick - leaves damaging pool on ground
        else if n[0].name == "magma" then
            // Add pool duration if it doesn't exist yet
            if n.len <= 4 then
                n.push 0  // n[4] will track how long the pool remains
            end if
            
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // When animation completes once, create persistent pool effect
            if n[2] >= (n[1].len-1) and n[4] < 5 then
                n[3] = time  // Reset animation timer
                n[4] = n[4] + 1  // Increment pool duration counter
                
                // If we're still in pool phase, damage enemies who walk through
                for enemy in enemies
                    if enemy[1] != "death" and enemy[1] != "hurt" then
                        // Check if enemy is in range of magma pool
                        dx = abs(enemy[0].x - n[0].x)
                        if dx < 40 then
                            enemy[1] = "death"
                            enemy[2] = time
                        end if
                    end if
                end for
            end if
            
            // Remove after duration expires
            if n[4] >= 5 then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add UltimateFire ability gimmick - splits into multiple projectiles
        else if n[0].name == "ultimatefire" then
            // Check if this is the first frame
            if n[2] == 0 and not n.hasIndex(4) then
                n.push true  // Mark that we've created child projectiles
                
                // Create two additional fire projectiles at angles
                for i in range(0, 1)
                    sprite = new Sprite
                    sprite.image = UltimateFireFrames[0]
                    sprite.scale = [1.5, 1.5]
                    sprite.y = 340 - (i * 20)  // Stagger height
                    sprite.x = n[0].x + (i * 25 - 7)  // Offset positions
                    sprite.localBounds = new Bounds
                    sprite.localBounds.width = sprite.image.width
                    sprite.localBounds.height = sprite.image.height
                    sprite.name = "ultimatefire"
                    globals.childAttacks.push [sprite, UltimateFireFrames, 0, time]
                    display(4).sprites.push sprite
                end for
            end if
            
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Move horizontally for better spread effect
            if n[0].x < 480 then
                n[0].x = n[0].x - 1  // Slow movement left
            else
                n[0].x = n[0].x + 1  // Slow movement right
            end if

            for i in globals.childAttacks
                i[0].image = i[1][n[2]]     
                // Move horizontally for better spread effect
                if i[0].x < 480 then
                    i[0].x = i[0].x - 0.5  // Slow movement left
                else
                    i[0].x = i[0].x + 0.5  // Slow movement right
                end if
            end for
            
            // Remove when animation completes
            if n[2] >= (n[1].len-1) then
                for i in globals.childAttacks
                    i[0].image = null
                    idx = display(4).sprites.indexOf(i[0])
                    display(4).sprites.remove idx
                end for
                globals.childAttacks = []
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add UltimateNature ability gimmick - creates growing AoE damage zone
        else if n[0].name == "ultimatenature" then
            // Track growth stage if not already set
            if n.len <= 4 then
                n.push 1  // n[4] is growth stage (starts at 1)
            end if
            
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // When animation completes, grow larger for next cycle
            if n[2] >= (n[1].len-1) then
                n[4] = n[4] + 1  // Increment growth stage
                n[3] = time  // Reset animation timer
                
                // Scale up by 0.5 each cycle, up to 3 cycles
                if n[4] <= 3 then
                    n[0].scale = [1.5 + (n[4] * 0.5), 1.5 + (n[4] * 0.5)]
                    
                    // Damage enemies in growing radius
                    radius = 30 * n[4]  // Radius grows with each cycle
                    for enemy in enemies
                        if enemy[1] != "death" and enemy[1] != "hurt" then
                            // Check if enemy is in range
                            dx = abs(enemy[0].x - n[0].x)
                            if dx < radius then
                                enemy[1] = "death"
                                enemy[2] = time
                            end if
                        end if
                    end for
                else
                    // Remove after 3 growth cycles
                    n[0].image = null
                    idx = display(4).sprites.indexOf(n[0])
                    display(4).sprites.remove idx
                    rmlist.push count
                end if
            end if
            
        // Add UltimateWater ability gimmick - creates giant wave that pushes enemies
        else if n[0].name == "ultimatewater" then
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Make the wave larger than regular water wave
            if n[0].x < 480 then
                n[0].scale = [3, 3]
            else
                n[0].scale = [-3, 3]            
            end if
            
            // Move faster than regular water wave
            if n[0].x < 480 then
                n[0].x = n[0].x - 5  // Fast movement left
                // Push enemies in path
                for enemy in enemies
                    if enemy[1] != "death" and enemy[1] != "hurt" then
                        if enemy[0].x > n[0].x and abs(enemy[0].x - n[0].x) < 100 then
                            enemy[0].x = enemy[0].x - 3  // Push enemy along
                        end if
                    end if
                end for
            else
                n[0].x = n[0].x + 5  // Fast movement right
                // Push enemies in path
                for enemy in enemies
                    if enemy[1] != "death" and enemy[1] != "hurt" then
                        if enemy[0].x < n[0].x and abs(enemy[0].x - n[0].x) < 100 then
                            enemy[0].x = enemy[0].x + 3  // Push enemy along
                        end if
                    end if
                end for
            end if
            
            // Remove if off screen
            if n[0].x < -100 or n[0].x > 1060 then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add FireBomb ability gimmick - explosion radius damage
        else if n[0].name == "firebom" then
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Apply explosion damage at animation midpoint
            if floor(n[2]) == 7 then  // Midpoint of explosion animation
                // Apply area damage
                for enemy in enemies
                    if enemy[1] != "death" and enemy[1] != "hurt" then
                        // Check if enemy is in explosion radius (80 pixels)
                        dx = abs(enemy[0].x - n[0].x)
                        if dx < 80 then
                            enemy[1] = "death"
                            enemy[2] = time
                        end if
                    end if
                end for
            end if
            
            // Remove when animation completes
            if n[2] >= (n[1].len-1) then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Add Fire ability gimmick - travels in direction and burns enemies
        else if n[0].name == "firesweep" then
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Move in direction based on wizard's facing
            if n[0].x < 480 then  // If facing left (scale is negative)
                n[0].x = n[0].x - 2  // Move left
                n[0].scale = [-2,2]
            else
                n[0].x = n[0].x + 2  // Move right
            end if
            
            // Remove when animation completes
            if n[2] >= (n[1].len-1) then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
            
        // Default case for any other abilities
        else
            // Update animation frame
            n[2] = (time - n[3]) * animSpeedFirebom % n[1].len
            n[0].image = n[1][n[2]]
            
            // Remove when animation completes
            if n[2] >= (n[1].len-1) then
                n[0].image = null
                idx = display(4).sprites.indexOf(n[0])
                display(4).sprites.remove idx
                rmlist.push count
            end if
        end if
        
        count += 1

    end for
    
    rmlist.reverse
    for n in rmlist
        attacks.remove(n)
    end for
end function

// Create new attack based on selected ability
// Create new attack based on selected ability
updateAttackList = function
    if globals.selectedAbl == "firebom" then
        if not isOnCooldown("firebom") then
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
            useAbility("firebom")
            return true
        end if
    else if globals.selectedAbl == "fire" then
        if not isOnCooldown("fire") then
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
            useAbility("fire") 
            return true
        end if
    else if globals.selectedAbl == "nature" then
        if not isOnCooldown("nature") then
            sprite = new Sprite
            sprite.image = NaturesAuraFrames[0]
            sprite.scale = [2,2]
            sprite.y = 320
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "naturesaura"
            globals.attacks.push [sprite,NaturesAuraFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("nature")
            return true
        end if
    else if globals.selectedAbl == "water" then
        if not isOnCooldown("water") then
            sprite = new Sprite
            sprite.image = waterWaveFrames[0]
            sprite.scale = [2,2]
            sprite.y = 330
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "waterwave"
            globals.attacks.push [sprite,waterWaveFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("water")
            return true
        end if
    // Add fusion abilities here
    else if globals.selectedAbl == "ultimatefire" then
        if not isOnCooldown("ultimatefire") then // Reuse fire cooldown for now
            sprite = new Sprite
            sprite.image = UltimateFireFrames[0]
            sprite.scale = [2,2]
            sprite.y = 340
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "ultimatefire"
            globals.attacks.push [sprite,UltimateFireFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("ultimatefire") // Reuse fire cooldown
            return true
        end if
    else if globals.selectedAbl == "ultimatenature" then
        if not isOnCooldown("ultimatenature") then // Reuse nature cooldown
            sprite = new Sprite
            sprite.image = UltimateNatureFrames[0]
            sprite.scale = [2,2]
            sprite.y = 320
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "ultimatenature"
            globals.attacks.push [sprite,UltimateNatureFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("ultimatenature") // Reuse nature cooldown
            return true
        end if
    else if globals.selectedAbl == "ultimatewater" then
        if not isOnCooldown("ultimatewater") then // Reuse water cooldown
            sprite = new Sprite
            sprite.image = UltimateWaterFrames[0]
            sprite.scale = [2,2]
            sprite.y = 350
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "ultimatewater"
            globals.attacks.push [sprite,UltimateWaterFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("ultimatewater") // Reuse water cooldown
            return true
        end if
    else if globals.selectedAbl == "magma" then
        if not isOnCooldown("magma") then // Use fire cooldown for magma
            sprite = new Sprite
            sprite.image = magmaFrames[0]
            sprite.scale = [2,2]
            sprite.y = 340
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "magma"
            globals.attacks.push [sprite,magmaFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("magma")
            return true
        end if
    else if globals.selectedAbl == "dark" then
        if not isOnCooldown("dark") then // Use nature cooldown for dark
            sprite = new Sprite
            sprite.image = darkFrames[0]
            sprite.scale = [2,2]
            sprite.y = 320
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "dark"
            globals.attacks.push [sprite,darkFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("dark")
            return true
        end if
    else if globals.selectedAbl == "light" then
        if not isOnCooldown("light") then // Use water cooldown for light
            sprite = new Sprite
            sprite.image = lightFrames[0]
            sprite.scale = [2,2]
            sprite.y = 320
            sprite.x = floor(mouse.x)
            sprite.localBounds = new Bounds
            sprite.localBounds.width = sprite.image.width
            sprite.localBounds.height = sprite.image.height
            sprite.name = "light"
            globals.attacks.push [sprite,lightFrames, 0, time]
            display(4).sprites.push sprite
            useAbility("light")
            return true
        end if
    end if
    return false
end function

// ===== COLLISION FUNCTIONS =====
// Handle mushroom enemy collision
mushroomcollision = function(abl, unit)
    if abl[0].x < 480 then
        if (unit[0].x+8) > (abl[0].x-20) and (unit[0].x-8) < (abl[0].x+20) then
            unit[3] -= 1
            if unit[3] > 0 then
                unit[1] = "hurt"
                unit[2] = time
            else
                unit[1] = "death"
                unit[2] = time
            end if

        end if
    else
        if (unit[0].x+8) > (abl[0].x-20) and (unit[0].x-8) < (abl[0].x+20) then
            unit[3] -= 1
            if unit[3] > 0 then
                unit[1] = "hurt"
                unit[2] = time
            else
                unit[1] = "death"
                unit[2] = time
            end if
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
    listrewards = []
    rewardList = []
    
    // Check current inventory and cards for possible fusions
    possibleFusions = getPossibleFusions()
    
    // If there's no space for new cards (3 cards already) and no possible fusions
    if cards.len >= 3 and possibleFusions.len == 0 then
        // No rewards to show in this case - player has no room and can't fuse
        return []
    end if
    
    // If player has 3 cards already and fusion is possible,
    // ONLY show fusion rewards (no base elements)
    if cards.len >= 3 and possibleFusions.len > 0 then
        // Add only fusion options (up to 3)
        for i in range(0, mathUtil.min(possibleFusions.len, 3) - 1)
            fusionResult = possibleFusions[i]
            fusionId = globals.elementIds[fusionResult]
            rewardList.push(fusionId)
        end for
    else
        // Player has space or no fusions - show mix of base elements and fusions
        
        // Add base elements to possible rewards
        for x in range(0, 2)
            rewardList.push(x)  // IDs 0, 1, 2 for Fire, Nature, Water
        end for
        
        // If fusions are available, replace some base elements with fusions
        if possibleFusions.len > 0 then
            // Replace base elements with fusions (up to all 3 if available)
            for i in range(0, mathUtil.min(possibleFusions.len, 3) - 1)
                fusionResult = possibleFusions[i]
                fusionId = globals.elementIds[fusionResult]
                
                // Replace a base element with fusion
                if i < rewardList.len then
                    rewardList[i] = fusionId
                end if
            end for
        end if
    end if
    
    // Create sprites for rewards
    for i in range(0, rewardList.len-1)
        elementId = rewardList[i]
        
        elementsprite = new Sprite
        if elementId <= 2 then
            // Base element
            elementsprite.image = file.loadImage(["assets/cards/FireElement.png", "assets/cards/NatureElement.png", "assets/cards/WaterElement.png"][elementId])
        else
            // Fusion element - use appropriate image path
            elementImages = {3: "assets/cards/LightFusion.png", 4: "assets/cards/DarkFusion.png", 5: "assets/cards/MagmaFusion.png", 6: "assets/cards/UltimateFireFusion.png", 7: "assets/cards/UltimateNatureFusion.png", 8: "assets/cards/UltimateWaterFusion.png"}
            elementsprite.image = file.loadImage(elementImages[elementId])
        end if
        
        // Position rewards evenly based on how many there are
        numRewards = rewardList.len
        spacing = 960 / (numRewards + 1)
        elementsprite.x = spacing * (i + 1)
        elementsprite.y = 320
        elementsprite.scale = [0.75, 0.75]
        elementsprite.localBounds = new Bounds
        elementsprite.localBounds.width = elementsprite.image.width
        elementsprite.localBounds.height = elementsprite.image.height
        
        display(4).sprites.push elementsprite
        listrewards.push elementsprite
        elementsprite.ID = elementId
        
        // Store fusion information if this is a fusion reward
        if elementId > 2 then
            // Store the fusion result name to know which cards to remove later
            elementsprite.fusionResult = globals.idToElement[elementId]
        end if
    end for
    
    return listrewards
end function

checkLeftM = function(x)
    if x > 450 then
        return true 
    end if
    return false
end function

checkRightM= function(x)
    if x < 510 then
        return true 
    end if
    return false
end function

owncollisioncalc = function(enemie)
    if globals.map == "default" then
        if enemie.x < 480 then
            return checkLeftM(enemie.x)
        else
            return checkRightM(enemie.x)
        end if
    end if
end function

globals.lastHit = time
checkwizardDMG = function 
    if not ((time-globals.lastHit) > dmgCD) then
        return
    end if
    for x in enemies 
        collision = wizard.overlaps(x[0])
        if collision and owncollisioncalc(x[0]) then 
            globals.lastHit = time
            globals.hp -= 1
            globals.lastHit = time
            if x[1] != "death" and x[1] != "hurt" then
                x[1] = "attack"
                x[2] = time
            end if
            if globals.hp < 1 then
                globals.state[0] = "death"
            else 
                globals.state[0] = "hit"
            end if
        end if
    end for
end function

// ===== GAME INITIALIZATION AND MAIN LOOP =====
drawbg()
globals.attacks = []
globals.LayerS = null
clickedElement = -1
picked = false
dmgCD = 2
globals.lastHit = time

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
    
    // Check for collisions abl vs enemie
    checkCollision

    // Handle card selection
    checkcardpressed
    
    // Display game information
    printLevel
    printEnemiesAlive
    printHP
    printCooldowns

    if not (globals.hp < 1) then
        checkwizardDMG
    end if

    // Handle player attacks
	if mouse.button and globals.state[0] != "death" then
        if mouse.y > 230 and (time - lastShot) > attackCD then
            // Only trigger the attack animation if we can actually use the ability
            if updateAttackList() then
                globals.lastShot = time
                globals.state[0] = "attack"
                
                if mouse.x < 480 then
                    globals.direction = "left"
                else 
                    globals.direction = "right"
                end if
            end if
        end if
	end if

    // ===== REWARD FUNCTIONS =====
    // Handle level completion and rewards in the main game loop
    if globals.enemieskilled >= enemiesAmountToKill then
        listrewards = showRewards()
        
        // Only wait for player input if we have rewards to show
        if listrewards.len > 0 then
            while not picked
                yield
                if mouse.button then
                    for x in listrewards
                        if x.isClicked(x) then
                            clickedElement = x.ID
                            picked = true
                            
                            // Check if this is a fusion card (ID > 2)
                            if x.ID > 2 and x.hasIndex("fusionResult") then
                                // Find and remove the cards used for this fusion
                                cardsToRemove = findCardsForFusion(x.fusionResult)
                                
                                // Remove the cards in reverse order to maintain indices
                                cardsToRemove.sort
                                cardsToRemove.reverse
                                for idx in cardsToRemove
                                    if idx >= 0 and idx < cards.len then
                                        cardSprite = cards[idx]
                                        display(4).sprites.remove(display(4).sprites.indexOf(cardSprite))
                                        cards.remove(idx)
                                    end if
                                end for
                                
                                // Update inventory after fusion
                                performFusion(x.fusionResult)
                                
                                // Add the new fusion card
                                card = createCard(x.ID)
                                cards.push(card)
                                reorganizeCards()
                            else
                                // This is a base element card
                                // Only add if we have space
                                if cards.len < 3 then
                                    card = createCard(x.ID)
                                    cards.push(card)
                                end if
                            end if
                            break
                        end if
                    end for
                end if
            end while
            
            // Clean up rewards
            for x in listrewards 
                idx = display(4).sprites.indexOf(x)
                display(4).sprites.remove idx 
            end for
        end if
        
        // Reset for next level
        listrewards = []
        globals.enemieskilled = 0
        globals.enemiesSpawned = 0
        globals.level += 1
        globals.enemiespawnCD -= globals.enemiespawnCD*(globals.level/3)
        enemiesAmountToKill = 2*(globals.level+1)
        picked = false
    end if
    yield
end while