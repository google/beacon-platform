// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "AppDelegate.h"

#import <GoogleMaps/GoogleMaps.h>

NSString *const kBSDLoginStatusChangedNotification = @"login_status_changed_notification";

@interface AppDelegate () <GIDSignInUIDelegate> {
}

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  // Many of the Google APIs we're using require an API Key -- we're storing that in the
  // APIKey.plist file, and will need to load that here.
  NSString *path = [[NSBundle mainBundle] pathForResource:@"APIKey" ofType:@"plist"];
  NSMutableDictionary *myDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
  _googleAPIKey = myDictionary[@"API_KEY"];

  // Initialise Maps and Places with our newly loaded API key.
  [GMSServices provideAPIKey:_googleAPIKey];

  _signInStatus = kBSDLoginStatusDetermining;

  NSError * configureError;
  [[GGLContext sharedInstance] configureWithError: &configureError];
  if (configureError != nil) {
    NSLog(@"Error configuring the Google context: %@", configureError);
  }

  [GIDSignIn sharedInstance].delegate = self;
  [GIDSignIn sharedInstance].uiDelegate = self;

  // Attempt to resume login from last time. If we are/were logged in, then we'll get the
  // signIn:DidSignInForUser:withError: callback with a user, otherwise we'll get an error there.
  // Note that we need to provide the OAuth scope for the Beacon Service.
  NSArray *currentScopes = [GIDSignIn sharedInstance].scopes;
  [GIDSignIn sharedInstance].scopes = [currentScopes arrayByAddingObject:
      @"https://www.googleapis.com/auth/userlocation.beacon.registry"];

  [[GIDSignIn sharedInstance] signInSilently];
  return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
  return [[GIDSignIn sharedInstance] handleURL:url
                             sourceApplication:sourceApplication
                                    annotation:annotation];
}


- (void)signIn:(GIDSignIn *)signIn
    didSignInForUser:(GIDGoogleUser *)user
     withError:(NSError *)error {
  if (user != nil) {
    _signInStatus = kBSDLoginStatusLoggedIn;
    [[NSNotificationCenter defaultCenter] postNotificationName:kBSDLoginStatusChangedNotification
                                                        object:self];
  } else if (error == nil) {
    _signInStatus = kBSDLoginStatusNotLoggedIn;
    [[NSNotificationCenter defaultCenter] postNotificationName:kBSDLoginStatusChangedNotification
                                                        object:self];
  } else {
    NSLog(@"%@", error);
    _signInStatus = kBSDLoginStatusLoginError;
  }
}

- (void)signIn:(GIDSignIn *)signIn
    didDisconnectWithUser:(GIDGoogleUser *)user
     withError:(NSError *)error {
  _signInStatus = kBSDLoginStatusNotLoggedIn;
  [[NSNotificationCenter defaultCenter] postNotificationName:kBSDLoginStatusChangedNotification
                                                      object:self];
}

- (void)signIn:(GIDSignIn *)signIn presentViewController:(UIViewController *)viewController {
  // ignore, we only do signInSilently
}

- (void)signIn:(GIDSignIn *)signIn dismissViewController:(UIViewController *)viewController {
  // ignore, we only do signInSilently
}

@end
