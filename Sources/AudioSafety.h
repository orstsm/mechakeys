#import <Foundation/Foundation.h>

// Swift cannot catch NSException from legacy AVAudioPlayerNode APIs.
NSError * _Nullable MKAudioCatchException(void (^ _Nonnull operation)(void));
