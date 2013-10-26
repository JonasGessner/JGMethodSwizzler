//
//  AppDelegate.m
//  JGMethodSwizzler
//
//  Created by Jonas Gessner on 22.08.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "AppDelegate.h"
#import "JGMethodSwizzler.h"

@implementation AppDelegate


static BOOL testFailed = NO;

#define JGTestCheck(condition, description) if (!condition) {testFailed = YES; NSLog(@"Test Failed: %@", description);}

- (int)a:(int)b {
    return b-2;
}

+ (CGRect)testRect {
    return CGRectMake(0.0f, 1.0f, 2.0f, 3.0f);
}


+ (CGRect)testRect2:(CGRect)r {
    return CGRectInset(r, 10.0f, 10.0f);
}


- (void)test:(NSUInteger)iteration {
    int add = arc4random_uniform(50);
    
    [self.class swizzleInstanceMethod:@selector(a:) withReplacement:^ JGMethodReplacementProviderBlock {
        return ^ JGMethodReplacement(int, AppDelegate *, int b) {
            int orig = JGCastOriginal(int, b);
            return orig+add;
        };
    }];
    
    int yoo = arc4random_uniform(100);
    
    int aa = [self a:yoo];
    
    JGTestCheck(aa == yoo+add, @"Integer calculation mismatch");
    
    
    
    [self.class swizzleClassMethod:@selector(testRect) withReplacement:^ JGMethodReplacementProviderBlock {
        return ^ JGMethodReplacement(CGRect, const Class *) {
            CGRect orig = JGCastOriginal(CGRect);
            
            return CGRectInset(orig, -5.0f, -5.0f);
        };
    }];
    
    
    JGTestCheck(CGRectEqualToRect([self.class testRect], CGRectInset(CGRectMake(0.0f, 1.0f, 2.0f, 3.0f), -5.0f, -5.0f)), @"CGRect swizzling failed");
    
    [self.class swizzleClassMethod:@selector(testRect2:) withReplacement:^ JGMethodReplacementProviderBlock {
        return ^ JGMethodReplacement(CGRect, const Class *, CGRect rect) {
            CGRect orig = JGCastOriginal(CGRect, rect);
            
            return CGRectInset(orig, -5.0f, -5.0f);
        };
    }];
    
    
    CGRect testRect = (CGRect){{(CGFloat)arc4random_uniform(100), (CGFloat)arc4random_uniform(100)}, {(CGFloat)arc4random_uniform(100), (CGFloat)arc4random_uniform(100)}};
    
    JGTestCheck(CGRectEqualToRect([self.class testRect2:testRect], CGRectInset(CGRectInset(testRect, 10.0f, 10.0f), -5.0f, -5.0f)), @"CGRect swizzling (2) failed");
    
    
    NSObject *object = [NSObject new];
    
    
    [object swizzleMethod:@selector(description) withReplacement:^ JGMethodReplacementProviderBlock {
        return ^ JGMethodReplacement(NSString *, NSObject *) {
            NSString *orig = JGCastOriginal(NSString *);
            
            return [orig stringByAppendingString:@"Only swizzled this instance"];
        };
    }];
    
    JGTestCheck([[object description] hasSuffix:@"Only swizzled this instance"] && ![[[NSObject new] description] hasSuffix:@"Only swizzled this instance"], @"Instance swizzling failed");
    
    [object swizzleMethod:@selector(init) withReplacement:^ JGMethodReplacementProviderBlock {
        return ^ JGMethodReplacement(id, NSObject *) {
            id orig = JGCastOriginal(id);
            
            return orig;
        };
    }];
    
    BOOL ok = [object deswizzleMethod:@selector(description)];
    BOOL ok1 = [object deswizzleMethod:@selector(init)];
    BOOL ok2 = [object deswizzle];
    
    JGTestCheck(ok == YES && ok1 == YES && ok2 == NO && ![[object description] hasSuffix:@"Only swizzled this instance"], @"Instance swizzling failed (1)");
}



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CFTimeInterval start = CFAbsoluteTimeGetCurrent();
    
    [self test:0];
    
    if (!testFailed) {
        NSLog(@"Tests Succeeded. Elapsed Time: %f", CFAbsoluteTimeGetCurrent()-start);
    }
    
    return YES;
}

@end
