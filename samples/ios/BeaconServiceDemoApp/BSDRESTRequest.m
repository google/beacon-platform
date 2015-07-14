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

#import "BSDRESTRequest.h"

static const int kRequestTimeout = 15; // seconds

@implementation BSDRESTRequest

+ (void)RESTfulJSONRequestToURL:(NSURL *)url
                         method:(NSString *)method
                       postBody:(NSData *)postBody
                 requestHeaders:(NSDictionary *)requestHeaders
              completionHandler:(void (^)(NSInteger httpResponseCode, NSString *response,
                                          NSError *error))completionHandler {
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  for (NSString *field in requestHeaders) {
    [request addValue:requestHeaders[field] forHTTPHeaderField:field];
  }

  [request setHTTPMethod:method];
  if (postBody) {
    request.HTTPBody = postBody;
    NSLog(@"POSTing: %@", [[NSString alloc] initWithData:postBody encoding:NSUTF8StringEncoding]);
  }

  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
  config.timeoutIntervalForRequest = kRequestTimeout;

  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                              completionHandler:
      ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *contents = nil;
        if (data) {
          contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }

        NSLog(@"contents: %@", contents);
        NSLog(@"response: %@", response);
        NSLog(@"error: %@", error);

        // Little bit of defensive coding here just in case.
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
          completionHandler(((NSHTTPURLResponse *)response).statusCode,
                            contents,
                            error);
        } else if (response) {
          NSLog(@"ERROR: response is not NSHTTPURLResponse!");
          NSString *bundle_identifier =
          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
          NSString *class_name = NSStringFromClass([response class]);
          NSError *oops = [NSError errorWithDomain:bundle_identifier
                                              code:-1
                                          userInfo:@{ @"class_name" : class_name }];
          completionHandler(-1, nil, oops);
        } else {
          NSLog(@"NSURLSession rejected this request");
          NSString *bundle_identifier =
          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
          NSError *oops = [NSError errorWithDomain:bundle_identifier
                                              code:-1
                                          userInfo:@{ @"error_obj" : error }];
          completionHandler(-1, nil, oops);
        }
      }
  ];

  [dataTask resume];
}

+ (NSData *)hexStringToNSData:(NSString *)hexString {
  NSMutableData *data = [[NSMutableData alloc] init];
  unsigned char whole_byte;
  char byte_chars[3] = {'\0','\0','\0'};

  int i;
  for (i = 0; i < [hexString length]/2; i++) {
    byte_chars[0] = [hexString characterAtIndex:i * 2];
    byte_chars[1] = [hexString characterAtIndex:i * 2 + 1];
    whole_byte = strtol(byte_chars, NULL, 16);
    [data appendBytes:&whole_byte length:1];
  }

  return data;
}

+ (NSString *)sanitiseBeaconID:(NSString *)beaconID {
  NSString *nospaces = [beaconID stringByReplacingOccurrencesOfString:@" " withString:@""];
  if ([nospaces rangeOfString:@"0x"].location == 0) {
    return [nospaces substringWithRange:NSMakeRange(2, [nospaces length] - 2)];
  } else {
    return nospaces;
  }
}

@end






