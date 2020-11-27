# NMEAcop by jmdasnoy 2020 MIT license

## Target platform ESP32 NodeMCU Lua 5.1

## Overview
This package provides a NMEA0183 multiplexer, traffic controller "cop" and queues for a backbone node.

The target NMEA network design is described in [Boat Network design](BoatNetworkDesign.md)

A limited use example is available [Partial example](nvab.lua)

## Application integration

This package provides 3 queues, feeding the backbone and stub outputs and the local decoder.
A variety of enqueueing and sending (dequeuing) functions are provided in the `actions` table.
Note the `single` variants available for data pacing of messages that can be dropped in favour of more recent ones, typically GPS fixes.

The `new()` function creates new listener objects, that can be precisely configured to handle/route incoming messages with specific tag matching and actions.

The main application will need to call the functions `NMEA.sendbackbone` and `NMEA.sendstub` (with a hardware talker function) to produce output.
The main application must also call the `NMEA.senddecode` function ( with a decoder function) to process the messages received and queued for decoding.

The main application is responsible for monitoring the queue sizes with `NMEA.stats` and adapting the frequency of calls to the sender functions.

The main application will tie the `<listener>:process` functions to the corresponding hardware listener callbacks to enqueue incoming messages.

The data producers on this node need to call the appropriate enqueuing function to prepare it for transmission.
Utility functions include `NMEA.addchecksum`.






