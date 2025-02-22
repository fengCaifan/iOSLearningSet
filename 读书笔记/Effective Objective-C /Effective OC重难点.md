### 一、熟悉OC
#### * 1、OC起源
* 消息与函数调用的区别：使用消息结构的语言，其运行时所应执行的代码由运行环境所决定；而函数调用则由编译器决定。函数调用在编译期间就知道具体需要执行的函数是什么，而消息总是在运行时才去确定最终所要执行的方法；
* OC的面向对象特性所需要的全部数据结构与函数都在运行期组件（runtime）里，比如全部内存管理方法。运行期组件本质就是一种与开发者所编写代码相连接的“动态库”；
* 所有OC对象所占内存总是分配在“堆空间”，而绝不会分配在“栈”上，分配在堆上的内存必须直接管理（引用计数）；

#### 2、在类的头文件中尽量少引用其他头文件
* 引入头文件时，会引入该文件所有声明的内容，导致引入了一些不需要用到的内容。所以尽量延迟引入时机，只在确定需要使用后再引入，这样可以减少不必要的头文件的编译，优化编译时间。
* 使用“向前声明”@class，则不会引入该类的所有实现细节。这有助于节省时间，也解决了两个类相互引用的问题，
* 使用#import实际并不会导致循环引用，但是会导致其中一个类无法正确编译。但是如果是继承或协议则必须使用#import；

#### 3、多使用字面量
* 数组、字典、set里存放的都必须是OC对象；
* 使用非字面量创建数组或字典时，都是使用nil结束，但是非字面量创建数组或时，若数组元素有nil，或字典键值一旦有值为nil，则都会抛出异常；
* 使用字面量创建出来的字符串、字典、数组都是不可变的。若要是可变版本则需要使用mutablecopy：
```objctive-c
	NSMutableArray * mutable = [@[@1,@2,@3,@4] mutablecopy];
```

#### 4、多用类型常量，少用#define
* 使用#define定义的常量没有类型信息。所以最好使用常量类型来定义。常量常用的命名法则：若常量局限于“实现文件”之内，则在前面加字母k；若要在类之外可见，则通常以类名为前缀；
* 编译单元内可见的常量，在实现文件中使用“static const”来定义，在头文件中使用extern来声明全局变量，并在相关实现文件中定义其值：
```Objective-C
	.h:	 extern const NSTimeInterval FCFAnimationDuratin;
	.m:	 const NSTimeInterval FCFAnimationDuration = 0.5;
```

#### 5、枚举使用
* 使用typedef NS_ENUM 来定义基本状态宏，使用typedef NS_OPTIONS来定义位移宏。
* 在处理枚举的switch语句中尽可能不要实现default

### 二、对象、消息、运行期
#### * 6、属性
* 属性 = 实例变量（ivar）+ 存取方法(getter/setter)
* 
