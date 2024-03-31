//
//  ViewController.m
//  OC特殊语法
//
//  Created by 冯才凡 on 2024/3/31.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import "FCFPerson.h"

@interface ViewController ()

@property (strong, nonatomic) FCFPerson *person;
@property (strong, nonatomic) FCFPerson *person2;

@end

@implementation ViewController

- (void)printMethodListOfClass:(Class)cls {
    unsigned int count;
    Method * methodList = class_copyMethodList(cls, &count);
    NSMutableString * methodNames = [NSMutableString string];
    
    for (int i=0; i<count; i++) {
        Method method = methodList[i];
        // 获取方法名
        NSString * methodName = NSStringFromSelector(method_getName(method));
        [methodNames appendString:methodName];
        [methodNames appendString:@", "];
    }
    
    free(methodList);
    NSLog(@"%@ %@", cls, methodNames);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.person = [[FCFPerson alloc] init];
    self.person.age = 10;
    
    self.person2 = [[FCFPerson alloc] init];
    self.person2.age = 21;
    
    NSLog(@"person1添加KVO之前：%@, %@",
          object_getClass(self.person), // FCFPerson
          object_getClass(self.person2)); // FCFPerson
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
    [self.person addObserver:self forKeyPath:@"age" options:options context:@"123"];
    
    NSLog(@"person1添加KVO之后：%@, %@",
          object_getClass(self.person), // NSKVONotifying_FCFPerson
          object_getClass(self.person2)); // FCFPerson

    NSLog(@"类对象：%p, %p",
          object_getClass(self.person), // 0x600003dc1500
          object_getClass(self.person2)); // 0x10eb6f388
    NSLog(@"元类对象：%p, %p",
          object_getClass(object_getClass(self.person)), // 0x600003dc1260
          object_getClass(object_getClass(self.person2))); // 0x10eb6f360
    
    [self printMethodListOfClass:[self.person class]]; // FCFPerson willChangeValueForKey:, didChangeValueForKey:, age, setAge:,
    [self printMethodListOfClass:object_getClass(self.person)]; // NSKVONotifying_FCFPerson setAge:, class, dealloc, _isKVOA
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.person.age = 20;
    self.person2.age = 22;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"监听到%@的%@属性值改变了：%@ - %@", object, keyPath, change, context);
}

- (void)dealloc {
    [self.person removeObserver:self forKeyPath:@"age"];
}

@end
