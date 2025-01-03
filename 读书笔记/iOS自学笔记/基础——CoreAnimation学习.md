---
title: iOS-技能知识小集
date: 2020-7-3 17:36:48
tags: knoeledgePoints
categories: iOS进阶
description:  阅读《iOS Core Animation》笔记摘要。补充一下iOS视图渲染相关的疑问。
---

### 显示
UIView及其子视图组成的视图层级关系，称之为**视图树**；与UIView的层级关系形成的一种平行的CALayer的层级关系，称之为**图层树**。
#### CALayer及其属性
**CALayer怎么进行绘制**
CALayer有一个id类型的**contents**属性，在iOS中实际对应一个CGImageRef指针，它指向一个CGImage结构体，也就是一张位图。实际上UIView的显示最终就是显示这张位图。所有生成UIView的过程实际上就是给contents赋值CGImage的过程。

* contentGravity ： 是指内容的显示方式，与contentMode是对应的值，主要用于图片拉伸；
* contentsScale：寄宿图的像素尺寸和视图大小的比例；
* maskToBounds：是否需要显示超出边界的内容；(Q1：为什么会绘制出超出边界的内容？)
* contentsRect：0~1的图层子阈，左上角是0，右下角是1。比如{0，0，0.5，0.5}那就是整个Layer的左上角那四分之一。主要用于多个图片拼合成一张的情况；这样一次性打包载入到一张大图上比多次载入不同的图片在内存使用、渲染等方面要好很多；
* contentsCenter：定义可拉伸区域，比如点九图。默认情况下，contentsCenter是{0，0，1，1}，意味着拉伸区域是整个图层，然后均匀拉伸。如果contentsCenter是{0.25，0.25，0.5，0.5}，那么拉伸区域就正好是距离各边界25%的中间区域；

#### 绘制
首先每一个UIView都自带一个**只读**属性的CALayer，其主要负责显示和动画操作。然后CALayer有一个可选的delegate属性，它是CALayerDelegate协议的代理。在正常情况下，我们使用UIView的时候，它都是使用自带的Layer来进行绘制，默认是将layer.delegate设置为自身，然后在内部对contents进行赋值。(ps：所以我们想要对cell做异步绘制，是没法通过cell的layer来真实实现的，而是使用其他的UIView按照异步绘制的方式进行实现，比如YYKit中使用UIView的子类，在setText的时候开辟子线程进行绘制流程)。其次UIView开放了drawRect:方法，也可以在这个方法里进行绘制操作。但是这将会更消耗性能（ps:原因看下文）。
但是如果是直接使用CALayer，则可以通过实现layer.delegate的displayLayer方法来手动设置contents。
所以，一般的做法是：

* 要么直接使用UIView，如果要自定义绘制，就调用UIView的drawRect方法；
* 要么使用单独的CALayer，可以实现它的代理方法来实现自定义绘制工作；
* 或者使用UIView，然后在其他情况下开辟子线程进行绘制，最后给layer.contents进行赋值。

##### 绘制流程：
当视图层级发生变化或者手动调用了UIView的setNeedsDisplay方法，会调用CALayer的同名方法setNeedsDisplay，但是并不会马上进行绘制，而是将CALayer打上脏标记，放到一个全局容器里，等到Core Animation监听到RunLoop的BeforWaiting或Exit状态后，会将全局容器里的CALayer执行display方法。当执行display方法时，其方法内部首先会判断是否实现了layer.delegate的displayLayer：方法，如果实现了，就调用displayLayer：方法，然后在方法里设置contents。否则CALayer会先创建一个后备缓存(backing store)，然后调用displayContext:方法，其方法内部又会判断是否实现了layer.delegate的drawLayer:inContext:方法，如果实现了就执行drawLayer:inContext:方法，在该方法里设置contents；如果没有实现，就还是走系统的drawRect方法。
但是要注意：

* 在使用drawInContext之前，系统会开辟一个后备缓存（也就是绘制上下文），给drawRect：或者drawlayer：inContext：进行绘制使用，所以在UIView的drawRect方法中进行绘制工作不是最好的选择；
* 同理，在使用drawInContext之前，系统会开辟一个后备缓存（也就是绘制上下文）。所以在drawRect：或者drawlayer：inContext：方法中是可以直接获取上下文的，但是使用displayLayer：则没法获取上下文，而是得手动创建一个上下文。

#### 排版布局
视图有三个比较重要的布局属性：frame、bounds、center。视图对应的layer也是这三个属性，可能center变成了position。
* frame：相对于父视图的坐标空间；它实际是根据bounds、position、transform计算而来，所以它们之间都是相互影响的；

* bounds：自身内部坐标空间，{0，0}表示左上角；

* center：CALayer对应position，代表相对于父视图anchorPoint所在位置；

  默认情况下(anchorPoint的默认值为 {0.5,0.5})，`position`的值便可以用下面的公式计算：

  ```
  position.x = frame.origin.x + 0.5 * bounds.size.width；  
  position.y = frame.origin.y + 0.5 * bounds.size.height；
  ```

* anchorPoint：锚点就是视图在执行变化的支点。通常情况下，锚点是在视图的正中心，值是{0.5,0.5}。（假设一张纸被一个图钉钉住，纸张围绕图钉做动画，那么这个图钉就是这个锚点）。总结来说：position 用来设置CALayer在父层中的位置，anchorPoint 决定着CALayer身上的哪个点会在position属性所指的位置。
  `frame、position与anchorPoint`有以下关系：

  ```
  frame.origin.x = position.x - anchorPoint.x * bounds.size.width；  
  frame.origin.y = position.y - anchorPoint.y * bounds.size.height；  
  ```

#### 视觉效果
* 圆角：conrnerRadius是指layer的曲率。默认情况下，conrnerRadius只影响背景色而不影响背景图片或子图层。所以如果要让其子图层或背景图片也响应这个曲率，则需要将maskToBounds设置成YES。

* 边框：图片边框由boarderWidth和boardColor定义。如果图层超出了边框，那么实际也是可以绘制出来的。

* 阴影：透明度shadowOpacity在[0,1]之间取值；shadowOffset设置阴影的方向和距离，默认值是(0，-3)，意思是阴影相对y轴有3个点的向上位移；shadowRadius设置阴影的模糊程度。
  * 阴影裁剪：图层的阴影不是根据边框和圆角来确定的，而是根据内容的外形，设置在layer的边界之外，也就是计算阴影的时候，会将其与寄宿图一起考虑。所以剪裁的时候阴影容易被剪切掉。所以解决方案就是：使用两个图层，一个是只画阴影的空的外图层，一个是使用了剪裁内容的内图层。
  * shadowPath：上述阴影剪裁的话，外图层其实得实时跟进内图层的形状，所以也是非常消耗资源的方案，尤其是多个子图层的时候。所以可以使用shadowPath来绘制阴影。

* 图层蒙版：layer的mask属性定义了layer的可见区域，它本身其实也是一个图层，所以可以给mask设置contents。

* 拉伸过滤：拉伸过滤算法就是将原图的像素根据需要生成新的像素显示在屏幕上；CALayer提供了三种拉伸过滤方法：kCAFilterLinear、kCAFilterNearest、kCAFilterTrilinear。

* 组透明：UIView有一个属性alpha，CALayer有一个属性opacity。这两个属性都是能影响子层级的。另外透明度混合叠加会导致子图层的透明度出现问题，可以使用shouldRasterize属性来处理。

#### 变换
* 仿射变换：transform用于对二维空间做旋转、缩放、平移等。底层实际就是对坐标进行矩阵运算。Core Graphics提供了一系列函数进行简单的变换：
```
CGAffineTransformMakeRotation(CGFloat angle); //旋转角度
CGAffineTransformMakeScale(CGFloat sx,CGFloat sy); //缩放
CGAffineTransformMakeTranslation(CGFloat tx,CGFloat ty); //平移
```
	* 混合变换：其实上述的每一个变换函数都会返回一个CGAffineTansform类型,可以对这个值进行连续变换：
	```
	//先缩小50%，再选择30度，然后右移200像素。
	CGAffineTransform transform = CGAffineTransformIdentity; 
	transform = CGAffineTransformScale(transform, 0.5, 0.5);
	transform = CGAffineTransformRotate(transform, M_PI / 180.0 * 30.0);
	transform = CGAffineTransformTranslate(transform, 200, 0);
	self.layerView.layer.affineTransform = transform;
	```
	* 剪切变换：其实就是让视图倾斜的变换。
	```
	CGAffineTransform transform = CGAffineTransformIdentity; 		transform.c = -1; //以45度角倾斜这一层
	transform.b = 0;
	self.layerView.layer.affineTransform = CGAffineTransformMakeShear(1, 0);
	```
* 3D变换：其实就是在上述2D变换的基础上加上了一维Z轴。API都是CATransform3DMake...：
	```
	CATransform3DMakeRotation(CGFloat angle，CGFloat x，CGFloat y，CGFloat z); //旋转角度
	CATransform3DMakeScale(CGFloat sx,CGFloat sy,CGFloat sz); 	//缩放
	CATransform3DMakeTranslation(CGFloat tx,CGFloat ty,CGFloat sz); //平移
	```

	* 透视投影：m34属性用于修改transform的透视效果。m34默认值是0，通过设置m34为-1.0/d来应用透视效果，d代表想象中视角相机和屏幕直接的距离:
	```
	CATransform3D transform = CATransform3DIdentity;
	transform.m34 = -1.0/500/0;
	transform = CATransform3DRotate(transform, M_PI_4, 0, 1, 0);
	self.layerView.layer.transform = transform;
	```
	* 灭点：也就是相机离得足够远的位置，属性anchorPoint表示；
	* 背面：相当于对3D视图做180度旋转后的视角；

#### 专用图层
##### CAShapeLayer
CAShapeLayer是一个通过矢量图形而不是bitmap绘制的图层。它有一些优点：
* 渲染快速。它使用了硬件加速，比单纯的Core Graphics快很多；
* 高效使用内存。它无需像CALayer一样创建寄宿图形，所以无论多大都不会占用太多内存。
* 不会被边界裁剪。它可以在边界之外绘制，所以设置阴影可以使用它。
* 不会像素化。做变换时，不会被像素化。
通常使用CAShapeLayer是和UIBezierPath一起使用。
```
//设置圆角，可以单独指定每个角
CGRect rect = CGRectMake(50, 50, 100, 100);
CGSize radii = CGSizeMake(20, 20);
UIRectCorner corners = UIRectCornerTopRight | UIRectCornerBottomRight | UIRectCornerBottomLeft;
UIBezierPath * path =  [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:corners cornerRadii:radi];
CAShapeLayer * shapeLayer = [CAShapeLayer layer];
shapeLayer.path = path.CGPath;
[self.containerView.layer addSublayer:shapeLayer];
```
##### CATextLayer
CATextLayer以图形的形式包含了UILabel几乎所有的绘制特性。它使用了Core Text,比UILabel渲染更快。但是CATextLayer并没有以retina的方式渲染，所以在高分辨率的屏幕上有点像素化了。通过设置contentScale可以解决这个问题。
```
CATextLayer * textLayer = [CATextLayer layer];
textLayer.frame = self.labelView.bounds;
[self.labelView.layer addSublayer:textLayer];
//设置attributes
textLayer.foregroundColor = [UIColor blackColor].CGColor; textLayer.alignmentMode = kCAAlignmentJustified; 
textLayer.wrapped = YES;
//设置字体
UIFont * font = [UIFont systemFontOfSize:15];
CFStringRef fontName = ( _ bridge CFStringRef)font.fontName; 
CGFontRef fontRef = CGFontCreateWithFontName(fontName); 
//textLayer.font = fontRef; 不是富文本可以直接这样设置字体
//textLayer.fontSize = font.pointSize;

NSString * text = @"Lorem ipsum dolor sit amet, consectetur adipiscing \ elit. Quisque massa arcu, eleifend lonejajskjnk jkn jkjak  jkla ljlnansl lkan ";

NSMutableAttributedString * string = nil;
string = [[NSMutableAttributedString alloc] initWithString:text];
NSDictionary * attribs = @{
( _ bridge id)kCTForegroundColorAttributeName:( _ bridge id)[UIColor blackColor].CGColor,
( _ bridge id)kCTFontAttributeName: ( _ bridge id)fontRef 
};
[string setAttributes:attribs range:NSMakeRange(0, [text length])]; 
attribs = @{
( _ bridge id)kCTForegroundColorAttributeName: ( _ bridge id)[UIColor redColor].CGColor, ( _ bridge id)kCTUnderlineStyleAttributeName: @(kCTUnderlineStyleSingle),
( _ bridge id)kCTFontAttributeName: ( _ bridge id)fontRef
};
[string setAttributes:attribs range:NSMakeRange(6, 5)];

//注意这个string不是NSString类型，而是一个id类型，所以可以设置NSString或NSAttributesString。
texxtLayer.string = string
//设置缩放
textLayer.contentsScale = [UIScreen mainScreen].scale;
```
但是真正的使用方式，不是直接使用CATextLayer，因为那太复杂了。考虑考虑继承自UILabel，然后添加一个子图层CATextLayer并重写显示文本的方法，但是这也同样需要重写drawRect方法，同时生成一个缓存区。所以也可以考虑直接使用UIView，重写layerClass方法创建一个CATextLayer。

##### CAGradientLayer
渐变图层，CAGradientLayer是两种或更多颜色平滑渐变。它也使用了硬件加速。
```
CAGradientLayer * gradientLayer = [CAGradientLayer layer];
gradientLayer.frame = self.view.bounds;
[self.view.layer addSublayer:gradientLayer];
//设置颜色，colors可以是多种颜色，会均匀分布在layer上面
gradientLayer.colors = @[( _ bridge id )[UIColor redColor].CGColor,( _ bridge id )[UIColor blueColor].CGColor];
//颜色位置,表示每个颜色的起始位置
gradientLayer.locations = @[@0.0,@0.5];
//设置渐变方向
gradientLayer.startPoint = CGPointMake(0,0);
gradientLayer.endPoint = CGPointMake(1,1);
```
#### CATiledLayer
如果一张图片太大，那么对其进行解码读取到内存中将是一件很消耗性能的事情。并且加载的过程会非常慢。其次OpenGL也有一个最大纹理尺寸(大概是4096*4096)。如果你要显示一张比这个尺寸还大的图，则会强制CPU进行处理了，那么就更加消耗性能。
CATiledLayer将大图分解成小片，然后按需加载。

```
{
    //使用ScrollView滚动CATiledLayer进行加载
	CATiledLayer * tileLayer = [CATiledLayer layer];
	tileLayer.frame = CGRectMake(0, 0, 2048, 2048);
	tileLayer.delegate = self; 
	[self.scrollView.layer addSublayer:tileLayer];
	//使用
	self.scrollView.contentSize = tileLayer.frame.size;
	tileLayer.contentsScale = [UIScreen mainScreen].scale;
	[tileLayer setNeedsDisplay];
}
//实现drawlayer:incontext:代理
- (void)drawLayer:(CATiledLayer * )layer inContext:(CGContextRef)ctx {

	CGRect bounds = CGContextGetClipBoundingBox(ctx); 
	CGFloat scale = [UIScreen mainScreen].scale;
	NSInteger x = floor(bounds.origin.x / layer.tileSize.width * scale);
    NSInteger y = floor(bounds.origin.y / layer.tileSize.height * scale);
	//
	NSString * imageName = [NSString stringWithFormat: @"Snowman_%02i_%02i", x, y]; 
	NSString * imagePath = [[NSBundle mainBundle] pathForResource:imageName ofType:@"jpg"]; 
	UIImage * tileImage = [UIImage imageWithContentsOfFile:imagePath];
	//draw tile 
	UIGraphicsPushContext(ctx); 
	[tileImage drawInRect:bounds]; 
	UIGraphicsPopContext();
}
//
```

### 动画
#### 隐式动画
Core Animation假设屏幕上的任何东西都可以做动画，动画需要手动关闭，否则它会一直存在。当改变一个CALayer的可做动画属性时，它并不会立刻在屏幕上体现，而是从旧的值平滑过渡到新的值。这就是**隐式动画**。
* 事务：Core Animation判断隐式动画执行的类型和持续时间是根据事务的设置来的。这里的事务就是指一系列属性动画集合。它是通过栈来管理每个动画的入栈和出栈。Core Animation在每一次RunLoop周期中都会自动开启一次新的事务。UIView的动画函数实际执行的都是CALayer的动画属性。默认情况下UIView禁用了CALayer的动画属性，只有在UIView执行动画函数时，才会恢复动画属性。
* 呈现与模型：给CALayer设置的动画属性实际没有立即生效，而是过了一段时间才慢慢过渡生效，但是属性值却是在设置的那一刻就已经生效了。实际上在执行动画的时候是展示层在显示，动画停止的时候是模型层在显示。展示层是模型层的复制品。

#### 显示动画 (略)
### 绘制
#### 性能调优
* CPU VS GPU ：CPU是中央处理器，基本工作在软件层面，GPU是图像处理器，工作在硬件层面。通常来说，我们可以使用软件(CPU)做任何事情，但是对于图像处理，硬件(GPU)会更快。**大多数图像动画性能优化都关于智能利用CPU和GPU**。
* 动画和屏幕上组合的图层实际上被一个单独的**进程**管理，而不是当前应用程序。这个进程就是**渲染服务(Render Server)**。当运行一段动画时，这个过程会被分离成4个阶段：
  * 布局：准备视图/图层的层级关系，设置图层属性(位置、背景、边框等)；
  * 显示：图层寄宿图片被绘制的阶段，这里可能会调用drawRect:或drawLayer:inContext:；
  * 准备：Core Animation准备发送动画数据到渲染服务进程中；
  * 提交：Core Animation打包所有图层和动画属性，通过IPC发送到渲染服务并显示；
  一旦打包的图层和动画提交到渲染服务进程，则会被反序列化成一棵渲染树的图层树。然后进行渲染操作。

#### GPU
GPU主要负责OpenGL渲染管线相关事情。最新的可能对应metal相关渲染
* 什么事情会降低GPU图层绘制？
	* 太多图层
	* 重绘
	* 离屏渲染
	* 过大图片 (超过4096*4096就会显著降低GPU性能)
	
#### CPU 
正常来说除了GPU的工作，其他软件层面上的操作都是由CPU完成的。
* 哪些操作比较耗CPU性能？
	* 布局计算：层级过于复杂
	* IO操作：比如从数据库获取数据，从nib对于懒加载确实可以优化内存和启动时间，但是如果懒加载的视图是从数据库或者nib文件中加载出来的。
	* 重写drawRect:或者drawLayer:inContext:,因为在执行这些方法之前会创建一个后备缓存。
	* 解压图片：因为在将图片绘制到屏幕之前，必须把它扩展成完整的未解压的尺寸。

#### 离屏渲染：
* 定义：如果要在显示屏上显示内容，则就至少需要一块与屏幕像素数据量一样的frame buffer(帧缓存区)，作为像素数据存储区域，而这也是GPU存储渲染结果的地方。如果有时面临一些限制，无法把渲染结果直接写入frame buffer,而是先暂存在另外的内存区域，之后再写入frame buffer,那么这个过程被称之为**离屏渲染**; (打开xcode的离屏渲染开关，属于离屏渲染的区域会被标记为黄色)

* 并不是在frame buffer之外的内存区域进行渲染都是离屏渲染。比如通过drawRect，申请一块后备缓存进行绘画。这只能称作CPU的软件渲染。**真正的离屏渲染发送在GPU**。

* 为什么会发生离屏渲染？

  首先图层的渲染模块是交给一个叫做**Render Server**的独立进程来做的。这个Render Server是遵循**画家算法**来进行渲染的，具体来说就是按照视图的层级关系，一层一层渲染好输出到frame buffer，后一层覆盖前一层（相当于父视图渲染好输出到帧缓存中，然后子视图再渲染好，输出到帧缓存并覆盖到父视图上）。而且这种渲染方式无法在某一层渲染之后，再回过头来进行改动。这就意味着，所有添加到frame buffer的渲染结果必须一次性渲染完成，否则就得借助其它内存来临时完成更复杂、多次的渲染操作，然后再将结果回馈输出到frame buffer。

* 常见的离屏渲染常见
  * cornerRadius+clipsToBounds: 单独的一个layer切圆角是可以直接渲染出来的。但是视图容器里的子layer因为父视图有圆角，那么也需要被裁剪，而父视图渲染的时候，子视图是不知道的，也就是说子视图无法跟父视图一起被裁剪。 所以这就需要开辟独立空间，将当前视图以及其所有子视图一起渲染裁剪，最后再把结果反馈到frame buffer中。

  * shadow：阴影需要在本体被渲染完成之后才能渲染出来。而阴影layer是放在在本体下一层，也就是说优先本体渲染到frame buffer中。所以它也需要额外独立空间将阴影和本体都渲染完成后输出到frame buffer中。（所以，我们通常先使用shadowPath去单独设置阴影路径，然后结合其他layer来单独绘制阴影，这样就不会产生离屏渲染问题）

  * group opacity：group opacity是指给一组图层添加透明度。所以可想而知，是不可能一次性渲染完成的。得要所有相关图层都渲染完成，然后加上透明度，才能得到预期效果。所以这肯定也是需要额外开辟空间处理的；

  * mask：mask是应用在layer和其所有子leyer的组合之上的。所以它存在和group opacity一样的问题，不得不在离屏渲染中完成；

  * UIBlurEffect：也是应用到一组图层之上的。

* 离屏渲染为什么会影响性能？
  GPU的操作是高度流水化的。如果遇到不得不开辟另一块内存进行渲染操作的情况，则GPU就会终止当前流水线的工作，而切换到额外内存中进行渲染，之后再切回到当前屏幕缓冲区继续流水线工作。
  所以频繁的上下文切换是导致性能受影响的主要因素。(比如说cell，滚动的每一帧变化都会触发每个cell的重新绘制。因此一旦存在离屏渲染，那么这种上下文切换就会每秒发生60次，如果一帧画面不止一个图片，每个图片都存在离屏渲染，则切换次数将会更加可观)。
* 如何优化离屏渲染？
  * 1、利用CPU渲染避免离屏渲染。其实性能优化经常做的一种事情就是平衡CPU和GPU的负载，让它们尽量做自己最擅长的工作。比如文字(CoreText使用CoreGraphics渲染)和图片(ImageIO)渲染，则是由CPU进行处理，之后再将结果传给GPU。所以像给图片加圆角这种操作，就可以考虑用CPU渲染来完成。
  * 2、在离屏渲染无法避免的情况下，则想办法把性能影响降到最低。主要的优化思路就是：**将渲染出来的结果缓存起来**。CALayer提供了一个shouldRasterize。shouldRasterize设置为true，则Render Server就会强制把渲染结果(包括子layer、圆角、阴影、group opacity等)保存在一块内存中，这样在下一帧中就可以被复用，而不会再次触发离屏渲染。但是也需要注意一些细节：
    * shouldRasterise**总是会至少触发一次离屏渲染**，如果你的layer不会产生离屏渲染，切忌不要使用；

    * 离屏渲染缓存有空间上限，最多不超过屏幕总像素的2.5倍大小；

    * 一旦缓存超过100ms没有被使用，就会自动丢弃；

    * layer一旦打算变化(size、动画)，则缓存立即失效；

    * 如果layer子视图结构复杂，也可以打开shouldRasterise，把整个layer树绘制到一块缓存。

* 《即刻》app所做的离屏渲染优化
  * 即刻大量应用AsyncDisplayKit(Texture)作为主要渲染框架，对于文字和图片的异步渲染操作交由框架来处理。关于这方面可以看我之前的一些介绍

  * 对于图片的圆角，统一采用“precomposite”的策略，也就是不经由容器来做剪切，而是预先使用CoreGraphics为图片裁剪圆角

  * 对于视频的圆角，由于实时剪切非常消耗性能，我们会创建四个白色弧形的layer盖住四个角，从视觉上制造圆角的效果

  * 对于view的圆形边框，如果没有backgroundColor，可以放心使用cornerRadius来做

  * 对于所有的阴影，使用shadowPath来规避离屏渲染

  * 对于特殊形状的view，使用layer mask并打开shouldRasterize来对渲染结果进行缓存

  * 对于模糊效果，不采用系统提供的UIVisualEffect，而是另外实现模糊效果（CIGaussianBlur），并手动管理渲染结果 

* iOS10之后的离屏渲染处理方式
	* 如果方便的情况下，可以让设计师直接提供裁切好圆角的图片。
	* 对于UIView，只设置CornerRadius,无需设置ClipToBounds就可以实现圆角效果，不会触发离屏渲染。
	* 对于UILabel，只设置CornerRadius,无需设置ClipToBounds就可以实现圆角效果，不会触发离屏渲染；如果label有背景色，在iOS10以上系统，可以使用CornerRadius + ClipToBounds组合，10以下的系统，可以设置label.layer.backgroundColor来代替label.backgroundColor。
	* 对于UIImageView 如果只需要支持iOS10及更新版本的机型，那么大胆的使用cornerRadius + masksToBounds，不会触发离屏渲染； 10以下的机型，可以通过给UIImage添加Category，利用UIBezierPath来实现。
	* 对于UIButton，如果只需要实现文字 + 圆角效果，那么用ConerRadius就可以了；如果要实现有图片的Button的圆角效果, 可以先参照上述方法先对图片进行处理。
	* 对于简单阴影，可以使用CGContexRef/UIBezierPath绘制阴影路径并设置给ShadowPath来代替shadowOffset等属性设置阴影，下面是关于shadowPath的官方解释

#### 高效绘制

使用Core Graphics进行简单的素描，画的越多，程序就越慢。因为每次移动手指都会重绘整个UIBezierPath。所以更好的方法是使用专用图层：CAShapLayer绘制多边形、直线和曲线；CATextLayer绘制文本；CAGradientLayer绘制渐变。

设备通常会把屏幕区分为需要重绘的区域和不需要重绘的区域。需要重绘的区域被称作“脏区域”。当一个视图被改动了，TA可能需要重绘。但是通常情况下，脏区域太大了，导致重绘太浪费。所以可以使用**setNeedsDisplayInRect:**来指定脏区域的范围，从而减少不必要的绘制。

* 异步绘制

  UIKit只可以在主线程上更新。所以就会导致可能会打断用户交互的情况。所以可以考虑在某些情况下，将要显示的内容提前在另一个线程上绘制好，然后将绘制好的图片直接设置为图层内容。

  * CATiledLayer：它会在多个线程中为每个小块同时调用-drawLayer:inContext:方法。
  * drawsAsynchronously：drawsAsynchronously对传入-drawLayer:inContext:的CGContext进行改动，允许CGContext延缓绘制命令的执行以至于不阻塞用户交互。

#### 图像 I/O

* 在子线程中加载图片

  ```
  - (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                      cellForItemAtIndexPath:(NSIndexPath *)indexPath
  {
      UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
      
      const NSInteger imageTag = 99;
      UIImageView *imageView = (UIImageView *)[cell viewWithTag:imageTag];
      if (!imageView) {
          imageView = [[UIImageView alloc] initWithFrame: cell.contentView.bounds];
          imageView.tag = imageTag;
          [cell.contentView addSubview:imageView];
      }
      cell.tag = indexPath.row;
      imageView.image = nil;
  
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
          NSInteger index = indexPath.row;
          NSString *imagePath = self.imagePaths[index];
          UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
  
          dispatch_async(dispatch_get_main_queue(), ^{
              if (index == cell.tag) {
                  imageView.image = image; }
          });
      });
      return cell;
  }
  ```

* 延迟解压

