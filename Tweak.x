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

@interface PJGroupEditViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *groups;
@end
@implementation PJGroupEditViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Groups";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.groups = [[NSUserDefaults standardUserDefaults] arrayForKey:@"misakaGroups"].mutableCopy ?: [@[@"Work", @"Family", @"Other"] mutableCopy];
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
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
    NSString *gn = self.groups[ip.row];
    c.textLabel.text = gn;
    // 显示该组有几个会话
    NSArray *all = [SessionGroups() allKeysForObject:gn];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%lu chats", (unsigned long)all.count];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSString *groupName = self.groups[ip.row];
    NSMutableArray *names = [NSMutableArray array];
    for (id info in g_allSessions) {
        NSString *un = [info valueForKey:@"userName"];
        if (un) [names addObject:un];
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:groupName message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *n in names) {
        NSString *current = [SessionGroups() objectForKey:n];
        BOOL selected = [current isEqualToString:groupName];
        NSString *title = selected ? [NSString stringWithFormat:@"✓ %@", n] : n;
        [a addAction:[UIAlertAction actionWithTitle:title style:selected ? UIAlertActionStyleCancel : UIAlertActionStyleDefault handler:^(UIAlertAction * _) {
            if (selected) {
                [SessionGroups() removeObjectForKey:n];
            } else {
                [SessionGroups() setObject:groupName forKey:n];
            }
            SaveSessionGroups();
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDestructive handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
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