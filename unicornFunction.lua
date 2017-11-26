setTickRate(10)
function onTick()
  local speed = getGpsSpeed()
  local rpm = getTimerRpm(0)
  if rpm > 10000 then rpm = 10000 end --simple filter for noisy rpm spikes
  function checkGear
  function checkOil
  function logging
  function maxRev
  function overRevCounter
  function shiftLight
end