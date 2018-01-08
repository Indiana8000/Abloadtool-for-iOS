//
//  AT_GalleryTableViewController.m
//  Abloadtool
//
//  Created by Andreas Kreisl on 19.10.17.
//  Copyright © 2017 Andreas Kreisl. All rights reserved.
//

#define cImageCell @"ImageTableViewCell"

#import "AT_GalleryTableViewController.h"
#import "NetworkManager.h"


@interface AT_GalleryTableViewController ()

@end

@implementation AT_GalleryTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(doRefresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    self.navigationItem.title = NSLocalizedString(@"Gallery", @"Navigation Title");
    //self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(doRefresh:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(doAddGallery:)];

    [self.tableView registerClass:[AT_ImageTableViewCell class] forCellReuseIdentifier:cImageCell];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated {
    if([[[NetworkManager sharedManager] loggedin] intValue] == 0) {
        [[NetworkManager sharedManager] showLoginWithViewController:[self parentViewController] andCallback:^(void) {
            [self doRefresh:nil];
        }];
    } else if ([[[NetworkManager sharedManager] loggedin] intValue] == -1) {
        [[NetworkManager sharedManager] tokenCheckWithSuccess:^(NSDictionary *responseObject) {
            [self doRefresh:nil];
        }  failure:^(NSString *failureReason, NSInteger statusCode) {
            if([[[NetworkManager sharedManager] loggedin] intValue] == 0) {
                [self doRefresh:nil];
            } else {
                [NetworkManager showMessage:failureReason];
            }
        }];
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[NetworkManager sharedManager] gallery] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cImageCell forIndexPath:indexPath];

    cell.textLabel.text = [[[[NetworkManager sharedManager] gallery] objectAtIndex:indexPath.row] objectForKey:@"_name"];
    cell.detailTextLabel.text = [[[[NetworkManager sharedManager] gallery] objectAtIndex:indexPath.row] objectForKey:@"_desc"];
    
    NSString *tmpURL = [NSString stringWithFormat:@"https://www.abload.de/mini/%@", [[[[NetworkManager sharedManager] gallery] objectAtIndex:indexPath.row] objectForKey:@"_cover"]];
    [cell.imageView setImageWithURL:[NSURL URLWithString:tmpURL] placeholderImage:[UIImage imageNamed:@"AppIcon"]];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self doDeleteGallery:indexPath.row];
    }
}

#pragma mark - RefreshController

- (void)doRefresh:(id)sender {
    if([[[NetworkManager sharedManager] loggedin] intValue] == 1) {
        [[NetworkManager sharedManager] getGalleryList:^(NSDictionary *responseObject) {
            [self setLastRefresh];
            [[self refreshControl] endRefreshing];
            [self.tableView reloadData];
        } failure:^(NSString *failureReason, NSInteger statusCode) {
            [[self refreshControl] endRefreshing];
            [NetworkManager showMessage:failureReason];
        }];
    } else if ([[[NetworkManager sharedManager] loggedin] intValue] == -1) {
        [[NetworkManager sharedManager] tokenCheckWithSuccess:^(NSDictionary *responseObject) {
            [self doRefresh:nil];
        }  failure:^(NSString *failureReason, NSInteger statusCode) {
            if([[[NetworkManager sharedManager] loggedin] intValue] == 0) {
                [self doRefresh:sender];
            } else {
                [NetworkManager showMessage:failureReason];
            }
        }];
    } else {
        [[NetworkManager sharedManager] showLoginWithViewController:[self parentViewController] andCallback:^(void) {
            [self doRefresh:sender];
        }];
        [[self refreshControl] endRefreshing];
    }
}

- (void)setLastRefresh {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"]];
    [formatter setDateFormat:@"d. MMM, H:mm"];
    NSString *lastUpdated = [NSString stringWithFormat:NSLocalizedString(@"Letzte Aktualisierung am %@", @"Gallery Refresh"),
                             [formatter stringFromDate:[NSDate date]]];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:lastUpdated];
}

#pragma mark - Manage Gallerys

- (void)doAddGallery:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Abloadtool"
                                                                   message:NSLocalizedString(@"Name and Description of the new Gallery", @"Name and Description of the new Gallery")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Create", @"Create") style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [[NetworkManager sharedManager] showProgressHUD];
                                                   [[NetworkManager sharedManager] createGalleryWithName:[[alert.textFields objectAtIndex:0] text] andDesc:[[alert.textFields objectAtIndex:1] text] success:^(id responseObject) {
                                                       [[NetworkManager sharedManager] hideProgressHUD];
                                                       [self.tableView reloadData];
                                                   } failure:^(NSString *failureReason, NSInteger statusCode) {
                                                       [[NetworkManager sharedManager] hideProgressHUD];
                                                       [NetworkManager showMessage:failureReason];
                                                   }];
                                               }];
    [alert addAction:ok];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
    [alert addAction:cancel];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Name", @"Name");
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Description", @"Description");
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doDeleteGallery:(NSInteger) row {
    long gid = [[[[[NetworkManager sharedManager] gallery] objectAtIndex:row] objectForKey:@"_id"] intValue];
    long bc = [[[[[NetworkManager sharedManager] gallery] objectAtIndex:row] objectForKey:@"_images"] intValue];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Abloadtool"
                                                                   message:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the Gallery:\r\n%@", @"Do you really want to delete the Gallery:\r\n%@"), [[[[NetworkManager sharedManager] gallery] objectAtIndex:row] objectForKey:@"_name"]]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes, only the Gallery", @"Yes, only the Gallery") style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [[NetworkManager sharedManager] deleteGalleryWithID:gid andImages:0 success:^(NSDictionary *responseObject) {
                                                       [self.tableView reloadData];
                                                   } failure:^(NSString *failureReason, NSInteger statusCode) {
                                                       [NetworkManager showMessage:failureReason];
                                                   }];
                                               }];
    [alert addAction:ok];
    
    UIAlertAction *ok2 = [UIAlertAction actionWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Yes, and all %ld images", @"Yes, and all %ld images"), bc] style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [[NetworkManager sharedManager] deleteGalleryWithID:gid andImages:1 success:^(NSDictionary *responseObject) {
                                                       [self.tableView reloadData];
                                                   } failure:^(NSString *failureReason, NSInteger statusCode) {
                                                       [NetworkManager showMessage:failureReason];
                                                   }];
                                               }];
    [alert addAction:ok2];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"No, changed my mind", @"No, changed my mind") style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
    [alert addAction:cancel];

    
    [self presentViewController:alert animated:YES completion:nil];
}


@end
