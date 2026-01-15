import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

-- 1. IMAGE LOADING & PRE-TRANSFORMING
-- We load PNGs and create flipped versions once to keep the kitchen running fast
local function loadAndScale(path)
    local img = gfx.image.new(path)
    if img then
        -- Scale to 32x32 (assumes original is 64x64)
        return img:scaled(0.5)
    else
        print("Warning: Missing " .. path .. ".png")
        return gfx.image.new(32, 32, gfx.kColorClear)
    end
end

local capybaraUp = loadAndScale("images/capybara")
local capybaraDown = capybaraUp:flipped(gfx.kImageFlippedY)
local capybaraHurt = loadAndScale("images/damaged_capybara")
local rockImage = loadAndScale("images/rock")
local birdImage = loadAndScale("images/birds")

-- 2. SPRITE INITIALIZATION
-- Player
local playerSprite = gfx.sprite.new(capybaraUp)
playerSprite:setCollideRect(0, 0, 32, 32)
playerSprite:moveTo(40, 120)
playerSprite:add()

-- Rock Obstacle
local obstacleSprite = gfx.sprite.new(rockImage)
obstacleSprite:setCollideRect(0, 0, 32, 32)
obstacleSprite:moveTo(450, 240)
obstacleSprite:add()

-- Active Fantail (Bonus)
local birdSprite = gfx.sprite.new(birdImage)
birdSprite:setCollideRect(0, 0, 32, 32)
birdSprite:moveTo(600, 100)
birdSprite:add()

-- 3. GAME VARIABLES
local gameState = "stopped"
local score = 0
local birdsCaught = 0
local speed = 5

function pd.update()
    gfx.sprite.update()

    if gameState == "stopped" then
        gfx.drawTextAligned("Press **A** to Start", 200, 40, kTextAlignment.center)
        if pd.buttonJustPressed(pd.kButtonA) then
            gameState = "active"
            score = 0
            birdsCaught = 0
            playerSprite:setImage(capybaraUp)
            playerSprite:moveTo(40, 120)
            obstacleSprite:moveTo(450, math.random(40, 200))
            birdSprite:moveTo(600, math.random(40, 200))
        end
    elseif gameState == "active" then
        
        -- MOVEMENT & FLIP LOGIC
        local crankPos = pd.getCrankPosition()
        if crankPos <= 90 or crankPos >= 270 then
            playerSprite:moveBy(0, -3)
            playerSprite:setImage(capybaraUp) -- Facing Up
        else
            playerSprite:moveBy(0, 3)
            playerSprite:setImage(capybaraDown) -- Facing Down
        end

        -- MOVE ROCK & BIRD
        obstacleSprite:moveBy(-speed, 0)
        -- Bird flies in a wavy "Sine Wave" pattern
        local wave = math.sin(pd.getElapsedTime() * 8) * 3
        birdSprite:moveBy(-(speed + 2), wave)

        -- RESET POSITIONS
        if obstacleSprite.x < -20 then
            obstacleSprite:moveTo(450, math.random(40, 200))
            score += 1
        end
        if birdSprite.x < -20 then
            birdSprite:moveTo(600, math.random(40, 200))
        end

        -- COLLISION DETECTION
        local collisions = playerSprite:overlappingSprites()
        for i=1, #collisions do
            local other = collisions[i]
            if other == obstacleSprite then
                playerSprite:setImage(capybaraHurt)
                gameState = "stopped"
            elseif other == birdSprite then
                birdsCaught += 1
                birdSprite:moveTo(600, math.random(40, 200)) -- Catch the bird!
            end
        end

        -- SCREEN BOUNDS
        if playerSprite.y > 240 or playerSprite.y < 0 then
            gameState = "stopped"
        end
    end

    -- UI DISPLAY
    gfx.drawText("Score: " .. score, 10, 10)
    gfx.drawText("Birds: " .. birdsCaught, 10, 30)
end