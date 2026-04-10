local m = addChannel("MaxRpm", 1, 0, 0, 9000)
local g = addChannel("Gear", 5, 0, 0, 5)
local c = addChannel("Camera", 1, 0, 0, 2)
-- Command needed to tag.  Pre-built to save memory, concatenated strings in the function takes more memory
local get = 'GET /gp/gpControl/command/storage/tag_moment HTTP/1.0' .. string.char(13) .. string.char(10) .. string.char(13) .. string.char(10)
st = getUptime() -- Stop time
mv = false -- Moving
eo = getUptime() -- Engine Off Time
sl = 1 -- Shift Light State
lr = getUptime() -- Last Response
lk = getUptime() -- Last Keep Alive
lrq = getUptime() -- Last Request
l = getLapCount() -- Lap Count
t = true -- Time Not Sent

-- Function to send raw data on the serial bus
function sR(val) -- Send Raw
    for i = 1, #val do
        writeCSer(5, string.byte(val, i))
    end
end

-- Function to send an AT command
function sA(val) -- Send AT
    sR(val)
    writeCSer(5, 13)
    writeCSer(5, 10)
end

-- Function to send a command over UDP
function sC(command, connection) -- Send Command
    sA('AT+CIPSEND=' .. connection .. ',' .. string.sub(#command, 1, -3))
    pi()
    sR(command)
    pi()
end

-- Helper function to send a TCP command to the camera.  This opens the connection and then sends
function sT(command) -- Send TCP
        sA('AT+CIPSTART=3,"TCP","10.71.79.2",80')
        pi()
        sA('AT+CIPSEND=3,' .. string.sub(#command, 1, -3))
        pi()
        sR(command)
        pi()
        sA("AT+CIPCLOSE,3")
end

-- Helper function to set a number to a hexadecimal
function tH(val) -- To Hex
    local hex = string.format("%x", val)
    if string.len(hex) < 2 then
        hex = "0" .. hex
    end
    return "%" .. hex
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
                lr = getUptime()
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

sA('AT+RST')
pi()
sA('AT+CWMODE_CUR=2')
pi()
sA('AT+CWSAP_CUR="HERO-RC-000000","",1,0')
pi()
sA('AT+CIPAPMAC_CUR="d8:96:85:00:00:00"')
pi()
sA('AT+CIPAP_CUR="10.71.79.1"')
pi()
sA('AT+CIPMUX=1')
pi()
sleep(1000)
sA('AT+CIPSTART=0,"UDP","255.255.255.255",9')
pi()
sA('AT+CIPSTART=1,"UDP","10.71.79.2",8484,8383')
pi()

setTickRate(25)
function onTick()
    local rpm = getChannel("RPM")
    if rpm == nil then rpm = 0 end
    -- Various functions around stopping and going
    if (mv) then -- If the car was moving last time we checked
        st = getUptime() -- Always update when moving 
        if (getGpsSpeed() == 0 and rpm == 0) then mv = false end 
    else -- if NOT moving
        if ((getGpsSpeed() > 10) and (rpm > 500)) then -- If the car was not moving last time we checked, but now it is...
            mv = true
            sC(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x02),'1') -- Start GoPro
            startLogging()
        -- Stop logging if the car has been stopped for 30s
        elseif ((getUptime() - st) > 30000) and isLogging() ~= 0 then stopLogging()
        -- Check to see if the car has been stopped for 2 minutes
        elseif ((getUptime() - st) > 120000) then
            resetLapStats()
            setChannel(m, rpm) -- Reset the maxRpm channel
        end
    end
    if (rpm > 500) then
        eo = getUptime()
    end
    -- Max RPM
    if rpm > getChannel(m) then setChannel(m, rpm) end -- Update max RPM if greater than current

    -- Reset Button
    if getButton() == true then -- Checks the button on the front of the RaceCapture for a press
        setChannel(m, rpm) -- Reset the MaxRpm
        resetLapStats()
        st = getUptime()
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
        if (mv) then setGpio(0, 1) -- If the car is moving, set the light
        else
            if ((getUptime() - eo) < 5000) then
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
        sl = 0
    end
    if rpm > 6000 then
        if sl == 1 then
            setGpio(1, 0)
            sl = 0
        else
            sl = 1
        end
    end
    -- Check Cameras
    if (getUptime() - lr) > 5000 then -- Send the WOL packet
        setChannel(c, 0)
        local mac = string.char(0xd4, 0xd9, 0x19, 0x99, 0xc4, 0xef)
        local packet = string.char(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
        for i = 1, 16 do
            packet = packet .. mac -- Add MAC address 16 times
        end
        sC(packet, '0')
    end
    if isLogging() == 0 and getChannel(c) == 2 then -- If we are not logging, but the camera is running, stop it
        sC(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x00), '1')
        setChannel(c, 1)
    end
    if isLogging() ~= 0 and getChannel(c) == 1 then -- If we ARE logging, and not recording, then start
        sC(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x53, 0x48, 0x02), '1')
        setChannel(c, 2)
    end
    -- Send KeepAlive every 1.5s
    if (getUptime() - lk) > 1500 then
        sA('AT+CIPSEND=1,22')
        pi()
        sR('_GPHD_:0:0:2:0.000000\n')
        pi()
        lk = getUptime()
    end
    -- Request an update every 5 seconds
    if (getUptime() - lrq) > 5000 then
        sC(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x73, 0x74), '1')
        lrq = getUptime()
    end
    -- Set tag on lap rollover
    if l ~= getLapCount() then
        l = getLapCount()
        sT(get)
    end
    -- Set camera date/time
    if t and getChannel(c) > 0 then -- Only send the time once, and only if the camera is connected
        local y, mo, d, h, mi, s = getDateTime()
        if y > 1970 then
            t = false
            local dt = ""
            for _, v in ipairs({y % 100, mo, d, h, mi, s}) do dt = dt .. tH(math.floor(v)) end
            local command = "GET /gp/gpControl/command/setup/date_time?p=" .. dt .. " HTTP/1.0\r\n\r\n"
            sT(command)
        end
    end
	txCAN(0, 0x600, 0, {isLogging(), 0, 0, 0, 0, 0, 0, 0})
    pi()
    collectgarbage()
end
