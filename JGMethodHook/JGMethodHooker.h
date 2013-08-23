//
//  JGMethodHooker.h
//  JGMethodHooker
//
//  Created by Jonas Gessner 22.08.2013
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef IMP JG_ORIG_IMP;

typedef id JGHookBlock;

#ifndef JGExtern

#ifdef __cplusplus
#define JGExtern extern "C"
#else
#define JGExtern extern
#endif

#endif


/**
 Returns the original implementation of a hooked instance method.
 
 @param object An instance of the class being hooked.
 @param selector Selector of the original implementation to return.
 
 @return Returns the original implementation of the instance class method. Its signature is: method_return_type ^(id self, SEL cmd, method_args...).
 
 */

JGExtern JG_ORIG_IMP getOrig(id object, SEL selector);


/**
 Returns the original implementation of a hooked class method.
 
 @param object An instance of the class being hooked.
 @param selector Selector of the original implementation to return.

 @return Returns the original implementation of the specified class method. Its signature is: method_return_type ^(id self, SEL cmd, method_args...).
 */

JGExtern JG_ORIG_IMP getOrig_C(id object, SEL selector);


@interface JGMethodHooker : NSObject

//-----------------------------------------------
/** @name Hooking using an instance of JGMethodHooker */
//-----------------------------------------------


/**
 Returns a newly initialized instance of JGMethodHooker. No hooking is done at this point. Invoke -hookInstancesMethodWithReplacement: or -hookClassMethodWithReplacement: on the returned instance to hook the specified method.
 
 @param selector Selector of the method to hook.
 @param objectClass The class to hook.
 
 */

+ (instancetype)hookerWithSelector:(SEL)selector andClass:(Class)objectClas;



/**
 Hooks the (instance) method.
 
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 
 */

- (void)hookInstanceMethodWithReplacement:(JGHookBlock)replacement;

/**
 Hooks the (instance) method.
 
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 
 */

- (void)hookClassMethodWithReplacement:(JGHookBlock)replacement;


/**
 @return Returns the selector of the method that is being hooked.
 */

- (SEL)selector;

/**
 @return Returns the original implementation of the method that is being hooked. Its signature is: method_return_type ^(id self, SEL cmd, method_args...).
 */

- (JG_ORIG_IMP)orig;




//-----------------------------------------------
/** @name Direct hooking using JGMethodHooker's class methods */
//-----------------------------------------------

/**
 Replace the specified instance method's implementation with a block. A trampoline method is created for the original implementation which can be accessed through getOrig().
 
 @param selector Selector of the method to hook.
 @param objectClass The class to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 
 */

+ (void)hookInstanceMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement;


/**
 Replace the specified class method's implementation with a block. A trampoline method is created for the original implementation which can be accessed through getOrig_C().
 
 @param selector Selector of the method to hook.
 @param objectClass The class to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 
 */

+ (void)hookClassMethod:(SEL)method ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement;







/**
 Replace the specified instance method's implementation with a block.
 
 @param selector Selector of the method to hook.
 @param objectClass The class to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 @param orig A pointer to a reference of the original implementation. Its signature is: method_return_type ^(id self, SEL cmd, method_args...). (optional)
 */

+ (void)hookInstanceMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig;


/**
 Replace the specified class method's implementation with a block.
 
 @param selector Selector of the method to hook.
 @param objectClass The class to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 @param orig A pointer to a reference of the original implementation. Its signature is: method_return_type ^(id self, SEL cmd, method_args...). (optional)
 */

+ (void)hookClassMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig;



@end

@interface NSObject (JGMethodHooker)

//-----------------------------------------------
/** @name Category for extremely easy hooking */
//-----------------------------------------------

/**
 Replace the specified class method's implementation with a block. A trampoline method is created for the original implementation which can be accessed through getOrig().
 
 @param selector Selector of the method to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 
 */

+ (void)hookInstanceMethod:(SEL)selector usingBlock:(JGHookBlock)replacement;


/**
 Replace the specified class method's implementation with a block. A trampoline method is created for the original implementation which can be accessed through getOrig_C().
 
 @param selector Selector of the method to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 
 */

+ (void)hookClassMethod:(SEL)selector usingBlock:(JGHookBlock)replacement;








/**
 Replace the specified class method's implementation with a block.
 
 @param selector Selector of the method to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 @param orig A pointer to a reference of the original implementation. Its signature is: method_return_type ^(id self, SEL cmd, method_args...). (optional)
 
 @warning orig requires a __block attribute.
 */

+ (void)hookInstanceMethod:(SEL)selector usingBlock:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig;


/**
 Replace the specified class method's implementation with a block.
 
 @param selector Selector of the method to hook.
 @param replacement The replacement block for the method that is hooked. Its signature should be: method_return_type ^(id self, method_args...).
 @param orig A pointer to a reference of the original implementation. Its signature is: method_return_type ^(id self, SEL cmd, method_args...). (optional)
 
 @warning orig requires a __block attribute.
 */

+ (void)hookClassMethod:(SEL)selector usingBlock:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig;


@end
