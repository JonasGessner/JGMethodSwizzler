//
//  JGMethodHooker.m
//  JGMethodHooker
//
//  Created by Jonas Gessner 22.08.2013
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <objc/runtime.h>
#import "JGMethodHooker.h"

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
    JGHookBlock dummy = ^ JGHookReplacement {
        return nil;
    };
    const char *factoryType = blockGetType(dummy);
    return (strcmp(factoryType, blockType) == 0);
}


static JG_IMP originalClassMethod(__unsafe_unretained Class class, SEL selector) {
    static NSMutableDictionary *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary new];
    });

    NSString *key = [[NSStringFromClass(class) stringByAppendingString:@" "] stringByAppendingString:NSStringFromSelector(selector)];
    
    NSValue *pointer = dict[key];
    
    if (pointer) {
        return [pointer pointerValue];
    }
    else {
        JG_IMP orig = (JG_IMP)[class methodForSelector:selector];
        
        dict[key] = [NSValue valueWithPointer:orig];
        
        return orig;
    }
}


static JG_IMP originalInstanceMethod(__unsafe_unretained Class class, SEL selector) {
    static NSMutableDictionary *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary new];
    });
    
    NSString *key = [[NSStringFromClass(class) stringByAppendingString:@" "] stringByAppendingString:NSStringFromSelector(selector)];
    
    NSValue *pointer = dict[key];
    
    if (pointer) {
        return [pointer pointerValue];
    }
    else {
        JG_IMP orig = (JG_IMP)[class instanceMethodForSelector:selector];
        
        dict[key] = [NSValue valueWithPointer:orig];
        
        return orig;
    }
}



NS_INLINE void hookClassMethod(__unsafe_unretained Class class, SEL selector, JGHookBlock replacement) {
    NSCAssert(blockIsValidReplacementProvider(replacement), @"Invalid method replacemt provider");
    
    NSCAssert([class respondsToSelector:selector], @"Invalid method: +[%@ %@]", NSStringFromClass(class), NSStringFromSelector(selector));
    
    JG_IMP orig = originalClassMethod(class, selector);
    
    id replaceBlock = replacement(orig, class, selector);
    
    
    NSCAssert(blockIsCompatibleWithMethodType(replaceBlock, class, selector, NO), @"Invalid method replacement");
    
    
    JG_IMP replace = (JG_IMP)imp_implementationWithBlock(replaceBlock);
    
    
    orig = nil;
    
    
    Class meta = object_getClass(class);
    
    MSHookMessageEx(meta, selector, replace, NULL);
}


NS_INLINE void hookInstanceMethod(__unsafe_unretained Class class, SEL selector, JGHookBlock replacement) {
    NSCAssert(blockIsValidReplacementProvider(replacement), @"Invalid method replacemt provider");
    
    NSCAssert([class instancesRespondToSelector:selector], @"Invalid method: -[%@ %@]", NSStringFromClass(class), NSStringFromSelector(selector));
    
    JG_IMP orig = originalInstanceMethod(class, selector);
    
    id replaceBlock = replacement(orig, class, selector);
    
    
    NSCAssert(blockIsCompatibleWithMethodType(replaceBlock, class, selector, YES), @"Invalid method replacement");
    
    
    JG_IMP replace = (JG_IMP)imp_implementationWithBlock(replaceBlock);
    
    orig = nil;
    
    MSHookMessageEx(class, selector, replace, NULL);
}


@implementation NSObject (JGMethodHooker)

+ (void)hookClassMethod:(SEL)selector usingBlock:(JGHookBlock)replacement {
    @synchronized(self) {
        hookClassMethod(self, selector, replacement);
    }
}

+ (void)hookInstanceMethod:(SEL)selector usingBlock:(JGHookBlock)replacement {
    @synchronized(self) {
        hookInstanceMethod(self, selector, replacement);
    }
}

@end


