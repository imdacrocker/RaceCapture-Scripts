-- Max RPM marker

maxRpmId = addChannel("MaxRpm",1,0,0,9000)
maxRpm = 0

function maxRev()
  if rpm > maxRpm 
    then
    maxRpm = rpm
    setChannel(maxRpmId, maxRpm)
  end
end
