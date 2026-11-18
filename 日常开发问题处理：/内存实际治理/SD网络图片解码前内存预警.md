SD网络图片解码前内存预警

# 一、背景
 [图片内存预警](https://ku.baidu-int.com/knowledge/HFVrC7hq1Q/pKzJfZczuc/cmlXUWMvnp/D74W0ITtEcAUtB?t=mention&mt=doc&dt=doc)

* 背景：运营或者PM经常配置一些比较大的图片。大图会导致很多性能问题，比如卡顿、OOM。

所以我们计划在图片解码之前预估一下图片的大小，如果太大就进行预警。后期也可以直接对大图进行处理（TODO）。

* **目标**：尽可能做成pod，非侵入式、不影响SDWebImage库本身与业务层项目。

# 二、实施步骤
## 2.1 技术预研
### SDWebImage解码流程源码阅读：
#### Decoder时序图
![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=330697a3eb1549f59f11e7a1ea2f7829&docGuid=0Bjyv5qlyFhnBV)
* SDWebImageDownloaderOperation：图片下载operation，获取到imageData；
* SDWebImageDownloaderDecryptor：如果图片有做加解密处理，则这里会将imageData传入解密代理，之后返回解密后的Data；
* SDImageLoaderDecodeImageData：是一个全局函数。解密完成后，会将解码任务放到解密队列里。解码逻辑是由这个全局函数作为入口的；
* SDImageCodersManager：解码流程到manager。会根据不同图片的dataformat。来调用不同的解码方式进行解码；
* SDImageCoder：解码协议。不同的解码方式需要实现这个协议；

#### 解码架构：
> SDImageCodersManager与SDImageCoder协议及实现协议的类，组成了的解码框架。整体使用策略模式。
![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=7fa6008951134e1aa041a3d6ba9f1646&docGuid=0Bjyv5qlyFhnBV)
* SDImageIOCoder：负责png、jpeg等图片解码。但是最终调用的还是SDImageIOAnimatedCoder里的解码方法。
* SDImageIOAnimatedCoder：PNG、JPEG、GIF格式的最终解码函数。
* SDImageWebPCoder：webp的解码类。

**重点**：最终实施解码的函数：

```
1、CGImageSourceCreateImageAtIndex
2、CGImageSourceCreateThumbnailAtIndex
```
## 2.2 实时阶段
**整体流程**：下载完成后获取图片数据。然后计算对应的解码大小，如果有使用缩略图，则计算缩略图的解码大小。如果大小超过了阈值，则打印图片信息，做出警告。（后续可能进一步对大小进行处理）

> 正常如果在SDImageLoaderDecodeImageData全局函数的位置进行上述步骤是最合理的。因为这里可以拿到所有我们想要的数据：图片URL、图片Data、图片配置数据options(有缩略图大小等信息)。
> 但是SDImageLoaderDecodeImageData全局函数无法hook。（PS：使用fishhook存在crash，线上方案无法保证完全没问题）。
> 所以，就分两步走：
> 1、在下载完成后，通过Decryptor获取图片Data和图片url；
> 2、在解码前获取图片Data和图片配置数据options。
> 3、根据图片Data计算解码大小：
> 3.1、根据图片Data和options得到原始数据CGImageSourceRef和CGImageSourceProperties。计算得到原始图片解码大小；
> 3.2、根据图片Data和options得到缩略尺寸，计算缩略图解码大小。
> 4、根据解码大小判断阈值。通过图片url进行预警。
### 1、获取图片Data和图片url
在图片解码之前获取图片的data和url。主要是通过实现SDWebImageDownloaderDecryptor协议，自定义一个Decryptor类，然后在回调函数里拿到想要的数据。但是因为业务层可能会有自己的Decryptor类。所以不能直接将自定义的Decryptor类，插入到context中，怕会影响业务层的Decryptor类。所以最终方法是使用装饰器模式，对原有context里的业务层Decryptor类进行包装。将SDWebImageDownloaderDecryptor协议的回调转嫁到我们自定义的Decryptor类里。

#### 1.1、 创建自定义Decryptor类
```
import SDWebImage

/// 图片下载解密
@objc public class TPDecoderEarlyWarningDecryptor: SDWebImageDownloaderDecryptor {
    var relDecryptor: SDWebImageDownloaderDecryptor? // 业务层Decryptor
    
    @objc public func setRelDecryptor(_ decrypto: SDWebImageDownloaderDecryptor) {
        self.relDecryptor = decrypto
    }
    // 协议回调，获取到Data和URLResponse
    public override func decryptedData(with data: Data, response: URLResponse?) -> Data? {
        // 将Data和URLResponse传入Manager中进行临时存储。
        TPDecoderEarlyWarningManager.share.imgMemEarlyWarning(with: data, response: response)
        if let relDecryptor = self.relDecryptor {
            // 如果存在业务层Decryptor类，则执行业务层的解密逻辑
            return relDecryptor.decryptedData(with: data, response: response)
        } else {
            return data
        }
    }
}


```
#### 1.2、替换context中的Decryptor
通过hook，sd的入口函数sd_internalSetImageWithURL，来替换Decryptor。

```
- (void)hook_sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                           context:(nullable SDWebImageContext *)context
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDImageLoaderProgressBlock)progressBlock
                              completed:(nullable SDInternalCompletionBlock)completedBlock {
    // 拦截context里的decryptor，用于记录下载回来的图片数据（data+response）
    SDWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    if ([context valueForKey:SDWebImageContextDownloadDecryptor]) {
        id<SDWebImageDownloaderDecryptor> decryptor = [context valueForKey:SDWebImageContextDownloadDecryptor];
        TPDecoderEarlyWarningDecryptor * newDecryptor = [TPDecoderEarlyWarningDecryptor new];
        [newDecryptor setRelDecryptor:decryptor];
        mutableContext[SDWebImageContextDownloadDecryptor] = newDecryptor; // 插入自定义Decryptor
    } else {
        TPDecoderEarlyWarningDecryptor * newDecryptor = [TPDecoderEarlyWarningDecryptor new];
        mutableContext[SDWebImageContextDownloadDecryptor] = newDecryptor; // 插入自定义Decryptor
    }
    context = [mutableContext copy];
    
    return [self hook_sd_internalSetImageWithURL:url
                                placeholderImage:placeholder
                                         options:options
                                         context:context
                                   setImageBlock:setImageBlock
                                        progress:progressBlock
                                       completed:completedBlock];
}
@end
```
### 2、获取图片Data和图片配置数据options
通过上面的解码架构图可以知道，所有图片的解码逻辑是由SDImageCodersManager统一管理的。所以这里通过hook SDImageCodersManager的 decodedImageWithData函数实现：

```
- (UIImage *)hook_decodedImageWithData:(NSData *)data options:(nullable SDImageCoderOptions *)options {
    // 将Data和options传入Manager中进行处理。
    [[TPDecoderEarlyWarningManager share] decodedImageWith:data options:options];
    
    return [self hook_decodedImageWithData:data options:options];
}
```
### 3、计算图片大小和预警
这里设计思路，也是利用策略模式，对不同imageFormat的图片进行对应的计算。

#### 3.1 TPDecoderEarlyWarningManager
> 持有所有计算逻辑的类，负责管理解码逻辑
```
@objc public class TPDecoderEarlyWarningManager: NSObject {
    private var imageMaps: [Data: TPDecoderEarlyWarningModel] = [:]
    private lazy var earlyMemWarningItems: [TPDecoderEarlyWarningProtocol] = [TPIOImgDecoderEarlyWarning(),TPGIFImgDecoderEarlyWarning(),TPWebpImgDecoderEarlyWarning()]

    /// 1，先走的解密流程拦截到的图片下载完成后的data和response信息
    func imgMemEarlyWarning(with data: Data, response: URLResponse?) {
        debugPrint("ImgMemEarlyWarning imgMemEarlyWarning ")
        guard imageMaps[data] == nil,
              let urlStr = response?.url?.absoluteString else {
            return
        }
        let newModel = TPDecoderEarlyWarningModel(data: data, url: urlStr)
        imageMaps[data] = newModel
    }
    
    /// 2,后走的解码逻辑，在图片解码前进行拦截。
    /// SDImageCoderOptions
    /// SDImageCoderOptions
    /// [SDWebImageContextOption: AnyObject] SDImageCoderOption, id
    @objc public func decodedImage(with data: Data, options: [SDImageCoderOption: AnyObject]) {
        debugPrint("ImgMemEarlyWarning decodedImage ")
        guard let model = imageMaps[data] else { return }
        let imageFormat: SDImageFormat = NSData.sd_imageFormat(forImageData: data)
        model.options = options
        model.imageFormat = imageFormat
        for item in earlyMemWarningItems where item.imageFormats.contains(imageFormat) {
            item.imgMemEarlyWarningHandler(model: model)
        }
        imageMaps.removeValue(forKey: data)
    }
}
```
#### 3.2 TPDecoderEarlyWarningProtocol
定义计算解码大小的协议。

```
protocol TPDecoderEarlyWarningProtocol {
    var imageFormats: [SDImageFormat] { get }
    func imgMemEarlyWarningHandler(model: TPDecoderEarlyWarningModel)
    // 查看是否有缩略图大小
    func getThumbnailSize(by options: [SDImageCoderOption: AnyObject]) -> CGSize
}

extension TPDecoderEarlyWarningProtocol {
    func getThumbnailSize(by options: [SDImageCoderOption: AnyObject]) -> CGSize {
        if let size = options[.decodeThumbnailPixelSize] as? CGSize {
            return size
        }
        return .zero
    }
}
```
#### 3.3 具体计算
##### 3.3.1 TPIOImgDecoderEarlyWarning
主要处理.JPEG, .PNG格式的图片

```
class TPIOImgDecoderEarlyWarning: TPDecoderEarlyWarningProtocol {
    var imageFormats: [SDImageFormat] {
        return [.JPEG, .PNG]
    }
    
    func imgMemEarlyWarningHandler(model: TPDecoderEarlyWarningModel) {
        guard let source = CGImageSourceCreateWithData(model.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, model.options as CFDictionary?) as? [CFString: Any] else {
            return
        }
        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0.0
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0.0
        let size = pixelWidth * pixelHeight * 4 / 1024 / 1024
        model.printDetail()
    }
}
```
##### 3.3.2 TPGIFImgDecoderEarlyWarning
主要处理GIF格式图片

```
class TPGIFImgDecoderEarlyWarning: TPDecoderEarlyWarningProtocol {
    var imageFormats: [SDImageFormat] {
        return [.GIF]
    }
    
    func imgMemEarlyWarningHandler(model: TPDecoderEarlyWarningModel) {
        guard let source = CGImageSourceCreateWithData(model.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, model.options as CFDictionary?) as? [CFString: Any] else {
            return
        }
        let count = CGImageSourceGetCount(source) // 图片数量
        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0.0
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0.0
        let size = pixelWidth * pixelHeight * 4 / 1024 / 1024
        
        model.printDetail()
    }
}
```
##### 3.3.3 TPWebpImgDecoderEarlyWarning
主要处理WebP格式图片

```
class TPWebpImgDecoderEarlyWarning: TPDecoderEarlyWarningProtocol {
    var imageFormats: [SDImageFormat] {
        return [.webP]
    }
    
    func imgMemEarlyWarningHandler(model: TPDecoderEarlyWarningModel) {
        var webpData = WebPData()
        WebPDataInit(&webpData)
        webpData.bytes = (model.data as NSData).bytes.bindMemory(to: UInt8.self, capacity: model.data.count)
        webpData.size = model.data.count
        
        let demuxer = WebPDemux(&webpData)
        if demuxer != nil {
            let frameCount = WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT) // webp数量
            var iter = WebPIterator()
            if WebPDemuxGetFrame(demuxer, 1, &iter) != 0 {
                let pixelWidth = CGFloat(iter.width)
                let pixelHeight = CGFloat(iter.height)
                let size = pixelWidth * pixelHeight * 4 / 1024 / 1024
                model.printDetail()
                WebPDemuxReleaseIterator(&iter)
            }
        }
        WebPDemuxDelete(demuxer)
    }
}
```
# 三、总结
#### 遇到的问题：
* 无法hook全局函数
    * 尝试使用fishhook，会有crash。故未实现

* 私有pod混编
    * 找不到project-Swift.h文件。需要使用下面代码


```
#if __has_include("SDImageEarlyWarming-Swift.h")
#import "SDImageEarlyWarming-Swift.h"
#else
#import <SDImageEarlyWarming/SDImageEarlyWarming-Swift.h>
#endif
```
* 外部找不到库里的类
    * 原因是，没有将初始化函数public。


#### TODO：
* 阈值处理
* 超过大小如何处理
* 目前也不太好对不同业务进行预警



> 总结本次技术应用中可积累的代码和经验
#### **技术经验**
* sdwebImage 解码流程源码
* hook方式：
    * 无法hook全局方法
    * fishhook使用及源码学习

* 装饰器设计模式很精妙

#### **有待提升**：
* 多看源码

