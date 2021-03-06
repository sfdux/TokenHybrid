//
//  TokenSSRenderController.m
//  TokenHTMLRender
//
//  Created by 陈雄 on 2017/9/23.
//  Copyright © 2017年 com.feelings. All rights reserved.
//

#import "TokenHybridRenderController.h"
#import "TokenHybridDefine.h"
#import "TokenViewBuilder.h"
#import "TokenJSContext.h"
#import "TokenXMLNode.h"
#import "TokenPureComponent.h"
#import "TokenButtonComponent.h"
#import "TokenHybridConstant.h"
#import "TokenHybridOrganizer.h"

#import "UIColor+SSRender.h"
#import "NSString+Token.h"
#import "UIView+Attributes.h"
#import "TokenHybridDebugView.h"
#import "UINavigationController+KMNavigationBarTransition.h"

#import <TBActionSheet/TBActionSheet.h>

@interface TokenHybridRenderController () <TokenViewBuilderDelegate,TokenJSContextDelegate,TokenHybridDebugViewDelegate>
@property(nonatomic ,strong) UILabel          *reloadLabel;
@property(nonatomic ,strong) TBActionSheet    *actionSheet;
@property(nonatomic ,strong) TokenViewBuilder *viewBuilder;
@end

@implementation TokenHybridRenderController{
    NSMutableArray *_navItems;
    NSDictionary   *_navigationBarTitleAttributes;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewBuilder = [[TokenViewBuilder alloc] init];
        self.viewBuilder.delegate = self;
        self.allowDebug = YES;
    }
    return self;
}

-(instancetype)initWithHTMLURL:(NSString *)htmlURL{
    if (self = [self init]) {
        _htmlURL = htmlURL;
    }
    return self;
}

-(instancetype)initWithHTML:(NSString *)html{
    if (self = [self init]) {
        [self.viewBuilder buildViewWithHTML:html];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!self.hiddenTitle) {
        self.title = @"加载中...";
    }
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    if (_htmlURL) {
        [self.viewBuilder buildViewWithSourceURL:_htmlURL];
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self viewBuilderWillRunScript];
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = YES;
    [self.viewBuilder refreshView];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.viewBuilder.jsContext pageClose];
    [TokenHybridOrganizer sharedOrganizer].currentViewBuilder    = nil;
    [TokenHybridOrganizer sharedOrganizer].currentViewController = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:TokenHybridPageDisappearNotification object:nil];
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = NO;
}

-(void)reloadData{
    if (!self.hiddenTitle) {
        self.title = @"加载中...";
    }
    self.viewBuilder = [[TokenViewBuilder alloc] init];
    self.viewBuilder.delegate = self;
    [self.viewBuilder buildViewWithSourceURL:_htmlURL];
}

#pragma mark - TokenHierarchyAnalystDelegate
-(void)viewBuilderWillRunScript{
    
    if (self.extension) {
        JSValue *windowValue = [self.viewBuilder.jsContext evaluateScript:@"setExtension"];
        NSDictionary *newObj = [self.extension copy];
        [windowValue callWithArguments:newObj?@[newObj]:nil];
    }
    
    [TokenHybridOrganizer sharedOrganizer].currentViewBuilder    = self.viewBuilder;
    [TokenHybridOrganizer sharedOrganizer].currentViewController = self;
    self.viewBuilder.jsContext.delegate = self;
}

-(void)viewBuilder:(TokenViewBuilder *)viewBuilder didFetchTitle:(NSString *)title{
    self.title = title;
}

-(void)viewBuilder:(TokenViewBuilder *)viewBuilder parserErrorOccurred:(NSError *)error{
    if (!self.hiddenTitle) {
        self.title = @"加载错误";
    }
    [self.view.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *clsString = NSStringFromClass([obj class]);
        if ([clsString hasPrefix:@"Token"]) { [obj removeFromSuperview];}
    }];
    self.reloadLabel.hidden = NO;
    NSString *desc = @"页面存在语法错误:\n".token_append(error.description).token_append(@"\n点击重新加载!");
    self.reloadLabel.text = desc;
}

-(void)viewBuilder:(TokenViewBuilder *)viewBuilder didCreatNavigationBarNode:(TokenXMLNode *)node{
    NSString *barTinColor = node.innerAttributes[@"backgroundColor"];
    if (barTinColor) {
        self.navigationController.navigationBar.barTintColor = [UIColor ss_colorWithString:barTinColor];
    }
    NSString *translucent = node.innerAttributes[@"translucent"];
    if (translucent) {
        self.navigationController.navigationBar.translucent = translucent.token_turnBoolStringToBoolValue();
    }
    
    NSString *titleColor = node.innerAttributes[@"titleColor"];
    if (titleColor) {
        _navigationBarTitleAttributes = self.navigationController.navigationBar.titleTextAttributes;
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor ss_colorWithString:titleColor]}];
    }
    //navItems
    NSMutableArray *_navigationBarItems = @[].mutableCopy;
    [node.childNodes enumerateObjectsUsingBlock:^(__kindof TokenXMLNode * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj.name isEqualToString:@"navItem"]) return ;
        TokenButtonComponent *buttonItem = [UIView token_produceViewWithNode:obj];
        buttonItem.associatedNode = obj;
        obj.associatedView = buttonItem;
        [buttonItem token_updateAppearanceWithNormalDictionary:obj.innerAttributes];
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:buttonItem];
        [_navigationBarItems addObject:item];
    }];
    self.navigationItem.rightBarButtonItems = _navigationBarItems;
}


-(void)viewBuilder:(TokenViewBuilder *)viewBuilder didCreatBodyView:(TokenPureComponent *)view{
    _reloadLabel.hidden = YES;
    [self.view.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *clsString = NSStringFromClass([obj class]);
        if ([clsString hasPrefix:@"Token"]) { [obj removeFromSuperview];}
    }];
    [self.view addSubview:view];
}

#pragma mark - debug
-(void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event{
    if (!self.allowDebug || self.actionSheet.visible) return;
    [self.actionSheet show];
}

-(BOOL)canBecomeFirstResponder{
    return YES;
}

-(void)debugView:(TokenHybridDebugView *)debugView didPressExcuseButtonWithScript:(NSString *)script{
    JSContext *context = [TokenHybridOrganizer sharedOrganizer].currentViewBuilder.jsContext;
    if ([script isEqualToString:@"clear"]) {
        [debugView clear];
    }
    else {
        [context evaluateScript:script];
    }
}

#pragma mark - TokenJSContextDelegate
-(void)context:(TokenJSContext *)context didReceiveLogInfo:(NSString *)info{
    TokenHybridDebugView *debugView = (TokenHybridDebugView *)self.actionSheet.customView;
    [debugView addLog:info];
    [debugView scrollToBottom];
}

-(void)context:(TokenJSContext *)context setPriviousExtension:(NSDictionary *)extension{
    if ([extension isKindOfClass:[NSDictionary class]] && self.previousController) {
        NSDictionary *previousExt = self.previousController.extension;
        NSMutableDictionary *ext = [NSMutableDictionary dictionaryWithDictionary:previousExt?previousExt:@{}];
        [ext addEntriesFromDictionary:extension];
        self.previousController.extension = extension;
    }
}

#pragma mark - getter
-(UILabel *)reloadLabel{
    if (_reloadLabel == nil) {
        _reloadLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 40, CGRectGetWidth(self.view.frame)-20, 200)];
        _reloadLabel.userInteractionEnabled = YES;
        _reloadLabel.numberOfLines = 0;
        _reloadLabel.textAlignment = NSTextAlignmentLeft;
        _reloadLabel.textColor = [UIColor darkTextColor];
        [_reloadLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reloadData)]];
        [self.view addSubview:_reloadLabel];
    }
    return _reloadLabel;
}

-(TBActionSheet *)actionSheet{
    if (_actionSheet == nil) {
        _actionSheet = [[TBActionSheet alloc] initWithTitle:@"简易控制台" message:@"输入clear清空" delegate:nil cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:nil];
        TokenHybridDebugView *debugView = [[TokenHybridDebugView alloc] initWithFrame:CGRectMake(0, 0, [TBActionSheet appearance].sheetWidth, 380)];
        _actionSheet.customView         = debugView;
        debugView.delegate              = self;
    }
    return _actionSheet;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    HybridLog(@"TokenHybridRenderController dead");
}

@end
