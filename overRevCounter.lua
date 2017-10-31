-- Overrev Count

orcId = addChannel("OverRevs",1,0,0,10)
local overRevCount = 0 --sets initial over rev count
local overRevStatus = 0  --sets initial over rev status
function overRevCounter()
	if rpm < 6800 then overRevStatus = 0 end --resets flag when you fall below RPM limit
	if rpm > 6800 and overRevStatus == 0 
		then 
		overRevStatus = 1 --makes sure counter only increases when you cross RPM limit
		overRevCount = overRevCount + 1
		setChannel(orcId,overRevCount)
	end 
end