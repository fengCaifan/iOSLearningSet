//
//  main.m
//  OC对象的本质
//
//  Created by 冯才凡 on 2024/3/24.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <malloc/malloc.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        
        NSObject * objc = [[NSObject alloc] init];
        NSLog(@"%zd", class_getInstanceSize([NSObject class])); // 8
        NSLog(@"%zd", malloc_size((__bridge void *) objc)); // 16
    }
    return 0;
}
