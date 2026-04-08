local m = addChannel("MaxRpm", 1, 0, 0, 9000)
local g = addChannel("Gear", 5, 0, 0, 5)
local c = addChannel("Camera", 1, 0, 0, 2)
local get = 'GET /gp/gpControl/command/storage/tag_moment HTTP/1.0' ..
            string.char(13) .. string.char(10) .. string.char(13) .. string.char(10)
StopTime = getUptime()
Moving = false
EngineOffTime = getUptime()
ShiftLightState = 1
LastResponse = getUptime()
LastKeepAlive = getUptime()
LastRequest = getUptime()
Lap = getLapCount()

function sendRaw(val)
    for i = 1, #val do
        writeCSer(5, string.byte(val, i))
    end
end

function sendAt(val)
    sendRaw(val)
    writeCSer(5, 13)
    writeCSer(5, 10)
end

function sendCommand(command, connection)
    sendAt('AT+CIPSEND=' .. connection .. ',' .. string.sub(#command, 1, -3))
    processIncoming()
    sendRaw(command)
    processIncoming()
end

function processIncoming()
    local char = readCSer(5, 100)
    if char == nil then
        return
    end
    local line = ''
    while (char ~= nil) do
        line = line .. string.char(char)
        if string.find(line, '+IPD,') then
            if readCSer(5, 100) == nil then return end
            char = readCSer(5, 100)
            if char == nil then return end
            char = readCSer(5, 100)
            if char == nil then return end
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
                    local b = readCSer(5, 100)
                    if b == nil then
                        return
                    end
                    packet = packet .. string.sub(b, 1, -3) .. ' '
                end
                LastResponse = getUptime()
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
processIncoming()
sendAt('AT+CWMODE_CUR=2')
processIncoming()
sendAt('AT+CWSAP_CUR="HERO-RC-000000","",1,0')
processIncoming()
sendAt('AT+CIPAPMAC_CUR="d8:96:85:00:00:00"')
processIncoming()
sendAt('AT+CIPAP_CUR="10.71.79.1"')
processIncoming()
sendAt('AT+CIPMUX=1')
processIncoming()
sleep(1000)
sendAt('AT+CIPSTART=0,"UDP","255.255.255.255",9')
processIncoming()
sendAt('AT+CIPSTART=1,"UDP","10.71.79.2",8484,8383')
processIncoming()

setTickRate(10)
function onTick()
    local rpm = getChannel("RPM")
    if rpm == nil then rpm = 0 end
    -- Various functions around stopping and going
    if (Moving) then -- If the car was moving last time we checked
        StopTime = getUptime() -- Always update when moving 
        if (getGpsSpeed() == 0 and rpm == 0) then Moving = false end 
    else -- if NOT moving
        if ((getGpsSpeed() > 10) and (rpm > 500)) then -- If the car was not moving last time we checked, but now it is...
            Moving = true
            sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x02),'1') -- Start GoPro
            startLogging()
        -- Stop logging if the car has been stopped for 30s
        elseif ((getUptime() - StopTime) > 30000) and isLogging() ~= 0 then stopLogging()
        -- Check to see if the car has been stopped for 2 minutes
        elseif ((getUptime() - StopTime) > 120000) then
            resetLapStats()
            setChannel(m, rpm) -- Reset the maxRpm channel
        end
    end
    if (rpm > 500) then
        EngineOffTime = getUptime()
    end

    -- Max RPM
    if rpm > getChannel(m) then setChannel(m, rpm) end -- Update max RPM if greater than current

    -- Reset Button
    if getButton() == true then -- Checks the button on the front of the RaceCapture for a press
        setChannel(m, rpm) -- Reset the MaxRpm
        resetLapStats()
        StopTime = getUptime()
    end

    -- Gear Calculator
    local gearPos = calcGear(58.42, 3.73, 4.2, 2.49, 1.66, 1.24, 1.0)
    if (gearPos == nil) then gearPos = 0 end -- Set the gear to 0 if none is detected
    setChannel(g, gearPos)

    -- Oil Pressure
    local oilP = getChannel("OilPress")
    if oilP == nil then oilP = 0 end
    if (rpm > 3000 and oilP < 20) then setGpio(0, 1)
    elseif (oilP < 5 and rpm <= 3000) then
        if (Moving) then setGpio(0, 1) -- If the car is moving, set the light
        else
            if ((getUptime() - EngineOffTime) < 5000) then
                setGpio(0, 1) -- If the car is NOT moving, only show the light if the car has been stopped for less than 5 seconds
            else
                setGpio(0, 0) end -- If the car has been stopped for more than 5 seconds, shut off the light
        end
    else setGpio(0, 0) end -- Otherwise, set the light to off

    -- Shift Light
    if rpm > 5750 then
        setGpio(1, 1)
    else
        setGpio(1, 0)
        ShiftLightState = 0
    end
    if rpm > 6000 then
        if ShiftLightState == 1 then
            setGpio(1, 0)
            ShiftLightState = 0
        else
            ShiftLightState = 1
        end
    end
    -- Check Cameras
    if (getUptime() - LastResponse) > 5000 then -- Send the WOL packet
        setChannel(c, 0)
        local mac = string.char(0xd4, 0xd9, 0x19, 0x99, 0xc4, 0xef)
        local packet = string.char(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
        for i = 1, 16 do
            packet = packet .. mac -- Add MAC address 16 times
        end
        sendCommand(packet, '0')
    end
    if isLogging() == 0 and getChannel(c) == 2 then -- If we are not logging, but the camera is running, stop it
        sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x00), '1')
        setChannel(c, 1)
    end
    if isLogging() ~= 0 and getChannel(c) == 1 then -- If we ARE logging, and not recording, then start
        sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x02), '1')
        setChannel(c, 2)
    end
    -- Send KeepAlive every 1.5s
    if (getUptime() - LastKeepAlive) > 1500 then
        sendAt('AT+CIPSEND=1,22')
        processIncoming()
        sendRaw('_GPHD_:0:0:2:0.000000\n')
        processIncoming()
        LastKeepAlive = getUptime()
    end
    -- Request an update every 5 seconds
    if (getUptime() - LastRequest) > 5000 then
        sendCommand(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x73, 0x74), '1')
        LastRequest = getUptime()
    end
    -- Set tag on lap rollover
    if Lap ~= getLapCount() then
        Lap = getLapCount()
        sendAt('AT+CIPSTART=3,"TCP","10.71.79.2",80')
        processIncoming()
        sendAt('AT+CIPSEND=3,' .. string.sub(#get,1, -3))
        processIncoming()
        sendRaw(get)
        processIncoming()
        sendAt("AT+CIPCLOSE,3")
    end
    processIncoming()
    collectgarbage()
end
