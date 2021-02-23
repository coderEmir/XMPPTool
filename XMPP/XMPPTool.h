//
//  XMPPTool.h
//  XMPP
//
//  Created by xKing on 2020/4/25.
//  Copyright © 2020 xKing. All rights reserved.
//

#import <Foundation/Foundation.h>
// 电子名片模块
#import <XMPPvCardTemp.h>
#import <XMPPUserCoreDataStorageObject.h>
// 聊天信息对象的类
#import <XMPPMessageArchiving_Message_CoreDataObject.h>
typedef void(^registerBlock)(BOOL isSuccess);
typedef void(^loginBlock)(BOOL isSuccess);
typedef void(^reloadFriendsBlock)(BOOL isChanged);
typedef void(^messageChangeBlock)(BOOL isChanged);

typedef enum : NSUInteger {
    XMPPBodyTypeText,
    XMPPBodyTypeImage,
    XMPPBodyTypeVideo,
} XMPPBodyType;

NS_ASSUME_NONNULL_BEGIN

#define XMPPToolInstance [XMPPTool performSelector:NSSelectorFromString(@"XMPPToolSharedInstance")]

@interface XMPPTool : NSObject

// 连接服务器
- (void)connectToHost;

// 断开服务器的连接
- (void)disconnectFromHost;

// 注册
- (void)registerUserWithName:(NSString *)name password:(NSString *)pwd registerBack:(registerBlock)block;

// 登录
- (void)loginWithName:(NSString *)name password:(NSString *)pwd loginBack:(loginBlock)block;

// 获取用户个人信息--->利用电子名片模块获取
- (XMPPvCardTemp *)uservCardTemp;

- (void)updateUservCardTemp;

// 获取好友列表信息
- (NSArray *)friendsList;
- (NSArray *)reloadFriendsListWithBlock:(reloadFriendsBlock)block;

// 添加好友
- (void)addNewFriendWithUserName:(NSString *)name;

//删除好友
- (void)deleteFriendWithUserName:(NSString *)name;

// 清除内存中的XMPP
- (void)teardownXMPP;

// 获取聊天数据
- (NSArray *)loadMessagesWithDelegate:(id<NSFetchedResultsControllerDelegate>)delegate;
- (NSArray *)loadMessagesWithFriendName:(nullable NSString *)name withDelegate:(id<NSFetchedResultsControllerDelegate>)delegate;
// 发送文字聊天数据
- (void)sendMessageWithName:(NSString *)name content:(NSString *)content bodyType:(XMPPBodyType)type;
@end

NS_ASSUME_NONNULL_END
