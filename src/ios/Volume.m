#import "Volume.h"

@implementation Volume {
    NSString *changeCallbackId;
}

#pragma mark - Plugin lifecycle ------------------------------------------------

- (void)pluginInitialize
{
    [super pluginInitialize];

    AVAudioSession *session = AVAudioSession.sharedInstance;

    // 1) Let our session coexist with the WKWebView/Howler session.
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:nil];

    // 2) KVO only works while the session is active.
    [session setActive:YES error:nil];

    // 3) Start watching the hardware volume.
    [session addObserver:self
              forKeyPath:@"outputVolume"
                 options:NSKeyValueObservingOptionNew
                 context:nil];

    // 4) Re-wire everything if the system rebuilds the audio stack.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMediaServicesReset:)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:session];
}

- (void)dealloc
{
    [self removeObserversAndNotifications];
}

- (void)pluginReset   // Cordova calls this on page reload
{
    [self removeObserversAndNotifications];
}

#pragma mark - JavaScript API ---------------------------------------------------

- (void)getVolume:(CDVInvokedUrlCommand *)command
{
    [self sendCurrentVolumeTo:command.callbackId];
}

- (void)setVolumenChangeCallback:(CDVInvokedUrlCommand *)command
{
    if (changeCallbackId) {
        NSLog(@"Overwriting volumeChangeCallback: %@!", changeCallbackId);
    }
    changeCallbackId = command.callbackId;
}

#pragma mark - KVO --------------------------------------------------------------

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"outputVolume"] && changeCallbackId) {
        [self sendCurrentVolumeTo:changeCallbackId];
    }
}

#pragma mark - AVAudioSession notifications ------------------------------------

- (void)handleMediaServicesReset:(NSNotification *)notification
{
    // The system rebuilt all audio objects. Re-configure and re-observe.
    AVAudioSession *session = AVAudioSession.sharedInstance;

    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:nil];
    [session setActive:YES error:nil];

    [session addObserver:self
              forKeyPath:@"outputVolume"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
}

#pragma mark - Helpers ----------------------------------------------------------

- (void)sendCurrentVolumeTo:(NSString *)callbackId
{
    CDVPluginResult *result = [self currentVolume];
    result.keepCallback = @YES;          // stay alive for future events
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (CDVPluginResult *)currentVolume
{
    float volume = AVAudioSession.sharedInstance.outputVolume;
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                              messageAsDouble:volume];
}

- (void)removeObserversAndNotifications
{
    AVAudioSession *session = AVAudioSession.sharedInstance;

    @try {
        [session removeObserver:self forKeyPath:@"outputVolume"];
    } @catch (NSException * __unused ex) { }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
