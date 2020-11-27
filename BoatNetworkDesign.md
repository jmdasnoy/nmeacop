# Boat network design
by jmdasnoy 2020

The primary boat network is NMEA0183 over serial RS-422.
A physical, wired network is considered mandatory to ensure reliable operation.
Wireless connections may be added for convenience purposes.
The usual design issues of single talker, multiple listener and various baud-rates apply.

Equipment on the network can be either permanently active and connected (e.g. GPS source, instrument display, AP) or temporary users (smartphone) or optional (eg openCPN chartplotter on PC).

The network should not rely on the presence of these optional or temporary nodes to work.
Additionally, all nodes should eventually receive all messages. This implies that messages from various talkers have to be merged into a single stream and reach all listeners.


## Network topology as a ring backbone with stubs
### Permanent nodes are on the backbone ring

The permanent (i.e. always active) nodes are connected in a ring.
Each backbone node has an upstream incoming NMEA serial connection and a downstream outgoing serial NMEA output.
Each node will basically listen to ( and possibly process) incoming messages, add its own messages and forward everything downstream. This ensures that all backbone nodes receive the full data flow.
This backbone ring must use a higher baud rate (57600 ?)  than the 38400 as used for AIS.

Each AIS channel (161.975 & 162.025MHz) can produce 2250 AIS position updates per minute.
In total this is 75 VDM messages per second, each 50 bytes i.e. 500 bits. At full load this implies 75*500 = 37500 baud.

This must be tested to ensure that the backbone nodes can handle this !!!

### Avoiding infinite message repetition

Messages entered into the backbone ring will be transferred from node to node, potentially going around the backbone repeatedly and causing queue saturation. A strict policy is needed to ensure that any message sent to the backbone is eventually discarded after having been seen by all backbone participants.
Each backbone node will receive as input the messages it has generated, after they go around the backbone ring. These known messages must be discarded on entry. These messages can also be used to check ring integrity.
On the other hand, each node expects others to apply the same policy and any other messages received should be forwarded down the ring.
So, the default policy for backbone incoming messages is to forward them.

Incoming messages on stub lines are a different case. The device on the stub line can echo some or all of the messages it has received. It can also produce a variety of messages according to its setting and operation modes.
Again, if any of these messages are sent down the backbone it is the backbone node’s responsibility to avoid infinite loops. A dynamic policy can be considered, tracking all messages sent to a stub to cancel echos and listing all messages received from stubs and forwarded downstream to discard them on return/reentry. This leads to extra processing for each stub message.
For the time being, a static policy is chosen, with a default of discarding any incoming stub messages.

### Non permanent or listen-only nodes on stubs

Listeners who can use the backbone baudrate can tap off directly. (e.g. Open CPN )
Fixed rate listeners (typically a 4800 baud VHF DSC radio without GPS) will use the second UART i.e. the stub talker of the ring node at the appropriate speed.
Talkers (e.g. openCPN, or AIS ) will talk to a ring node on its second UART line i.e. the stub listener.
Stub connections can also be added as UDP sockets for NMEA over IP, as talkers or listeners.
UDP multicast addresses should be used whenever possible but not all routers process these properly and most equipment will not be capable of listening to multicasts as opposed to broadcasts.
The ring node will then forward the messages received on the stub to the ring backbone, as appropriate.

## Queuing and filtering

Each backbone node will maintain a queue for each outgoing stream and for the stream of messages to be decoded and used locally.
The listener callback functions need to be fast. They will perform minimal processing, based on the start of the message, ie the NMEA tag and enqueue the message in the appropriate queue.

### Message overwriting and data pacing
Messages enqueued for transmission or decoding may, in some cases, be replaced by a newer, more recently received instance. Typically there is no need to transmit or decode a GPS position message (“GPGLL”) still in a queue when a newer one is received. In this case, the output buffer for a given stream will only contain one instance of a given message type.

However, this must not be done for multipart messages like AIS or Routes.
Likewise, WPL messages need more parsing than the tag extract to check whether they are repeats or different, so they cannot be distinguished by the time constrained listener callback.

Messages for slower stubs may be throttled/decimated. Typically a 10Hz GPS update on the backbone may be reduced to a slower frequency e.g. 1Hz update for a 4800 baud listen-only VHF radio. The message replacement can be used for this purpose, as any repeated message can be requested to replace the one still in the slower stub queue, if any.

There may be an opposite use case, where low frequency messages, e.g. temperature and pressure measured once a minute may need to be repeated to keep a display alive, for example the openCPN dashboard plugin. This is not (yet) implemented.

### Speed adjustment

The callbacks on the hardware sending functions can be used to request sending of the next message in the queue.
However, when the queue is empty, this auto-queuing will stop and will need to be restarted. This might also to lead to hogging behaviour...
For a software queue consumer, i.e. the decode queue this method is not applicable.
The issue is to find a way to check queue size and (re)start transmitting or decoding.

The current choice is to use a timer for the outgoing or decode queues with dynamic timer interval adjustment.

Queue sizes, message replacement or dropping must be monitored and used for warnings in case of increased latency or congestion.

### Checksums
Messages that are simply received and forwarded will not be inspected for their content nor for valid checksums. This avoids the significant overhead of having all nodes inspecting all messages. Also a valid checksum at one node is no guarantee that the message will reach the intended receivers without issues.
Any node, whether backbone or stub, must perform a checksum verification on all messages it wishes to use/decode for content.

### Modes and switches

Various operating modes may be required at different times and should be communicated throughout the network.
Mode changes are mostly triggered by user input through push-buttons or control surfaces.
The classical example is the choice of auto-pilot modes between stand-by/manual helm, wind steering, fixed heading steering, waypoint steering with set and drift compensation, and the usual +/- 1, +10/-10, dodge and other buttons.
The Seatalk protocol has messages for these key presses.
Other commercial autopilot control units communicate with the autopilot main system either through a specific connection and protocol or over NMEA2K.

The boat mode, according to Colregs Rule 3, can also be useful for activating lights, sound signals, anchor watches etc.

These modes and changes are critical pieces of information and should be transmitted over a physical connection. Other protocols such as Signal-K or MQTT could be used for these purposes. Mixing them on the hardware NMEA bus could confuse existing equipment or would add complexity to the backbone nodes.
Commercial systems, like navigation light control, address this by defining additional proprietary NMEA0183 messages.

The standard NMEA Alarm ALR and Alarm Acknowledge ACK messages will be used here to handle this information.
They can also, of course, be used by nodes for reporting internal error conditions.



