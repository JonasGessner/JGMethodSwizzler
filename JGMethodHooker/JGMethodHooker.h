//
//  JGMethodHooker.h
//  JGMethodHooker
//
//  Created by Jonas Gessner 22.08.2013
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>



//-------------------------
/** @name typedefs */
//-------------------------

typedef void *(* JG_IMP)(__unsafe_unretained id, SEL, ...);

typedef id (^JGHookBlock)(JG_IMP original, __unsafe_unretained Class swizzledClass, SEL selector);





//-------------------------
/** @name Helper macros */
//-------------------------

#define JGHookMethod(returntype, selftype, ...) returntype (__unsafe_unretained selftype self, ##__VA_ARGS__)

#define JGHookReplacement id (JG_IMP original, __unsafe_unretained Class swizzledClass, SEL selector)

#define JGHookCast(type, original) ((__typeof(type (*)(__typeof(self), SEL, ...)))original) //always use JGHookCast (unless the return type really is void *)






@interface NSObject (JGMethodHooker)


//-----------------------------------------------
/** @name Category for extremely easy hooking */
//-----------------------------------------------



/**
 Hook the specified class method.
 
 @param selector Selector of the method to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: return_type ^(id self, ...).
 
 */

+ (void)hookClassMethod:(SEL)selector usingBlock:(JGHookBlock)replacement;


/**
 Hook the specified instance method.
 
 @param selector Selector of the method to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: return_type ^(id self, ...).
 
 */

+ (void)hookInstanceMethod:(SEL)selector usingBlock:(JGHookBlock)replacement;


@end
