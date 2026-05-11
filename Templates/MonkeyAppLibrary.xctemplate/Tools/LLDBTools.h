//  weibo: http://weibo.com/xiaoqing28
//  blog:  http://www.alonemonkey.com
//
//  LLDBTools.h
//  MonkeyDev
//
//  Created by AloneMonkey on 2018/3/8.
//  Copyright © 2018年 AloneMonkey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <mach/vm_types.h>

//(lldb) po pviews()

#ifdef __cplusplus
extern "C" {
#endif

NSString* pvc(void);

NSString* pviews(void);

NSString* pactions(vm_address_t address);

NSString* pblock(vm_address_t address);

NSString* methods(const char * classname);

NSString* ivars(vm_address_t address);

NSString* choose(const char* classname);

NSString* vmmap(void);

NSString* pblock_signature(id block_obj);

#ifdef __cplusplus
}
#endif
