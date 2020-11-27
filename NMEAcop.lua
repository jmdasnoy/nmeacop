-- jmdasnoy scripsit 2019 copyright MIT
-- This package provides a NMEA cop/traffic manager handling a hub with 3 predefined queues, talkers for each queue, and any number of listeners
-- Target platform ESP 32 NodeMCU Lua 5.1
--
-- *** DESIGN alternative could use general functions operating on queue objects, to allow any number of queues, heap and CPU load allowing...
-- *** The code could be shorter but possibly slower due to additional lookups in objects instead of the current locals
--
-- predefined backbone, stub and decode queues
local backbonequeue = {}
local backbonetaglist = {}
local backboneoldest = 1
local backbonenewest = 0
local stubqueue = {}
local stubtaglist = {}
local stuboldest = 1
local stubnewest = 0
local decodequeue = {}
local decodetaglist = {}
local decodeoldest = 1
local decodenewest = 0
--
-- action functions for the process function
-- can also be used to enqueue locally generated messages
-- note the overwrite/decimation mechanism in the *single versions, keeping at most one tag in queue
-- do not use for multipart messages i.e. routes RTE, satellite lists GSV or AIS VDM, etc
-- do not use for WPL waypoints etc
--
local function discard( tag , s )
--[[
  print( "discarding message " , s)
--]]
end
--
local function enqueuebackbone( tag , s )
--[[
  print( "queuing message to backbone " , s)
--]]
  backbonenewest = backbonenewest + 1
  backbonequeue[ backbonenewest ] = s
end
--
local function enqueuebackbonesingle( tag , s )
  local pos = backbonetaglist.tag
  if pos then
--[[
    print( "overwriting existing message in backbone queue " , tag , " at: ", pos)
--]]
    backbonequeue[ pos ] = s
  else
    backbonenewest = backbonenewest + 1
    backbonequeue[ backbonenewest ] = s
    backbonetaglist.tag = backbonenewest
--[[
    print( "no such tag yet in backbone queue " , tag , " adding at: ", backbonenewest )
--]]
  end
end
--
local function enqueuestub( tag , s )
--[[
  print( "queuing message to stub " , s)
--]]
  stubnewest = stubnewest + 1
  stubqueue[ stubnewest ] = s
end
--
local function enqueuestubsingle( tag , s )
  local pos = stubtaglist.tag
  if pos then
--[[
    print( "overwriting existing message in stub queue " , tag , " at: ", pos)
--]]
    stubqueue[ pos ] = s
  else
    stubnewest = stubnewest + 1
    stubqueue[ stubnewest ] = s
    stubtaglist.tag = stubnewest
--[[
    print( "no such tag yet in stub queue " , tag , " adding at: ", stubnewest )
--]]
  end
end
--
--
local function enqueuedecode( tag , s )
--[[
  print( "queuing message for decoding " , s)
--]]
  decodenewest = decodenewest + 1
  decodequeue[ decodenewest ] = s
end
--
--
local function enqueuedecodesingle( tag , s )
  local pos = decodetaglist.tag
  if pos then
--[[
    print( "overwriting existing message in decode queue " , tag , " at: ", pos)
--]]
    decodequeue[ pos ] = s
  else
    decodenewest = decodenewest + 1
    decodequeue[ decodenewest ] = s
    decodetaglist.tag = decodenewest
--[[
    print( "no such tag yet in decode queue " , tag , " adding at: ", decodenewest )
--]]
  end
end
--
-- dual output functions
--
local function enqueuedecodandstub( tag , s )
  enqueuedecode( tag , s )
  enqueuestub( tag , s)
end
--
local function enqueuedecodeandbackbone( tag , s )
  enqueuedecode( tag , s )
  enqueuebackbone( tag , s)
end
--
local function enqueuedecodeandstubsingle( tag , s )
  enqueuedecodesingle( tag , s )
  enqueuestubsingle( tag , s)
end
--
local function enqueuedecodeandbackbonesingle( tag , s )
  enqueuedecodesingle( tag , s )
  enqueuebackbonesingle( tag , s)
end
--
local function enqueuestubandbackbone( tag , s )
  enqueuestub( tag , s )
  enqueuebackbone( tag , s)
end
--
local function enqueuestubandbackbonesingle( tag , s )
  enqueuestubsingle( tag , s )
  enqueuebackbonesingle( tag , s)
end
--
-- functions for transmitting/emptying the queues
--
-- caller must supply the effective function to be called for tranmission
-- for udp sockets function( data ) sck:send(data) end call back possible via sck.on()
-- for serial uart lines function( data ) uart.write( uart_id , data) end no call back
-- for the decode queue, the decoder function :-)
--
local function sendbackbone( sendfn )
  if backbonenewest >= backboneoldest then
    local s = backbonequeue[ backboneoldest ]
    local tag = s:sub( 2 , 6 )
    backbonetaglist.tag = nil -- avoid overwrite update
    backbonequeue[ backboneoldest ] = nil
    backboneoldest = backboneoldest + 1
--[[
    print("backbone output: ", s)
--]]
    sendfn( s )
    return true
  end
end
--
local function senddecode( sendfn )
  if decodenewest >= decodeoldest then
    local s = decodequeue[ decodeoldest ]
    local tag = s:sub( 2 , 6 )
    decodetaglist.tag = nil -- avoid overwrite update
    decodequeue[ decodeoldest ] = nil
    decodeoldest = decodeoldest + 1
--[[
    print("decode requested on : ", s)
--]]
    sendfn( s )
    return true
  end
end
--
local function sendstub( sendfn )
  if stubnewest >= stuboldest then
    local s = stubqueue[ stuboldest ]
    local tag = s:sub( 2 , 6 )
    stubtaglist.tag = nil -- avoid overwrite update
    stubqueue[ stuboldest ] = nil
    stuboldest = stuboldest + 1
--[[
    print("stub output: ", s)
--]]
    sendfn( s )
    return true
  end
end
--
local function addchecksum( s )
-- Max 80 chars including checksum *xx , excluding initial, quid cr/lf 
-- conflicting alternative states maximum sentence length, including the $ and <CR><LF> is 82 bytes.
  local numchars = s:len( )
  if numchars > 77 then
---[[
    print( "NMEA message longer than 80 chars, ignored" )
--]]
    return nil
  else
    local checksum = 0
    for i = 2 , numchars do
      checksum = bit.bxor( checksum , s:byte(i) )
    end
    return ("%s*%02X\r\n"):format( s , checksum )
  end
end
--
-- this function is the call back for the input stream listeners (serial or udp)
-- keep it short and sweet
--
local function process( self, s )
--[[
  print( "Received NMEA string: ", s)
--]]
-- get the NMEA tag ie talker id as 2 chars + code as 3 chars (note some vendor extensions have more than 3 chars, sorry)
-- ie extract IIHDM from  $IIHDM,176.6,M*24<0x0D><0x0A>
  local tag = s:sub( 2 , 6 )
--[[
  print( "tag is: ", tag )
--]]
-- is there any trigger for this tag ?
  local trig = self.triggers[ tag ]
  if trig then
--[[
    print( "applying trigger for" , tag )
--]]
    trig( tag , s )
  else
--[[
    print( "no trigger found, applying default" )
--]]
    self.default( tag , s )
  end
end
--
local function printbackboneq()
  print( backboneoldest , backbonenewest , backbonenewest - backboneoldest + 1 )
  for i=backboneoldest , backbonenewest do print( backbonequeue[ i ] ) end
end
--
local function printstubq()
  print( stuboldest , stubnewest , stubnewest - stuboldest + 1 )
  for i=stuboldest , stubnewest do print( stubqueue[ i ] ) end
end
--
local function printdecodeq()
  print( decodeoldest , decodenewest , decodenewest - decodeoldest + 1 )
  for i=decodeoldest , decodenewest do print( decodequeue[ i ] ) end
end
--
local function stats()
  return backbonenewest-backboneoldest+1 , stubnewest-stuboldest+1 , decodenewest-decodeoldest+1
end
--
local function new( ) -- create and return a new listener
  local nmo = {}
-- callback function for input listeners
  nmo.process = process
-- default processing behaviour is discard
  nmo.default = discard
-- the trigger list is empty initially
  nmo.triggers = {}
  return nmo
end
-- the package exposes
--  the constructor function new() for creating listeners
--  a table "actions" with the possible action functions for the listeners
--  the predefined stub, backbone and decode queues
--  functions for sending/emptying queues
--  utility functions: addchecksum queueprinters and stats

local actions = {discard = discard , enqueuebackbone = enqueuebackbone , enqueuebackbonesingle = enqueuebackbonesingle ,
 enqueuestub = enqueuestub , enqueuestubsingle = enqueuestubsingle ,
 enqueuedecode = enqueuedecode , enqueuedecodesingle = enqueuedecodesingle , 
 enqueuedecodeandstub = enqueuedecodeandstub , enqueuedecodeandbackbone = enqueuedecodeandbackbone , 
 enqueuedecodeandstubsingle = enqueuedecodeandstubsingle , enqueuedecodeandbackbonesingle = enqueuedecodeandbackbonesingle , 
 enqueuestubandbackbone =  enqueuestubandbackbone ,  enqueuestubandbackbonesingle =  enqueuestubandbackbonesingle ,
}
print( "NMEAlistener package loaded")
return { new = new ,
  actions = actions ,
  backbonequeue = backbonequeue , stubqueue = stubqueue , decodequeue = decodequeue ,
  sendbackbone = sendbackbone , sendstub = sendstub , senddecode = senddecode ,
  addchecksum = addchecksum , 
  printbackboneq = printbackboneq , printstubq = printstubq , printdecodeq = printdecodeq , 
  stats = stats
}
