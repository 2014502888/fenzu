#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

static UIViewController *PJTopmostVC(void) {
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

// 设置页: 管理分组
@interface PJGroupEditViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *groups;
@end
@implementation PJGroupEditViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"会话分组";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.groups = [[NSUserDefaults standardUserDefaults] arrayForKey:@"misakaGroups"].mutableCopy ?: [@[@"工作", @"家人", @"其他"] mutableCopy];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addGroup)];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.groups.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    c.textLabel.text = self.groups[ip.row];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)addGroup {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"新建分组" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"分组名"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
        NSString *name = a.textFields.firstObject.text;
        if (name.length) { [self.groups addObject:name]; [self save]; [self.tableView reloadData]; }
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)save { [[NSUserDefaults standardUserDefaults] setObject:self.groups forKey:@"misakaGroups"]; }
@end

// 设置入口
static UITableView *PJFindTableView(UIView *view) {
    if ([view isKindOfClass:[UITableView class]]) return (UITableView *)view;
    for (UIView *sub in view.subviews) { UITableView *t = PJFindTableView(sub); if (t) return t; }
    return nil;
}
@interface PJButtonTarget : NSObject
@end
@implementation PJButtonTarget
- (void)onTap {
    PJGroupEditViewController *s = [PJGroupEditViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:s];
    [PJTopmostVC() presentViewController:nav animated:YES completion:nil];
}
@end
static void PJAddSettingsEntry(UIViewController *vc) {
    UITableView *tv = PJFindTableView(vc.view);
    if (!tv) return;
    if ([tv.tableFooterView.accessibilityLabel isEqual:@"pj_entry"]) return;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, 0, tv.bounds.size.width, 54);
    btn.backgroundColor = [UIColor whiteColor];
    btn.accessibilityLabel = @"pj_entry";
    [btn setTitle:@"会话分组设置" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16];
    PJButtonTarget *t = [PJButtonTarget new];
    objc_setAssociatedObject(btn, "pj_t", t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [btn addTarget:t action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    tv.tableFooterView = btn;
}

%hook MoreViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    PJAddSettingsEntry(self);
}
%end

%hook NewSettingViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    PJAddSettingsEntry(self);
}
%end

%ctor {
    @autoreleasepool { }
}