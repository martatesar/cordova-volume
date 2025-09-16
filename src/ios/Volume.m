#import "Volume.h"
#import <UIKit/UIKit.h>

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

    // 5) When app returns to foreground/active, ensure session is active and push fresh volume
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
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

- (void)handleAppWillEnterForeground:(NSNotification *)notification
{
    // Proactively reactivate before becoming active
    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:nil];
    [session setActive:YES error:nil];
}

- (void)handleAppDidBecomeActive:(NSNotification *)notification
{
    // Ensure session is active and send a fresh reading to JS if a callback is registered
    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setActive:YES error:nil];
    if (changeCallbackId) {
        [self sendCurrentVolumeTo:changeCallbackId];
    }
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
    // Ensure the session is active to avoid stale values after backgrounding
    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setActive:YES error:nil];
    float volume = session.outputVolume;
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
