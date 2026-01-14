import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

-- Helper to load & force-resize image to 32x32
local function loadAndResize(path)
    local img = gfx.image.new(path)
    if img then
        return img:scaledImage(32 / img:getSize())  -- scale to fit 32px width (preserves aspect, but Playdate crops/centers nicely)
    else
        -- fallback tiny black square if image missing
        local fallback = gfx.image.new(32, 32)
        gfx.pushContext(fallback)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 32, 32)
        gfx.popContext()
        return fallback
    end
end

-- Player
local playerStartX = 40
local playerStartY = 120
local playerSpeed = 3
local playerImage = loadAndResize("images/capybara")
local playerSprite = gfx.sprite.new(playerImage)
playerSprite:setCollideRect(0, 0, 32, 32)  -- full 32×32 hitbox
playerSprite:moveTo(playerStartX, playerStartY)
playerSprite:add()

-- Game State
local gameState = "stopped"
local score = 0

-- Obstacle
local obstacleSpeed = 5
local obstacleImage = loadAndResize("images/rock")
local obstacleSprite = gfx.sprite.new(obstacleImage)
obstacleSprite:setCollideRect(0, 0, 32, 32)  -- full size
obstacleSprite:moveTo(450, 120)  -- start centered vertically
obstacleSprite:add()

function pd.update()
    gfx.sprite.update()

    if gameState == "stopped" then
        gfx.drawTextAligned("Press A to Start", 200, 40, kTextAlignment.center)
        if pd.buttonJustPressed(pd.kButtonA) then
            gameState = "active"
            score = 0
            obstacleSpeed = 5
            playerSprite:moveTo(playerStartX, playerStartY)
            obstacleSprite:moveTo(450, math.random(40, 200))
        end
    elseif gameState == "active" then
        -- Crank vertical movement
        local crankPosition = pd.getCrankPosition()
        local dy = (crankPosition <= 90 or crankPosition >= 270) and -playerSpeed or playerSpeed
        playerSprite:moveBy(0, dy)

        -- Keep player on screen
        local px, py = playerSprite:getPosition()
        py = math.max(16, math.min(240 - 16, py))  -- 32px tall, stay visible
        playerSprite:moveTo(px, py)

        -- Move obstacle left
        local actualX, actualY, collisions, length = obstacleSprite:moveWithCollisions(obstacleSprite.x - obstacleSpeed, obstacleSprite.y)

        -- Reset when off left edge
        if obstacleSprite.x < -32 then
            obstacleSprite:moveTo(450, math.random(40, 200))
            score += 1
            obstacleSpeed += 0.2
        end

        -- Crash conditions
        if length > 0 or py > 240 + 16 or py < -16 then
            gameState = "stopped"
        end
    end

    gfx.drawTextAligned("Score: " .. score, 390, 10, kTextAlignment.right)
end