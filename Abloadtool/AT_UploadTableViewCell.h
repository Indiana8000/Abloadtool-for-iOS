//
//  AT_UploadTableViewCell.h
//  Abloadtool
//
//  Created by Andreas Kreisl on 08.01.18.
//  Copyright © 2018 Andreas Kreisl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AFNetworking/UIImageView+AFNetworking.h>
#import "AT_ImageTableViewCell.h"

@interface AT_UploadTableViewCell : AT_ImageTableViewCell
    @property UIProgressView* progressView;
@end
