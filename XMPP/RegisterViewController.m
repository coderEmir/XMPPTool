//
//  RegisterViewController.m
//  XMPP
//
//  Created by xKing on 2020/4/25.
//  Copyright © 2020 xKing. All rights reserved.
//

#import "RegisterViewController.h"
#import "XMPPTool.h"
@interface RegisterViewController () <UITableViewDelegate ,UITableViewDataSource ,NSFetchedResultsControllerDelegate>

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityView;

@property (weak, nonatomic) IBOutlet UITextField *addFriendTextField;

@property (weak, nonatomic) IBOutlet UITextField *delFriendTextField;

@property (weak, nonatomic) IBOutlet UITextField *userTextField;

@property (weak, nonatomic) IBOutlet UITextField *userPwdField;

@property (weak, nonatomic) IBOutlet UITextField *addresseeTextField;

@property (weak, nonatomic) IBOutlet UITextField *contentTextField;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

/** 聊天数据 */
@property (nonatomic, strong) NSArray *messagesArr;
@end

@implementation RegisterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.messagesArr = [NSMutableArray array];
    self.messagesArr = [XMPPToolInstance loadMessagesWithDelegate:self];
}

#pragma mark - event

- (IBAction)addFriendEvent:(id)sender {
    NSString *addUserJID = self.addFriendTextField.text;
    [XMPPToolInstance addNewFriendWithUserName:addUserJID];
    NSLog(@"%@",addUserJID);
}

- (IBAction)delFriendEvent:(id)sender {
    NSString *delUserName = self.delFriendTextField.text;
    [XMPPToolInstance deleteFriendWithUserName:delUserName];
    NSLog(@"%@",delUserName);
}


- (IBAction)registerEvent:(id)sender {
    NSString *registerName = self.userTextField.text;
    NSString *registerPwd = self.userPwdField.text;
    
    [XMPPToolInstance registerUserWithName:registerName password:registerPwd registerBack:^(BOOL isSuccess) {
        NSLog(@"%d----注册成功！",isSuccess);
    }];
    NSLog(@"%@---%@",registerName,registerPwd);
}


- (IBAction)sendMsgEvent:(id)sender {
    NSString *addresseeJID = self.addresseeTextField.text;
    NSString *contentText = self.contentTextField.text;
    
    [XMPPToolInstance sendMessageWithName:addresseeJID content:contentText bodyType:XMPPBodyTypeText];
}

- (IBAction)loginOut:(id)sender {
    [XMPPToolInstance disconnectFromHost];
}
- (IBAction)dismissEvent:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messagesArr.count;
}

#pragma mark - UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellID = @"cellID";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    XMPPMessageArchiving_Message_CoreDataObject *obj = self.messagesArr[indexPath.row];
    NSString *type = [obj.message attributeStringValueForName:@"chatType"];
    if ([type isEqualToString:@"image"])
    {
        
    }
    cell.textLabel.text = obj.body;
    return cell;
}

#pragma mark - NSFetchedResultsControllerDelegate
// 内容发生改变 会调用
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    NSLog(@"数据发生改变,刷新数据");
    self.messagesArr = controller.fetchedObjects;
    [self.tableView reloadData];
}

@end
