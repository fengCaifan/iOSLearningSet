//
//  FCFPerson.m
//  OC特殊语法
//
//  Created by 冯才凡 on 2024/3/31.
//

#import "FCFPerson.h"

@implementation FCFPerson

-(void)willChangeValueForKey:(NSString *)key {
    NSLog(@"willChangeValueForKey - begin");
    [super willChangeValueForKey:key];
    NSLog(@"willChangeValueForKey - end");
}

-(void)didChangeValueForKey:(NSString *)key {
    NSLog(@"didChangeValueForKey - begin");
    [super didChangeValueForKey:key];
    NSLog(@"didChangeValueForKey - end");
}
@end
