//
//  searchResultsModel.m
//  lection14
//
//  Created by iOS-School-1 on 04.05.17.
//  Copyright © 2017 iOS-School-1. All rights reserved.
//

#import "SLVSearchResultsModel.h"
#import "SLVImageDownloadOperation.h"
#import "SLVImageProcessing.h"
#import "SLVNetworkManager.h"
#import "SLVCache.h"

@interface SLVSearchResultsModel()

@property (nonatomic, assign) NSUInteger page;
@property (nonatomic, strong) NSOperationQueue *imageDownloadQueue;
@property (nonatomic, strong) NSOperationQueue *imageFilteringQueue;
@property (nonatomic, strong) SLVNetworkManager *networkManager;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation SLVSearchResultsModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _imageDownloadQueue = [NSOperationQueue new];
        _imageDownloadQueue.name = @"imageDownloadQueue";
        _imageFilteringQueue = [NSOperationQueue new];
        _imageFilteringQueue.name = @"imageFilteringQueue";
        _imageFilteringQueue.qualityOfService = NSQualityOfServiceUserInitiated;
        _session = [NSURLSession sessionWithConfiguration:
                    [NSURLSessionConfiguration defaultSessionConfiguration]];
        _imageCache = [SLVCache cacheWithCapacity:40];
        _filteredImagesCache = [SLVCache cacheWithCapacity:5];
        _page = 1;
        _items = [NSArray new];
    }
    return self;
}

#pragma mark - getItems

- (void)getItemsForRequest:(NSString*) request withCompletionHandler:(voidBlock)completionHandler {
    NSString *normalizedRequest = [request stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSString *escapedString = [normalizedRequest stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    NSString *apiKey = @"&api_key=6a719063cc95dcbcbfb5ee19f627e05e";
    NSString *sortBy = @"interestingness-desc";
    NSString *urls = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.search&format=json&nojsoncallback=1&sort=%@&per_page=10&tags=%@%@&page=%lu", sortBy, escapedString, apiKey, self.page];
    NSURL *url = [NSURL URLWithString:urls];
    [SLVNetworkManager getModelWithSession:self.session fromURL:url withCompletionHandler:^(NSDictionary *json) {
        NSArray *newItems = [self parseData:json];
        self.items = [self.items arrayByAddingObjectsFromArray:newItems];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler();
        });
    }];
    self.page++;
}

- (NSArray *)parseData:(NSDictionary *)json {
    if (json) {
        NSMutableArray *parsingResults = [NSMutableArray new];
        for (NSDictionary * dict in json[@"photos"][@"photo"]) {
            [parsingResults addObject:[SLVItem itemWithDictionary:dict]];
        }
        return [parsingResults copy];
    } else {
        return nil;
    }
}

#pragma mark - Working with images

- (void)loadImageForIndexPath:(NSIndexPath *)indexPath withCompletionHandler:(voidBlock)completionHandler {
    SLVItem *currentItem = self.items[indexPath.row];
    UIImage *image = [self.imageCache objectForKey:indexPath];
    if (!image) {
        SLVImageDownloadOperation *imageDownloadOperation = [[SLVImageDownloadOperation alloc] initWithNetworkSession:self.session item:currentItem indexPath:indexPath cache:self.imageCache];
        imageDownloadOperation.completionBlock = ^{completionHandler(); };
        
        for (SLVImageDownloadOperation *operation in self.imageDownloadQueue.operations) {
            if ([operation.name isEqualToString:imageDownloadOperation.name]) {
                [operation resume];
                return;
            }
        }
        [self.imageDownloadQueue addOperation:imageDownloadOperation];
    } else {
        if (completionHandler) completionHandler();
    }
}

- (void)filterItemAtIndexPath:(NSIndexPath *)indexPath filter:(BOOL)filter withCompletionBlock:(void(^)(UIImage *filteredImage))completion {
    UIImage *image = [self.imageCache objectForKey:indexPath];
    if (filter) {
        NSOperation *filterOperation = [NSBlockOperation blockOperationWithBlock:^{
            SLVItem *currentItem = self.items[indexPath.row];
            currentItem.filtered = YES;
            UIImage *image = [self.imageCache objectForKey:indexPath];
            UIImage *filteredImage = [SLVImageProcessing applyFilterToImage:image];
            completion(filteredImage);
        }];
        if (image) {
            [self.imageFilteringQueue addOperation:filterOperation];
        } else {
            for (SLVImageDownloadOperation *operation in self.imageDownloadQueue.operations) {
                if ([operation.indexPath isEqual:indexPath]) {
                    [filterOperation addDependency:operation];
                    [self.imageFilteringQueue addOperation:filterOperation];
                    break;
                }
            }
        }
    } else {
        self.items[indexPath.row].filtered = NO;
        [self.filteredImagesCache removeObjectForKey:indexPath];
        completion(image);
    }
}

#pragma mark - Utilities

- (void)pauseOperations {
    for (SLVImageDownloadOperation *operation in self.imageDownloadQueue.operations) {
        [operation pause];
    }
}

- (void)clearModel {
    self.items = [NSArray new];
    [self pauseOperations];
    [self.imageCache clear];
    self.page = 0;
}

@end
