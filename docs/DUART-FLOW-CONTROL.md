# DUART channel-A hardware flow control

NDOS uses MC68681 channel A for its console.  Its physical RS-232 flow-control
signals are now assigned as follows:

| Signal | MC68681 path | NDOS behavior |
| --- | --- | --- |
| RTS# (output) | output-port OP0, RS-232 RTS | Asserted when the receive queue can accept input; deasserted at 224 queued bytes; reasserted at 128 bytes. |
| CTS# (input) | RS-232 CTS to MC68681 IP0 | MR2A bit 4 enables CTS-gated transmitter operation. |

The software receive queue is 256 bytes.  It is interrupt-fed and is distinct
from the MC68681's small hardware receive FIFO.

The current MAME `serial_terminal` device is a development console: it holds
CTS asserted and does **not** react to RTS.  Therefore the new wiring and
watermarks model the J68K serial contract but cannot make fast pastes into
that particular terminal pause.  The larger 256-byte NDOS queue is the direct
MAME improvement.  A flow-control-capable external serial endpoint can honor
RTS without an NDOS ABI change.

Status: **SIMULATION INTEGRATION** for the MAME wiring and NDOS queue logic.
It is not physical DUART, MAX232, cable, or terminal hardware verification.
