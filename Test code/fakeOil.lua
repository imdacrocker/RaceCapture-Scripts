--RPM sweep for testing

thrRpmLo = 6000
 --Low RPM threshold for change direction
 
thrRpmHi = 8000
--Hi RPM threshold for change direction

incrementRpm = 33

--Step between each RPM increment/decrement, will affect the speed, higher = faster

rpm = 6001

direction = 0

rpmId = addChannel("RPM", 10, 0, 0, 10000)

function fakeRPM()
  setChannel(rpmId, rpm)

  if (rpm<=thrRpmHi and direction == 0 ) then rpm = rpm + incrementRpm  
  	elseif (rpm>=thrRpmLo and direction == 1 ) then rpm = rpm - incrementRpm
  end

  if (rpm>thrRpmHi) then direction = 1
   	elseif (rpm<thrRpmLo) then direction = 0
  end

end

--Oil pressure sweep for testing

throillo = 1
 --Low RPM threshold for change direction
 
throilhi = 10
--Hi RPM threshold for change direction

incrementoil = 1

--Step between each RPM increment/decrement, will affect the speed, higher = faster

oil = 0

directionoil = 0

oilId = addChannel("OilPress", 10, 0, 0, 60)