//
//  StatusBarNotifierView.m
//  StatusBarNotifier
//
//  Created by Francesco Di Lorenzo on 05/09/12.
//  Copyright (c) 2012 Francesco Di Lorenzo. All rights reserved.
//

#import "FDStatusBarNotifierView.h"

NSTimeInterval const kTimeOnScreen = 2.0;

@interface FDStatusBarNotifierView ()

@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSTimer *showStatusBarTimer;

@end


@implementation FDStatusBarNotifierView

+ (instancetype)sharedInstance
{
    static FDStatusBarNotifierView *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[FDStatusBarNotifierView alloc] initWithMessage:@""];
        shared.manuallyHide = YES;
    });
    return shared;
}

#pragma mark - Init

- (id)init
{
    self = [super init];
    if (self) {
        self.clipsToBounds = YES;
        self.frame = CGRectMake(0, 20, [UIScreen mainScreen].bounds.size.width, 20);
        
        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, ([UIScreen mainScreen].bounds.size.width), 20)];
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
            self.messageLabel.textColor = [UIColor whiteColor];
        }else{
            // we might have to us white if the prefered statusbar style is UIStatusBarStyleLightContent
            self.messageLabel.textColor = [UIColor blackColor];
        }
        self.messageLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        self.messageLabel.font = [UIFont boldSystemFontOfSize:12];
        self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.shouldHideOnTap = NO;
        self.manuallyHide = YES;
        [self addSubview:self.messageLabel];
        
        self.timeOnScreen = kTimeOnScreen;
    }
    return self;
}

- (id)initWithMessage:(NSString *)message
{
    self = [self initWithMessage:message delegate:nil];
    if (self) {
        
    }
    return self;
    
}

- (id)initWithMessage:(NSString *)message delegate:(id<FDStatusBarNotifierViewDelegate>)delegate
{
    self = [self init];
    if (self) {
        self.delegate           = delegate;
        self.message            = message;
        self.messageLabel.text  = message;
    }
    return self;
}

#pragma mark - Presentation

- (BOOL)isShown
{
    return self.superview != nil;
}

- (void)showInWindow:(UIWindow *)window
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(willPresentNotifierView:)]) {
        [self.delegate willPresentNotifierView:self];
    }
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    [window addSubview:self];
    
    NSDictionary *attributes = @{NSFontAttributeName:self.messageLabel.font};
    CGFloat textWith = 0;
    
    // Load resources for iOS 7 or later
    CGRect textSize = [self.message boundingRectWithSize:CGSizeMake(MAXFLOAT, 20)
                                                 options:NSStringDrawingUsesFontLeading
                                              attributes:attributes
                                                 context:nil];
    
    textWith = textSize.size.width;
    
    if (textWith < self.messageLabel.frame.size.width) { // the message to display fits in the status bar view
        
        CGRect animationDestinationFrame;
        if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait) {
            animationDestinationFrame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 20);
        } else {
            animationDestinationFrame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, 20);
        }
        
        CGRect animationStartFrame = self.frame;
        if (CGRectGetMinY(animationStartFrame) > 0) {
            animationStartFrame.size.height = 0;
        }
        animationStartFrame.origin.y = - animationStartFrame.size.height;
        self.frame = animationStartFrame;
        [UIView animateWithDuration:.4
                         animations:^{
                             self.frame = animationDestinationFrame;
                         } completion:^(BOOL finished){
                             
                             if (self.delegate && [self.delegate respondsToSelector:@selector(didPresentNotifierView:)]) {
                                 [self.delegate didPresentNotifierView:self];
                             }
                             
                             if (!self.manuallyHide) {
                                 [self.showStatusBarTimer invalidate];
                                 self.showStatusBarTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeOnScreen
                                                                                            target:self
                                                                                          selector:@selector(hide)
                                                                                          userInfo:nil
                                                                                           repeats:NO];
                             }

                         }];
        
    } else {
        if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait) {
            CGRect frame = self.messageLabel.frame;
            CGFloat exceed = textWith - frame.size.width;
            frame.size.width = textWith;
            self.messageLabel.frame = frame;
            NSTimeInterval timeExceed = exceed / 60;
            [UIView animateWithDuration:.4 animations:^{
                self.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 20);
            } completion:^(BOOL finished){
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(didPresentNotifierView:)])
                    [self.delegate didPresentNotifierView:self];
                
                if (!self.manuallyHide) {
                    [self performSelector:@selector(hide)
                               withObject:nil
                               afterDelay:self.timeOnScreen + timeExceed];
                    
                    [self performSelector:@selector(doTextScrollAnimation:)
                               withObject:[NSNumber numberWithFloat:timeExceed]
                               afterDelay:self.timeOnScreen / 3];
                } else {
                    [self performSelector:@selector(doTextScrollAnimation:)
                               withObject:[NSNumber numberWithFloat:timeExceed]
                               afterDelay:kTimeOnScreen / 3];
                }

                
            }];
        } else {
            // add support for landscape
        }
    }
}

- (void)showAboveNavigationController:(UINavigationController *)navigationController
{
    CGRect frame = navigationController.navigationBar.frame;
    UIViewController *lastViewController = [navigationController.viewControllers lastObject];
    CGRect viewFrame = lastViewController.view.frame;
    
    if (!lastViewController.view.window) {
        [self performSelector:@selector(showAboveNavigationController:) withObject:navigationController afterDelay:0.2];// the view has not appeared yet.
    }else{
        [self showInWindow:navigationController.view.window];
        lastViewController.view.frame = viewFrame;
        
        navigationController.navigationBar.frame = frame;
        frame.size.height += frame.origin.y;
        frame.origin.y = -frame.origin.y;
        for (UIView *view in navigationController.navigationBar.subviews) {
            if ([view isKindOfClass:NSClassFromString(@"_UINavigationBarBackground")]) {
                for (UIView *view2 in view.subviews) {
                    if (![view2 isKindOfClass:[UIImageView class]]) {
                        view2.frame = frame;
                    }
                }
            }
        }
    }
}

- (void)hideAfter:(CGFloat)delay
{
    double delayInSeconds = delay;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self hide];
    });
}

- (void)hideWithCompletion:(void(^)())completion
{
    if (self.isHidden) {
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(willHideNotifierView:)]) {
        [self.delegate willHideNotifierView:self];
    }
    
    CGRect animationDestinationFrame;
    if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait) {
        animationDestinationFrame = CGRectMake(0, -20, [UIScreen mainScreen].bounds.size.width, 0);
    } else {
        animationDestinationFrame = CGRectMake(0, 20, [UIScreen mainScreen].bounds.size.height, 0);
    }
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO
                                            withAnimation:UIStatusBarAnimationSlide];
    [UIView animateWithDuration:.4
                     animations:^{
                         self.frame = animationDestinationFrame;
                     } completion:^(BOOL finished){
                         if (finished) {
                             
                             if (self.delegate && [self.delegate respondsToSelector:@selector(didHideNotifierView:)]) {
                                 [self.delegate didHideNotifierView:self];
                             }
                             
                             [self removeFromSuperview];
                         }
                         
                         if(completion) {
                             completion();
                         }
                     }];
}

- (void)hide
{
    [self hideWithCompletion:nil];
}

- (BOOL)isHidden
{
    return (self.superview == nil);
}

- (void)doTextScrollAnimation:(NSNumber*)timeInterval
{
    if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait) {
        __block CGRect frame = self.messageLabel.frame;
        [UIView transitionWithView:self.messageLabel
                          duration:timeInterval.floatValue
                           options:UIViewAnimationOptionCurveLinear
                        animations:^{
                            frame.origin.x = [UIScreen mainScreen].bounds.size.width - frame.size.width - frame.origin.x;
                            self.messageLabel.frame = frame;
                        } completion:nil];
    } else {
        // add support for landscape
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.shouldHideOnTap == YES) {
        [self hide];
    }
    [self.delegate notifierViewTapped:self];
}

#pragma mark - Accessor

- (void)setMessage:(NSString *)message
{
    _message = message;
    self.messageLabel.text = message;
}

@end
