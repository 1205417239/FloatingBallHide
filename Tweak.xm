#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 手势处理辅助类
@interface FBHGestureHandler : NSObject
+ (void)handleTap:(UITapGestureRecognizer *)gesture;
@end

@implementation FBHGestureHandler
+ (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        NSLog(@"[FloatingBallHide] 三指点击4次触发");
        toggleFloatingBall();
    }
}
@end

// 全局状态
static BOOL g_ballHidden = NO;
static UITapGestureRecognizer *g_threeFingerTap = nil;
static UIView *g_overlayView = nil;

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

// 查找所有窗口中的悬浮面板
static UIView *findFloatingBallInAllWindows(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        UIView *found = findFloatingBallView(w);
        if (found) return found;
    }
    return nil;
}

// 隐藏悬浮球
static void hideFloatingBall(void) {
    UIView *ball = findFloatingBallInAllWindows();
    if (ball) {
        ball.hidden = YES;
        g_ballHidden = YES;
        NSLog(@"[FloatingBallHide] 悬浮球已隐藏");
    }
}

// 显示悬浮球
static void showFloatingBall(void) {
    UIView *ball = findFloatingBallInAllWindows();
    if (ball) {
        ball.hidden = NO;
        g_ballHidden = NO;
        NSLog(@"[FloatingBallHide] 悬浮球已显示");
    }
}

// 切换悬浮球显示状态
static void toggleFloatingBall(void) {
    if (g_ballHidden) {
        showFloatingBall();
    } else {
        hideFloatingBall();
    }
}

// 安装手势识别器
static void installGesture(void) {
    if (g_threeFingerTap) return;
    
    UIWindow *window = getKeyWindow();
    if (!window) return;
    
    // 创建一个全屏透明覆盖视图来接收手势
    if (!g_overlayView) {
        g_overlayView = [[UIView alloc] initWithFrame:window.bounds];
        g_overlayView.backgroundColor = [UIColor clearColor];
        g_overlayView.userInteractionEnabled = YES;
        g_overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    
    g_threeFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:[FBHGestureHandler class] action:@selector(handleTap:)];
    g_threeFingerTap.numberOfTouchesRequired = 3;  // 三指
    g_threeFingerTap.numberOfTapsRequired = 4;      // 点击4次
    g_threeFingerTap.cancelsTouchesInView = NO;
    g_threeFingerTap.delaysTouchesBegan = NO;
    g_threeFingerTap.delaysTouchesEnded = NO;
    
    // 将手势添加到覆盖视图
    [g_overlayView addGestureRecognizer:g_threeFingerTap];
    
    // 将覆盖视图添加到窗口最上层
    [window addSubview:g_overlayView];
    [window bringSubviewToFront:g_overlayView];
    
    NSLog(@"[FloatingBallHide] 三指点击4次手势已安装");
}

// 延迟隐藏悬浮球（等待悬浮球创建完成）
static void delayedHideBall(void) {
    // 先立即尝试
    hideFloatingBall();
    
    // 延迟多次尝试，确保悬浮球创建后被隐藏
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        hideFloatingBall();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        hideFloatingBall();
        installGesture();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        hideFloatingBall();
    });
}

// Hook UIApplication 启动完成
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    NSLog(@"[FloatingBallHide] APP启动完成，准备隐藏悬浮球");
    dispatch_async(dispatch_get_main_queue(), ^{
        delayedHideBall();
    });
    return result;
}

%end

// Hook 顶层窗口，确保手势始终在最上层
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_overlayView) {
            UIWindow *kw = getKeyWindow();
            if (kw && g_overlayView.superview != kw) {
                [kw addSubview:g_overlayView];
            }
            [kw bringSubviewToFront:g_overlayView];
        }
    });
}

%end

// 构造函数
__attribute__((constructor))
static void initialize(void) {
    NSLog(@"[FloatingBallHide] dylib已加载");
    // 延迟到主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        delayedHideBall();
    });
}
