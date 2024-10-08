//
//  ShareViewController.m
//  AbloadtoolShare
//
//  Created by Andreas Kreisl on 15.02.18.
//  Copyright © 2018 Andreas Kreisl. All rights reserved.
//

#import "ShareViewController.h"

@interface ShareViewController ()
@property NSNumber* imagesToTransfere;
@property NSNumber* imagesSuccess;
@property NSNumber* imagesFailed;

@end

@implementation ShareViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Abloadtool", @"Abloadtool");

    //NSURL* securityPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.de.bluepaw.Abloadtool2"];
    //NSString* filePath = [[securityPath path] stringByAppendingPathComponent:@"plugin.log"];
    //freopen([filePath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        // nothing todo
    }];
    
    self.imagesSuccess = [NSNumber numberWithInt:0];
    self.imagesFailed = [NSNumber numberWithInt:0];

    NSExtensionItem* extensionItem = self.extensionContext.inputItems[0];
    self.imagesToTransfere = [NSNumber numberWithLong: extensionItem.attachments.count];
    [self addToLog:[NSString stringWithFormat:@"imagesToTransfere: %ld", [self.imagesToTransfere longValue]]];

    [self didSelectPost];
}

- (NSArray *)configurationItems {
    return @[];
}

- (BOOL)isContentValid {
    return YES;
}

- (void)didSelectPost {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.de.bluepaw.Abloadtool2"];
    
    NSURL* securityPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.de.bluepaw.Abloadtool2"];
    NSString* filePath = [[securityPath path] stringByAppendingPathComponent:@"images"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [self addToLog:[NSString stringWithFormat:@"filePath: %@", filePath]];
    
    if(securityPath) {
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.includeHiddenAssets = YES;
        _assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
        _imageManager = [[PHCachingImageManager alloc] init];
        _imageList = [[NSMutableDictionary alloc] init];
        for(PHAsset* asset in _assetsFetchResults) {
            [_imageList setObject:asset forKey:[asset valueForKey:@"filename"]];
        }
        [self addToLog:[NSString stringWithFormat:@"PHAsset Count: %ld", _assetsFetchResults.count]];

        NSExtensionItem* extensionItem = self.extensionContext.inputItems[0];
        for(NSItemProvider* itemProvider in extensionItem.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:itemProvider.registeredTypeIdentifiers.firstObject]) {
                [self addToLog:[NSString stringWithFormat:@"itemProvider Type: %@", itemProvider.registeredTypeIdentifiers.firstObject]];
                [itemProvider loadItemForTypeIdentifier:itemProvider.registeredTypeIdentifiers.firstObject options:nil completionHandler:^(id<NSSecureCoding>  _Nullable item, NSError * _Null_unspecified error) {
                    [self addToLog:[NSString stringWithFormat:@"itemProvider Data: %@", item]];
                    NSData* imgData = nil;
                    if( [(NSObject*)item isKindOfClass:[NSURL class]]) {
                        imgData = [NSData dataWithContentsOfURL:(NSURL*)item];
                        if(imgData == nil)
                            imgData = [self fetchImage:[[(NSURL*)item pathComponents] lastObject]];
                    } else if( [(NSObject*)item isKindOfClass:[UIImage class]]) {
                        imgData = UIImageJPEGRepresentation((UIImage*)item, 0.92);
                    } else if( [(NSObject*)item isKindOfClass:[NSData class]]) {
                        imgData = (NSData*)item;
                    }
                    if(imgData != nil) {
                        NSInteger shareCount;
                        if([defaults integerForKey:@"share_count"]) {
                            shareCount = [defaults integerForKey:@"share_count"] +1;
                        } else {
                            shareCount = 1;
                        }
                        
                        NSString* fileName = [filePath stringByAppendingPathComponent:[NSString stringWithFormat:@"shared.%ld.jpeg", shareCount]];
                        [imgData writeToFile:fileName atomically:YES];

                        [defaults setInteger:shareCount forKey:@"share_count"];
                        [defaults synchronize];
                        self.imagesSuccess = [NSNumber numberWithLong:([self.imagesSuccess longValue] -1)];
                    } else {
                        self.imagesFailed = [NSNumber numberWithLong:([self.imagesFailed longValue] -1)];
                    }
                    self.imagesToTransfere = [NSNumber numberWithLong:([self.imagesToTransfere longValue] -1)];
                    [self addToLog:[NSString stringWithFormat:@"imagesToTransfere: %ld", [self.imagesToTransfere longValue]]];
                    if([self.imagesToTransfere longValue] <= 0) {
                        if([self.imagesFailed longValue] > 0) {
                            [self showMessageAndProcess:[NSString stringWithFormat:NSLocalizedString(@"share_msg_failed %ld %ld", @"ShareExtension"), [self.imagesFailed longValue], extensionItem.attachments.count]];
                        } else {
                            [self processingDone];
                        }
                    }
                }];
            }
        }
    } else {
        [self showMessageAndDone:@"FATAL ERROR: Permission denied!"];
    }
}

- (void)processingDone {
    NSURL *destinationURL = [NSURL URLWithString:@"abloadtool://share"];
    // Get "UIApplication" class name through ASCII Character codes.
    NSString *className = [[NSString alloc] initWithData:[NSData dataWithBytes:(unsigned char []){0x55, 0x49, 0x41, 0x70, 0x70, 0x6C, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6F, 0x6E} length:13] encoding:NSASCIIStringEncoding];
    [self addToLog:[NSString stringWithFormat:@"className: %@", className]];
    if(NSClassFromString(className)) {
        [self addToLog:[NSString stringWithFormat:@"className: Found!"]];
        id object = [NSClassFromString(className) performSelector:@selector(sharedApplication)];
        [object performSelector:@selector(openURL:) withObject:destinationURL];
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    } else {
        [self addToLog:[NSString stringWithFormat:@"className: Show Alert!"]];
        NSExtensionItem* extensionItem = self.extensionContext.inputItems[0];
        [self showMessageAndDone:[NSString stringWithFormat:NSLocalizedString(@"share_msg_done %ld", @"ShareExtension"), extensionItem.attachments.count]];
    }
}

- (NSData*)fetchImage:(NSString*) filename {
    [self addToLog:[NSString stringWithFormat:@"fetchImage: %@", filename]];
    if([_imageList objectForKey:filename]) {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.synchronous = YES;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        __block NSData* tmp = nil;
        [_imageManager requestImageDataForAsset:[_imageList objectForKey:filename] options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            tmp = imageData;
        }];
        [self addToLog:[NSString stringWithFormat:@"fetchImage: Found"]];
        return tmp;
    } else {
        [self addToLog:[NSString stringWithFormat:@"fetchImage: Missed"]];
        return nil;
    }
}

- (void)showMessageAndDone:(NSString*) msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:msg
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_ok", @"Abloadtool") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMessageAndProcess:(NSString*) msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:msg                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_ok", @"Abloadtool") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self processingDone];
    }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addToLog:(NSString*)msg {
    NSLog(@"%@", msg);
}

@end
