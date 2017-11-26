--Oil Pressure Warning

function checkOil()
  if getAnalog(6) < 5
    then 
      setGpio(0,1)
    else 
      setGpio(0,0)
  end
end