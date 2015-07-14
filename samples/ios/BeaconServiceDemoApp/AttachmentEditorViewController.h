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

#import <UIKit/UIKit.h>

@class AttachmentEditorViewController;
@protocol AttachmentEditorViewControllerDelegate <NSObject>

- (void)attachmentEditor:(AttachmentEditorViewController *)viewController
        didAddAttachment:(NSString *)name
              attachment:(NSDictionary *)attachment;

- (void)attachmentEditor:(AttachmentEditorViewController *)viewController
     didDeleteAttachment:(NSString *)name
              attachment:(NSDictionary *)attachment;

@end

@interface AttachmentEditorViewController : UIViewController
@property(nonatomic, strong) NSString *beaconID;
@property(nonatomic, strong) NSString *likelyNamespaceName;
@property(nonatomic, strong) NSDictionary *attachmentData;
@property(nonatomic, weak) id<AttachmentEditorViewControllerDelegate> delegate;

@end
