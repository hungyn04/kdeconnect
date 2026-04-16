// vim: tabstop=2 shiftwidth=2
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <kdeconnectjb-Swift.h>

CPDistributedMessagingCenter *daemonMessageCenter;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t *__restrict,
                                          uid_t, uint32_t);
extern int
posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t *__restrict, uid_t);
extern int
posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t *__restrict, uid_t);

static NSArray<NSString *> *daemonPathCandidates() {
  NSMutableArray<NSString *> *paths = [NSMutableArray array];

  NSString *execPath = NSBundle.mainBundle.executablePath;
  NSRange appRange = [execPath rangeOfString:@"/Applications/"];
  if (appRange.location != NSNotFound) {
    NSString *prefix = [execPath substringToIndex:appRange.location];
    if (prefix.length > 0) {
      [paths addObject:[prefix stringByAppendingString:@"/usr/local/bin/kdeconnectd"]];
    }
  }

  [paths addObject:@"/var/jb/usr/local/bin/kdeconnectd"];
  [paths addObject:@"/usr/local/bin/kdeconnectd"];
  [paths addObject:@"/.jbroot/usr/local/bin/kdeconnectd"];

  return paths;
}

int spawn(NSString *path, NSArray *args) {
  NSMutableArray *argsM = args.mutableCopy ?: [NSMutableArray new];
  [argsM insertObject:path atIndex:0];

  NSUInteger argCount = [argsM count];
  char **argsC = (char **)malloc((argCount + 1) * sizeof(char *));

  for (NSUInteger i = 0; i < argCount; i++) {
    argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
  }
  argsC[argCount] = NULL;

  posix_spawnattr_t attr;
  posix_spawnattr_init(&attr);

  posix_spawn_file_actions_t action;
  posix_spawn_file_actions_init(&action);

  pid_t task_pid;
  int spawnError = posix_spawn(&task_pid, [path UTF8String], &action, &attr,
                               (char *const *)argsC, NULL);
  posix_spawnattr_destroy(&attr);

  if (spawnError != 0) {
    NSLog(@"posix_spawn error %d\n", spawnError);
    return spawnError;
  }

  return 0;
}

static BOOL startDaemonIfNeeded() {
  NSFileManager *fm = [NSFileManager defaultManager];
  for (NSString *path in daemonPathCandidates()) {
    if (![fm isExecutableFileAtPath:path]) {
      continue;
    }

    int err = spawn(path, @[]);
    if (err == 0) {
      NSLog(@"spawned kdeconnectd from path %@", path);
      return YES;
    }

    NSLog(@"failed spawning kdeconnectd from %@ (err=%d)", path, err);
  }

  return NO;
}

static void ensureDaemonReady() {
  if (!daemonMessageCenter) {
    daemonMessageCenter = [CPDistributedMessagingCenter centerNamed:@"dev.r58playz.kdeconnectjb.daemon"];
  }

  NSDictionary *probe = [daemonMessageCenter sendMessageAndReceiveReplyName:@"paired_device_list" userInfo:nil];
  if ([probe isKindOfClass:[NSDictionary class]]) {
    return;
  }

  if (!startDaemonIfNeeded()) {
    return;
  }

  for (NSUInteger i = 0; i < 20; i++) {
    usleep(250000);
    probe = [daemonMessageCenter sendMessageAndReceiveReplyName:@"paired_device_list" userInfo:nil];
    if ([probe isKindOfClass:[NSDictionary class]]) {
      NSLog(@"kdeconnectd is now responding");
      return;
    }
  }

  NSLog(@"kdeconnectd did not respond after spawn attempts");
}

void createMessageCenter() {
  daemonMessageCenter = [CPDistributedMessagingCenter centerNamed:@"dev.r58playz.kdeconnectjb.daemon"];
  ensureDaemonReady();
  NSLog(@"daemon center: %@", daemonMessageCenter);
}

NSArray *getConnectedDevices() {
  ensureDaemonReady();
  NSDictionary *reply = [daemonMessageCenter sendMessageAndReceiveReplyName:@"connected_device_list" userInfo:nil];
  NSArray *ret = [reply objectForKey:@"info"];
  if (![ret isKindOfClass:[NSArray class]]) {
    return @[];
  }
  NSLog(@"daemon response: %@", ret);
  return ret;
}

NSArray *getPairedDevices() {
  ensureDaemonReady();
  NSDictionary *reply = [daemonMessageCenter sendMessageAndReceiveReplyName:@"paired_device_list" userInfo:nil];
  NSArray *ret = [reply objectForKey:@"info"];
  if (![ret isKindOfClass:[NSArray class]]) {
    return @[];
  }
  NSLog(@"daemon response: %@", ret);
  return ret;
}

void rebroadcast() {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"rebroadcast" userInfo:nil];
}

void sendPing(NSString *id) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"send_ping" userInfo:@{@"id":id}];
}

void sendPairReq(NSString *id, NSNumber *pair) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"pair" userInfo:@{@"id":id,@"pair":pair}];
}

void sendFind(NSString *id) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"send_find" userInfo:@{@"id":id}];
}

void sendPresenter(NSString *id, NSNumber *dx, NSNumber *dy) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"send_presenter" userInfo:@{@"id":id,@"dx":dx,@"dy":dy}];
}

void stopPresenter(NSString *id) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"stop_presenter" userInfo:@{@"id":id}];
}

void requestVolume(NSString *id) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"get_volume" userInfo:@{@"id":id}];
}

void sendVolume(NSString *id, NSString *name, NSNumber *enabled, NSNumber *muted, NSNumber *volume) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"send_volume" userInfo:@{@"id":id,@"name":name,@"enabled":enabled,@"muted":muted,@"volume":volume}];
}

void sendFiles(NSString *id, NSArray *files, NSNumber* open) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"share_files" userInfo:@{@"id":id,@"files":files,@"open":open}];
}

void requestPlayers(NSString *id) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"get_players" userInfo:@{@"id":id}];
}

void requestPlayer(NSString *id, NSString *playerId) {
	[daemonMessageCenter sendMessageAndReceiveReplyName:@"get_players" userInfo:@{@"id":id, @"player_id":playerId}];
}

void requestPlayerAction(NSString *id, NSString *playerId, NSNumber *action, NSNumber *val) {
	[daemonMessageCenter sendMessageAndReceiveReplyName:@"request_player_action" userInfo:@{@"id":id, @"player_id":playerId, @"player_action":action, @"player_action_int":val}];
}

void requestMousepadAction(NSString *id, NSString *key, NSNumber *alt, NSNumber *ctrl, NSNumber *shift, NSNumber *dx, NSNumber *dy, NSNumber *scroll, NSNumber *singleclick, NSNumber *doubleclick, NSNumber *middleclick, NSNumber *rightclick, NSNumber *singlehold, NSNumber *singlerelease) {
	[daemonMessageCenter sendMessageAndReceiveReplyName:@"request_mousepad_action" userInfo:@{@"id":id, @"key":key, @"alt":alt, @"ctrl":ctrl, @"shift":shift, @"dx":dx, @"dy":dy, @"scroll":scroll, @"singleclick":singleclick, @"doubleclick":doubleclick, @"middleclick":middleclick, @"rightclick":rightclick, @"singlehold":singlehold, @"singlerelease":singlerelease}];
}

void requestCommands(NSString *id) {
  [daemonMessageCenter sendMessageAndReceiveReplyName:@"get_commands" userInfo:@{@"id":id}];
}

void runCommand(NSString *id, NSString *commandId) {
	[daemonMessageCenter sendMessageAndReceiveReplyName:@"run_command" userInfo:@{@"id":id, @"command_id":commandId}];
}

void sendExit() {
  [daemonMessageCenter sendMessageName:@"killyourself" userInfo:nil];
}

@interface KConnectObjcServer : NSObject
@property (nonatomic, strong) KConnectSwiftServer *swift;
@end

@implementation KConnectObjcServer 
+ (id)newWithSwift:(KConnectSwiftServer*) swift {
  return [[self alloc] initWithSwift:swift];
}
- (id)initWithSwift:(KConnectSwiftServer*) swift {
	if ((self = [super init])) {
    self.swift = swift;
		CPDistributedMessagingCenter * messagingCenter = [CPDistributedMessagingCenter centerNamed:@"dev.r58playz.kdeconnectjb.app"];
		[messagingCenter runServerOnCurrentThread];

    [messagingCenter registerForMessageName:@"refresh" target:self selector:@selector(refresh:)];
    NSLog(@"registered CPDistributedMessagingCenter"); 
	}

	return self;
}
- (void)refresh:(NSString*)refresh {
  [self.swift refreshRequested];
}
@end
