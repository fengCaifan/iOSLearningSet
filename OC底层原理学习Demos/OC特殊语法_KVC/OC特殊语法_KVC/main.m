//
//  main.m
//  OC特殊语法_KVC
//
//  Created by 冯才凡 on 2024/4/1.
//

#import <Foundation/Foundation.h>
#import "FCFPerson.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        FCFPerson * person = [[FCFPerson alloc] init];
//        person.cat = [[Cat alloc] init];
        
        person->age = 10;
        person->_age = 11;
        person->isAge = 12;
        person->_isAge = 13;
        
//        [person setValue:@20 forKey:@"age"];
//        person.age = 10;
        
//        [person setValue:@20 forKey:@"age"];
        NSLog(@"person.age: %@", [person valueForKey:@"age"]);
//
//        [person setValue:@11 forKeyPath:@"cat.weight"];
//        NSLog(@"person.cat.weight: %@", [person valueForKeyPath:@"cat.weight"]);
        
    }
    return 0;
}
