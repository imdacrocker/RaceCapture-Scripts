
--Gear Check

gearId = addChannel("Gear",5,0,0,5)
function checkGear()
  local gearErr = 0.1
  local rpmSpeedRatio = (rpm/speed)/60.7117 --(FinalDrive of 4.10*1056/(TireDia of 22.7*3.14159))
  if speed > 10 --makes sure not dividing by 0
    then
      if ((3.8 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 1 end
      if ((2.2 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 2 end 
      if ((1.4 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 3 end 
      if ((1 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 4 end
      if ((.81 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 5 end
    else gearPos = 0 
  end
  setChannel(gearId, gearPos)
end