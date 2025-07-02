#import <Cordova/CDVPlugin.h>
#import <AVFoundation/AVFoundation.h>

@interface Volume : CDVPlugin

/// Returns the current hardware output-volume (0.0-1.0).
- (void)getVolume:(CDVInvokedUrlCommand*)command;

/// Registers a persistent JS callback that fires every time the user presses
/// the volume buttons.
- (void)setVolumenChangeCallback:(CDVInvokedUrlCommand*)command;

@end
