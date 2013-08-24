//
//  JGMethodHooker.m
//  JGMethodHooker
//
//  Created by Jonas Gessner 22.08.2013
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <objc/runtime.h>
#import "JGMethodHooker.h"


typedef void *(* JG_IMP)(id, SEL, ...);


#define kOrigSelPrefix @"__JGMethodHooker__orig_method__"
#define kHookSelPrefix @"__JGMethodHooker__hook_method__"

void MSHookMessageEx(Class _class, SEL sel, JG_IMP imp, JG_IMP *result);

@interface JGMethodHooker ()

+ (SEL)getOrigSelectorFromSelector:(SEL)selector;
+ (SEL)getHookSelectorFromSelector:(SEL)selector;

- (instancetype)initWithSelector:(SEL)_selector andClass:(Class)_objectClass;

@end


JG_ORIG_IMP getOrig(id object, SEL selector) {
    SEL final = [JGMethodHooker getOrigSelectorFromSelector:selector];
    JG_IMP imp = (JG_IMP)[[object class] instanceMethodForSelector:final];
    return (JG_ORIG_IMP)imp;
}


JG_ORIG_IMP getOrig_C(id object, SEL selector) {
    SEL final = [JGMethodHooker getOrigSelectorFromSelector:selector];
    JG_IMP imp = (JG_IMP)[object_getClass([object class]) instanceMethodForSelector:final];
    return (JG_ORIG_IMP)imp;
}


@implementation JGMethodHooker {
    SEL selector;
    Class hookClass;
    JG_IMP orig;
}

+ (instancetype)hookerWithSelector:(SEL)_selector andClass:(Class)_objectClass {
    return [[self alloc] initWithSelector:_selector andClass:_objectClass];
}

- (instancetype)initWithSelector:(SEL)_selector andClass:(Class)_objectClass {
    self = [super init];
    if (self) {
        selector = _selector;
        hookClass = _objectClass;
    }
    return self;
}

- (void)hookInstanceMethodWithReplacement:(JGHookBlock)replacement {
    orig = (JG_IMP)[hookClass instanceMethodForSelector:selector];
    
    JG_IMP replacementImp = (JG_IMP)imp_implementationWithBlock(replacement);
    
    MSHookMessageEx(hookClass, selector, replacementImp, &orig);
}

- (void)hookClassMethodWithReplacement:(JGHookBlock)replacement {
    Class meta = object_getClass(hookClass);
    
    orig = (JG_IMP)[meta instanceMethodForSelector:selector];
    
    JG_IMP replacementImp = (JG_IMP)imp_implementationWithBlock(replacement);
    
    MSHookMessageEx(meta, selector, replacementImp, &orig);
}

- (SEL)selector {
    return selector;
}

- (JG_ORIG_IMP)orig {
    return (JG_ORIG_IMP)orig;
}





+ (SEL)getOrigSelectorFromSelector:(SEL)selector {
    NSString *origSel = NSStringFromSelector(selector);
    origSel = [kOrigSelPrefix stringByAppendingString:origSel];
    return NSSelectorFromString(origSel);
}

+ (SEL)getHookSelectorFromSelector:(SEL)selector {
    NSString *origSel = NSStringFromSelector(selector);
    if ([origSel hasPrefix:kOrigSelPrefix]) {
        origSel = [origSel substringFromIndex:kOrigSelPrefix.length];
    }
    origSel = [kHookSelPrefix stringByAppendingString:origSel];
    return NSSelectorFromString(origSel);
}




+ (void)hookInstanceMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement {
    JG_ORIG_IMP origIMP = nil;
    
    [self hookInstanceMethod:selector ofClass:objectClass withReplacement:replacement getOrig:&origIMP];
    
    NSAssert(class_addMethod(objectClass, [self getOrigSelectorFromSelector:selector], (IMP)origIMP, method_getTypeEncoding(class_getInstanceMethod(objectClass, selector))), @"Could not create trampoline method for the original implementation of -[%@ %@]", NSStringFromClass(objectClass), NSStringFromSelector(selector));
}



+ (void)hookClassMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement {
    Class meta = object_getClass(objectClass);
    
    JG_ORIG_IMP origIMP = nil;
    
    [self hookClassMethod:selector ofClass:objectClass withReplacement:replacement getOrig:&origIMP];
    
    NSAssert(class_addMethod(meta, [self getOrigSelectorFromSelector:selector], (IMP)origIMP, method_getTypeEncoding(class_getClassMethod(objectClass, selector))), @"Could not create trampoline method for the original implementation of +[%@ %@]", NSStringFromClass(objectClass), NSStringFromSelector(selector));
}





+ (void)hookInstanceMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig {
    NSAssert(objectClass != self, @"I better shouldn't hook myself...");

    JG_ORIG_IMP origIMP = (JG_ORIG_IMP)[objectClass instanceMethodForSelector:selector];
    
    NSAssert((origIMP != NULL && [objectClass instancesRespondToSelector:selector]), @"Invalid method: -[%@ %@]", NSStringFromClass(objectClass), NSStringFromSelector(selector));
    
    if (orig) {
        *orig = origIMP;
    }
    
    JG_IMP replace = (JG_IMP)imp_implementationWithBlock(replacement);
    
    MSHookMessageEx(objectClass, selector, replace, (JG_IMP *)&origIMP);
}



+ (void)hookClassMethod:(SEL)selector ofClass:(Class)objectClass withReplacement:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig {
    NSAssert(objectClass != self, @"I better shouldn't hook myself...");
    
    Class meta = object_getClass(objectClass);
    
    JG_ORIG_IMP origIMP = (JG_ORIG_IMP)[objectClass methodForSelector:selector];
    
    NSAssert((origIMP != NULL && [objectClass respondsToSelector:selector]), @"Invalid method: +[%@ %@]", NSStringFromClass(objectClass), NSStringFromSelector(selector));
    
    if (orig) {
        *orig = origIMP;
    }
    
    JG_IMP replace = (JG_IMP)imp_implementationWithBlock(replacement);
    
    MSHookMessageEx(meta, selector, replace, (JG_IMP *)&origIMP);
}

@end


@implementation NSObject (JGMethodHooker)

+ (void)hookInstanceMethod:(SEL)selector usingBlock:(JGHookBlock)replacement {
    [JGMethodHooker hookInstanceMethod:selector ofClass:self withReplacement:replacement];
}

+ (void)hookClassMethod:(SEL)selector usingBlock:(JGHookBlock)replacement {
    [JGMethodHooker hookClassMethod:selector ofClass:self withReplacement:replacement];
}


+ (void)hookInstanceMethod:(SEL)selector usingBlock:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig {
    [JGMethodHooker hookInstanceMethod:selector ofClass:self withReplacement:replacement getOrig:orig];
}

+ (void)hookClassMethod:(SEL)selector usingBlock:(JGHookBlock)replacement getOrig:(JG_ORIG_IMP *)orig {
    [JGMethodHooker hookClassMethod:selector ofClass:self withReplacement:replacement getOrig:orig];
}

@end


