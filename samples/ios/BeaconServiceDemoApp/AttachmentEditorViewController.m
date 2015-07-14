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

#import "AttachmentEditorViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "BSDAdminAPI.h"


@interface AttachmentEditorViewController ()
@property (strong, nonatomic) IBOutlet UITextField *namespacedTypeTextField;
@property (strong, nonatomic) IBOutlet UITextView *attachmentDataTextView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *textViewBottomConstraint;
@property (strong, nonatomic) IBOutlet UIButton *saveButton;
@property (strong, nonatomic) IBOutlet UIButton *cancelButton;

@end

@implementation AttachmentEditorViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  _attachmentDataTextView.layer.borderWidth = 1.0f;
  _attachmentDataTextView.layer.borderColor =
      [[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1] CGColor];
  _attachmentDataTextView.layer.cornerRadius = 4.0f;

  if (_attachmentData) {
    _namespacedTypeTextField.text = _attachmentData[@"namespacedType"];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:_attachmentData[@"data"]
                                                       options:0];
    
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    _attachmentDataTextView.text = text;
    [_saveButton setTitle:@"Delete" forState:UIControlStateNormal];
    [_saveButton setTitle:@"Delete" forState:UIControlStateSelected];
    [_saveButton setTitle:@"Delete" forState:UIControlStateHighlighted];

    _namespacedTypeTextField.enabled = NO;
    _attachmentDataTextView.editable = NO;

    [_attachmentDataTextView
        setSelectedTextRange:[_attachmentDataTextView
            textRangeFromPosition:_attachmentDataTextView.beginningOfDocument
                       toPosition:_attachmentDataTextView.endOfDocument]];
    
  } else if (_likelyNamespaceName) {
    _namespacedTypeTextField.text = [NSString stringWithFormat:@"%@/", _likelyNamespaceName];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWillShow:)
                                               name:UIKeyboardWillShowNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWillHide:)
                                               name:UIKeyboardWillHideNotification
                                             object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cancelButtonPressed:(id)sender {
  [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)saveButtonPressed:(id)sender {
  _saveButton.enabled = NO;
  _cancelButton.enabled = NO;

  if (!_attachmentData) {
    // Not valid to have empty namespacedType or data fields.
    if ([_namespacedTypeTextField.text length] == 0
        || [_attachmentDataTextView.text length] == 0) {
      UIAlertController* alert =
          [UIAlertController alertControllerWithTitle:@"Missing Data"
                                              message:@"You must enter a namespaced-type and data."
                                       preferredStyle:UIAlertControllerStyleAlert];

      UIAlertAction* defaultAction =
          [UIAlertAction actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {}];

      [alert addAction:defaultAction];
      [self presentViewController:alert animated:YES completion:nil];
      _saveButton.enabled = YES;
      _cancelButton.enabled = YES;
      return;
    } else {
      NSArray *parts = [_namespacedTypeTextField.text componentsSeparatedByString:@"/"];
      if ([parts count] != 2 || [parts[0] length] == 0 || [parts[1] length] == 0) {
        // The API doesn't have the best checks here for this and can produce some confusing error
        // messages, so I added a bit of extra code to help make sure this happens correctly.
        UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Missing Data"
                                            message:
            @"Namespaced types must be of the form \"ns/type\"."
                                     preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* defaultAction =
        [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {}];

        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        _saveButton.enabled = YES;
        _cancelButton.enabled = YES;
        return;
      }
    }

    // First time saving the attachment? Just go ahead and "add" it.
    if (!_attachmentData) {
      [BSDAdminAPI addAttachmentToBeaconID:_beaconID
                           withNamespacedType:_namespacedTypeTextField.text
                               attachmentData:_attachmentDataTextView.text
                            completionHandler:
          ^(NSDictionary *attachment, NSDictionary *errorInfo) {
            dispatch_async(dispatch_get_main_queue(), ^() {
              if (attachment) {
                if ([_delegate
                     respondsToSelector:@selector(attachmentEditor:didAddAttachment:attachment:)]) {
                  [_delegate attachmentEditor:self
                             didAddAttachment:attachment[@"attachmentName"]
                                   attachment:attachment];
                }
                [self dismissViewControllerAnimated:YES completion:NULL];
              } else {
                [self displayErrorPopupForErrorInfo:errorInfo];
              }
            });
            _saveButton.enabled = YES;
            _cancelButton.enabled = YES;
          }
      ];
    }
  } else {
    UIAlertController *alertController;
    UIAlertAction *destroyAction;
    UIAlertAction *otherAction;

    alertController = [UIAlertController alertControllerWithTitle:@"Delete Attachment?"
                                                          message:@"This cannot be undone."
                                                   preferredStyle:
        UIAlertControllerStyleActionSheet];

    destroyAction = [UIAlertAction actionWithTitle:@"Delete"
                                             style:UIAlertActionStyleDestructive
                                           handler:
        ^(UIAlertAction *action) {
          // Disable this for network access.
          _saveButton.enabled = NO;

          [BSDAdminAPI deleteAttachmentForBeaconID:_beaconID
                                                named:_attachmentData[@"attachmentName"]
                                    completionHandler:
              ^(NSDictionary *errorInfo) {
                _saveButton.enabled = YES;
                if (errorInfo) {
                  [self displayErrorPopupForErrorInfo:errorInfo];
                } else {
                  dispatch_async(dispatch_get_main_queue(), ^() {
                    if ([_delegate
                         respondsToSelector:
                         @selector(attachmentEditor:didDeleteAttachment:attachment:)]) {
                      [_delegate attachmentEditor:self
                              didDeleteAttachment:_attachmentData[@"attachmentName"]
                                       attachment:_attachmentData];
                    }

                    [self dismissViewControllerAnimated:YES completion:NULL];
                  });
                }

                _saveButton.enabled = YES;
                _cancelButton.enabled = YES;
              }
           ];
        }
    ];
    otherAction = [UIAlertAction actionWithTitle:@"Cancel"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                           _saveButton.enabled = YES;
                                           _cancelButton.enabled = YES;
                                         }];

    [alertController addAction:destroyAction];
    [alertController addAction:otherAction];
    [alertController setModalPresentationStyle:UIModalPresentationPopover];

    [self presentViewController:alertController animated:YES completion:nil];
  }
}

- (void)keyboardWillShow:(NSNotification *)notification {
  NSDictionary *info = [notification userInfo];
  NSValue *keyboardFrame = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
  NSTimeInterval animationDuration =
      [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  CGRect keyboardFrameRect = [keyboardFrame CGRectValue];

  CGFloat height = keyboardFrameRect.size.height;

  self.textViewBottomConstraint.constant = height + 2; // +2 for some padding.

  [UIView animateWithDuration:animationDuration animations:^{
    [self.view layoutIfNeeded];
  }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
}


- (void)displayErrorPopupForErrorInfo:(NSDictionary *)errorInfo {
  NSString *title, *body;
  if (errorInfo[kRequestErrorMessage]) {
    body = errorInfo[kRequestErrorMessage];
    title = errorInfo[kRequestErrorStatus];
  } else {
    title = @"Error";
    body = errorInfo[kRequestErrorStatus];
  }

  dispatch_async(dispatch_get_main_queue(), ^() {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:title
                                            message:body
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil];
    [alertController addAction:ok];
    [self presentViewController:alertController animated:YES completion:nil];
  });
}

@end
