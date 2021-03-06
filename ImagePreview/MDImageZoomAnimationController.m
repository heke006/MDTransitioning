// Copyright (c) 2017 Modool. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "MDImageZoomAnimationController.h"

@implementation UIImage (AspectFit)

- (CGRect)aspectFitRectForSize:(CGSize)size {
    CGFloat targetAspect = size.width / size.height;
    CGFloat sourceAspect = self.size.width / self.size.height;
    CGRect rect = CGRectZero;
    
    if (targetAspect > sourceAspect) {
        rect.size.height = size.height;
        rect.size.width = ceilf(rect.size.height * sourceAspect);
        rect.origin.x = ceilf((size.width - rect.size.width) * 0.5);
    }
    else {
        rect.size.width = size.width;
        rect.size.height = ceilf(rect.size.width / sourceAspect);
        rect.origin.y = ceilf((size.height - rect.size.height) * 0.5);
    }
    
    return rect;
}

@end

@interface MDImageZoomAnimationController ()

@property (nonatomic, assign) NSTimeInterval duration;

@property (nonatomic, assign) MDPresentionAnimatedOperation presentionAnimatedOperation;

@property (nonatomic, weak) UIViewController<MDImageZoomViewControllerDelegate> *fromViewController;
@property (nonatomic, weak) UIViewController<MDImageZoomViewControllerDelegate> *toViewController;

@end

@implementation MDImageZoomAnimationController

- (instancetype)initWithReferenceImageView:(UIImageView *)referenceImageView;{
    if (self = [super init]) {
        NSAssert([referenceImageView contentMode] == UIViewContentModeScaleAspectFill, @"*** referenceImageView must have a UIViewContentModeScaleAspectFill contentMode!");
        _referenceImageView = referenceImageView;
        _hideReferenceImageViewWhenZoomIn = YES;
    }
    return self;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *viewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    return [viewController isBeingPresented] ? 0.5 : 0.25;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    if ([self presentionAnimatedOperation] == MDPresentionAnimatedOperationPresent) {
        [self animateZoomInTransition:transitionContext];
    } else if ([self presentionAnimatedOperation] == MDPresentionAnimatedOperationDismiss) {
        [self animateZoomOutTransition:transitionContext];
    }
}

- (void)animateZoomInTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    // Get the view controllers participating in the transition
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController<MDImageZoomViewControllerDelegate> *toViewController = (id)[transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    NSAssert([toViewController conformsToProtocol:@protocol(MDImageZoomViewControllerDelegate)], @"*** toViewController must conforms to protocol for YRImageViewController!");
    
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    UIColor *windowBackgroundColor = [window backgroundColor];
    
    window.backgroundColor = [UIColor blackColor];
    // Create a temporary view for the zoom in transition and set the initial frame based
    // on the reference image view
    UIImageView *transitionView = [[UIImageView alloc] initWithImage:[[self referenceImageView] image]];
    transitionView.contentMode = UIViewContentModeScaleAspectFill;
    transitionView.clipsToBounds = YES;
    transitionView.frame = [[transitionContext containerView] convertRect:[[self referenceImageView] bounds]
                                                                 fromView:[self referenceImageView]];
    [[transitionContext containerView] addSubview:transitionView];
    
    // Compute the final frame for the temporary view
    CGRect finalFrame = [transitionContext finalFrameForViewController:toViewController];
    CGRect transitionViewFinalFrame = [[[self referenceImageView] image] aspectFitRectForSize:finalFrame.size];
    
    if ([self hideReferenceImageViewWhenZoomIn]) {
        self.referenceImageView.hidden = YES;
    }
    // Perform the transition using a spring motion effect
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    
    [UIView animateWithDuration:duration
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         fromViewController.view.alpha = 0;
                         transitionView.frame = transitionViewFinalFrame;
                     }
                     completion:^(BOOL finished) {
                         window.backgroundColor = windowBackgroundColor;
                         fromViewController.view.alpha = 1;
                         
                         if ([transitionContext transitionWasCancelled] && [self hideReferenceImageViewWhenZoomIn]) {
                             self.referenceImageView.hidden = NO;
                         }
                         
                         [transitionView removeFromSuperview];
                         [[transitionContext containerView] addSubview:[toViewController view]];
                         [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
                     }];
}

- (void)animateZoomOutTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    // Get the view controllers participating in the transition
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController<MDImageZoomViewControllerDelegate> *fromViewController = (id)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    NSAssert([fromViewController conformsToProtocol:@protocol(MDImageZoomViewControllerDelegate)], @"*** fromViewController must conforms to protocol for YRImageViewController!");
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    UIColor *windowBackgroundColor = [window backgroundColor];
    
    // The toViewController view will fade in during the transition
    toViewController.view.frame = [transitionContext finalFrameForViewController:toViewController];
    if ([fromViewController modalPresentationStyle] == UIModalPresentationNone) {
        toViewController.view.alpha = 0;
        window.backgroundColor = [UIColor blackColor];
        
        [[transitionContext containerView] addSubview:[toViewController view]];
        [[transitionContext containerView] sendSubviewToBack:[toViewController view]];
    }
    // Compute the initial frame for the temporary view based on the image view
    // of the YRImageViewController
    CGRect transitionViewInitialFrame = [[[fromViewController imageView] image] aspectFitRectForSize:[[fromViewController imageView] bounds].size];
    transitionViewInitialFrame = [[transitionContext containerView] convertRect:transitionViewInitialFrame
                                                                       fromView:[fromViewController imageView]];
    
    // Compute the final frame for the temporary view based on the reference
    // image view
    CGRect transitionViewFinalFrame = [[transitionContext containerView] convertRect:[[self referenceImageView] bounds]
                                                                            fromView:[self referenceImageView]];
    
    // Create a temporary view for the zoom out transition based on the image
    // view controller contents
    UIImageView *transitionView = [[UIImageView alloc] initWithImage:[[fromViewController imageView] image]];
    transitionView.contentMode = UIViewContentModeScaleAspectFill;
    transitionView.layer.cornerRadius = [[[self referenceImageView] layer] cornerRadius];
    transitionView.layer.borderWidth = [[[self referenceImageView] layer] borderWidth];
    transitionView.layer.borderColor = [[[self referenceImageView] layer] borderColor];
    transitionView.clipsToBounds = YES;
    transitionView.frame = transitionViewInitialFrame;
    
    [[transitionContext containerView] addSubview:transitionView];
    
    fromViewController.imageView.hidden = YES;
    if ([self hideReferenceImageViewWhenZoomIn]) {
        self.referenceImageView.hidden = YES;
    }
    // Perform the transition
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         toViewController.view.alpha = 1.f;
                         fromViewController.view.alpha = 0.f;
                         transitionView.frame = transitionViewFinalFrame;
                     } completion:^(BOOL finished) {
                         if ([self hideReferenceImageViewWhenZoomIn]) {
                             self.referenceImageView.hidden = NO;
                         }
                         window.backgroundColor = windowBackgroundColor;
                         if ([transitionContext transitionWasCancelled]) {
                             fromViewController.imageView.hidden = NO;
                             fromViewController.view.alpha = 1.f;
                         }
                         [transitionView removeFromSuperview];
                         [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
                     }];
}

@end

@implementation MDImageZoomAnimationController (MPresentionAnimatedTransitioning)

+ (id<MPresentionAnimatedTransitioning>)animationForPresentOperation:(MDPresentionAnimatedOperation)presentionAnimatedOperation fromViewController:(UIViewController<MDImageZoomViewControllerDelegate> *)fromViewController toViewController:(UIViewController<MDImageZoomViewControllerDelegate> *)toViewController;{
    return [[self alloc] initWithPresentionAnimatedOperation:presentionAnimatedOperation fromViewController:fromViewController toViewController:toViewController];
}

- (instancetype)initWithPresentionAnimatedOperation:(MDPresentionAnimatedOperation)presentionAnimatedOperation fromViewController:(UIViewController<MDImageZoomViewControllerDelegate> *)fromViewController toViewController:(UIViewController<MDImageZoomViewControllerDelegate> *)toViewController;{
    
    NSParameterAssert(presentionAnimatedOperation != MDPresentionAnimatedOperationNone);
    NSParameterAssert([fromViewController respondsToSelector:@selector(imageView)]);
    NSParameterAssert([toViewController respondsToSelector:@selector(imageView)]);
    
    UIImageView *referenceImageView = presentionAnimatedOperation == MDPresentionAnimatedOperationPresent ? [fromViewController imageView] : [toViewController imageView];
    if (self = [self initWithReferenceImageView:referenceImageView]) {
        self.presentionAnimatedOperation = presentionAnimatedOperation;
        self.fromViewController = fromViewController;
        self.toViewController = toViewController;
        self.hideReferenceImageViewWhenZoomIn = YES;
    }
    return self;
}

@end
