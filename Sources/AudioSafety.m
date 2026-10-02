#import "AudioSafety.h"

NSError *MKAudioCatchException(void (^operation)(void)) {
    @try {
        operation();
        return nil;
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:@"com.mechakeys.audio" code:1
            userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Audio route became unavailable"}];
    }
}
