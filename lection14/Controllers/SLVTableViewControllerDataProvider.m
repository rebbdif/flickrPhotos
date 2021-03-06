//
//  SLVTableViewControllerDataSource.m
//  lection14
//
//  Created by 1 on 27.05.17.
//  Copyright © 2017 iOS-School-1. All rights reserved.
//

#import "SLVTableViewControllerDataProvider.h"
#import "SLVSearchResultsModel.h"
#import "SLVTableViewCell.h"
#import "SLVCache.h"

@interface SLVTableViewControllerDataProvider() <CellDelegate>

@property (nonatomic, weak) SLVSearchResultsModel *model;
@property (nonatomic, weak) UITableView *tableView;

@end

@implementation SLVTableViewControllerDataProvider

- (instancetype)initWithModel:(SLVSearchResultsModel *)model tableView:(UITableView *)tableView {
    self = [super init];
    if (self) {
        _model = model;
        _tableView = tableView;
    }
    return self;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.model.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SLVTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SLVTableViewCell class]) forIndexPath:indexPath];
    [self configureCell:cell forTableView:tableView indexPath:indexPath];
    return cell;
}

- (void)configureCell:(SLVTableViewCell *)cell forTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    cell.delegate = self;
    SLVItem *currentItem = self.model.items[indexPath.row];
    cell.indexPath = indexPath;
    [cell.applyFilterSwitch setOn:currentItem.filtered];
    UIImage *image = [self.model.imageCache objectForKey:indexPath];
    if (!image) {
        if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
            [self.model loadImageForIndexPath:indexPath withCompletionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    SLVTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                    cell.photoImageView.image = [self.model.imageCache objectForKey: indexPath];
                    [cell.activityIndicator stopAnimating];
                    cell.progressView.hidden = YES;
                });
            }];
        }
        cell.activityIndicator.hidden = NO;
        [cell.activityIndicator startAnimating];
        cell.progressView.hidden = NO;
        cell.progressView.progress = currentItem.downloadProgress;
    } else {
        if (currentItem.filtered) {
            UIImage *filteredImage = [self.model.filteredImagesCache objectForKey:indexPath];
            if (!filteredImage) {
                __weak typeof(self) weakSelf = self;
                [self.model filterItemAtIndexPath:indexPath filter:YES withCompletionBlock:^(UIImage *filteredImage) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        SLVTableViewCell *cell = [weakSelf.tableView cellForRowAtIndexPath:indexPath];
                        cell.photoImageView.image = filteredImage;
                    });
                }];
            } else {
                cell.photoImageView.image = filteredImage;
            }
        } else {
            cell.photoImageView.image = image;
        }
    }
}

#pragma mark - CellDelegate

- (void)didClickSwitch:(UISwitch *)switcher atIndexPath:(NSIndexPath *)indexPath {
    if (switcher.on) {
        [self.model filterItemAtIndexPath:indexPath filter:YES withCompletionBlock:^(UIImage *image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SLVTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                cell.photoImageView.image = image;
            });
        }];
    } else {
        [self.model filterItemAtIndexPath:indexPath filter:NO withCompletionBlock:^(UIImage *image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SLVTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                cell.photoImageView.image = image;
            });
        }];
    }
}

@end
