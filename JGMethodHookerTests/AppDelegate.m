//
//  AppDelegate.m
//  JGMethodHook
//
//  Created by Jonas Gessner on 22.08.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "AppDelegate.h"
#import "JGMethodHooker.h"

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


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    int add = arc4random_uniform(50);
    
    [self.class hookInstanceMethod:@selector(a:) usingBlock:^ JGHookReplacement {
        return ^JGHookMethod(int, AppDelegate *, int b) {
            int orig = JGHookCast(int, original)(self, selector, b);
            
            return orig+add;
        };
    }];
    
    int yoo = arc4random_uniform(100);
    
    int aa = [self a:yoo];
    
    JGTestCheck(aa == yoo+add, @"Integer calculation mismatch");
    
    
    
    [self.class hookClassMethod:@selector(testRect) usingBlock:^ JGHookReplacement {
        return ^JGHookMethod(CGRect, const Class *) {
            CGRect orig = JGHookCast(CGRect, original)(self, selector);
            
            return CGRectInset(orig, -5.0f, -5.0f);
        };
    }];
    
    
    JGTestCheck(CGRectEqualToRect([self.class testRect], CGRectInset(CGRectMake(0.0f, 1.0f, 2.0f, 3.0f), -5.0f, -5.0f)), @"CGRect hooking failed");
    
    
    
    [self.class hookClassMethod:@selector(testRect2:) usingBlock:^ JGHookReplacement {
        return ^JGHookMethod(CGRect, const Class *, CGRect rect) {
            CGRect orig = JGHookCast(CGRect, original)(self, selector, rect);
            
            return CGRectInset(orig, -5.0f, -5.0f);
        };
    }];
    
    
    CGRect testRect = (CGRect){{(CGFloat)arc4random_uniform(100), (CGFloat)arc4random_uniform(100)}, {(CGFloat)arc4random_uniform(100), (CGFloat)arc4random_uniform(100)}};
    
    JGTestCheck(CGRectEqualToRect([self.class testRect2:testRect], CGRectInset(CGRectInset(testRect, 10.0f, 10.0f), -5.0f, -5.0f)), @"CGRect hooking (2) failed");
    
    if (!testFailed) {
        NSLog(@"Tests Succeeded");
    }
    
    return YES;
}

@end
