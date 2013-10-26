//
//  JGMethodSwizzler.m
//  JGMethodSwizzler
//
//  Created by Jonas Gessner 22.08.2013
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <objc/runtime.h>
#import "JGMethodSwizzler.h"
#import <libkern/OSAtomic.h>

FOUNDATION_EXTERN void MSHookMessageEx(Class class, SEL selector, JG_IMP replacement, JG_IMP *original);


// See http://clang.llvm.org/docs/Block-ABI-Apple.html#high-level
struct Block_literal_1 {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor_1 {
        unsigned long int reserved;         // NULL
        unsigned long int size;         // sizeof(struct Block_literal_1)
        // optional helper functions
        void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
        void (*dispose_helper)(void *src);             // IFF (1<<25)
        // required ABI.2010.3.16
        const char *signature;                         // IFF (1<<30)
    } *descriptor;
    // imported variables
};

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};
typedef int BlockFlags;


NS_INLINE const char *blockGetType(id block) {
    struct Block_literal_1 *blockRef = (__bridge struct Block_literal_1 *)block;
    BlockFlags flags = blockRef->flags;
    
    if (flags & BLOCK_HAS_SIGNATURE) {
        void *signatureLocation = blockRef->descriptor;
        signatureLocation += sizeof(unsigned long int);
        signatureLocation += sizeof(unsigned long int);
        
        if (flags & BLOCK_HAS_COPY_DISPOSE) {
            signatureLocation += sizeof(void(*)(void *dst, void *src));
            signatureLocation += sizeof(void (*)(void *src));
        }
        
        const char *signature = (*(const char **)signatureLocation);
        return signature;
    }
    
    return NULL;
}

NS_INLINE BOOL blockIsCompatibleWithMethodType(id block, __unsafe_unretained Class class, SEL selector, BOOL instanceMethod) {
    const char *blockType = blockGetType(block);
    
    NSMethodSignature *blockSignature = [NSMethodSignature signatureWithObjCTypes:blockType];
    NSMethodSignature *methodSignature = (instanceMethod ? [class instanceMethodSignatureForSelector:selector] : [class methodSignatureForSelector:selector]);
    
    if (!blockSignature || !methodSignature) {
        return NO;
    }
    
    if (blockSignature.numberOfArguments != methodSignature.numberOfArguments) {
        return NO;
    }
    const char *blockReturnType = blockSignature.methodReturnType;
    
    if (strncmp(blockReturnType, "@", 1) == 0) {
        blockReturnType = "@";
    }
    
    if (strcmp(blockReturnType, methodSignature.methodReturnType) != 0) {
        return NO;
    }
    
    for (unsigned int i = 0; i < methodSignature.numberOfArguments; i++) {
        if (i == 0) {
            // self in method, block in block
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], "@") != 0) {
                return NO;
            }
            if (strcmp([blockSignature getArgumentTypeAtIndex:i], "@?") != 0) {
                return NO;
            }
        }
        else if(i == 1) {
            // SEL in method, self in block
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], ":") != 0) {
                return NO;
            }
            if (instanceMethod ? strncmp([blockSignature getArgumentTypeAtIndex:i], "@", 1) != 0 : (strncmp([blockSignature getArgumentTypeAtIndex:i], "@", 1) != 0 && strcmp([blockSignature getArgumentTypeAtIndex:i], "r^#") != 0)) {
                return NO;
            }
        }
        else {
            const char *blockSignatureArg = [blockSignature getArgumentTypeAtIndex:i];
            
            if (strncmp(blockSignatureArg, "@", 1) == 0) {
                blockSignatureArg = "@";
            }
            
            if (strcmp(blockSignatureArg, [methodSignature getArgumentTypeAtIndex:i]) != 0) {
                return NO;
            }
        }
    }
    
    return YES;
}


NS_INLINE BOOL blockIsValidReplacementProvider(id block) {
    const char *blockType = blockGetType(block);
    const char *expectedType = "@16@?0^?4#8:12";
    return (strcmp(expectedType, blockType) == 0);
}


static Method originalClassMethod(__unsafe_unretained Class class, SEL selector, BOOL fetchOnly) {
    static NSMutableDictionary *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary dictionary];
    });

    NSString *key = [[NSStringFromClass(class) stringByAppendingString:@" "] stringByAppendingString:NSStringFromSelector(selector)];
    
    NSValue *pointer = dict[key];
    
    if (pointer) {
        void *p = [pointer pointerValue];
        if (fetchOnly) {
            [dict removeObjectForKey:key];
        }
        return p;
    }
    else if (!fetchOnly) {
        Method orig = class_getClassMethod(class, selector);
        
        dict[key] = [NSValue valueWithPointer:orig];
        
        return orig;
    }
    else {
        return NULL;
    }
}


static Method originalInstanceMethod(__unsafe_unretained Class class, SEL selector, BOOL fetchOnly) {
    static NSMutableDictionary *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary dictionary];
    });
    
    NSString *key = [[NSStringFromClass(class) stringByAppendingString:@" "] stringByAppendingString:NSStringFromSelector(selector)];
    
    NSValue *pointer = dict[key];
    
    if (pointer) {
        void *p = [pointer pointerValue];
        if (fetchOnly) {
            [dict removeObjectForKey:key];
        }
        return p;
    }
    else if (!fetchOnly) {
        Method orig = class_getInstanceMethod(class, selector);
        
        dict[key] = [NSValue valueWithPointer:orig];
        
        return orig;
    }
    else {
        return NULL;
    }
}







//Core swizzling

static OSSpinLock lock = OS_SPINLOCK_INIT;

NS_INLINE void swizzleClassMethod(__unsafe_unretained Class class, SEL selector, JGMethodReplacementProvider replacement) {
    NSCAssert(blockIsValidReplacementProvider(replacement), @"Invalid method replacemt provider");
    
    NSCAssert([class respondsToSelector:selector], @"Invalid method: +[%@ %@]", NSStringFromClass(class), NSStringFromSelector(selector));
    
    
    OSSpinLockLock(&lock);
    
    JG_IMP orig = (JG_IMP)method_getImplementation(originalClassMethod(class, selector, NO));
    
    id replaceBlock = replacement(orig, class, selector);
    
    
    NSCAssert(blockIsCompatibleWithMethodType(replaceBlock, class, selector, NO), @"Invalid method replacement");
    
    
    JG_IMP replace = (JG_IMP)imp_implementationWithBlock(replaceBlock);
    
    
    orig = nil;
    
    
    Class meta = object_getClass(class);
    
    MSHookMessageEx(meta, selector, replace, NULL);
    
    OSSpinLockUnlock(&lock);
}


NS_INLINE void swizzleInstanceMethod(__unsafe_unretained Class class, SEL selector, JGMethodReplacementProvider replacement) {
    NSCAssert(blockIsValidReplacementProvider(replacement), @"Invalid method replacemt provider");
    
    NSCAssert([class instancesRespondToSelector:selector], @"Invalid method: -[%@ %@]", NSStringFromClass(class), NSStringFromSelector(selector));
    
    
    OSSpinLockLock(&lock);
    
    JG_IMP orig = (JG_IMP)method_getImplementation(originalInstanceMethod(class, selector, NO));
    
    id replaceBlock = replacement(orig, class, selector);
    
    
    NSCAssert(blockIsCompatibleWithMethodType(replaceBlock, class, selector, YES), @"Invalid method replacement");
    
    
    JG_IMP replace = (JG_IMP)imp_implementationWithBlock(replaceBlock);
    
    orig = nil;
    
    MSHookMessageEx(class, selector, replace, NULL);
    
    OSSpinLockUnlock(&lock);
}





NS_INLINE void classSwizzleMethod(Class cls, Method method, IMP newImp) {
    if (!newImp) {
        newImp = method_getImplementation(method);
    }
    
	BOOL success = class_addMethod(cls, method_getName(method), newImp, method_getTypeEncoding(method));
	if (!success) {
		// class already has implementation, swizzle it instead
		method_setImplementation(method, newImp);
	}
}

static NSMutableDictionary *instanceSwizzleCount;

NS_INLINE unsigned int swizzleCount(__unsafe_unretained id object) {
    NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(object)];
    
    unsigned int count = [instanceSwizzleCount[key] unsignedIntValue];
    
    return count;
}

NS_INLINE void increaseSwizzleCount(__unsafe_unretained id object) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instanceSwizzleCount = [NSMutableDictionary dictionary];
    });
    
    NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(object)];
    
    unsigned int count = [instanceSwizzleCount[key] unsignedIntValue];
    
    instanceSwizzleCount[key] = @(count+1);
}

NS_INLINE void eliminateSwizzleCount(__unsafe_unretained id object) {
    NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(object)];
    [instanceSwizzleCount removeObjectForKey:key];
}

NS_INLINE void decreaseSwizzleCount(__unsafe_unretained id object) {
    NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(object)];
    
    unsigned int count = [instanceSwizzleCount[key] unsignedIntValue];
    
    if (count == 1) {
        [instanceSwizzleCount removeObjectForKey:key];
    }
    else if (count > 1) {
        instanceSwizzleCount[key] = @(count-1);
    }
}



static NSMutableDictionary *dynamicSubclassesByObject;

NS_INLINE BOOL deswizzleInstance(__unsafe_unretained id object) {
    OSSpinLockLock(&lock);
    
    BOOL success = NO;
    
    if (swizzleCount(object) > 0) {
        object_setClass(object, [object class]);
        
        Class dynamicSubclass = object_getClass(object);
        
        objc_disposeClassPair(dynamicSubclass);
        
        [dynamicSubclassesByObject removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(object)]];
        
        eliminateSwizzleCount(object);
        
        success = YES;
    }
    OSSpinLockUnlock(&lock);
    
    return success;
}

NS_INLINE BOOL deswizzleMethod(__unsafe_unretained id object, SEL selector) {
    OSSpinLockLock(&lock);
    
    BOOL success = NO;
    
    unsigned int count = swizzleCount(object);
    
    if (count == 1) {
        OSSpinLockUnlock(&lock);
        return deswizzleInstance(object);
    }
    else if (count > 1) {
        Method originalMethod = originalInstanceMethod([object class], selector, YES);
        
        if (originalMethod) {
            classSwizzleMethod(object_getClass(object), originalMethod, NULL);
            success = YES;
        }
        decreaseSwizzleCount(object);
    }
    
    OSSpinLockUnlock(&lock);
    
    return success;
}


NS_INLINE void swizzleInstance(__unsafe_unretained id object, SEL selector, JGMethodReplacementProvider replacementProvider) {
    Class class = [object class];
    
    NSCAssert(blockIsValidReplacementProvider(replacementProvider), @"Invalid method replacemt provider");
    
    NSCAssert([object respondsToSelector:selector], @"Invalid method: -[%@ %@]", NSStringFromClass(class), NSStringFromSelector(selector));
    
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dynamicSubclassesByObject = [NSMutableDictionary dictionary];
	});
    
	OSSpinLockLock(&lock);
	
	Class newClass = [dynamicSubclassesByObject[[NSValue valueWithPointer:(__bridge const void *)(object)]] pointerValue];
    
	if (!newClass) {
        NSString *dynamicSubclass = [NSStringFromClass(class) stringByAppendingFormat:@"_JGMS_%@", [[NSUUID UUID] UUIDString]];
		
        const char *newClsName = [dynamicSubclass UTF8String];
        
        NSCAssert(!objc_lookUpClass(newClsName), @"Class %s already exists!\n", newClsName);
        
        newClass = objc_allocateClassPair(class, newClsName, 0);
        NSCAssert(newClass, @"Could not create class %s\n", newClsName);
        
        objc_registerClassPair(newClass);
        
        dynamicSubclassesByObject[[NSValue valueWithPointer:(__bridge const void *)(object)]] = [NSValue valueWithPointer:(__bridge const void *)(newClass)];
        
        Method classMethod = class_getInstanceMethod(newClass, @selector(class));
        
        id swizzledClass = ^Class (__unsafe_unretained id self) {
            return class;
        };
        
        classSwizzleMethod(newClass, classMethod, imp_implementationWithBlock(swizzledClass));
    }
    
    Method origMethod = originalInstanceMethod(class, selector, NO);
    
    id replaceBlock = replacementProvider((JG_IMP)method_getImplementation(origMethod), class, selector);
    
    NSCAssert(blockIsCompatibleWithMethodType(replaceBlock, class, selector, YES), @"Invalid method replacement");
    
    classSwizzleMethod(newClass, origMethod, imp_implementationWithBlock(replaceBlock));

    
    
    SEL deallocSel = sel_getUid("dealloc");
    
    Method dealloc = class_getInstanceMethod(newClass, deallocSel);
    JG_IMP deallocImp = (JG_IMP)method_getImplementation(dealloc);
	
	id deallocHandler = ^(__unsafe_unretained id self) {
        
        NSCAssert(deswizzleInstance(self), @"Deswizzling of class %@ failed", NSStringFromClass([self class]));
        
        if (deallocImp) {
            deallocImp(self, deallocSel);
        }
    };
    
    classSwizzleMethod(newClass, dealloc, imp_implementationWithBlock(deallocHandler));
    
    
    
    
    object_setClass(object, newClass);
	
    increaseSwizzleCount(object);
    
	OSSpinLockUnlock(&lock);
}




@implementation NSObject (JGMethodSwizzler)

+ (void)swizzleClassMethod:(SEL)selector withReplacement:(JGMethodReplacementProvider)replacementProvider {
    swizzleClassMethod(self, selector, replacementProvider);
}

+ (void)swizzleInstanceMethod:(SEL)selector withReplacement:(JGMethodReplacementProvider)replacementProvider {
    swizzleInstanceMethod(self, selector, replacementProvider);
}

- (void)swizzleMethod:(SEL)selector withReplacement:(JGMethodReplacementProvider)replacementProvider {
    swizzleInstance(self, selector, replacementProvider);
}

- (BOOL)deswizzleMethod:(SEL)selector {
    return deswizzleMethod(self, selector);
}

- (BOOL)deswizzle {
    return deswizzleInstance(self);
}

@end


