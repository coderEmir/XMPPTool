//
//  ViewController.m
//  XMPP
//
//  Created by xKing on 2020/4/24.
//  Copyright © 2020 xKing. All rights reserved.
//

#import "ViewController.h"
#import "RegisterViewController.h"
#import <XMPPFramework/XMPPFramework.h>
#import "XMPPTool.h"

/*
 *  实现登录
 1. 初始化XMPPStream
 2. 连接到服务器（传一个JID）
 3. 连接到服务器成功后，在发送密码授权
 4. 授权成功后，发送“在线”消息
 退出
 注销
 
 coreData操作步骤：
 //        使用coreData获取数据
 //        1.上下文【关联到数据】
 //        2.FetchRequest
 //        3.设置过滤和排序
 //        4.执行请求获取数据
 */
@interface ViewController () 

@property (weak, nonatomic) IBOutlet UITextField *userTextField;
@property (weak, nonatomic) IBOutlet UITextField *pwdTextField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)registerEvent:(id)sender {
    [XMPPToolInstance registerUserWithName:self.userTextField.text password:self.pwdTextField.text registerBack:^(BOOL isSuccess) {
        
    }];
}

#pragma mark - event
- (IBAction)loginEvent:(id)sender {
    // 登录实现
    /*
     1.用户名和密码放入沙盒
     2.调用AppDelete的一个connect 连接服务并登录
     */
    NSString *name = self.userTextField.text;
    
    NSString *password = self.pwdTextField.text;
    
    [XMPPToolInstance loginWithName:name password:password loginBack:^(BOOL isSuccess)
    {
        if (isSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIStoryboard * sb =
                [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                UIViewController * lvc =
                [sb instantiateViewControllerWithIdentifier:@"RegisterViewController"];
                [self presentViewController:lvc animated:YES completion:nil];
            });
        }
    }];
}

@end
