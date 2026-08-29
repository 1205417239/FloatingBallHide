#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 全局状态
static BOOL g_ballHidden = YES;  // 默认隐藏
static UIView *g_savedBall = nil;
static UIView *g_savedSuperview = nil;
static CGRect g_savedFrame;
static dispatch_source_t g_hideTimer = nil;
static UITapGestureRecognizer *g_threeFingerTap = nil;

// 函数原型声明
static void showFloatingBall(void);
static void hideFloatingBall(void);
static void startHideTimer(void);

// 手势处理辅助类
@interface FBHGestureHandler : NSObject
+ (void)handleTap:(UITapGestureRecognizer *)gesture;
@end

@implementation FBHGestureHandler
+ (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        NSLog(@"[FBH] 三指点击4次触发，呼出悬浮球");
        showFloatingBall();
        startHideTimer();
    }
}
@end

// 获取 keyWindow
static UIWindow *getKeyWindow(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow && !w.isHidden) return w;
    }
    return [UIApplication sharedApplication].keyWindow;
}

// 递归查找悬浮面板视图
static UIView *findFloatingBallView(UIView *view) {
    if (!view) return nil;
    Class ballClass = NSClassFromString(@"悬浮面板");
    if (ballClass && [view isKindOfClass:ballClass]) {
        return view;
    }
    for (UIView *sub in view.subviews) {
        UIView *found = findFloatingBallView(sub);
        if (found) return found;
    }
    return nil;
}

static UIView *findFloatingBallInAllWindows(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        UIView *found = findFloatingBallView(w);
        if (found) return found;
    }
    return nil;
}

// 隐藏悬浮球
static void hideFloatingBall(void) {
    if (g_ballHidden) return;
    UIView *ball = findFloatingBallInAllWindows();
    if (ball) {
        g_savedBall = ball;
        g_savedSuperview = ball.superview;
        g_savedFrame = ball.frame;
        [ball removeFromSuperview];
        g_ballHidden = YES;
        NSLog(@"[FBH] 悬浮球已隐藏");
    }
}

// 显示悬浮球
static void showFloatingBall(void) {
    if (!g_ballHidden) return;
    if (g_savedBall && g_savedSuperview) {
        g_savedBall.frame = g_savedFrame;
        [g_savedSuperview addSubview:g_savedBall];
        [g_savedSuperview bringSubviewToFront:g_savedBall];
        g_ballHidden = NO;
        NSLog(@"[FBH] 悬浮球已显示");
    } else {
        UIView *ball = findFloatingBallInAllWindows();
        if (ball) {
            ball.hidden = NO;
            g_ballHidden = NO;
        }
    }
}

// 启动3秒无操作自动隐藏计时器
static void startHideTimer(void) {
    if (g_hideTimer) {
        dispatch_source_cancel(g_hideTimer);
        g_hideTimer = nil;
    }
    g_hideTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(g_hideTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(g_hideTimer, ^{
        hideFloatingBall();
    });
    dispatch_resume(g_hideTimer);
}

// 安装三指点击4次手势
static void installGesture(void) {
    if (g_threeFingerTap) return;
    UIWindow *window = getKeyWindow();
    if (!window) return;
    
    g_threeFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:[FBHGestureHandler class] action:@selector(handleTap:)];
    g_threeFingerTap.numberOfTouchesRequired = 3;
    g_threeFingerTap.numberOfTapsRequired = 4;
    g_threeFingerTap.cancelsTouchesInView = NO;
    g_threeFingerTap.delaysTouchesBegan = NO;
    g_threeFingerTap.delaysTouchesEnded = NO;
    
    [window addGestureRecognizer:g_threeFingerTap];
    NSLog(@"[FBH] 三指点击4次手势已安装");
}

// 构造函数
__attribute__((constructor))
static void initialize(void) {
    NSLog(@"[FBH] 悬浮球自动隐藏dylib已加载");
    dispatch_async(dispatch_get_main_queue(), ^{
        // 延迟2秒，等待悬浮球创建后隐藏
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hideFloatingBall();
            installGesture();
        });
        // 再延迟3秒确保隐藏
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hideFloatingBall();
        });
    });
}
