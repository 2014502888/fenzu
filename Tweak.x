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

static NSString *PJSortMode(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"misakaSortMode"] ?: @"time";
}

static NSString *PJDisplayName(id info) {
    @try {
        NSArray *keys = @[@"m_nsDisplayName", @"m_nsNickName", @"m_nsTitle", @"displayName", @"nickName", @"title"];
        for (NSString *k in keys) {
            NSString *v = [info valueForKey:k];
            if (v.length) return v;
        }
    } @catch(id e) {}
    return [info valueForKey:@"userName"];
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
    c.textLabel.text = PJDisplayName(info);
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
    self.title = @"Sort";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    UITableView *tv = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tv.dataSource = self; tv.delegate = self;
    [self.view addSubview:tv];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 3; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    NSArray *names = @[@"By Time", @"By Unread", @"Mixed"];
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

@interface PJGroupEditViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *groups;
@end
@implementation PJGroupEditViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Groups";
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
    return s == 0 ? @"Sort" : @"Groups";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
    if (ip.section == 0) {
        c.textLabel.text = @"Sort Mode";
        NSString *m = PJSortMode();
        c.detailTextLabel.text = [m isEqualToString:@"unread"] ? @"By Unread" : [m isEqualToString:@"mixed"] ? @"Mixed" : @"By Time";
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *gn = self.groups[ip.row];
        c.textLabel.text = gn;
        NSArray *all = [SessionGroups() allKeysForObject:gn];
        c.detailTextLabel.text = [NSString stringWithFormat:@"%lu chats", (unsigned long)all.count];
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
        PJGroupChatPicker *p = [PJGroupChatPicker new];
        p.groupName = self.groups[ip.row];
        [self.navigationController pushViewController:p animated:YES];
    }
}
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    if (es == UITableViewCellEditingStyleDelete) {
        NSString *gn = self.groups[ip.row];
        NSArray *keys = [SessionGroups() allKeysForObject:gn];
        for (NSString *k in keys) [SessionGroups() removeObjectForKey:k];
        SaveSessionGroups();
        [self.groups removeObjectAtIndex:ip.row];
        [self save];
        [t deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}
- (void)addGroup {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"New Group" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"Name"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
        NSString *name = a.textFields.firstObject.text;
        if (name.length) { [self.groups addObject:name]; [self save]; [self.tableView reloadData]; }
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)save { [[NSUserDefaults standardUserDefaults] setObject:self.groups forKey:@"misakaGroups"]; }
@end

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
static void PJAddSettingsEntry(id vc) {
    UITableView *tv = PJFindTableView([vc view]);
    if (!tv) return;
    if ([tv.tableFooterView.accessibilityLabel isEqual:@"pj_entry"]) return;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, 0, tv.bounds.size.width, 54);
    btn.backgroundColor = [UIColor whiteColor];
    btn.accessibilityLabel = @"pj_entry";
    [btn setTitle:@"Session Groups" forState:UIControlStateNormal];
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

%ctor {
    @autoreleasepool { }
}