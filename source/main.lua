import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd <const> = playdate
local gfx <const> = pd.graphics

-- Load images (nil-safe)
local playerImage = gfx.image.new("images/player_in_car")
if playerImage then playerImage = playerImage:scaledImage(0.5) end

local damagedImage = gfx.image.new("images/damaged_capybara")
if damagedImage then damagedImage = damagedImage:scaledImage(0.5) end

local obstacleNames = {"rock", "birds", "cow-kick-can", "elephant", "giraffe", "lizard"}
local obstacleImages = {}
for _, name in ipairs(obstacleNames) do
    local img = gfx.image.new("images/" .. name)
    if img then
        table.insert(obstacleImages, img:scaledImage(0.5))
    end
end

-- Sounds - no CoreLibs/sound import needed!
local enginePlayer = playdate.sound.fileplayer.new("sounds/car-engine-roaring")
if enginePlayer then
    enginePlayer:setVolume(0.75)
end

local crashPlayer = playdate.sound.fileplayer.new("sounds/car-crash-sound-effect")
local damagePlayer = playdate.sound.fileplayer.new("sounds/damage")
local startPlayer = playdate.sound.fileplayer.new("sounds/car-start")
local failIgnition = playdate.sound.fileplayer.new("sounds/car-engine-ignition-fail")

local animalPlayers = {
    rock = playdate.sound.fileplayer.new("sounds/rocks-and-gravel-slide"),
    birds = playdate.sound.fileplayer.new("sounds/bird_chirps"),
    ["cow-kick-can"] = playdate.sound.fileplayer.new("sounds/cow-mooing"),
    elephant = playdate.sound.fileplayer.new("sounds/elephant"),
    lizard = playdate.sound.fileplayer.new("sounds/iguana"),
    -- giraffe silent for now
}

-- Constants
local GRAVITY <const> = 0.25
local NUM_OBSTACLES <const> = 6

-- Player sprite
local playerSprite = gfx.sprite.new(playerImage or gfx.image.new(32,32))
playerSprite:setCollideRect(0, 0, 32, 32)
playerSprite:moveTo(40, 120)
playerSprite:add()

-- Obstacles table
local obstacles = {}
local gameSpeed = 5

for i = 1, NUM_OBSTACLES do
    local obs = gfx.sprite.new(gfx.image.new(32,32))
    obs:setCollideRect(0, 0, 32, 32)
    obs:add()
    respawnObs(obs)
    table.insert(obstacles, obs)
end

function respawnObs(obs)
    if #obstacleImages == 0 then return end
    local randIndex = math.random(#obstacleImages)
    obs:setImage(obstacleImages[randIndex])
    local name = obstacleNames[randIndex]
    obs.type = name
    obs.isFalling = (name == "rock" or name == "birds")
    obs.speedX = -(gameSpeed + math.random(3))
    obs.speedY = 0
    local startY = obs.isFalling and math.random(30, 70) or math.random(170, 210)
    obs:moveTo(450 + math.random(0, 300), startY)
    
    -- Play animal sound on spawn/respawn
    local snd = animalPlayers[name]
    if snd then
        snd:play(0)
    end
end

-- Game state
local gameState = "playing"
local score = 0
local highScore = 0
local glitchTimer = 0
local glitchActive = false

-- Start engine
if enginePlayer then
    enginePlayer:play(0)  -- loop forever
    enginePlayer:setRate(0.8)
end

function pd.update()
    playerSprite:update()
    for _, obs in ipairs(obstacles) do
        obs:update()
    end

    if gameState == "playing" then
        gameSpeed = 5 + score * 0.05

        -- Engine pitch rev
        if enginePlayer then
            local rate = 0.8 + (gameSpeed - 5) * 0.1
            enginePlayer:setRate(math.min(2.0, rate))
        end

        -- Crank movement
        local crankPos = pd.getCrankPosition()
        local dy = (crankPos <= 90 or crankPos >= 270) and -4 or 4
        playerSprite:moveBy(0, dy)
        local px, py = playerSprite:getPosition()
        py = math.max(30, math.min(210, py))
        playerSprite:moveTo(px, py)

        -- Obstacles
        for _, obs in ipairs(obstacles) do
            obs:moveBy(obs.speedX, obs.speedY)
            if obs.isFalling then
                obs.speedY += GRAVITY
            end
            local ox, oy = obs:getPosition()
            if ox < -40 or (obs.isFalling and oy > 260) then
                respawnObs(obs)
                score += 1
            end
        end

        -- Collision
        if #playerSprite:overlappingSprites() > 0 and not glitchActive then
            if enginePlayer then enginePlayer:stop() end
            if crashPlayer then crashPlayer:play(0) end
            if damagePlayer then damagePlayer:play(0) end
            playerSprite:setImage(damagedImage)
            glitchActive = true
            glitchTimer = 45
            gameState = "glitching"
            if score > highScore then highScore = score end
        end

    elseif gameState == "glitching" then
        glitchTimer -= 1
        if failIgnition and math.random() < 0.4 then
            failIgnition:play(0)
        end
        if glitchTimer <= 0 then
            glitchActive = false
            gameState = "gameOver"
        end

    elseif gameState == "gameOver" then
        if pd.buttonJustPressed(pd.kButtonA) then
            score = 0
            gameSpeed = 5
            playerSprite:setImage(playerImage)
            playerSprite:moveTo(40, 120)
            for _, obs in ipairs(obstacles) do
                respawnObs(obs)
            end
            if enginePlayer then
                enginePlayer:play(0)
                enginePlayer:setRate(0.8)
            end
            if startPlayer then startPlayer:play(0) end
            gameState = "playing"
        end
    end

    -- Drawing
    if glitchActive then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)

        local shakeX = math.random(-16, 16)
        local shakeY = math.random(-16, 16)

        local doInvert = math.random() < 0.35
        if doInvert then
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(0, 0, 400, 240)
        end

        gfx.setColor(gfx.kColorWhite)
        local ditherAmt = 0.3 + math.random() * 0.7
        gfx.setDitherPattern(ditherAmt, gfx.image.kDitherTypeBayer2x2)

        for i = 1, 240, math.random(1, 3) do
            if math.random() > 0.15 then
                local offset = math.random(-4, 4) + (shakeY // 3)
                gfx.drawLine(0, i + offset, 400, i + offset)
            end
        end

        if math.random() < 0.6 then
            local tearY = math.random(20, 220)
            local tearWidth = math.random(60, 180)
            local tearOffset = math.random(-40, 40)
            gfx.drawLine(tearOffset, tearY, tearOffset + tearWidth, tearY)
            gfx.drawLine(tearOffset, tearY + 1, tearOffset + tearWidth, tearY + 1)
        end

        for _ = 1, 120 do
            gfx.drawPixel(math.random(0, 399), math.random(0, 239))
        end

        gfx.setDitherPattern(0.0)

        gfx.pushContext()
        gfx.setDrawOffset(shakeX, shakeY)
        playerSprite:draw()
        for _, obs in ipairs(obstacles) do
            obs:draw()
        end
        gfx.popContext()

        gfx.setColor(gfx.kColorWhite)
        local texts = {"CRASH DETECTED", "CARTRIDGE ERROR", "SYSTEM MELTDOWN", "GLITCH MODE", "FATAL 0xDEAD"}
        for i = 1, 5 do
            local txt = texts[math.random(#texts)]
            gfx.drawText(txt, math.random(10, 380), math.random(10, 220))
        end

    else
        playerSprite:draw()
        for _, obs in ipairs(obstacles) do
            obs:draw()
        end

        gfx.setColor(gfx.kColorWhite)
        gfx.drawText("Score: " .. score, 5, 5)
        gfx.drawText("High: " .. highScore, 250, 5)

        if gameState == "gameOver" then
            gfx.drawText("GAME OVER!", 110, 100)
            gfx.drawText("Final: " .. score, 140, 120)
            gfx.drawText("Press A to restart", 100, 140)
        end
    end
end