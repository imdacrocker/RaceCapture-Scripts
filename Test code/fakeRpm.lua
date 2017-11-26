direction = 0

rpmId = addChannel("RPM", 10, 0, 0, 10000)

function fakeRPM()
  if (rpm<=150 and direction == 0 ) then rpm = rpm + 10  
  	elseif (rpm>=50 and direction == 1 ) then rpm = rpm - 10
  end

  if (rpm>150) then direction = 1
   	elseif (rpm<50) then direction = 0
  end
	println("RPM " ..rpm)
	setChannel(rpmId, rpm)
end