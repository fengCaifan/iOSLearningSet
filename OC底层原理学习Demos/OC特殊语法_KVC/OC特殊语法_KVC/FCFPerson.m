//
//  FCFPerson.m
//  OC特殊语法_KVC
//
//  Created by 冯才凡 on 2024/4/1.
//

#import "FCFPerson.h"

@implementation Cat

@end

@implementation FCFPerson

//- (void)setAge:(int) age {
//    NSLog(@"FCFPerson setAge: %d", age);
//}

//- (void)_setAge:(int) age {
//    NSLog(@"FCFPerson _setAge: %d", age);
//}

//- (int)getAge {
//    return 11;
//}

//- (int)age {
//    return 12;
//}

//- (int)isAge {
//    return 13;
//}

//- (int)_age {
//    return 14;
//}



+ (BOOL)accessInstanceVariablesDirectly {
    return YES;
}

@end
