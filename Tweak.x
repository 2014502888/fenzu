#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
@class ChatRoomInfoViewController;
static UIViewController *PJTopmostVC(void) {
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

static NSMutableArray *g_allSessions = nil;
static NSMutableDictionary *g_sessionGroups = nil;

static NSMutableDictionary *SessionGroups(void) {
    if (!g_sessionGroups) {
        g_sessionGroups = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"sessionGroups"].mutableCopy ?: [NSMutableDictionary dictionary];
    }
    return g_sessionGroups;
}
static void SaveSessionGroups(void) {
    [[NSUserDefaults standardUserDefaults] setObject:g_sessionGroups forKey:@"sessionGroups"];
}

static NSArray *GroupNames(void) {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:@"misakaGroups"] ?: @[];
}

static NSString *PJSortMode(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"misakaSortMode"] ?: @"time";
}

static NSString *PJGroupAvatarKey(NSString *gn) {
    return [NSString stringWithFormat:@"groupAvatar_%@", gn];
}
static UIImage *PJGroupAvatar(NSString *gn) {
    NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:PJGroupAvatarKey(gn)];
    if (path) return [UIImage imageWithContentsOfFile:path];
    return nil;
}

static void PJShowAssignMenu(NSString *userName) {
    if (!userName) return;
    UIViewController *host = PJTopmostVC();
    UIAlertController *a = [UIAlertController alertControllerWithTitle:userName message:@"选择分组" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *gn in GroupNames()) {
        [a addAction:[UIAlertAction actionWithTitle:gn style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            [SessionGroups() setObject:gn forKey:userName];
            SaveSessionGroups();
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"移出分组" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _) {
        [SessionGroups() removeObjectForKey:userName];
        SaveSessionGroups();
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [host presentViewController:a animated:YES completion:nil];
}

@interface PJGroupChatPicker : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSString *groupName;
@property (nonatomic, strong) UITableView *tableView;
@end
@implementation PJGroupChatPicker
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.groupName;
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return g_allSessions.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
    id info = g_allSessions[ip.row];
    NSString *un = [info valueForKey:@"userName"];
    c.textLabel.text = un;
    c.detailTextLabel.text = un;
    NSString *current = [SessionGroups() objectForKey:un];
    c.accessoryType = [current isEqualToString:self.groupName] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    id info = g_allSessions[ip.row];
    NSString *un = [info valueForKey:@"userName"];
    NSString *current = [SessionGroups() objectForKey:un];
    if ([current isEqualToString:self.groupName]) {
        [SessionGroups() removeObjectForKey:un];
    } else {
        [SessionGroups() setObject:self.groupName forKey:un];
    }
    SaveSessionGroups();
    [self.tableView reloadData];
}
@end

@interface PJSortPicker : UIViewController <UITableViewDataSource, UITableViewDelegate>
@end
@implementation PJSortPicker
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"排序方式";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    UITableView *tv = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tv.dataSource = self; tv.delegate = self;
    [self.view addSubview:tv];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 3; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    NSArray *names = @[@"按时间", @"按未读", @"混合"];
    c.textLabel.text = names[ip.row];
    NSString *cur = PJSortMode();
    NSArray *keys = @[@"time", @"unread", @"mixed"];
    c.accessoryType = [cur isEqualToString:keys[ip.row]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSArray *keys = @[@"time", @"unread", @"mixed"];
    [[NSUserDefaults standardUserDefaults] setObject:keys[ip.row] forKey:@"misakaSortMode"];
    [t reloadData];
}
@end

@interface PJGroupEditViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, copy) NSString *editingGroup;
@end
@implementation PJGroupEditViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"会话分组";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.groups = [[NSUserDefaults standardUserDefaults] arrayForKey:@"misakaGroups"].mutableCopy ?: [NSMutableArray array];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addGroup)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? 1 : self.groups.count;
}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return s == 0 ? @"排序" : @"分组";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
    if (ip.section == 0) {
        c.imageView.image = nil;
        c.textLabel.text = @"排序方式";
        NSString *m = PJSortMode();
        c.detailTextLabel.text = [m isEqualToString:@"unread"] ? @"按未读" : [m isEqualToString:@"mixed"] ? @"混合" : @"按时间";
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *gn = self.groups[ip.row];
        c.textLabel.text = gn;
        UIImage *av = PJGroupAvatar(gn);
        c.imageView.image = av ?: [UIImage systemImageNamed:@"folder"];
        c.imageView.layer.cornerRadius = 20;
        c.imageView.clipsToBounds = YES;
        c.imageView.contentMode = UIViewContentModeScaleAspectFill;
        NSArray *all = [SessionGroups() allKeysForObject:gn];
        c.detailTextLabel.text = [NSString stringWithFormat:@"%lu 个聊天", (unsigned long)all.count];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) {
        PJSortPicker *p = [PJSortPicker new];
        [self.navigationController pushViewController:p animated:YES];
    } else {
        NSString *gn = self.groups[ip.row];
        self.editingGroup = gn;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:gn message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [a addAction:[UIAlertAction actionWithTitle:@"选择聊天" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            PJGroupChatPicker *p = [PJGroupChatPicker new];
            p.groupName = gn;
            [self.navigationController pushViewController:p animated:YES];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"设置头像" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            [self pickAvatar];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}
- (void)pickAvatar {
    UIImagePickerController *p = [UIImagePickerController new];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.delegate = self;
    [self presentViewController:p animated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img && self.editingGroup) {
        NSData *data = UIImageJPEGRepresentation(img, 0.5);
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"avatar_%@.jpg", self.editingGroup]];
        [data writeToFile:path atomically:YES];
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:PJGroupAvatarKey(self.editingGroup)];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.tableView reloadData];
}
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    if (es == UITableViewCellEditingStyleDelete) {
        NSString *gn = self.groups[ip.row];
        NSArray *keys = [SessionGroups() allKeysForObject:gn];
        for (NSString *k in keys) [SessionGroups() removeObjectForKey:k];
        SaveSessionGroups();
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:PJGroupAvatarKey(gn)];
        [self.groups removeObjectAtIndex:ip.row];
        [self save];
        [t deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
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

@interface PJChatMisakaPage : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *userName;
@end
@implementation PJChatMisakaPage
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"分组";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    UITableView *tv = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tv.dataSource = self; tv.delegate = self;
    [self.view addSubview:tv];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 1; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
    c.textLabel.text = @"分组名称";
    NSString *current = [SessionGroups() objectForKey:self.userName];
    c.detailTextLabel.text = current ?: @"未分组";
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    PJShowAssignMenu(self.userName);
}
@end

static UITableView *PJFindTableView(UIView *view) {
    if ([view isKindOfClass:[UITableView class]]) return (UITableView *)view;
    for (UIView *sub in view.subviews) { UITableView *t = PJFindTableView(sub); if (t) return t; }
    return nil;
}
@interface PJButtonTarget : NSObject
@property (nonatomic, copy) NSString *userName;
@end
@implementation PJButtonTarget
- (void)onTap {
    if (self.userName) {
        PJChatMisakaPage *p = [PJChatMisakaPage new];
        p.userName = self.userName;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:p];
        [PJTopmostVC() presentViewController:nav animated:YES completion:nil];
        return;
    }
    PJGroupEditViewController *s = [PJGroupEditViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:s];
    [PJTopmostVC() presentViewController:nav animated:YES completion:nil];
}
@end
static void PJAddSettingsEntry(id vc) {
    UITableView *tv = PJFindTableView([vc view]);
    if (!tv) return;
    if ([tv.tableFooterView.accessibilityLabel isEqual:@"pj_entry"]) return;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, 0, tv.bounds.size.width, 54);
    btn.backgroundColor = [UIColor whiteColor];
    btn.accessibilityLabel = @"pj_entry";
    [btn setTitle:@"会话分组" forState:UIControlStateNormal];
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

%hook MainFrameLogicController
- (NSUInteger)getSessionCount {
    NSUInteger c = %orig;
    @try {
        id me = self;
        g_allSessions = [[me valueForKey:@"m_frontSessionArray"] mutableCopy];
    } @catch(id e) {}
    return c;
}
%end

static BOOL pjAdded = NO;
static void (*orig_CRVC_viewWillAppear)(id, SEL, BOOL);
static void hook_CRVC_viewWillAppear(id self, SEL _cmd, BOOL animated) {
    orig_CRVC_viewWillAppear(self, _cmd, animated);
    @try {
        if (pjAdded) return;
        id info = [self valueForKey:@"m_tableViewInfo"];
        if (!info) return;
        id sections = [info performSelector:@selector(getAllSections)];
        id sec1 = [(NSArray *)sections objectAtIndex:1];
        id cells1 = [sec1 performSelector:@selector(getAllCells)];
        id templateCell = [(NSArray *)cells1 objectAtIndex:0];
        id templateCfg = [templateCell valueForKey:@"cellConfig"];
        id templateLeft = [templateCfg valueForKey:@"leftConfig"];
        // New config
        Class cfgCls = objc_getClass("WCTableViewCellNormalConfig");
        id newCfg = [[cfgCls alloc] init];
        Class leftCls = objc_getClass("WCTableViewCellLeftConfig");
        id newLeft = [[leftCls alloc] init];
        [newLeft setValue:@"分组" forKey:@"title"];
        [newLeft setValue:@"未分组" forKey:@"detail"];
        id font = [templateLeft valueForKey:@"titleFont"];
        id color = [templateLeft valueForKey:@"titleColor"];
        if (font) [newLeft setValue:font forKey:@"titleFont"];
        if (color) [newLeft setValue:color forKey:@"titleColor"];
        [newCfg setValue:newLeft forKey:@"leftConfig"];
        // Copy base config
        id selStyle = [templateCfg valueForKey:@"selectionStyle"];
        if (selStyle) [newCfg setValue:selStyle forKey:@"selectionStyle"];
        // New cell
        Class cellCls = objc_getClass("WCTableViewNormalCellManager");
        id newCell = [[cellCls alloc] init];
        [newCell setValue:newCfg forKey:@"cellConfig"];
        // New section
        Class secCls = objc_getClass("WCTableViewSectionManager");
        id newSec = [[secCls alloc] init];
        [newSec performSelector:@selector(addCell:) withObject:newCell];
        // Try addSection first (at bottom)
        [info performSelector:@selector(addSection:) withObject:newSec];
        [info performSelector:@selector(reloadTableView)];
        pjAdded = YES;
    } @catch(id e) {}
}
%ctor {
    MSHookMessageEx(objc_getClass("ChatRoomInfoViewController"), @selector(viewWillAppear:), (IMP)hook_CRVC_viewWillAppear, (IMP *)&orig_CRVC_viewWillAppear);
}