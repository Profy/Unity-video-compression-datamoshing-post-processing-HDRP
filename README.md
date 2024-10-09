# Unity video compression (datamoshing) post-processing | HDRP


## How to use:
Go to Project Settings > Graphics > HDRP Global Settings > Custom Post Process Order. Add it under After Post Process.

Add the post-processing to a post-process volume.

Blocking artifacts occur whenever a complex image is streamed over a low-bandwidth connection.
![screenshot](ball.gif)

Floating artifacts and ghosting artifacts occur in low-bitrate videos whenever the encoder skips predictive frames.
![screenshot](capsule.gif)

## Credit
Based on the work of Keijiro, [KinoDatamosh](https://github.com/keijiro/KinoDatamosh). Check his repository for more information.
