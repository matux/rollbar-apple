//
//  RollbarSession.m
//  
//
//  Created by Andrey Kornich on 2022-04-21.
//

#import "RollbarSession.h"
#import "RollbarSessionState.h"
#import <sys/stat.h>

@import RollbarCommon;

#if __has_include(<WatchKit/WatchKit.h>)
#import <WatchKit/WatchKit.h>
#define __HAS_WATCHKIT_FRAMEWORK__
#elif __has_include(<TVUIKit/TVUIKit.h>)
#import <TVUIKit/TVUIKit.h>
#define __HAS_TVUIKIT_FRAMEWORK__
#elif __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#define __HAS_UIKIT_FRAMEWORK__
#elif __has_include(<AppKit/AppKit.h>)
#import <AppKit/AppKit.h>
#define __HAS_APPKIT_FRAMEWORK__
#endif


//@import SwiftUI;

//#if TARGET_OS_WATCH
//@import WatchKit;
//#elif TARGET_OS_TV
//#if TARGET_OS_TV
//@import TVUIKit;
//#elif TARGET_OS_IOS
//@import UIKit;
//@import TVUIKit;
//#else
//@import AppKit;
//#endif

static NSString * const SESSION_FILE_NAME = @"rollbar.session";

@implementation RollbarSession {
    
@private
    RollbarSessionState *_state;
    NSString *_stateFilePath;
}

- (void)enableOomMonitoringWithCrashCheck:(RollbarCrashReportCheck)crashCheck {
    
    //TODO: implement...
}

#pragma mark - System and Application notification hooks

- (void)registerForSystemSignals {
    
    signal(SIGABRT, onSysSignal);
    signal(SIGQUIT, onSysSignal);
    signal(SIGTERM, onSysSignal);
}

static void onSysSignal(int signalID) {
    
    NSString *signalDescriptor = nil;
    switch(signalID) {
        case SIGABRT:
            signalDescriptor = @"SIGABRT";
            break;
        case SIGQUIT:
            signalDescriptor = @"SIGQUIT";
            break;
        case SIGTERM:
            signalDescriptor = @"SIGTERM";
            break;
        default:
            return;
    }
    
    [[RollbarSession sharedInstance] captureSystemSignal:signalDescriptor];
}

- (void)captureSystemSignal:(nonnull NSString *)signal {
    
    self->_state.sysSignal = signal;
    [self saveCurrentSessionState];
}

- (void)registerApplicationHooks {
    
#if defined(__HAS_WATCHKIT_FRAMEWORK__)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationInForeground:)
                                                 name:WKApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationInBackground:)
                                                 name:WKApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationTerminated:)
                                                 name:WKApplicationWillResignActiveNotification
                                               object:nil];
#elif defined(__HAS_TVUIKIT_FRAMEWORK__)


#elif defined(__HAS_UIKIT_FRAMEWORK__)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationInForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationInBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationTerminated:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationReceivedMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];

    
#elif defined(__HAS_APPKIT_FRAMEWORK__)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationInForeground:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationInBackground:)
                                                 name:NSApplicationDidResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationTerminated:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
#endif
}

- (void)applicationInForeground:(NSNotification *)notification {
    
    self->_state.appInBackgroundFlag = RollbarTriStateFlag_Off;
    [self saveCurrentSessionState];
}

- (void)applicationInBackground:(NSNotification *)notification {

    self->_state.appInBackgroundFlag = RollbarTriStateFlag_On;
    [self saveCurrentSessionState];
}

- (void)applicationTerminated:(NSNotification *)notification {

    self->_state.appTerminationTimestamp = [NSDate date];
    [self saveCurrentSessionState];
}

- (void)applicationReceivedMemoryWarning:(NSNotification *)notification {

    self->_state.appMemoryWarningTimestamp = [NSDate date];
    [self saveCurrentSessionState];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - app termination checks


#pragma mark - app/OS version change checks

- (BOOL)didAppVersionChange:(nonnull NSString *)oldVersion {
    
    BOOL result =
    (NSOrderedSame != [[RollbarBundleUtil detectAppBundleVersion] compare:oldVersion]);
    return result;
}

- (BOOL)didOsVersionChange:(nonnull NSString *)oldVersion {
    
    BOOL result =
    (NSOrderedSame != [[RollbarOsUtil detectOsVersionString] compare:oldVersion]);
    return result;
}

#pragma mark - state access

- (RollbarSessionState *)getCurrentState {
  
    NSString *json = [self->_state serializeToJSONString];
    RollbarSessionState *stateClone = [[RollbarSessionState alloc] initWithJSONString:json];
    return stateClone;
}

#pragma mark - Sigleton pattern

+ (nonnull instancetype)sharedInstance {
    
    static id singleton;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        singleton = [self new];
    });
    
    return singleton;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        self->_stateFilePath = [RollbarCachesDirectory getCacheFilePath:SESSION_FILE_NAME];
        
        if (NO == [RollbarCachesDirectory ensureCachesDirectoryExists]) {
            
            RollbarSdkLog(@"Failed to create the Rollbar Caches Directory!");
            return self;
        }
        
        if (YES == [RollbarCachesDirectory checkCacheFileExists:SESSION_FILE_NAME]) {
            
            self->_state = [self loadSessionState];
        }
        else {

            self->_state = [RollbarSessionState new];
            [self saveCurrentSessionState];
        }
    }
    return self;
}

#pragma mark - session state persistence

- (RollbarSessionState *)loadSessionState {
   
    NSData *data = [[NSData alloc] initWithContentsOfFile:self->_stateFilePath];
    RollbarSessionState *state = [[RollbarSessionState alloc] initWithJSONData:data];
    return state;
}

- (BOOL)saveSessionState:(nonnull RollbarSessionState *)state {
    
    NSError *error;
    NSData *data = [NSJSONSerialization rollbar_dataWithJSONObject:state.jsonFriendlyData
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error
                                                              safe:true];
    if (!data && error) {
        RollbarSdkLog(@"Error saving Rollbar Session State: %@ !!!", [error localizedDescription]);
    }
    [data writeToFile:self->_stateFilePath atomically:YES];
}

- (BOOL)saveCurrentSessionState {
    
    return [self saveSessionState:self->_state];
}

@end
