//
//  main.m
//  OC对象的本质
//
//  Created by 冯才凡 on 2024/3/24.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <malloc/malloc.h>

@interface NSObject (Test)
- (void)test;
@end

@implementation NSObject (Test)
- (void)test {
    NSLog(@"NSObject test");
}
@end


@interface Student : NSObject
{
    // 这里还要一个isa指针，8字节
    int _age; // 4字节
    int _height; // 4字节
}
+ (void)test;
@end

@implementation Student
@end

@interface Student2 : NSObject
{
    // 这里还要一个isa指针，8字节
    int _age; // 4字节
}
@end

@implementation Student2

+ (void)test {
    NSLog(@"Student2 test");
}
@end

@interface Person : NSObject
{
    // 这里还要一个isa指针，8字节
    int _age; // 4字节
    NSString * _name; // 指针8字节
    NSString * _country;
}
@end

@implementation Person
@end


// 学习笔记：https://bhhbdrz3p9.feishu.cn/docx/LEYDdqHQSoNDsuxok1xc9ruAn6f
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        
        NSObject * objc = [[NSObject alloc] init];
        NSLog(@"NSObject %zd", class_getInstanceSize([NSObject class])); // 8
        NSLog(@"NSObject %zd", malloc_size((__bridge void *) objc)); // 16
        
        
        Student * stu = [[Student alloc] init];
        NSLog(@"Student %zd", class_getInstanceSize([Student class])); // 16
        NSLog(@"Student %zd", malloc_size((__bridge void *) stu)); // 16
        
        Student2 * stu2 = [[Student2 alloc] init];
        NSLog(@"Student2 %zd", class_getInstanceSize([Student2 class])); // 16
        NSLog(@"Student2 %zd", malloc_size((__bridge void *) stu2)); // 16
        
        Person * per = [[Person alloc] init];
        NSLog(@"Person %zd", class_getInstanceSize([Person class])); // 16
        NSLog(@"Person %zd", malloc_size((__bridge void *) per)); // 32
        
        
        // 实例对象
        Student * stu3 = [[Student alloc] init]; // 获取实例对象 0x600000004050
        Class stuClass =  [Student class]; // 获取类对象 0x1000083a8
        Class stuClass2 = object_getClass(stu3); // 获取类对象 0x1000083a8
        Class stuMetaClass = object_getClass(stuClass); // 获取元类对象 0x100008380
        
        NSLog(@"%p, %p, %p, %p", stu3, stuClass, stuClass2, stuMetaClass);
        
        [stu test];
    }
    return 0;
}
