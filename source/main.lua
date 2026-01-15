import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

-- Helper: load & force-scale image to 32×32
local function loadAndScale(path)
    local img = gfx.image.new(path)
    if img then
        return img:scaledImage(32 / img:getSize())
    else
        print("Warning: Missing image: " .. path)
        return gfx.image.new(32, 32, gfx.kColorClear)
    end
end

-- Background Music (looping MP3)
local bgmPlayer = pd.sound.fileplayer.new("sounds/hype-music", "sounds/music-free.mp3", "sounds/crash.mp3")
if bgmPlayer then
    bgmPlayer:setVolume(0.55)  -- not too overpowering
    bgmPlayer:setRate(1.0)     -- start normal
end

-- 1. LOAD & PREPARE IMAGES (all 32×32)
local capybaraUp   = loadAndScale("images/capybara")
local capybaraDown = capybaraUp:flipped(gfx.kImageFlippedY)
local capybaraHurt = loadAndScale("images/damaged_capybara")
local rockImage    = loadAndScale("images/rock")
local birdImage    = loadAndScale("images/birds")

-- 2. SPRITE SETUP
local playerSprite = gfx.sprite.new(capybaraUp)
playerSprite:setCollideRect(0, 0, 32, 32)
playerSprite:moveTo(40, 120)
playerSprite:add()

local obstacleSprite = gfx.sprite.new(rockImage)
obstacleSprite:setCollideRect(0, 0, 32, 32)
obstacleSprite:moveTo(450, 240)
obstacleSprite:add()

local birdSprite = gfx.sprite.new(birdImage)
birdSprite:setCollideRect(0, 0, 32, 32)
birdSprite:moveTo(600, 100)
birdSprite:add()

-- 3. GAME VARS
local gameState = "stopped"
local score = 0
local birdsCaught = 0
local speed = 5

function pd.update()
    gfx.sprite.update()

    if gameState == "stopped" then
        if bgmPlayer then bgmPlayer:stop() end
        gfx.drawTextAligned("Press **A** to Start", 200, 40, kTextAlignment.center)
        if pd.buttonJustPressed(pd.kButtonA) then
            gameState = "active"
            score = 0
            birdsCaught = 0
            playerSprite:setImage(capybaraUp)
            playerSprite:moveTo(40, 120)
            obstacleSprite:moveTo(450, math.random(40, 200))
            birdSprite:moveTo(600, math.random(40, 200))
            if bgmPlayer then
                bgmPlayer:play(0)  -- 0 = infinite loop
                bgmPlayer:setRate(1.0)  -- reset pitch
            end
        end
    elseif gameState == "active" then
        
        -- Crank movement & flip
        local crankPos = pd.getCrankPosition()
        local dy = 3
        if crankPos <= 90 or crankPos >= 270 then
            dy = -3
            playerSprite:setImage(capybaraUp)
        else
            playerSprite:setImage(capybaraDown)
        end
        playerSprite:moveBy(0, dy)

        -- Screen clamp
        local px, py = playerSprite:getPosition()
        py = math.max(16, math.min(240 - 16, py))
        playerSprite:moveTo(px, py)

        -- Obstacles move
        obstacleSprite:moveBy(-speed, 0)
        local wave = math.sin(pd.getElapsedTime() * 8) * 3
        birdSprite:moveBy(-(speed + 2), wave)

        -- Reset
        if obstacleSprite.x < -32 then
            obstacleSprite:moveTo(450, math.random(40, 200))
            score += 1
            speed += 0.2
        end
        if birdSprite.x < -32 then
            birdSprite:moveTo(600, math.random(40, 200))
        end

        -- Collisions
        local collisions = playerSprite:overlappingSprites()
        for i = 1, #collisions do
            local other = collisions[i]
            if other == obstacleSprite then
                playerSprite:setImage(capybaraHurt)
                if bgmPlayer then bgmPlayer:stop() end
                gameState = "stopped"
            elseif other == birdSprite then
                birdsCaught += 1
                birdSprite:moveTo(600, math.random(40, 200))
            end
        end

        -- Off-screen
        if playerSprite.y > 240 or playerSprite.y < 0 then
            if bgmPlayer then bgmPlayer:stop() end
            gameState = "stopped"
        end

        -- BGM pitch ramps with speed (racer adrenaline!)
        if bgmPlayer then
            local rate = 0.9 + (speed - 5) * 0.1
            bgmPlayer:setRate(math.min(1.6, rate))
        end
    end

    -- UI
    gfx.drawText("Score: " .. score, 10, 10)
    gfx.drawText("Birds: " .. birdsCaught, 10, 30)
end