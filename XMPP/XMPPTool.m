//
//  XMPPTool.m
//  XMPP
//
//  Created by xKing on 2020/4/25.
//  Copyright © 2020 xKing. All rights reserved.
//

#import "XMPPTool.h"
#import <XMPPFramework/XMPPFramework.h>

// XMPP日志
#import <DDLog.h>
#import <DDTTYLogger.h>
@interface XMPPTool () <XMPPStreamDelegate ,XMPPReconnectDelegate ,XMPPRosterDelegate>
{
    XMPPStream *_xmppStream;
    // 电子名片模块的数据存储
    XMPPvCardCoreDataStorage *_vCardStorge;
    // 头像模块
    XMPPvCardAvatarModule *_avatar;
    // 重连模块
    XMPPReconnect *_reconnect;
    // 花名册模块
    XMPPRoster *_roster;
    // 花名册模块数据存储
    XMPPRosterCoreDataStorage *_rosterStorge;
    //消息模块
    // XMPP接收到好友发来的聊天数据，把聊天数据放在本地数据库
    XMPPMessageArchiving *_messageArchiving;
    // 消息模块的数据存储
    XMPPMessageArchivingCoreDataStorage *_messageStorage;
}
//登录
@property (nonatomic , copy) NSString *userName;

@property (nonatomic , copy) NSString *userPwd;
// 电子名片模块
@property (nonatomic, strong) XMPPvCardTempModule *vCard;

@property (nonatomic , assign) BOOL isRegister;
/** 注册回调 */
@property (nonatomic , copy) registerBlock registerBlock;
/** 登录回调 */
@property (nonatomic , copy) registerBlock loginBlock;
@property (nonatomic , copy) reloadFriendsBlock reloadFriendsBlock;

/**信息更新回调*/
@property (nonatomic , copy) messageChangeBlock messageChangeBlock;

/** 好友查询控制器 */
@property (nonatomic, strong) NSFetchedResultsController *friendResultVC;

/** 信息查询控制器 */
@property (nonatomic, strong) NSFetchedResultsController *messageResultVC;
@end

@implementation XMPPTool

static XMPPTool *_tool;
+ (XMPPTool *)XMPPToolSharedInstance
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tool = [XMPPTool new];
//        XMPP自带的日志系统
//        [DDLog addLogger:[DDTTYLogger sharedInstance]];
    });
    return _tool;
}

- (void)registerUserWithName:(NSString *)name password:(NSString *)pwd registerBack:(registerBlock)block
{
    self.userName = name;
    self.userPwd = pwd;
    self.isRegister = YES;
    self.registerBlock = block;
    [self disconnectFromHost];
    [self connectToHost];
}

- (void)loginWithName:(NSString *)name password:(NSString *)pwd loginBack:(loginBlock)block
{
    self.userName = name;
    self.userPwd = pwd;
    self.isRegister = NO;
    self.loginBlock = block;
    [self disconnectFromHost];
    [self connectToHost];
}

- (void)disconnectFromHost
{
        // 注销  发送注销消息   断开连接
    XMPPPresence *offline = [XMPPPresence presenceWithType:@"unavilable"];
    [_xmppStream sendElement:offline];
    [_xmppStream disconnect];
}

- (void)connectToHost
{
    if (!_xmppStream)
    {
        [self setUpXMPPStream];
    }
    NSError *error = nil;
    
    // 设置JID, User 填写用户名 domain 服务器域名  resource 标识客户端
    XMPPJID *myJID = [XMPPJID jidWithUser:self.userName domain:@"localhost" resource:@"iPhone"];
    _xmppStream.myJID = myJID;
    
    // 设置服务器域名 或 IP地址
    _xmppStream.hostName = @"localhost";
    
    // 设置端口  如果服务器默认端口是5222，可以省略设置
    _xmppStream.hostPort = 5222;
    
    // 返回一个bool，失败可查看error; 不超时 建立tcp长连接
    [_xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error];
}

- (void)setUpXMPPStream
{
    _xmppStream = [[XMPPStream alloc] init];
    #warning 每一个模块添加后，都要激活
    // 消息模块
    _messageStorage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    _messageArchiving = [[XMPPMessageArchiving alloc] initWithMessageArchivingStorage:_messageStorage];
    // 激活
    [_messageArchiving activate:_xmppStream];
    
    // 花名册模块（好友列表）
    _rosterStorge = [XMPPRosterCoreDataStorage sharedInstance];
    _roster = [[XMPPRoster alloc] initWithRosterStorage:_rosterStorge];
    [_roster addDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    //自动同步，从服务器取出好友
    [_roster setAutoFetchRoster:YES];
    [_roster setAutoAcceptKnownPresenceSubscriptionRequests:NO];
    // 激活
    [_roster activate:_xmppStream];
    
    // 添加自动连接模块
    _reconnect = [[XMPPReconnect alloc] init];
    // 激活
    [_reconnect activate:_xmppStream];

    // 添加电子名片模块 (配置完成，xmpp内部会请求服务器获取个人信息）
    _vCardStorge = [XMPPvCardCoreDataStorage sharedInstance];
    self.vCard = [[XMPPvCardTempModule alloc] initWithvCardStorage:_vCardStorge];
    //激活电子名片模块
    [self.vCard activate:_xmppStream];
    NSLog(@"%@",self.vCard.myvCardTemp);
    // 头像模块
    _avatar = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:_vCard];
    // 激活
    [_avatar activate:_xmppStream];
    // 设置代理
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
}

- (void)addReconnectDelegate
{   
    [_reconnect addDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
}

- (void)teardownXMPP
{
    // 移除代理
    [_xmppStream removeDelegate:self];
    // 停止模块
    [_reconnect deactivate];
    [_avatar deactivate];
    [_vCard deactivate];
    [_roster deactivate];
    [_messageArchiving deactivate];
    // 断开连接
    [_xmppStream disconnect];
    
    // 释放变量,清空资源
    _reconnect = nil;
    _avatar = nil;
    
    _vCard = nil;
    _vCardStorge = nil;
    
    _roster = nil;
    _rosterStorge = nil;
    
    _messageArchiving = nil;
    _messageStorage = nil;
    
    _xmppStream = nil;
}


- (void)sendPwdToHost
{
    // 3. 连接到服务器成功后，发送密码授权
    NSError *error = nil;
    if (self.isRegister)
    {
        [_xmppStream registerWithPassword:self.userPwd error:&error];
        return;
    }
    // 注册用户，发送注册密码
    [_xmppStream authenticateWithPassword:self.userPwd error:&error];
}

- (void)sendOnlineToHost
{
    //  4. 授权成功后，发送“在线”消息
    XMPPPresence *presence = [XMPPPresence presence];
    // 发送XML类型presense字符串
    [_xmppStream sendElement:presence];
}

- (XMPPvCardTemp *)uservCardTemp
{
    NSLog(@"========");
    NSLog(@"%@",self.vCard);
    return self.vCard.myvCardTemp;
}

- (void)updateUservCardTemp
{
    // updateMyvCardTemp内部会实现数据上传到服务器，不需手动编码上传
    [self.vCard updateMyvCardTemp:self.vCard.myvCardTemp];
}

- (NSArray *)friendsList
{
    //        使用coreData获取数据
    //        1.上下文【关联到数据】
    NSManagedObjectContext *context = _rosterStorge.mainThreadManagedObjectContext;
    //        2.FetchRequest--->指定查哪张表
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"XMPPUserCoreDataStorageObject"];
    //        3.设置过滤和排序
    // 过滤当前登录用户的好友（因为所有用户好友数据都在相同的表里）
    // 获取JID
    NSString *JID = [NSString stringWithFormat:@"%@@%@",_xmppStream.myJID.user,_xmppStream.myJID.domain];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr=%@",JID];
    request.predicate = predicate;
    // 排序
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES];
    request.sortDescriptors = @[sort];
    //        4.执行请求获取数据
    NSArray *friends = [context executeFetchRequest:request error:nil];
//    XMPPUserCoreDataStorageObject *object = friends.firstObject;
//    NSLog(@"%@",object.jidStr);
    return friends;
}

- (NSArray *)reloadFriendsListWithBlock:(reloadFriendsBlock)block
{
    self.reloadFriendsBlock = block;
    //        使用coreData获取数据
    //        1.上下文【关联到数据】
    NSManagedObjectContext *context = _rosterStorge.mainThreadManagedObjectContext;
    //        2.FetchRequest--->指定查哪张表
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"XMPPUserCoreDataStorageObject"];
    //        3.设置过滤和排序
    // 过滤当前登录用户的好友（因为所有用户好友数据都在相同的表里）
    // 获取JID
    NSString *JID = [NSString stringWithFormat:@"%@@%@",_xmppStream.myJID.user,_xmppStream.myJID.domain];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr=%@",JID];
    request.predicate = predicate;
    // 排序
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES];
    request.sortDescriptors = @[sort];
    //        4.执行请求获取数据
    self.friendResultVC = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
//    self.friendResultVC.delegate = self;
    
    NSError *error = nil;
    [self.friendResultVC performFetch:&error];
    if (error) {
        NSLog(@"%@",error);
    }
//    XMPPUserCoreDataStorageObject *object = resultsController.fetchedObjects.firstObject;
//    object.sectionNum // 好友状态  0 在线  1  离开  2  离线
    return self.friendResultVC.fetchedObjects;
}

- (void)addNewFriendWithUserName:(NSString *)name
{
//    NSString *JIDStr = [NSString stringWithFormat:@"%@@%@",name,_xmppStream.myJID.domain];
    NSString *JIDStr = [self friendJID:name];
    XMPPJID *friendJID = [XMPPJID jidWithString:JIDStr];
    // 花名册模块 订阅功能----> 添加好友
    if ([_xmppStream.myJID.user containsString:name])
    {
        NSLog(@"不能添加自己");
    }
    else if ([_rosterStorge userExistsWithJID:friendJID xmppStream:_xmppStream])
    {
        NSLog(@"已经是好友了");
    }
    else
    {
        [_roster subscribePresenceToUser:friendJID];
    }
}

- (NSString *)currentUserJID
{
    return [NSString stringWithFormat:@"%@@%@",_xmppStream.myJID.user,_xmppStream.myJID.domain];
}

- (NSString *)friendJID:(NSString *)friendName
{
    return [NSString stringWithFormat:@"%@@%@",friendName,_xmppStream.myJID.domain];
}

- (void)deleteFriendWithUserName:(NSString *)name
{
    NSString *JIDStr = [self friendJID:name];
    XMPPJID *friendJID = [XMPPJID jidWithString:JIDStr];
    [_roster removeUser:friendJID];
}
- (NSArray *)loadMessagesWithDelegate:(id<NSFetchedResultsControllerDelegate>)delegate
{
    return [self loadMessagesWithFriendName:nil withDelegate:delegate];
}

- (NSArray *)loadMessagesWithFriendName:(nullable NSString *)name withDelegate:(nonnull id<NSFetchedResultsControllerDelegate>)delegate
{
//    self.messageChangeBlock = block;
//    coreData操作步骤：
    //        1.上下文【关联到数据】
    NSManagedObjectContext *context = _messageStorage.mainThreadManagedObjectContext;
    //        2.FetchRequest 获取表的实体
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"XMPPMessageArchiving_Message_CoreDataObject"];
    //        3.设置过滤和排序
    // 当前登录用户的JID消息
    NSString *conditionStr = self.currentUserJID;
    if (name) {
        conditionStr = [NSString stringWithFormat:@"%@ AND bareJidStr=%@",self.currentUserJID,[self friendJID:name]];
    }
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@",name];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr=%@",conditionStr];
    request.predicate = predicate;
    
    NSSortDescriptor *timeSort = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES];
    request.sortDescriptors = @[timeSort];
    
    self.messageResultVC = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
    //        4.执行请求获取数据
    NSError *error = nil;
    self.messageResultVC.delegate = delegate;
    [self.messageResultVC performFetch:&error];
    
    return self.messageResultVC.fetchedObjects;
}

- (void)sendMessageWithName:(NSString *)name content:(nonnull NSString *)content bodyType:(XMPPBodyType)type
{
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:[XMPPJID jidWithString:[self friendJID:name]]];
    switch (type) {
        case XMPPBodyTypeText:
        {
            [message addAttributeWithName:@"bodyType" stringValue:@"text"];
        }
            break;
        case XMPPBodyTypeImage:
        {
            [message addAttributeWithName:@"bodyType" stringValue:@"image"];
        }
            break;
        case XMPPBodyTypeVideo:
        {
            [message addAttributeWithName:@"bodyType" stringValue:@"video"];
        }
            break;
        default:
            break;
    }
    
    [message addBody:content];
    [_xmppStream sendElement:message];
}

#pragma mark - XMPPStreamDelegate
- (void)xmppStreamDidRegister:(XMPPStream *)sender
{
    NSLog(@"注册成功");
    if (self.registerBlock)self.registerBlock(YES);
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error
{
    NSLog(@"注册失败");
    if (self.registerBlock)self.registerBlock(NO);
}

- (void)xmppStreamWillConnect:(XMPPStream *)sender
{
    NSLog(@"将要连接");
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    NSLog(@"连接成功");
    
    [self sendPwdToHost];
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    NSLog(@"与主机断开连接");
}

// 发送密码授权的成功回调
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    if (self.loginBlock) {
        self.loginBlock(YES);
    }
    
    NSString *JID = self.currentUserJID;
    NSLog(@"%@",JID);
    NSLog(@"授权成功");
    [self sendOnlineToHost];
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSArray *friends = [self friendsList];
        NSLog(@"%@",friends);
    });
}

// 发送密码授权的失败回调
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error
{
    if (self.loginBlock) {
        self.loginBlock(NO);
    }
    NSLog(@"授权失败");
}

#pragma mark - XMPPReconnectDelegate
- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkConnectionFlags)connectionFlags
{
    NSLog(@"重连成功");
}
- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkConnectionFlags)connectionFlags
{
//    将要重连，是否需要进行重连
    return YES;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        // 本地通知
        UILocalNotification *localNoti = [[UILocalNotification alloc] init];
        // 设置内容
        localNoti.alertBody = message.body;
        // 设置通知执行时间
        localNoti.fireDate = NSDate.date;
        // 声音
        localNoti.soundName = UILocalNotificationDefaultSoundName;
        // 执行
        [UIApplication.sharedApplication scheduleLocalNotification:localNoti];
        /**
            // 8.0以上要在AppDelegate注册通知
            if (UIDevice.currentDevice.systemVersion.doubleValue > 8.0)
            {
                UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIAccessibilityTraitPlaysSound categories:nil];
                [application registerUserNotificationSettings:settings];
            }
         */
    }
}

// 接收到好友请求，
- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    // 判断是否为添加好友行为
    if ([presence.type containsString:@"subscribe"])
    {
        // 处理请求
        NSString *friendJIDStr = [[presence attributeForName:@"from"] stringValue];
        XMPPJID *JID = [XMPPJID jidWithString:friendJIDStr];
        [_roster acceptPresenceSubscriptionRequestFrom:JID andAddToRoster:YES];
        NSLog(@"============");
    }
//        [self addNewFriendWithUserName:[friendJID componentsSeparatedByString:@"@"].firstObject];
        
//        // 添加好友：根据给定的账户名，把对方用户添加到自己的好友列表中，并且申请订阅对方用户的在线状态
//        - (void)addUser:(XMPPJID *)jid withNickname:(NSString *)optionalName;
//
//        // 删除好友：从好友列表中删除对方用户，并且取消订阅对方用户的在线状态，同时取消对方用户对我们自己在线状态的订阅（如果对方设置允许这样的话）
//        - (void)removeUser:(XMPPJID *)jid;
//
//        // 同意好友请求
//        - (void)acceptPresenceSubscriptionRequestFrom:(XMPPJID *)jid andAddToRoster:(BOOL)flag;
//
//        // 拒绝好友请求
//        - (void)rejectPresenceSubscriptionRequestFrom:(XMPPJID *)jid;
}
@end
