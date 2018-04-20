setTickRate(10) --Times per second this script runs

-- VARIOUS SETTINGS

--RPM limit for over rev marker

local rpmLimit = 6500

--RPM for shift light activation

local shiftRpm = 5750
local shiftRpmBlink = 6000

--Low oil pressure warning

local pressureWarn = 5

--gear ratios

local _1stGear = 3.8
local _2ndGear = 2.20
local _3rdGear = 1.4
local _4thGear = 1.0
local _5thGear = 0.81
local FinalDrive = 4.10
local TireDia = 22.7 
local gearErr = 0.1 --Allowable error in the calculation

--FUNCTIONS

-- Overrev Count

orcId = addChannel("OverRevs",1,0,0,10)
local overRevCount = 0 --sets initial over rev count
local overRevStatus = 0  --sets initial over rev status

function overRevCounter()
 if rpm > rpmLimit and overRevStatus == 0 
  then 
  overRevStatus = 1 --makes sure counter only increases when you cross RPM limit
  overRevCount = overRevCount + 1
  setChannel(orcId,overRevCount)
 end
 if rpm < rpmLimit
  then
  overRevStatus = 0  --resets flag when you fall below RPM limit
 end

end

-- Max RPM marker

maxRpmId = addChannel("MaxRpm",1,0,0,9000)
local maxRpm = 0 --sets initial Max RPM

function maxRev()
 if rpm > maxRpm 
  then
  maxRpm = rpm
  setChannel(maxRpmId, maxRpm)
 end
end

--start logging to SD card

local logstatus = 0

function logging()
 if getButton() == true then
    println("Pushed")
    maxRpm = 0  --Resets maximum RPM counter
	setChannel(maxRpmId, maxRpm)
    overRevCount = 0  --Resets over rev counter
	setChannel(orcId,overRevCount)
	end
 if rpm > 100
  then
  startLogging()
 end
 -- println("RPM " ..rpm)
 -- println("Speed " ..speed)
 -- println("Battery " ..getAnalog(7))
 -- println("Loggin Status" ..logstatus)
 -- println("Max RPM" ..maxRpm)
 -- println("Over REvs " ..overRevCount)
 -- println("Is Logging " ..isLogging())
end

--Oil Pressure LED

function checkOil()
 if getAnalog(6) < pressureWarn --Checks oil pressure
  then 
   setGpio(0,1)
  else 
   setGpio(0,0)
 end
end

-- Shift Light

local timer = 1
local button = 0 
local lightOn = 0

function shiftLight()

 if rpm > shiftRpm
  then 
   setGpio(1,1)
  else
   setGpio(1,0)
 end 
 if rpm > shiftRpmBlink
  then
   if timer == 1
    then
     setGpio(1,0)
     timer = 0
    else
     timer = timer + 1
    end
   end
 end

-- Gear Check

gearId = addChannel("Gear",5,0,0,5)
local rpmSpeedRatio = 0 --sets initial gear calculation
local gearPos = 0 --sets initial gear position

function checkGear()
 rpmSpeedRatio = (rpm/speed)/(FinalDrive*1056/(TireDia*3.14159))
 if speed > 10 --makes sure not dividing by 0
  then
   if ((_1stGear - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 1 end
   if ((_2ndGear - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 2 end
   if ((_3rdGear - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 3 end
   if ((_4thGear - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 4 end
   if ((_5thGear - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 5 end
  else gearPos = 0 
 end
 setChannel(gearId, gearPos)
end

function onTick()  --Runs all of the other functions 
 rpm = getTimerRpm(0) --Gets RPM needed for various functions
 speed = getGpsSpeed() --Gets speed needed for various functions
 maxRev()
 logging()
 checkGear()
 overRevCounter()
 checkOil()
 shiftLight()
end