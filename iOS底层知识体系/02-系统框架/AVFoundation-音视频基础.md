# AVFoundation-音视频基础

> 一句话总结：**AVFoundation 把「采集 / 解码 / 合成 / 导出」串成流水线；入门以 `AVCaptureSession`（相机/麦克风）与 `AVPlayer`（播放）两条主链为主。**

---

## 1. 核心概念

### 1.1 模块分层（常用心智模型）

| 场景 | 典型类型 |
|------|-----------|
| **相机 / 录音采集** | `AVCaptureSession` + `AVCaptureDeviceInput` + `AVCaptureVideoDataOutput` / `AVCaptureAudioDataOutput` |
| **播放** | `AVPlayer` + `AVPlayerItem` + `AVAsset` |
| **剪辑 / 导出** | `AVMutableComposition`、`AVMutableVideoComposition`、`AVAssetExportSession` |
| **静态元数据** | `AVMetadataItem` |

### 1.2 线程与预览

- 预览层：`AVCaptureVideoPreviewLayer` 附在 view 上。
- 处理视频帧回调通常在**专用队列**（session queue），避免阻塞主线程；UI 更新 `dispatch_async` 回主队列。

---

## 2. 底层原理（采集管线）

### 2.1 最小可运行采集链路

1. `AVCaptureSession`：`beginConfiguration` → 设 `sessionPreset`（如 `.high`）  
2. `AVCaptureDevice.DiscoverySession` 取摄像头/麦克风  
3. `try AVCaptureDeviceInput(device:)` 加入 session  
4. 加 output：  
   - 要预览：previewLayer  
   - 要原始帧：`AVCaptureVideoDataOutput`，实现 `captureOutput(_:didOutput:from:)`  
5. `commitConfiguration` → `startRunning()`

### 2.2 权限

- 相机：`NSCameraUsageDescription`  
- 麦克风：`NSMicrophoneUsageDescription`  
- 首次使用时系统弹窗；拒绝后需引导用户到设置打开。

### 2.3 播放

- `AVURLAsset(url:)` → `AVPlayerItem(asset:)` → `AVPlayer(playerItem:)`  
- KVO 观察 `status`、`playbackBufferEmpty` 等；或用 `AVPlayerViewController` 快速搭 UI。

---

## 3. 关键问题 & 面试题

- **session preset 与分辨率、性能关系？** preset 越高数据量越大，需与算法/网络上传带宽平衡。  
- **为何视频回调里避免重活？** 否则丢帧；应用缓冲队列、降帧或降低分辨率。  
- **前后台切换** 要停 session / 释放相机资源，否则耗电且易触发系统限制。

---

## 4. 实战建议

- 采集与 UI **严格分队列**；对 `CMSampleBuffer` 尽快处理或异步 handed-off。
- 若只关心「有没有画面」可先跑通 **preview + photo output**，再换 `VideoDataOutput`。
- ProRes / HDR 等能力随系统版本与机型变化，需 runtime 判断。

---

## 5. 参考资料

- [AVFoundation - Apple Documentation](https://developer.apple.com/documentation/avfoundation)
- [Capturing Photos and Videos - Apple](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture)
- 旧笔记：`读书笔记/iOS自学笔记/基础——AVFoundation框架与音视频处理.md`
