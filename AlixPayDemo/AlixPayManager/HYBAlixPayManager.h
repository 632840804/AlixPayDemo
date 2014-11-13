//
//  HYBAlixPayManager.h
//  AlixPayDemo
//
//  Created by 黄仪标 on 14/11/13.
//
//

#import <Foundation/Foundation.h>

/*!
 * @brief  支付宝支付功能封装类，此类提供一键式调起支付宝功能，方便快捷
 *
 * @author haungyibiao
 */
@interface HYBAlixPayManager : NSObject

+ (HYBAlixPayManager *)shared;

// status 为nil，表示调起成功，不为nil，表示用户手机未安装支付宝钱包
typedef void (^HYBAlixPayCompletion)(NSString *status);
typedef void (^HYBAlixPayErrorBlock)(NSError *error);
- (void)alixPayWithCompletion:(HYBAlixPayCompletion)completion errorBlock:(HYBAlixPayErrorBlock)errorBlock;

// 在appdelegate中调用
- (void)handleOpenURL:(NSURL *)url application:(UIApplication *)application;

@end
