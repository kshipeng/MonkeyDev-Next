//  github: https://github.com/AloneMonkey/MonkeyDev
//  github: https://github.com/kshipeng/MonkeyDev-Next
//
//  ___FILENAME___
//  ___PACKAGENAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

#import "___FILEBASENAME___.h"
#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

CHConstructor{
    printf(INSERT_SUCCESS_WELCOME);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"


CHDeclareClass(CustomViewController)

//add new method
CHDeclareMethod1(void, CustomViewController, newMethod, NSString*, output){
    NSLog(@"This is a new method : %@", output);
}

#pragma clang diagnostic pop

CHOptimizedClassMethod0(self, void, CustomViewController, classMethod){
    NSLog(@"hook class method");
    CHSuper0(CustomViewController, classMethod);
}

CHOptimizedMethod0(self, NSString*, CustomViewController, getMyName){
    //get origin value
    NSString* originName = CHSuper(0, CustomViewController, getMyName);
    
    NSLog(@"origin name is:%@",originName);
    
    //get property
    NSString* password = CHIvar(self,_password,__strong NSString*);
    
    NSLog(@"password is %@",password);
    
    [self newMethod:@"output"];
    
    //set new property
    self.newProperty = @"newProperty";
    
    NSLog(@"newProperty : %@", self.newProperty);
    
    //change the value
    return @"___FULLUSERNAME___";
    
}

//add new property
CHPropertyRetainNonatomic(CustomViewController, NSString*, newProperty, setNewProperty);

CHConstructor{
    @autoreleasepool{
        CHLoadLateClass(CustomViewController);
        CHClassHook0(CustomViewController, getMyName);
        CHClassHook0(CustomViewController, classMethod);
        
        CHHook0(CustomViewController, newProperty);
        CHHook1(CustomViewController, setNewProperty);
    }
}

