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

#import "RegisterBeaconViewController.h"

#import "AppDelegate.h"
#import "AttachmentEditorViewController.h"
#import "BeaconInfoTableViewCell.h"
#import "BeaconRegistrationEditorViewController.h"
#import "BSDAdminAPI.h"


static NSString *const kShowAttachmentEditorSegueName = @"ShowAttachmentEditorSegue";
static NSString *const kShowBeaconRegistrationEditorSegueName =
    @"ShowBeaconRegistrationEditorSegue";
static NSString *const kCellIdentifier = @"table_view_cell";

NSString *GetNamespacedType(NSString *namespacedType) {
  NSArray *parts = [namespacedType componentsSeparatedByString:@"/"];
  if ([parts count] != 2) {
    return nil;
  }

  return parts[0];
}

@interface RegisterBeaconViewController ()
    <AttachmentEditorViewControllerDelegate, BeaconRegistrationEditorViewControllerDelegate> {
  BOOL _registered;
  NSArray *_attachments;

  /**
   * Although it's possible that, in the future, multiple namespaces will be possible for any given
   * account, right now, only one is. We'll fetch that from the server and set that on the
   * Attachment Editor whenever we bring that up.
   */
  NSString *_registeredNamespace;
}
@property (strong, nonatomic) IBOutlet UILabel *beaconIDLabel;
@property (strong, nonatomic) IBOutlet UITableView *actionTableView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *scanningThrobber;

@end

@implementation RegisterBeaconViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  _scanningThrobber.hidden = YES;
  _registered = (_beaconData != nil);

  // If this beacon is registered, then go fetch its attachment data (if any).
  if (_registered) {
    _scanningThrobber.hidden = NO;
    [_scanningThrobber startAnimating];
    [BSDAdminAPI attachmentsForBeaconID:_beaconID completionHandler:
        ^(NSArray *attachments, NSDictionary *errorInfo) {
          NSLog(@"%@", attachments);
          NSLog(@"%@", errorInfo);

          _attachments = attachments;

          dispatch_async(dispatch_get_main_queue(), ^{
            [self finishAttachmentDownload];
          });

        }
    ];
  }

  [BSDAdminAPI listAvailableNamespaces:^(NSArray *namespaces, NSDictionary *errorInfo) {
    if (namespaces) {
      if (namespaces[0][@"namespaceName"]) {
        _registeredNamespace = namespaces[0][@"namespaceName"];
      }
    }
  }];

  _beaconIDLabel.text = _beaconID;

  _actionTableView.rowHeight = 80;
}

- (void)finishAttachmentDownload {
  [_scanningThrobber stopAnimating];
  _scanningThrobber.hidden = YES;

  [_actionTableView reloadData];
}

- (IBAction)closeButtonPressed:(id)sender {
  [self dismissViewControllerAnimated:YES completion:NULL];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  if (_registered) {
    return 2;
  } else {
    return 1;
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  if (section == 1) {
    return 30;
  } else {
    return 0;
  }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    return @"";//Beacon Information";
  } else {
    return @"Attachments";
  }
}


- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0) {
    if (_registered) {
      return 205;
    } else {
      return 75;
    }
  } else {
    return 55;
  }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return 1;
  } else {
    return 1 + [_attachments count];
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0) {
    [self performSegueWithIdentifier:kShowBeaconRegistrationEditorSegueName sender:self];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
  } else {
    [self performSegueWithIdentifier:kShowAttachmentEditorSegueName sender:self];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
  }
}

- (void)tableView:(UITableView *)tableView
    willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
  view.tintColor = [UIColor whiteColor];// colorWithRed:0.93 green:0.93 blue:0.93 alpha:1];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

  if (indexPath.section == 0) {
    if (_registered) {
      BeaconInfoTableViewCell *cell =
          [tableView dequeueReusableCellWithIdentifier:@"BeaconInfoTableViewCell"];
      cell.beaconID = _beaconID;
      cell.beaconType = _beaconData[@"advertisedId"][@"type"];
      if (_beaconData[@"placeId"]) {
        cell.beaconLocation = @{ @"placeId" : _beaconData[@"placeId"] };
      } else {
        cell.beaconLocation = @{ @"latLng" : _beaconData[@"latLng"] };
      }

      cell.beaconStatus = _beaconData[@"status"];
      CGRect f = cell.frame;
      f.size.height = 100;
      cell.frame = f;
      return cell;
    } else {
      UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
      if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kCellIdentifier];
        cell.textLabel.font = [UIFont fontWithName:@"Arial" size:18.0];
      }

      cell.imageView.image = [UIImage imageNamed:@"database-add"];
      cell.textLabel.text = @"Register Eddystone";
      cell.textLabel.textColor = [UIColor colorWithRed:0 green:0.596 blue:0.392 alpha:1];
      return cell;
    }
  } else {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                    reuseIdentifier:kCellIdentifier];
      cell.textLabel.font = [UIFont fontWithName:@"Arial" size:18.0];
    }

    if (indexPath.row == 0) {
      cell.imageView.image = [UIImage imageNamed:@"add"];
      cell.textLabel.text = @"Add Attachment";
      cell.textLabel.textColor = [UIColor colorWithRed:0 green:0.392 blue:0.596 alpha:1];
    } else {
      cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:14.0];
      cell.textLabel.text = _attachments[indexPath.row - 1][@"namespacedType"];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
  }
}

/**
 * Tell the incoming view controller the beaconID of the selected row if we're doing a
 * show register beacon segue.
 */
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:kShowAttachmentEditorSegueName]) {
    NSIndexPath *indexPath = [_actionTableView indexPathForSelectedRow];
    AttachmentEditorViewController *vc = segue.destinationViewController;
    vc.beaconID = _beaconID;
    vc.delegate = self;
    vc.likelyNamespaceName = _registeredNamespace;
    if (indexPath.row > 0) {
      vc.attachmentData = _attachments[indexPath.row - 1];
    }
  } else {
    BeaconRegistrationEditorViewController *vc = segue.destinationViewController;
    vc.existingBeaconInfo = _beaconData;
    vc.beaconID = _beaconID;
    vc.delegate = self;
  }
}

- (void)attachmentEditor:(AttachmentEditorViewController *)viewController
        didAddAttachment:(NSString *)name
              attachment:(NSDictionary *)attachment {
  NSMutableArray *newAttachments = [NSMutableArray arrayWithCapacity:[_attachments count] + 1];
  BOOL found = NO;
  for (NSDictionary *att in _attachments) {
    if ([att[@"attachmentName"] isEqualToString:name]) {
      found = YES;
      [newAttachments addObject:attachment];
    } else {
      [newAttachments addObject:att];
    }
  }

  if (!found) {
    [newAttachments addObject:attachment];
  }

  _attachments = newAttachments;
  [_actionTableView reloadData];
}

- (void)attachmentEditor:(AttachmentEditorViewController *)viewController
     didDeleteAttachment:(NSString *)name
              attachment:(NSDictionary *)attachment {
  NSMutableArray *newAttachments = [NSMutableArray arrayWithCapacity:[_attachments count]];
  for (NSDictionary *att in _attachments) {
    if (![att[@"attachmentName"] isEqualToString:name]) {
      [newAttachments addObject:att];
    }
  }

  _attachments = newAttachments;
  [_actionTableView reloadData];
}

- (void)beaconRegistrationEditor:(BeaconRegistrationEditorViewController *)editor
               didRegisterBeacon:(NSDictionary *)beaconInfo {
  _beaconData = beaconInfo;
  if ([_delegate
      respondsToSelector:@selector(beaconRegistrator:didUpdateBeaconInfo:forBeaconID:)]) {
    [_delegate beaconRegistrator:self didUpdateBeaconInfo:beaconInfo forBeaconID:_beaconID];
  }
  _registered = YES;
  [_actionTableView reloadData];
}

- (void)beaconRegistrationEditor:(BeaconRegistrationEditorViewController *)editor
                 didUpdateBeacon:(NSDictionary *)beaconInfo {
  _beaconData = beaconInfo;
  if ([_delegate
      respondsToSelector:@selector(beaconRegistrator:didUpdateBeaconInfo:forBeaconID:)]) {
    [_delegate beaconRegistrator:self didUpdateBeaconInfo:beaconInfo forBeaconID:_beaconID];
  }

  [_actionTableView reloadData];
}

@end
