-- Shift Light

timer = 0

function shiftLight()
  if rpm > 6250 then setGpio(1,1) else setGpio(1,0) end
  if rpm > 6500 and timer == 1 --blinks shift light after set RPM
    then
      setGpio(1,0)
  end
  if timer == 1 then timer = 0 else timer = 1 end
end