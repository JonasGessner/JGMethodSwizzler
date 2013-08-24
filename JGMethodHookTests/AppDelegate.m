//
//  AppDelegate.m
//  JGMethodHook
//
//  Created by Jonas Gessner on 22.08.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "AppDelegate.h"
#import "JGMethodHooker.h"


typedef struct {
    CGRect a;
    long long c;
} test;



@interface JGMethodHookerTestObject : NSObject


+ (id)a:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f;
- (id)a:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f;


+ (id)b:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f;
- (id)b:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f;


+ (id)c:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f;
- (id)c:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f;


@end


@implementation JGMethodHookerTestObject

+ (id)a:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f {
    NSLog(@"Called Class Method %s", __PRETTY_FUNCTION__);
    return @"ORIG_CLASS_METHOD";
}

- (id)a:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f {
    NSLog(@"Called Instance Method %s", __PRETTY_FUNCTION__);
    return @"ORIG_INSTANCE_METHOD";
}



+ (id)b:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f {
    NSLog(@"Called Class Method %s", __PRETTY_FUNCTION__);
    return @"ORIG_CLASS_METHOD";
}

- (id)b:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f {
    NSLog(@"Called Instance Method %s", __PRETTY_FUNCTION__);
    return @"ORIG_INSTANCE_METHOD";
}



+ (id)c:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f {
    NSLog(@"Called Class Method %s", __PRETTY_FUNCTION__);
    return @"ORIG_CLASS_METHOD";
}

- (id)c:(double)a a:(char)b a:(id)c a:(long long)d a:(id)e a:(CGRect)f {
    NSLog(@"Called Instance Method %s", __PRETTY_FUNCTION__);
    return @"ORIG_INSTANCE_METHOD";
}


@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self testDidBegin];
    [self test];
    [self testWillEnd];
    
    return YES;
}

- (void)testDidBegin {
}

- (void)testWillEnd {
}




- (void)testHookWithInstance {
    JGMethodHooker *hookInstance = [JGMethodHooker hookerWithSelector:@selector(a:a:a:a:a:a:) andClass:[JGMethodHookerTestObject class]];
    
    [hookInstance hookInstanceMethodWithReplacement:^id (id self, double a, char b, id c, long long d, id e, CGRect f) {
        id orig = hookInstance.orig(self, hookInstance.selector, a, b, c, d, e, f);
        NSLog(@"Oig Value %@", orig);
        return @"Hooked Instance Method";
    }];
    
    
    JGMethodHooker *hookClass = [JGMethodHooker hookerWithSelector:@selector(a:a:a:a:a:a:) andClass:[JGMethodHookerTestObject class]];
    
    [hookClass hookClassMethodWithReplacement:^id (id self, double a, char b, id c, long long d, id e, CGRect f) {
        id orig = hookClass.orig(self, hookClass.selector, a, b, c, d, e, f);
        NSLog(@"Oig Value %@", orig);
        return @"Hooked Class Method";
    }];
    
    test a;
    
    a.a = CGRectMake(8, 9, 10, 11);
    a.c = 23103210978;
    
    NSArray *aa = @[@"Does it work??"];
    
    NSLog(@"Test Class %@", [JGMethodHookerTestObject a:99 a:1 a:aa a:748659780798 a:@"Yeah!" a:(CGRect){{7, 8}, {9, 10}}]);
    
    JGMethodHookerTestObject *tester = [JGMethodHookerTestObject new];
    
    NSLog(@"Test Instance %@",  [tester a:99 a:1 a:aa a:748659780798 a:@"Yeah!" a:(CGRect){{7, 8}, {9, 10}}]);
    
#if !__has_feature(objc_arc)
    [tester release];
#endif
}

- (void)testHookWithTrampoline {
    SEL sel1 = @selector(b:a:a:a:a:a:);
    
    [JGMethodHookerTestObject hookInstanceMethod:sel1 usingBlock:^id (id self, double a, char b, id c, long long d, id e, CGRect f) {
        id orig = getOrig(self, sel1)(self, sel1, a, b, c, d, e, f);
        NSLog(@"Oig Value %@", orig);
        return @"Hooked Instance Method";
    }];
    
    
    [JGMethodHookerTestObject hookClassMethod:sel1 usingBlock:^id (id self, double a, char b, id c, long long d, id e, CGRect f) {
        id orig = getOrig_C(self, sel1)(self, sel1, a, b, c, d, e, f);
        NSLog(@"Oig Value %@", orig);
        return @"Hooked Class Method";
    }];
    
    test a;
    
    a.a = CGRectMake(8, 9, 10, 11);
    a.c = 23103210978;
    
    NSArray *aa = @[@"Does it work??"];
    
    NSLog(@"Test Class %@", [JGMethodHookerTestObject b:99 a:1 a:aa a:748659780798 a:@"Yeah!" a:(CGRect){{7, 8}, {9, 10}}]);
    
    JGMethodHookerTestObject *tester = [JGMethodHookerTestObject new];
    
    NSLog(@"Test Instance %@",  [tester b:99 a:1 a:aa a:748659780798 a:@"Yeah!" a:(CGRect){{7, 8}, {9, 10}}]);
    
#if !__has_feature(objc_arc)
    [tester release];
#endif
}

- (void)testHookWithOrigPointer {
    SEL sel1 = @selector(c:a:a:a:a:a:);
    
    __block JG_ORIG_IMP orig1 = nil;
    
    [JGMethodHookerTestObject hookInstanceMethod:sel1 usingBlock:^id (id self, double a, char b, id c, long long d, id e, CGRect f) {
        id orig = orig1(self, sel1, a, b, c, d, e, f);
        NSLog(@"Oig Value %@", orig);
        return @"Hooked Instance Method";
    } getOrig:&orig1];
    
    
    __block JG_ORIG_IMP orig2 = nil;
    
    [JGMethodHookerTestObject hookClassMethod:sel1 usingBlock:^id (id self, double a, char b, id c, long long d, id e, CGRect f) {
        id orig = orig2(self, sel1, a, b, c, d, e, f);
        NSLog(@"Oig Value %@", orig);
        return @"Hooked Class Method";
    } getOrig:&orig2];
    
    test a;
    
    a.a = CGRectMake(8, 9, 10, 11);
    a.c = 23103210978;
    
    NSArray *aa = @[@"Does it work??"];
    
    NSLog(@"Test Class %@", [JGMethodHookerTestObject c:99 a:1 a:aa a:748659780798 a:@"Yeah!" a:(CGRect){{7, 8}, {9, 10}}]);
    
    JGMethodHookerTestObject *tester = [JGMethodHookerTestObject new];
    
    NSLog(@"Test Instance %@",  [tester c:99 a:1 a:aa a:748659780798 a:@"Yeah!" a:(CGRect){{7, 8}, {9, 10}}]);
    
#if !__has_feature(objc_arc)
    [tester release];
#endif
}

- (void)test {
    NSLog(@"Beginning tests. Use breakpoints to check function arguments");
    printf("\n\n\n");
    NSLog(@"Testing Instances:");
    [self testHookWithInstance];
    printf("\n\n\n");
    NSLog(@"Testing Trampolines:");
    [self testHookWithTrampoline];
    printf("\n\n\n");
    NSLog(@"Testing Pointer References:");
    [self testHookWithOrigPointer];
}


@end
