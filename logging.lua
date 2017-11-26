--Start logging

local logStatus = 0
function logging()
  --will reset max rpm and over rev counter if you stop and shut off the car and then start again
    if rpm < 100 and speed < 5 and getAnalog(7) < 13  --Checks RPM, speed, and battery voltage
    then 
    logStatus = 0
  end
  if rpm > 100 and logStatus == 0 
    then
    startLogging()
    maxRpm = 0  --Resets maximum RPM counter
    setChannel(maxRpmId, maxRpm)
    overRevCount = 0  --Resets over rev counter
    setChannel(orcId,overRevCount)
    local logStatus = 1
  end
end