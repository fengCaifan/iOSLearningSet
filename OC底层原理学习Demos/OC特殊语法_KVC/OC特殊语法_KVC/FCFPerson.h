//
//  FCFPerson.h
//  OC特殊语法_KVC
//
//  Created by 冯才凡 on 2024/4/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Cat : NSObject

@property (assign, nonatomic) int weight;

@end

@interface FCFPerson : NSObject
{
    @public
    int age;
    int _age;
    int isAge;
    int _isAge;
}
//@property (assign, nonatomic) int age;

@property (strong, nonatomic) Cat * cat;
@end

NS_ASSUME_NONNULL_END
