-- NMEA0183 sample setup for home tests, with UDP sockets instead of the real wired RS-422 network
-- get the package
NMEA = require( "NMEAcop" )
-- listener for incoming messages on backbone
bblistener = NMEA.new()
-- set up the filtering, override default discard action by forward to backbone output
bblistener.default = NMEA.actions.enqueuebackbone
-- this node produces TIROT, IIHDM, IIXDR and IIALR messages, so ignore them on input as they are only echoes
bblistener.triggers.TIROT = NMEA.actions.discard
bblistener.triggers.IIXDR = NMEA.actions.discard
bblistener.triggers.IIHDM = NMEA.actions.discard
bblistener.triggers.IIALR = NMEA.actions.discard
-- *** IMPROVE ME one of these messages could be used to pet a backbone integrity watchdog
--
-- the GPS is upstream on the MacBook and produces GPGSV,GPGGA,GPRMC
-- send these on the local stub to the Lenovo running openCPN chartplotter
-- no need to send them back out on the backbone that has only 2 nodes
--
bblistener.triggers.GPRMC = NMEA.actions.enqueuedecodeandstubsingle -- feed the chartplotter and decode locally
bblistener.triggers.GPGGA = NMEA.actions.enqueuedecodeandstubsingle
bblistener.triggers.GPGSV = NMEA.actions.enqueuestub -- only for chartplotter
-- listener for incoming messages on stub
stublistener = NMEA.new()
-- set up the filtering, default action is initially setup to discard, no need to repeat ...
-- stublistener.default = NMEA.actions.discard
-- this node produces TIROT, IIHDM, IIXDR messages, so ignore them on stub input as they are only echoes
stublistener.triggers.TIROT = NMEA.actions.discard
stublistener.triggers.IIXDR = NMEA.actions.discard
stublistener.triggers.IIHDM = NMEA.actions.discard
-- chartplotter output should be decoded and also sent down the backbone
stublistener.triggers.ECRMB = NMEA.actions.enqueuedecodeandbackbonesingle
stublistener.triggers.ECRMC = NMEA.actions.enqueuedecodeandbackbonesingle
stublistener.triggers.ECAPB = NMEA.actions.enqueuedecodeandbackbonesingle
stublistener.triggers.ECXTE = NMEA.actions.enqueuedecodeandbackbonesingle
stublistener.triggers.ECRTE = NMEA.actions.enqueuedecodeandbackbone
stublistener.triggers.ECWPL = NMEA.actions.enqueuedecodeandbackbone
-- but these chartplotter outputs should be discarded if they come back on the backbone
bblistener.triggers.ECRMB = NMEA.actions.discard
bblistener.triggers.ECRMC = NMEA.actions.discard
bblistener.triggers.ECAPB = NMEA.actions.discard
bblistener.triggers.ECXTE = NMEA.actions.discard
bblistener.triggers.ECRTE = NMEA.actions.discard
bblistener.triggers.ECWPL = NMEA.actions.discard
--
-- the main application will need to call the following functions  (with a hardware talker function)  to produce output

-- NMEA.sendbackbone , NMEA.sendstub
-- the main application will need to call the following function ( with a decoder) to process the messages received and queued for decoding
-- NMEA.senddecode
--
-- the main application must also tie the following functions to the listener callbacks to enqueue incoming messages
-- bblistener:process , stublistener:process
--
-- the data producers on this node need to call the appropriate function to prepare it for transmission
-- NMEA.addchecksum and the various variants of NMEA.actions.enqueue<variant>
--
