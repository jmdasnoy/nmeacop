-- testing for NMEA
-- for openCPN initial is $ for usual messages and ! for AIS
-- WI prefix for Weather Instruments
-- II prefix for Integrated Instrumentation
-- examples for air temperature and pressure
testvalues = {
  "$IIXDR,C,19.52,C,TempAir*19" , 
  "$IIXDR,P,1.02481,B,Barometer*29" , 
  "$SDXDR,C,23.13,C,WTHI*76" ,
  "$SDXDR,C,23.15,C,WTHI*70" ,
  "$IIXDR,P,1.01408,B,Barometer*2B" ,
  "$IIXDR,C,19.8,C,AirTemp*26" ,
}

nmea = require( "NMEAcop" )
--
for _ , v in ipairs( testvalues) do
  local sl = v:len()
  local s = v:sub( 2 , -4 )
  local r = nmea.addchecksum( "$" , s )
-- remove the cr/lf for comparison
  if r:sub( 1 , -3) == v then
    print( "Ok" , r)
  else
    print( "Error " , v , r)
  end
end
--
