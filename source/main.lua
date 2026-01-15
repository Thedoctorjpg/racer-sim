import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

-- Helper: load & force-scale image to 32×32
local function loadAndScale(path)
    local img = gfx.image.new(path)
    if img then
        -- Scale to fit exactly 32 px wide (preserves aspect, centers)
        return img:scaledImage(32 / img:getSize())
    else
        print("Warning: Missing image: " .. path)
        -- fallback transparent 32×32 square
        return gfx.image.new(32, 32, gfx.kColorClear)
    end
end

-- 1. LOAD & PREPARE IMAGES (all forced to 32×32)
local capybaraUp   = loadAndScale("images/capybara")
local capybaraDown = capybaraUp:flipped(gfx.kImageFlippedY)
local capybaraHurt = loadAndScale("images/damaged_capybara")
local rockImage    = loadAndScale("images/rock")
local birdImage    = loadAndScale("images/birds")

-- 2. SPRITE SETUP
-- Player
local playerSprite = gfx.sprite.new(capybaraUp)
playerSprite:setCollideRect(0, 0, 32, 32)
playerSprite:moveTo(40, 120)
playerSprite:add()

-- Rock obstacle
local obstacleSprite = gfx.sprite.new(rockImage)
obstacleSprite:setCollideRect(0, 0, 32, 32)
obstacleSprite:moveTo(450, 240)
obstacleSprite:add()

-- Bonus fantail bird
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
        local dy = 3
        if crankPos <= 90 or crankPos >= 270 then
            dy = -3
            playerSprite:setImage(capybaraUp)   -- facing up
        else
            playerSprite:setImage(capybaraDown) -- facing down
        end
        playerSprite:moveBy(0, dy)

        -- Keep player on screen (32 px tall)
        local px, py = playerSprite:getPosition()
        py = math.max(16, math.min(240 - 16, py))
        playerSprite:moveTo(px, py)

        -- MOVE OBSTACLES
        obstacleSprite:moveBy(-speed, 0)

        -- Bird sine wave pattern
        local wave = math.sin(pd.getElapsedTime() * 8) * 3
        birdSprite:moveBy(-(speed + 2), wave)

        -- RESET POSITIONS
        if obstacleSprite.x < -32 then
            obstacleSprite:moveTo(450, math.random(40, 200))
            score += 1
            speed += 0.2
        end
        if birdSprite.x < -32 then
            birdSprite:moveTo(600, math.random(40, 200))
        end

        -- COLLISION CHECK
        local collisions = playerSprite:overlappingSprites()
        for i = 1, #collisions do
            local other = collisions[i]
            if other == obstacleSprite then
                playerSprite:setImage(capybaraHurt)
                gameState = "stopped"
            elseif other == birdSprite then
                birdsCaught += 1
                birdSprite:moveTo(600, math.random(40, 200)) -- respawn bird after catch
            end
        end

        -- Off-screen game over
        if playerSprite.y > 240 or playerSprite.y < 0 then
            gameState = "stopped"
        end
    end

    -- UI
    gfx.drawText("Score: " .. score, 10, 10)
    gfx.drawText("Birds: " .. birdsCaught, 10, 30)
end