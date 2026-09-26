#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:userName message:@"闁瀚ㄩ崚鍡欑矋" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *gn in GroupNames()) {
        [a addAction:[UIAlertAction actionWithTitle:gn style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            [SessionGroups() setObject:gn forKey:userName];
            SaveSessionGroups();
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"缁夎鍤崚鍡欑矋" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _) {
        [SessionGroups() removeObjectForKey:userName];
        SaveSessionGroups();
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"閸欐牗绉? style:UIAlertActionStyleCancel handler:nil]];
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
    self.title = @"閹烘帒绨弬鐟扮础";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    UITableView *tv = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tv.dataSource = self; tv.delegate = self;
    [self.view addSubview:tv];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 3; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    NSArray *names = @[@"閹稿妞傞梻?, @"閹稿婀拠?, @"濞ｅ嘲鎮?];
    c.textLabel.text = names[ip.row];
    NSString *cur = PJSortMode();
    NSString *key = @[@"time", @"unread", @"mixed"][ip.row];
    c.accessoryType = [cur isEqualToString:key] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSString *key = @[@"time", @"unread", @"mixed"][ip.row];
    [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"misakaSortMode"];
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
    self.title = @"娴兼俺鐦介崚鍡欑矋";
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
    return s == 0 ? @"閹烘帒绨? : @"閸掑棛绮?;
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
    if (ip.section == 0) {
        c.imageView.image = nil;
        c.textLabel.text = @"閹烘帒绨弬鐟扮础";
        NSString *m = PJSortMode();
        c.detailTextLabel.text = [m isEqualToString:@"unread"] ? @"閹稿婀拠? : [m isEqualToString:@"mixed"] ? @"濞ｅ嘲鎮? : @"閹稿妞傞梻?;
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
        c.detailTextLabel.text = [NSString stringWithFormat:@"%lu 娑擃亣浜版径?, (unsigned long)all.count];
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
        [a addAction:[UIAlertAction actionWithTitle:@"闁瀚ㄩ懕濠傘亯" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            PJGroupChatPicker *p = [PJGroupChatPicker new];
            p.groupName = gn;
            [self.navigationController pushViewController:p animated:YES];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"鐠佸墽鐤嗘径鏉戝剼" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            [self pickAvatar];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"閸欐牗绉? style:UIAlertActionStyleCancel handler:nil]];
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"閺傛澘缂撻崚鍡欑矋" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"閸掑棛绮嶉崥?; }];
    [a addAction:[UIAlertAction actionWithTitle:@"閸欐牗绉? style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"绾喖鐣? style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
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
    self.title = @"閸掑棛绮?;
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    UITableView *tv = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tv.dataSource = self; tv.delegate = self;
    [self.view addSubview:tv];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 1; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
    c.textLabel.text = @"閸掑棛绮嶉崥宥囆?;
    NSString *current = [SessionGroups() objectForKey:self.userName];
    c.detailTextLabel.text = current ?: @"閺堫亜鍨庣紒?;
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
    [btn setTitle:@"娴兼俺鐦介崚鍡欑矋" forState:UIControlStateNormal];
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

%hook ChatRoomInfoViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    @try {
        id me = self;
        // 閹疯法鍏㈤崣?        NSString *un = [[me valueForKey:@"m_chatRoomContact"] valueForKey:@"m_nsUsrName"];
        if (!un) return;
        UITableView *tv = PJFindTableView([me view]);
        if (!tv) return;
        if ([tv viewWithTag:9527]) return;
        // 閸旂姳绔存稉鐚歟ll閺嶅嘲绱￠惃鍕攽閸︹暟ableView娑撳﹥鏌?        UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(0, tv.contentOffset.y, tv.bounds.size.width, 54)];
        cell.backgroundColor = [UIColor whiteColor];
        cell.tag = 9527;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(16, 0, cell.bounds.size.width - 32, 54);
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [btn setTitle:@"閸掑棛绮? forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:16];
        PJButtonTarget *t = [PJButtonTarget new];
        t.userName = un;
        objc_setAssociatedObject(btn, "pj_t", t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [btn addTarget:t action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
        [cell addSubview:btn];
        [tv addSubview:cell];
        // 瀵扳偓娑撳甯归崘鍛啇
        tv.contentInset = UIEdgeInsetsMake(54, 0, 0, 0);
    } @catch(id e) {}
}
%end
