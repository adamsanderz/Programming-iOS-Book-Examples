

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>


@interface ViewController ()
@property (nonatomic, strong) NSTimer* timer;
@property (nonatomic, strong) MPMediaItemCollection* q;
@property (nonatomic, strong) AVQueuePlayer* qp;
@property (nonatomic, strong) NSMutableArray* assets;
@property (nonatomic, weak) IBOutlet UIProgressView *p;
@property (nonatomic, weak) IBOutlet UILabel *label;

@end

@implementation ViewController {
    int _curnum;
    int _total;
}

@synthesize timer, q, qp, assets=_assets;

- (IBAction)doPlayAllShortSongs:(id)sender {
    MPMediaQuery* query = [MPMediaQuery songsQuery];
    NSMutableArray* marr = [NSMutableArray array];
    for (MPMediaItem* song in query.items) {
        CGFloat dur = 
        [[song valueForProperty:MPMediaItemPropertyPlaybackDuration] floatValue];
        if (dur < 30)
            [marr addObject: song];
    }
    if ([marr count] == 0) {
        NSLog(@"No songs that short!");
        return;
    }
    self.assets = [NSMutableArray array];
    for (MPMediaItem* item in marr) {
        AVPlayerItem* pi = [[AVPlayerItem alloc] initWithURL:
                            [item valueForProperty:MPMediaItemPropertyAssetURL]];
        [self.assets addObject:pi];
    }
    
    self->_curnum = 0;
    self->_total = [self.assets count];
    
    self.qp = [AVQueuePlayer queuePlayerWithItems:[self.assets objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,3)]]];
    [self.assets removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,3)]];
               
                                                   
    [self.qp addObserver:self forKeyPath:@"currentItem" options:0 context:NULL];
    [self.qp play];
    [self performSelector:@selector(changed)];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    

    // added a progress view as on p. 674 
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    [self.timer fire];
}

- (void) changed {
    
    AVPlayerItem* item = self.qp.currentItem;
    NSArray* arr = item.asset.commonMetadata;
    arr = [AVMetadataItem metadataItemsFromArray:arr 
                                         withKey:AVMetadataCommonKeyTitle 
                                        keySpace:AVMetadataKeySpaceCommon];
    AVMetadataItem* met = arr[0];
    [met loadValuesAsynchronouslyForKeys:@[@"value"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.label.text = [NSString stringWithFormat:@"%i of %i: %@",
                                ++self->_curnum, self->_total, [met valueForKey:@"value"]];
            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:@{MPMediaItemPropertyTitle: [met valueForKey:@"value"]}];
        });
    }];
    if (![self.assets count])
        return;
    AVPlayerItem* newItem = (self.assets)[0];
    [self.qp insertItem:newItem afterItem:[self.qp.items lastObject]];
    [self.assets removeObjectAtIndex:0];
    
    [self.timer fire];
}

- (void) timerFired: (id) dummy {
    if (self.qp.rate < 0.01)
        self.p.hidden = YES;
    else {
        self.p.hidden = NO;
        AVPlayerItem* item = self.qp.currentItem;
        CMTime cur = self.qp.currentTime;
        CMTime dur = item.duration;
        self.p.progress = CMTimeGetSeconds(cur)/CMTimeGetSeconds(dur);
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem"])
        [self changed];
}

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    UIEventSubtype rc = event.subtype;
    NSLog(@"hey, I got a remote event! %i", rc);
    if (rc == UIEventSubtypeRemoteControlPlay)
        [self.qp play];
    else if (rc == UIEventSubtypeRemoteControlStop)
        [self.qp pause];
    else if (rc == UIEventSubtypeRemoteControlTogglePlayPause) { // likeliest
        if (self.qp.rate > 0.1)
            [self.qp pause];
        else
            [self.qp play];
    }
}


@end
