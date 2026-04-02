local m = addChannel("MaxRpm", 1, 0, 0, 9000)
local g = addChannel("Gear", 5, 0, 0, 5)
local c = addChannel("Camera", 1, 0, 0, 2)
stopTime = getUptime()
moving = false
engineOffTime = getUptime()
running = false
timer = 1
lastResponse = getUptime()
lastKeepAlive = getUptime()
lastRequest = getUptime()
lap = getLapCount()

function sendRaw(val)
    for i = 1, #val do
        local c = string.sub(val, i, i)
        writeCSer(5, string.byte(c))
    end
end

function sendAt(val)
    sendRaw(val)
    writeCSer(5, 13)
    writeCSer(5, 10)
end

function sendCommand(command, connection)
    sendAt('AT+CIPSEND=' .. connection .. ',' .. string.sub(#command, 1, -3))
    pi()
    sendRaw(command)
    pi()
end

function pi()
    local char = readCSer(5, 100)
    if char == nil then
        return
    end
    local line = ''
    while (char ~= nil) do
        line = line .. string.char(char)
        if string.find(line, '+IPD,') then
            readCSer(5, 100)
            char = readCSer(5, 100)
            char = readCSer(5, 100)
            local length = ''
            while char ~= 58 do
                if char == nil then
                    return
                end
                length = length .. string.char(char)
                char = readCSer(5, 100)
            end
            local packet = ''
            if tonumber(length) == nil then
            else
                for i = 1, tonumber(length) do
                    packet = packet .. string.sub(readCSer(5, 100), 1, -3) .. ' '
                end
                lastResponse = getUptime()
                if getChannel(c) == 0 then
                    setChannel(c, 1)
                end
                if packet == '95 71 80 72 68 95 58 48 58 48 58 50 58 1 ' then
                    if getChannel(c) == 0 then
                        setChannel(c, 1)
                    end
                elseif packet == '0 0 0 0 0 0 0 0 0 0 0 115 116 0 0 0 0 0 0 0 ' then
                    setChannel(c, 1)
                elseif packet == '0 0 0 0 0 0 0 0 0 0 0 115 116 0 0 1 0 1 0 0 ' then
                    setChannel(c, 2)
                elseif packet == '0 0 0 0 0 0 0 0 0 0 0 115 116 1 0 0 0 0 0 0 ' then
                    setChannel(c, 0)
                end
                return
            end
        end
        char = readCSer(5, 100)
    end
end

sendAt('AT+RST')
pi()
sendAt('AT+CWMODE_CUR=2')
pi()
sendAt('AT+CWSAP_CUR="HERO-RC-000000","",1,0')
pi()
sendAt('AT+CIPAPMAC_CUR="d8:96:85:00:00:00"')
pi()
sendAt('AT+CIPAP_CUR="10.71.79.1"')
pi()
sendAt('AT+CIPMUX=1')
pi()
sleep(1000)
sendAt('AT+CIPSTART=0,"UDP","255.255.255.255",9')
pi()
sendAt('AT+CIPSTART=1,"UDP","10.71.79.2",8484,8383')
pi()

setTickRate(10)
function onTick()
    -- checkMoving()
    if (moving == false) then -- If the car was not moving last time we checked, check to see if it's moving
        if ((getGpsSpeed() > 10) and (getChannel("RPM") > 500)) then -- If the car has begun to move while running, then do these things
            moving = true -- Set Moving to true
            sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x02),'1') -- Start GoPro
            startLogging() -- Make sure logging is running
            if ((getUptime() - stopTime) > 120000) then -- If the car has been stopped for 2 minutes
                resetLapStats() -- Reset the lap stats
                maxRPM = getChannel("RPM") -- Reset the maxRpm channel
            end
  end
        if ((getUptime() - stopTime) > 30000) and isLogging() ~= 0 then -- If the car is stopped and logging, check to see if it's been stopped for 30 seconds
   sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48,0x00), '1') -- Stop GoPro
   stopLogging() -- Stop logging if the car has been stopped for 30s or more
  end
    end
    if (moving) then -- If the car was moving last time we checked, check to see if it's stopped
        stopTime = getUptime() -- Set the stop time to the current uptime constantly
        if (getGpsSpeed() == 0 and getChannel("RPM") == 0) then -- Use getGpsSpeed() AND getChannel("RPM") for this
            moving = false -- Set the car  to not moving
        end
    end
    -- checkRunning()
    if (running == false) then
        if (getChannel("RPM") > 500) then
            running = true
        end
    end
    if (running) then
        engineOffTime = getUptime()
        if (getChannel("RPM") == 0) then -- If the car is not running
            running = false
        end
    end

    -- maxRev
    if getChannel("RPM") > getChannel("MaxRpm") then
        setChannel(m, getChannel("RPM"))
        if (moving) then
            if (getChannel("RPM") > 6500) then
            end
        end
    end
    -- resetButton()
    if getButton() == true then -- Checks the button on the front of the RaceCapture for a press
        maxRpm = 0 -- Resets maximum getChannel("RPM") counter
        setChannel(m, 0)
        resetLapStats()
  stopTime = getUptime()
    end
    -- checkGear()
    --local gearPos = calcGear(58.42, 3.73, 3.83, 2.2, 1.4, 1.0, .89)
 local gearPos = calcGear(58.42, 3.73, 4.2, 2.49, 1.66, 1.24, 1.0)
    if (gearPos == nil) then
        gearPos = 0 -- Set the gear to 0 if none is detected
    end
    setChannel(g, gearPos) -- Actually set the channel

    -- checkOil()
    if (getChannel("OilPress") < 5 and getChannel("RPM") <= 3000) or -- If the pressure is less than 3, and the getChannel("RPM") is less than 3000
        (getChannel("RPM") > 3000 and getChannel("OilPress") < 20) -- If the getChannel("RPM") is above 3000, and the oil pressure is below 20
    then
        if (moving) then -- If the car is moving, set the light
            setGpio(0, 1)
        else
            if ((getUptime() - engineOffTime) < 5000) then -- If the car is NOT moving, only show the light if the car has been stopped for less than 5 seconds
                setGpio(0, 1)
            else
                setGpio(0, 0) -- If the car has been stopped for more than 5 seconds, shut off the light
            end
        end
    else
        setGpio(0, 0) -- Otherwise, set the light to off
    end
    -- shiftLight()
    if getChannel("RPM") > 5750 then
        setGpio(1, 1)
    else
        setGpio(1, 0)
    end
    if getChannel("RPM") > 6000 then
        if timer == 1 then
            setGpio(1, 0)
            timer = 0
        else
            timer = timer + 1
        end
    end
    -- checkCamera()
    if (getUptime() - lastResponse) > 5000 then
        setChannel(c, 0)
        local mac = string.char(0xd4, 0xd9, 0x19, 0x99, 0xc4, 0xef)
        local packet = string.char(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
        for i = 1, 16 do
            packet = packet .. mac -- Add MAC address 16 times
        end
        sendCommand(packet, '0')
    end
    if isLogging() == 0 and getChannel(c) == 2 then
     sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x00), '1') -- Stop camera
        setChannel(c, 1)
    end
    if isLogging() ~= 0 and getChannel(c) == 1 then -- If we ARE logging, and not recording, then record
        sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x02), '1') -- Start camera
        setChannel(c, 2)
    end
    if (getUptime() - lastKeepAlive) > 1500 then
        sendAt('AT+CIPSEND=1,22')
        pi()
        sendRaw('_GPHD_:0:0:2:0.000000\n')
        pi()
        lastKeepAlive = getUptime()
    end
    if (getUptime() - lastRequest) > 5000 then
        sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x73, 0x74), '1')
        lastRequest = getUptime()
    end
    -- Set tag
    if lap ~= getLapCount() then
        lap = getLapCount()
        sendAt('AT+CIPSTART=3,"TCP","10.71.79.2",80')
        pi()
        local get = 'GET /gp/gpControl/command/storage/tag_moment HTTP/1.0' .. string.char(13) .. string.char(10) .. string.char(13) .. string.char(10)
        sendAt('AT+CIPSEND=3,' .. string.sub(#get,1, -3))
        pi()
        sendRaw(get)
        pi()
        sendAt("AT+CIPCLOSE,3")
    end
    pi()
end
