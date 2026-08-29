#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 函数原型声明
static void toggleFloatingBall(void);
static void hideFloatingBall(void);
static void showFloatingBall(void);
static void installGesture(void);
static void addHideSwitchToView(UIView *view);

// 手势处理辅助类
@interface FBHGestureHandler : NSObject
+ (void)handleTap:(UITapGestureRecognizer *)gesture;
+ (void)handleSwitchTap:(UIButton *)sender;
@end

@implementation FBHGestureHandler
+ (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        NSLog(@"[FBH] 三指点击4次触发");
        toggleFloatingBall();
    }
}
+ (void)handleSwitchTap:(UIButton *)sender {
    NSLog(@"[FBH] 悬浮隐藏开关点击");
    toggleFloatingBall();
    // 更新按钮状态
    UIView *container = sender.superview;
    UIButton *onBtn = (UIButton *)[container viewWithTag:101];
    UIButton *offBtn = (UIButton *)[container viewWithTag:102];
    if (g_ballHidden) {
        onBtn.backgroundColor = [UIColor whiteColor];
        [onBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        offBtn.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        [offBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        offBtn.backgroundColor = [UIColor whiteColor];
        [offBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        onBtn.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        [onBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
}
@end

// 全局状态
static BOOL g_ballHidden = YES;  // 默认隐藏
static UITapGestureRecognizer *g_threeFingerTap = nil;
static UIView *g_switchRow = nil;
static UIView *g_savedBall = nil;       // 保存悬浮球实例
static UIView *g_savedSuperview = nil;  // 保存悬浮球的父视图
static CGRect g_savedFrame;              // 保存悬浮球的frame

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

static void hideFloatingBall(void) {
    UIView *ball = findFloatingBallInAllWindows();
    if (ball) {
        g_savedBall = ball;
        g_savedSuperview = ball.superview;
        g_savedFrame = ball.frame;
        [ball removeFromSuperview];
        g_ballHidden = YES;
        NSLog(@"[FBH] 悬浮球已移除");
    }
}

static void showFloatingBall(void) {
    if (g_savedBall && g_savedSuperview) {
        g_savedBall.frame = g_savedFrame;
        [g_savedSuperview addSubview:g_savedBall];
        [g_savedSuperview bringSubviewToFront:g_savedBall];
        g_ballHidden = NO;
        NSLog(@"[FBH] 悬浮球已恢复");
    } else {
        // 如果没有保存的实例，尝试重新查找并显示
        UIView *ball = findFloatingBallInAllWindows();
        if (ball) {
            ball.hidden = NO;
            g_ballHidden = NO;
        }
    }
}

static void toggleFloatingBall(void) {
    if (g_ballHidden) {
        showFloatingBall();
    } else {
        hideFloatingBall();
    }
}

// 安装手势识别器（直接加到keyWindow，不创建全屏overlay）
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
    NSLog(@"[FBH] 手势已安装到keyWindow");
}

// 创建悬浮隐藏开关行（匹配老贝贝样式）
static UIView *createSwitchRow(CGFloat width) {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 50)];
    row.backgroundColor = [UIColor clearColor];
    
    // 左侧文字
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, width * 0.4, 50)];
    label.text = @"悬浮隐藏";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor blackColor];
    [row addSubview:label];
    
    // 右侧按钮容器
    CGFloat btnW = (width * 0.45) / 2;
    CGFloat btnH = 36;
    CGFloat btnY = (50 - btnH) / 2;
    CGFloat btnX = width - btnW * 2 - 20;
    
    // 开启按钮
    UIButton *onBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    onBtn.frame = CGRectMake(btnX, btnY, btnW, btnH);
    onBtn.tag = 101;
    [onBtn setTitle:@"开启" forState:UIControlStateNormal];
    onBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    onBtn.layer.cornerRadius = 8;
    onBtn.layer.masksToBounds = YES;
    [onBtn addTarget:[FBHGestureHandler class] action:@selector(handleSwitchTap:) forControlEvents:UIControlEventTouchUpInside];
    
    // 关闭按钮
    UIButton *offBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    offBtn.frame = CGRectMake(btnX + btnW, btnY, btnW, btnH);
    offBtn.tag = 102;
    [offBtn setTitle:@"关闭" forState:UIControlStateNormal];
    offBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    offBtn.layer.cornerRadius = 8;
    offBtn.layer.masksToBounds = YES;
    [offBtn addTarget:[FBHGestureHandler class] action:@selector(handleSwitchTap:) forControlEvents:UIControlEventTouchUpInside];
    
    // 默认状态：悬浮球隐藏=开启
    onBtn.backgroundColor = [UIColor whiteColor];
    [onBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    offBtn.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    [offBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [row addSubview:onBtn];
    [row addSubview:offBtn];
    
    return row;
}

// 在设置弹窗中插入开关行
static void addHideSwitchToView(UIView *view) {
    if (!view || g_switchRow.superview) return;
    
    // 查找包含"防录屏防截屏"文字的视图
    UIView *targetView = nil;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            if ([lbl.text containsString:@"防录屏"]) {
                targetView = sub.superview;
                break;
            }
        }
        // 递归查找
        UIView *found = nil;
        for (UIView *s2 in sub.subviews) {
            if ([s2 isKindOfClass:[UILabel class]]) {
                UILabel *lbl = (UILabel *)s2;
                if ([lbl.text containsString:@"防录屏"]) {
                    found = s2.superview;
                    break;
                }
            }
        }
        if (found) { targetView = found; break; }
    }
    
    if (!targetView) {
        // 如果没找到，尝试在scrollView的内容视图中查找
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UIScrollView class]]) {
                UIScrollView *sv = (UIScrollView *)sub;
                for (UIView *content in sv.subviews) {
                    addHideSwitchToView(content);
                }
            }
        }
        return;
    }
    
    // 在targetView上方插入开关行
    UIView *superView = targetView.superview;
    if (!superView) return;
    
    CGFloat rowH = 50;
    CGRect targetFrame = targetView.frame;
    
    // 创建开关行
    g_switchRow = createSwitchRow(superView.bounds.size.width);
    g_switchRow.frame = CGRectMake(0, targetFrame.origin.y, superView.bounds.size.width, rowH);
    
    // 把targetView及其后面的所有子视图往下移
    CGFloat moveY = rowH;
    NSArray *subviews = [superView.subviews copy];
    BOOL foundTarget = NO;
    for (UIView *sub in subviews) {
        if (sub == targetView) {
            foundTarget = YES;
        }
        if (foundTarget && sub != g_switchRow) {
            CGRect f = sub.frame;
            f.origin.y += moveY;
            sub.frame = f;
        }
    }
    
    // 如果superView是scrollView，更新contentSize
    if ([superView isKindOfClass:[UIScrollView class]]) {
        UIScrollView *sv = (UIScrollView *)superView;
        CGSize cs = sv.contentSize;
        cs.height += moveY;
        sv.contentSize = cs;
    }
    
    [superView insertSubview:g_switchRow belowSubview:targetView];
    NSLog(@"[FBH] 悬浮隐藏开关已插入");
}

// 延迟隐藏悬浮球
static void delayedHideBall(void) {
    hideFloatingBall();
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

// Hook 设置弹窗
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 检查是否是老贝贝的设置弹窗
    NSString *clsName = NSStringFromClass([self class]);
    if ([clsName containsString:@"设置"] || [clsName containsString:@"弹窗"] || [clsName containsString:@"Setting"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addHideSwitchToView(self.view);
        });
    }
}

%end

// 构造函数
__attribute__((constructor))
static void initialize(void) {
    NSLog(@"[FBH] dylib已加载");
    dispatch_async(dispatch_get_main_queue(), ^{
        delayedHideBall();
    });
}
