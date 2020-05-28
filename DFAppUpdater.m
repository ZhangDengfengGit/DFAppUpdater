/*
 Created by ZDF
 Copyright (c) 2020 ZDF.<dengf_zhang@163.com>.All rights reserved.
 Website:
 GitHub: https://github.com/ioscodegithub
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

#import "ATAppUpdater.h"
#import "AppDelegate.h"

//APP ID
#define KAPPID @""
@implementation ATAppUpdater


#pragma mark - Init


+ (id)sharedUpdater
{
    static ATAppUpdater *sharedUpdater;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedUpdater = [[ATAppUpdater alloc] init];
    });
    return sharedUpdater;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.alertTitle = @"更新提示";
        self.alertMessage = @"新版本%@已经上线，快来更新吧!";
        self.alertUpdateButtonTitle = @"前往更新";
        self.alertCancelButtonTitle = @"取消";
    }
    return self;
}


#pragma mark - Instance Methods


- (void)showUpdateWithForce
{
    BOOL hasConnection = [self hasConnection];
    if (!hasConnection) return;
    
    [self checkNewAppVersion:^(BOOL newVersion, NSString *version) {
        if (newVersion) {
            [self alertUpdateForVersion:version withForce:YES];
        }
    }];
}

- (void)showUpdateWithConfirmation
{
    BOOL hasConnection = [self hasConnection];
    if (!hasConnection) return;
    [self checkNewAppVersion:^(BOOL newVersion, NSString *version) {
//        NSLog(@"&&&%d, %@", newVersion, version);
        if (newVersion) {
            NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
            NSString *currentVersion = bundleInfo[@"CFBundleShortVersionString"];
            NSString *currentStr = [currentVersion substringToIndex:3];//（1.0.0length为5）
            NSString *newStr = [version substringToIndex:3];//（1.0.0length为5）
//            NSLog(@"&&&%@, %@", currentStr, newStr);
            if ([newStr compare:currentStr options:NSNumericSearch] == NSOrderedDescending) {
                [self alertUpdateForVersion:version withForce:YES];
            }else {
                [self alertUpdateForVersion:version withForce:NO];
            }
        }
    }];
}

- (void)showUpdateWithConfirmationOnce
{
    BOOL hasConnection = [self hasConnection];
    if (!hasConnection) return;
    
    [self checkNewAppVersion:^(BOOL newVersion, NSString *version) {
        if (newVersion){
            NSString *keyUD_versionPromptInfo = @"versionPromptInfo";
            NSString *keyPromptInfo_version = @"version";
            NSString *keyPromptInfo_date = @"promptedAt";
            NSDictionary *info = [[NSUserDefaults standardUserDefaults] objectForKey:keyUD_versionPromptInfo];
            NSString *versionPrompted = info[keyPromptInfo_version];
            
            //not showing dialog, if prompted for this version already
            BOOL showDialog = [versionPrompted isEqualToString:version] ? NO : YES;
            if (showDialog) {
                [self alertUpdateForVersion:version withForce:NO];
                NSDictionary *newInfo = @{keyPromptInfo_version : version,
                                          keyPromptInfo_date: [NSDate date]
                                          };
                [[NSUserDefaults standardUserDefaults] setObject:newInfo forKey:keyUD_versionPromptInfo];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }];
}


#pragma mark - Private Methods


- (BOOL)hasConnection
{
    const char *host = "itunes.apple.com";
    BOOL reachable;
    BOOL success;
    
    // Link SystemConfiguration.framework! <SystemConfiguration/SystemConfiguration.h>
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, host);
    SCNetworkReachabilityFlags flags;
    success = SCNetworkReachabilityGetFlags(reachability, &flags);
    reachable = success && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired);
    CFRelease(reachability);
    return reachable;
}

NSString *appStoreURL = nil;

- (void)checkNewAppVersion:(void(^)(BOOL newVersion, NSString *version))completion
{
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
//    NSString *bundleIdentifier = bundleInfo[@"CFBundleIdentifier"];
    NSString *currentVersion = bundleInfo[@"CFBundleShortVersionString"];
    NSURL *lookupURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/cn/lookup?id=%@", KAPPID]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        
        NSData *lookupResults = [NSData dataWithContentsOfURL:lookupURL];
        if (!lookupResults) {
            completion(NO, nil);
            return;
        }
        
        NSDictionary *jsonResults = [NSJSONSerialization JSONObjectWithData:lookupResults options:0 error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            NSUInteger resultCount = [jsonResults[@"resultCount"] integerValue];
            if (resultCount){
                NSDictionary *appDetails = [jsonResults[@"results"] firstObject];
                NSString *appItunesUrl = [appDetails[@"trackViewUrl"] stringByReplacingOccurrencesOfString:@"&uo=4" withString:@""];
                NSString *latestVersion = appDetails[@"version"];
                if ([latestVersion compare:currentVersion options:NSNumericSearch] == NSOrderedDescending) {
                    appStoreURL = appItunesUrl;
                    completion(YES, latestVersion);
                } else {
                    completion(NO, nil);
                }
            } else {
                completion(NO, nil);
            }
        });
    });
}

- (void)alertUpdateForVersion:(NSString *)version withForce:(BOOL)force
{
    NSString *alertMessage = [NSString stringWithFormat:self.alertMessage, version];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:self.alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *updateAction = [UIAlertAction actionWithTitle:self.alertUpdateButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreURL] options:@{} completionHandler:nil];
//        [self exitApplication];
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:^{
            if ([self.delegate respondsToSelector:@selector(appUpdaterDidShowUpdateDialog)]) {
                [self.delegate appUpdaterDidShowUpdateDialog];
            }
        }];
        if ([self.delegate respondsToSelector:@selector(appUpdaterUserDidLaunchAppStore)]) {
            [self.delegate appUpdaterUserDidLaunchAppStore];
        }
    }];
//    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDestructive handler:nil];
    //修改按钮字体颜色
//    [cancelAction setValue:[UIColor redColor] forKey:@"titleTextColor"];
//    [updateAction setValue:[UIColor blueColor] forKey:@"titleTextColor"];
//    [alert addAction:cancelAction];
    [alert addAction:updateAction];
    
    if (!force) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:self.alertCancelButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            if ([self.delegate respondsToSelector:@selector(appUpdaterUserDidCancel)]) {
                [self.delegate appUpdaterUserDidCancel];
            }
        }];
        [alert addAction:cancelAction];
    }
    
    [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:^{
        if ([self.delegate respondsToSelector:@selector(appUpdaterDidShowUpdateDialog)]) {
            [self.delegate appUpdaterDidShowUpdateDialog];
        }
    }];
}


- (void)exitApplication {
    
    AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
    UIWindow *window = app.window;
    
    [UIView animateWithDuration:1.0f animations:^{
        window.alpha = 0;
        window.frame = CGRectMake(0, window.bounds.size.width, 0, 0);
    } completion:^(BOOL finished) {
        abort();
    }];
    //exit(0);
    
}
@end
