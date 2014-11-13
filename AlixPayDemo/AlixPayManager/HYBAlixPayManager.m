//
//  HYBAlixPayManager.m
//  AlixPayDemo
//
//  Created by 黄仪标 on 14/11/13.
//
//

#import "HYBAlixPayManager.h"
#import "NSString+Encryt.h"
#import "MKNetworkEngine.h"
#import "AlixPay.h"
#import "AlixPayResult.h"

@interface HYBAlixPayManager () {
  NSMutableString *_signString;
  
  HYBAlixPayCompletion _completion;
  HYBAlixPayErrorBlock _errorBlock;
}

@end

@implementation HYBAlixPayManager

+ (HYBAlixPayManager *)shared {
  static dispatch_once_t onceToken = 0;
  static HYBAlixPayManager *sharedManager = nil;
  
  dispatch_once(&onceToken, ^{
    if (!sharedManager) {
      sharedManager = [[[self class] alloc] init];
    }
  });
  
  return sharedManager;
}

- (void)alixPayWithCompletion:(HYBAlixPayCompletion)completion errorBlock:(HYBAlixPayErrorBlock)errorBlock {
  _completion = [completion copy];
  _errorBlock = [errorBlock copy];
  
  [self requestData];
  return;
}

/*!
 签名规则：将所有非null属性按key=value方式，对key进行自然排序后，以&符号拼接起来，末尾加上私钥(signKey)，然后对此字符串进行MD5运算。例：sign=MD5(sort(key1=value1&key2=value2)&signKey)
 value的计算规则为：基本类型(包括String)的属性值为属性值本身(小数格式化为0.######)，不进行任何附加运算；
 list与数组类型的属性值为MD5值，规则为：对每个元素进行对象MD5运算(无私钥(signKey)的签名规则)，并将结果进行自然排序后，以英文,号拼接起来，进行MD5运算。例：listKey=MD5(sort(MD5(list[0]),MD5(list[1])))
 map与非基本类型(包括String)的属性值为对象MD5运算(无私钥(signKey)的签名规则)。
 签名的key：公开权限的接口，url后方无TOKEN参数，此时使用约定的固定key加密；私密权限的接口，url后方有TOKEN参数，此时使用用户密码MD5作为key加密。
 */
- (NSString *)signWithSignKey:(NSString *)signKey params:(NSDictionary *)params {
  NSArray *allKeys = params.allKeys;
  
  [allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    return [obj1 compare:obj2 options:NSCaseInsensitiveSearch];
  }];
  
  if (_signString == nil) {
    _signString = [[NSMutableString alloc] init];
  }
  
  for (NSString *key in allKeys) {
    NSString *value = params[key];
    if (value == nil) {
      continue;
    }
    
    if ([value isKindOfClass:[NSDictionary class]]) {
      [_signString setString:[self signWithSignKey:@"" params:(NSDictionary *)value]];
      [_signString insertString:[NSString stringWithFormat:@"%@=", key] atIndex:0];
      continue;
    } else {
      NSString *valueString = [NSString stringWithFormat:@"%@", value];
      if (_signString.length == 0) {
        [_signString appendFormat:@"%@=%@", key, valueString];
      } else {
        [_signString appendFormat:@"&%@=%@", key, valueString];
      }
    }
  }
  
  if (signKey.length != 0) {
    [_signString appendFormat:@"&%@", signKey];
  }
  
  return _signString.md5.lowercaseString;
}

- (void)requestData {
  NSString *url = @"/ManicureShop/api/order/pay/%@";
  NSDictionary *dic = @{@"request" : @{
                            @"orderNo" : @"1409282102222110030643",
                            @"type" : @(2)
                            }
                        };
  _signString = nil;
  NSString *sign = [self signWithSignKey:@"test" params:dic];
  
  url = [NSString stringWithFormat:url, sign];
  MKNetworkEngine *engine = [[MKNetworkEngine alloc] initWithHostName:@"218.244.131.231" apiPath:nil customHeaderFields:@{@"Content-Type" : @"application/json"}];
  MKNetworkOperation *op = [engine operationWithPath:url params:dic httpMethod:@"POST"];
  op.postDataEncoding = MKNKPostDataEncodingTypeJSON;
  [op setHeader:@"Content-Type" withValue:@"application/json"];
  [op addCompletionHandler:^(MKNetworkOperation *completedOperation) {
    [completedOperation responseJSONWithCompletionHandler:^(id jsonObject) {
      //获取安全支付单例并调用安全支付接口
      AlixPay * alixpay = [AlixPay shared];
      int ret = [alixpay pay:jsonObject[@"response"][@"payRequest"] applicationScheme:@"AlixPayDemo"];
      
      if (ret == kSPErrorAlipayClientNotInstalled) {
        dispatch_async(dispatch_get_main_queue(), ^{
          UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"提示"
                                                               message:@"您还没有安装支付宝的客户端，请先装。"
                                                              delegate:nil
                                                     cancelButtonTitle:@"确定"
                                                     otherButtonTitles:nil];
          [alertView show];
          
          if (_completion) {
            _completion(@"您还没有安装支付宝的客户端，请先装");
          }
        });
      } else if (ret == kSPErrorSignError) {
        if (_errorBlock) {
          _errorBlock([self errorWithMessage:@"签名错误"]);
        }
      }
    }];
  } errorHandler:^(MKNetworkOperation *completedOperation, NSError *error) {
    if (_errorBlock) {
      _errorBlock(error);
    }
  }];
  [engine enqueueOperation:op];
  return;
}

- (void)handleOpenURL:(NSURL *)url application:(UIApplication *)application {
  AlixPay *alixpay = [AlixPay shared];
  AlixPayResult *result = [alixpay handleOpenURL:url];
  
  if (result) {
    // 支付成功
    if (9000 == result.statusCode) {
      // here do nothing
    }
    // 支付失败,可以通过result.statusCode查询错误码
    else {
      dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"提示"
                                                             message:result.statusMessage
                                                            delegate:nil
                                                   cancelButtonTitle:@"确定"
                                                   otherButtonTitles:nil];
        [alertView show];
      });
    }
  }
  return;
}

- (NSError *)errorWithMessage:(NSString *)message {
  NSError *error = [[NSError alloc] initWithDomain:message code:0 userInfo:nil];
  NSLog(@"%@", [error description]);
  return error;
}

@end
