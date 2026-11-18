修复UITargetedPreview initWithView:parameters:崩溃

# UITargetedPreview Crash Hook 修复文档
## 📋 崩溃信息
### 崩溃类型
```
Fatal Exception: NSInternalInconsistencyException
BUG_IN_CLIENT_OF_TARGETED_PREVIEW__VIEW_IS_NOT_IN_A_WINDOW
```
**Issue ID**：`f71b8fcf81cc23e58469fcd1adbbbe2c`**崩溃时间**：2025年10月22日 13:55:42

### 堆栈关键路径
```
UIKitCore: BUG_IN_CLIENT_OF_TARGETED_PREVIEW__VIEW_IS_NOT_IN_A_WINDOW
  ↓
UIKitCore: -[UITargetedPreview initWithView:parameters:]
  ↓
UIKitCore: UIContextMenuPresentationAnimation
  ↓
UIKitCore: UILongPressClickInteractionDriver (长按手势)
```
---

## 🔍 问题定位
### 根本原因
在创建 `UITargetedPreview` 时，目标 view 不在窗口层级中（`view.window == nil`），导致 UIKit 抛出断言崩溃。

### 触发场景
1. **Cell 复用时**：view 已从父视图移除但长按手势仍被触发
2. **页面切换时**：ViewController 正在 dismiss/pop 时触发长按
3. **动画过程中**：视图正在移除动画时被长按
4. **系统 Context Menu**：异常时机触发默认长按菜单

### 高风险代码
* `TPNewFeedDetailCommentView.swift` - 评论视图长按
* `TPNewFeedDetailCommentReplyCell.swift` - 评论回复长按

---

## 🛠️ 修复方案
### 核心思路
Hook `UITargetedPreview` 的 `initWithView:parameters:` 方法，在初始化时检查 view 是否在 window 中，如果不在则捕获异常避免崩溃。

---

## 📝 代码修改流程
### 1. 创建 Hook 实现文件
#### `UITargetedPreview+TPRuntimeSafe.h`
```
@interface UITargetedPreview (TPRuntimeSafe)
+ (void)hookRuntimeMethod;
@end
```
#### `UITargetedPreview+TPRuntimeSafe.m`
```
+ (void)hookRuntimeMethod {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TPCrashFixHero * hero = [TPCrashFixHero share];
        
        // 获取混淆后的类名和方法名
        NSString * tpTarPreview = [hero getHeroClassName: TPCrashFixClassKeyTpTarPreview];
        NSString * tpTarPreviewWithView = [hero getHeroSelName: TPCrashFixSelKeyTpTarPreviewWithView];
        
        // Hook initWithView:parameters:
        [self tpSwizzleMethodWith:tpTarPreview
                           oldSel:tpTarPreviewWithView
                           newSel:@"hookInitWithView:parameters:"
                         toTarget:@"UITargetedPreview"];
    });
}

- (instancetype)hookInitWithView:(UIView *)view parameters:(UIPreviewParameters *)parameters {
    // 关键防护：检查 view 是否在 window 中
    if (view.window == nil) {
        NSLog(@"[TPCrashFix] UITargetedPreview init with view not in window");
        
        // 使用 try-catch 捕获异常
        @try {
            return [self hookInitWithView:view parameters:parameters];
        } @catch (NSException *exception) {
            NSLog(@"[TPCrashFix] Caught exception: %@", exception);
            return nil;
        }
    }
    
    // view 正常在 window 中，调用原方法
    return [self hookInitWithView:view parameters:parameters];
}
```
---

### 2. 更新配置文件
#### `TPCrashFixKey.swift`
```swift
@objc public enum TPCrashFixClassKey: Int {
    case tpContainerI
    case tpSingleContainerI
    case tpContainerM
    case tpTarPreview  // 新增：混淆 UITargetedPreview
}

@objc public enum TPCrashFixSelKey: Int {
    case tpElementAt
    case tpElementAtSubsc
    case tpGetElementsSub
    case tpTarPreviewWithView  // 新增：混淆 initWithView:parameters:
}
```
#### `localhero` 加密配置
```json
{
  "tpTarPreview": "UITargetedPreview",
  "tpTarPreviewWithView": "initWithView:parameters:"
}
```
**混淆命名**：

* `UITargetedPreview` → `tpTarPreview`
* `initWithView:parameters:` → `tpTarPreviewWithView`

---

### 3. 启动时调用 Hook
#### `TPCrashHook.swift`
```swift
class TPCrashHook: TPBootTask {
    func app(_ app: UIApplication, didFinished options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        TPCrashFixHero.share.config()
        inputCrashFix()
        marrayCrashFix()
        targetedPreviewCrashFix()  // 新增
        return true
    }
    
    /// 修复 UITargetedPreview view not in window 崩溃
    private func targetedPreviewCrashFix() {
        guard TPHouyi.openFixTargetedPreviewCrash else {
            return
        }
        UITargetedPreview.hookRuntimeMethod()
    }
}
```
---

### 4. 添加远程开关
#### `TPHouyi.swift`
```swift
/// 9.4.2 是否开启 UITargetedPreview crash 修复
@HouyiBool(key: .openFixTargetedPreviewCrash, defualtValue: false)
static var openFixTargetedPreviewCrash: Bool
```
#### `TPHouyiManager+Extension.swift`
```swift
/// 9.4.2 是否开启 UITargetedPreview crash 修复
case openFixTargetedPreviewCrash
```
---

### 5. 更新桥接头文件
#### `Chat-Bridging-Header.h`
```
#import "NSArray+TPRuntimeSafe.h"
#import "NSMutableArray+TPRuntimeSafe.h"
#import "UITargetedPreview+TPRuntimeSafe.h"  // 新增
```
---

## 🧪 测试场景
### 测试入口
Feed 首页右下角显示 **🧪 橙色测试按钮**（仅 Debug 模式）。

### 场景1：正常 View 测试
**目的**：验证 Hook 不影响正常使用

**预期**：✅ 正常创建 UITargetedPreview

---

### 场景2：View 不在 Window 测试 ⭐️ 核心场景
**目的**：验证 Hook 防护崩溃

**预期日志**：

```
[TPCrashTest] View.window = ❌ nil
[TPCrashTest] 💥 尝试创建 UITargetedPreview...

👇 必须看到这两行！
[TPCrashFix] UITargetedPreview init with view not in window
[TPCrashFix] Caught exception in UITargetedPreview init

[TPCrashTest] ✅ Hook 生效！返回 nil，避免了崩溃
```
**验证标准**：

* ✅ 看到 `[TPCrashFix]` 日志
* ✅ 应用没有崩溃

---

### 场景3：Context Menu 测试
**目的**：测试真实使用场景

**操作**：长按红色方块，系统自动模拟以下场景：

1. 0.3秒后移除 view（模拟 Cell 复用）
2. 0.8秒后切换 Tab（模拟页面跳转）

**预期**：能正常弹出菜单，切换页面时不崩溃

---

### 场景4：极限崩溃复现 ⭐️ 100% 触发
**目的**：直接触发崩溃场景

**测试1**：View 添加后立即移除，然后创建 Preview

```swift
view.addSubview(testView)
testView.removeFromSuperview()  // view.window = nil
let preview = UITargetedPreview(view: testView)  // 💥 触发 Hook
```
**测试2**：模拟 Cell 复用

```swift
containerView.subviews.forEach { $0.removeFromSuperview() }  // 清空 Cell
let preview = UITargetedPreview(view: cellContentView)  // 💥 触发 Hook
```
**预期**：

* 测试1 和测试3 应该 **100% 触发** Hook 日志
* 应用不崩溃

---

## 📊 测试成功标准
|测试项|标准|
|-|-|
|**场景2 或 场景4**|必须看到 <br/>`[TPCrashFix]`<br/> 日志 ⭐️|
|**所有场景**|应用不崩溃|

**如果满足以上标准 = Hook 工作正常！** 🎉

---

## 📦 修改文件清单
### 新增文件
* `Chat/Chat/CrashFix/UITargetedPreview+TPRuntimeSafe.h`
* `Chat/Chat/CrashFix/UITargetedPreview+TPRuntimeSafe.m`
* `Chat/Chat/CrashFix/TPTargetedPreviewCrashTest.swift`

### 修改文件
* `Chat/Chat/CrashFix/TPCrashFixKey.swift`
* `Chat/Chat/CrashFix/localhero`
* `Chat/BootTask/TPCrashHook.swift`
* `Chat/Chat-Bridging-Header.h`
* `Chat/Chat/TPBusiness/Houyi/TPHouyi.swift`
* `Chat/Chat/TPBusiness/Houyi/TPHouyiManager+Extension.swift`
* `Chat/Chat/Feed/Controller/TPFeedContainerController.swift`（Debug 测试代码）

---

## 💻 完整测试代码
> **注意**：以下测试代码仅用于 Debug 模式验证，提交代码前会删除。
### 添加测试入口（在 TPFeedContainerController.swift 的 viewDidLoad 中）
```swift
// Debug 模式下添加测试按钮
#if DEBUG
setupCrashTestButton()
#endif
```
### 测试代码实现
#### 1. 创建测试按钮
```swift
// MARK: - Debug 测试工具
#if DEBUG
extension TPFeedContainerController {
    
    /// 设置 Crash 测试按钮（仅 Debug 模式）
    private func setupCrashTestButton() {
        let testButton = UIButton(type: .system)
        testButton.setTitle("🧪", for: .normal)
        testButton.titleLabel?.font = .systemFont(ofSize: 30)
        testButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        testButton.layer.cornerRadius = 25
        testButton.addTarget(self, action: #selector(crashTestButtonTapped), for: .touchUpInside)
        
        view.addSubview(testButton)
        testButton.snp.makeConstraints { make in
            make.width.height.equalTo(50)
            make.bottom.equalTo(submitFeedButton.snp.top).offset(-16)
            make.right.equalToSuperview().offset(-20.tp.fitScreen)
        }
        
        print("[TPCrashTest] 🧪 测试按钮已添加（仅 Debug 模式可见）")
    }
    
    /// 测试按钮点击事件
    @objc private func crashTestButtonTapped() {
        showCrashTestMenu()
    }
}
```
#### 2. 显示测试菜单
```swift
/// 显示测试菜单
private func showCrashTestMenu() {
    let alert = UIAlertController(
        title: "🧪 UITargetedPreview Crash 测试",
        message: "选择测试场景验证 Hook 是否生效",
        preferredStyle: .actionSheet
    )
    
    // 场景1：正常测试（view 在 window 中）
    alert.addAction(UIAlertAction(title: "✅ 场景1：正常 View 测试", style: .default) { [weak self] _ in
        self?.testNormalView()
    })
    
    // 场景2：崩溃场景测试（view 不在 window 中）
    alert.addAction(UIAlertAction(title: "⚠️ 场景2：View 不在 Window 测试", style: .default) { [weak self] _ in
        self?.testViewNotInWindow()
    })
    
    // 场景3：真实场景测试（Context Menu）
    alert.addAction(UIAlertAction(title: "🔍 场景3：Context Menu 测试", style: .default) { [weak self] _ in
        self?.testContextMenu()
    })
    
    // 场景4：极限崩溃测试（创建 Preview 时同步移除 view）
    alert.addAction(UIAlertAction(title: "💥 场景4：极限崩溃复现", style: .destructive) { [weak self] _ in
        self?.testExtremeCrashScenario()
    })
    
    // 场景5：完整测试（所有场景）
    alert.addAction(UIAlertAction(title: "🚀 场景5：运行所有测试", style: .default) { [weak self] _ in
        self?.runAllTests()
    })
    
    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
    
    present(alert, animated: true)
}
```
#### 3. 场景1：正常 View 测试
```swift
/// 场景1：正常 View 测试
private func testNormalView() {
    if #available(iOS 13.0, *) {
        TPTargetedPreviewCrashTest.showResult(from: self, message: "开始测试场景1...\n请查看控制台日志")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let testView = self.createTestView(title: "场景1")
            self.view.addSubview(testView)
            
            print("\n[TPCrashTest] ===== 场景1：正常 View =====")
            print("[TPCrashTest] View.window = \(testView.window != nil ? "✅ 存在" : "❌ nil")")
            
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            
            let preview: UITargetedPreview? = UITargetedPreview(view: testView, parameters: parameters)
            
            if preview != nil {
                print("[TPCrashTest] ✅ 成功创建 UITargetedPreview")
                TPTargetedPreviewCrashTest.showResult(from: self, message: "✅ 场景1 通过\n正常创建 UITargetedPreview")
            } else {
                print("[TPCrashTest] ❌ 创建失败")
                TPTargetedPreviewCrashTest.showResult(from: self, message: "❌ 场景1 异常\n创建失败")
            }
            
            testView.removeFromSuperview()
        }
    } else {
        TPTargetedPreviewCrashTest.showResult(from: self, message: "需要 iOS 13.0 及以上版本")
    }
}
```
#### 4. 场景2：View 不在 Window 测试
```swift
/// 场景2：View 不在 Window 测试
private func testViewNotInWindow() {
    if #available(iOS 13.0, *) {
        TPTargetedPreviewCrashTest.showResult(from: self, message: "开始测试场景2...\n这应该触发 Hook 防护\n请查看控制台日志")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let testView = self.createTestView(title: "场景2")
            // 注意：不添加到 superview，所以 view.window == nil
            
            print("\n[TPCrashTest] ===== 场景2：View 不在 Window =====")
            print("[TPCrashTest] View.window = \(testView.window != nil ? "✅ 存在" : "❌ nil")")
            print("[TPCrashTest] 🔍 尝试创建 UITargetedPreview（应该触发 Hook）...")
            
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            
            // 这里应该被 Hook 防护，不会崩溃
            let preview: UITargetedPreview? = UITargetedPreview(view: testView, parameters: parameters)
            
            if preview == nil {
                print("[TPCrashTest] ✅ Hook 生效！返回 nil，避免了崩溃")
                TPTargetedPreviewCrashTest.showResult(from: self, message: "✅ 场景2 通过\nHook 成功防护了崩溃！")
            } else {
                print("[TPCrashTest] ⚠️ 创建成功（可能系统允许）")
                TPTargetedPreviewCrashTest.showResult(from: self, message: "⚠️ 场景2 异常\n创建成功（可能系统版本原因）")
            }
        }
    } else {
        TPTargetedPreviewCrashTest.showResult(from: self, message: "需要 iOS 13.0 及以上版本")
    }
}
```
#### 5. 场景3：Context Menu 测试
```swift
/// 场景3：Context Menu 测试
private func testContextMenu() {
    if #available(iOS 13.0, *) {
        let testView = createTestView(title: "长按我")
        view.addSubview(testView)
        testView.center = view.center
        
        // 保存测试 view 引用
        testView.tag = 99999
        
        let interaction = UIContextMenuInteraction(delegate: self)
        testView.addInteraction(interaction)
        
        TPTargetedPreviewCrashTest.showResult(
            from: self,
            message: "✅ Context Menu 已添加\n\n请长按红色方块\n\n系统会自动模拟以下场景：\n1. 长按触发菜单\n2. 0.3秒后自动移除 view\n3. 0.8秒后自动切换页面"
        )
        
        print("\n[TPCrashTest] ===== 场景3：Context Menu =====")
        print("[TPCrashTest] ✅ 已添加 Context Menu，请长按红色方块")
        print("[TPCrashTest] 💡 长按后将自动切换页面，模拟崩溃场景")
        
        // 10秒后自动移除（兜底）
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if let view = self.view.viewWithTag(99999) {
                view.removeFromSuperview()
                print("[TPCrashTest] 测试 View 已自动移除（超时）")
            }
        }
    } else {
        TPTargetedPreviewCrashTest.showResult(from: self, message: "需要 iOS 13.0 及以上版本")
    }
}
```
#### 6. 场景4：极限崩溃复现
```swift
/// 场景4：极限崩溃测试（更激进的测试方式）
private func testExtremeCrashScenario() {
    if #available(iOS 13.0, *) {
        TPTargetedPreviewCrashTest.showResult(
            from: self,
            message: "开始极限崩溃测试...\n\n这个测试会直接触发原始崩溃场景\n请查看控制台日志"
        )
        
        print("\n[TPCrashTest] ===== 场景4：极限崩溃复现 =====")
        print("[TPCrashTest] 🔥 这是最接近真实崩溃的测试场景")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performExtremeCrashTest()
        }
    } else {
        TPTargetedPreviewCrashTest.showResult(from: self, message: "需要 iOS 13.0 及以上版本")
    }
}

/// 执行极限崩溃测试
@available(iOS 13.0, *)
private func performExtremeCrashTest() {
    print("\n[TPCrashTest] 开始执行极限崩溃测试...")
    
    // 测试1：创建 view 后立即从 window 移除，然后创建 Preview
    let testView1 = createTestView(title: "测试1")
    view.addSubview(testView1)
    
    print("[TPCrashTest] ✅ View 已添加到 window")
    print("[TPCrashTest] 🔥 立即移除 view...")
    
    testView1.removeFromSuperview()
    
    print("[TPCrashTest] ❌ View 已移除（view.window = \(testView1.window != nil ? "存在" : "nil")）")
    print("[TPCrashTest] 💥 尝试创建 UITargetedPreview...")
    
    let parameters1 = UIPreviewParameters()
    parameters1.backgroundColor = .clear
    
    let preview1: UITargetedPreview? = UITargetedPreview(view: testView1, parameters: parameters1)
    
    if preview1 == nil {
        print("[TPCrashTest] ✅ 测试1 通过！Hook 防护成功，返回 nil")
    } else {
        print("[TPCrashTest] ⚠️ 测试1 异常：创建成功（系统可能允许）")
    }
    
    // 测试2和测试3...
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.testCellReuseCrashScenario()
    }
}

/// 测试 Cell 复用崩溃场景
@available(iOS 13.0, *)
private func testCellReuseCrashScenario() {
    print("\n[TPCrashTest] --- 测试3：Cell 复用崩溃场景 ---")
    
    // 创建一个临时容器，模拟 Cell
    let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    containerView.backgroundColor = .systemGray
    view.addSubview(containerView)
    containerView.center = CGPoint(x: view.center.x, y: view.center.y - 100)
    
    let cellContentView = createTestView(title: "测试3\nCell")
    cellContentView.frame = containerView.bounds
    containerView.addSubview(cellContentView)
    
    print("[TPCrashTest] ✅ 模拟 Cell 已创建")
    print("[TPCrashTest] 🔥 模拟 Cell 被复用...")
    
    // 模拟 prepareForReuse：移除所有子视图
    containerView.subviews.forEach { $0.removeFromSuperview() }
    
    print("[TPCrashTest] ❌ Cell 内容已被清空（模拟 prepareForReuse）")
    print("[TPCrashTest] 💥 此时如果还有长按手势回调，尝试创建 Preview...")
    
    // 此时 cellContentView 已经不在 window 中了
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    
    let preview: UITargetedPreview? = UITargetedPreview(view: cellContentView, parameters: parameters)
    
    if preview == nil {
        print("[TPCrashTest] ✅ 测试3 通过！Hook 防护成功")
    } else {
        print("[TPCrashTest] ⚠️ 测试3 异常：创建成功")
    }
    
    // 清理
    containerView.removeFromSuperview()
    
    print("\n[TPCrashTest] ===== 场景4 极限测试完成 =====")
    print("[TPCrashTest] 📊 测试结果总结：")
    print("[TPCrashTest] - 如果看到 [TPCrashFix] 日志，说明 Hook 成功防护")
    print("[TPCrashTest] - 如果没有崩溃，说明修复方案有效")
    
    TPTargetedPreviewCrashTest.showResult(
        from: self,
        message: "极限测试完成！\n\n请检查控制台：\n1. 是否看到 [TPCrashFix] 日志\n2. 应用是否没有崩溃"
    )
}
```
#### 7. 辅助方法
```swift
/// 创建测试 View
private func createTestView(title: String) -> UIView {
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 120, height: 120))
    view.backgroundColor = .systemRed
    view.layer.cornerRadius = 12
    view.isUserInteractionEnabled = true
    
    let label = UILabel(frame: view.bounds)
    label.text = title
    label.textColor = .white
    label.textAlignment = .center
    label.font = .boldSystemFont(ofSize: 16)
    label.numberOfLines = 0
    view.addSubview(label)
    
    return view
}
```
#### 8. Context Menu 代理实现
```swift
// MARK: - UIContextMenuInteractionDelegate (测试用)
@available(iOS 13.0, *)
extension TPFeedContainerController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        print("[TPCrashTest] 🔍 Context Menu 被触发")
        
        // 自动模拟崩溃场景：0.3秒后移除 view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            print("[TPCrashTest] ⚡️ 开始自动模拟崩溃场景...")
            print("[TPCrashTest] 📱 方式1：移除测试 View（模拟 Cell 复用）")
            
            if let testView = self.view.viewWithTag(99999) {
                testView.removeFromSuperview()
                print("[TPCrashTest] ✅ 测试 View 已移除")
                print("[TPCrashTest] 🔍 此时如果 Context Menu 还在创建 Preview，应该触发 Hook")
            }
        }
        
        // 再延迟 0.5 秒，尝试切换页面（模拟页面跳转）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            
            print("[TPCrashTest] 📱 方式2：切换页面（模拟页面跳转）")
            
            // 切换到其他 Tab 再切回来
            if let tabBarController = self.tabBarController {
                let currentIndex = tabBarController.selectedIndex
                let nextIndex = (currentIndex + 1) % (tabBarController.viewControllers?.count ?? 1)
                
                tabBarController.selectedIndex = nextIndex
                print("[TPCrashTest] ✅ 已切换到 Tab \(nextIndex)")
                
                // 0.5秒后切回来
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tabBarController.selectedIndex = currentIndex
                    print("[TPCrashTest] ✅ 已切回原 Tab \(currentIndex)")
                    print("[TPCrashTest] ===== 场景3 自动测试完成 =====\n")
                }
            } else {
                print("[TPCrashTest] ⚠️ 无法获取 TabBarController，跳过页面切换测试")
                print("[TPCrashTest] ===== 场景3 自动测试完成 =====\n")
            }
        }
        
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil
        ) { _ in
            let action1 = UIAction(title: "测试选项1", image: UIImage(systemName: "checkmark")) { _ in
                print("[TPCrashTest] 测试选项1 被点击")
            }
            let action2 = UIAction(title: "测试选项2", image: UIImage(systemName: "star")) { _ in
                print("[TPCrashTest] 测试选项2 被点击")
            }
            let action3 = UIAction(title: "重新测试", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
                print("[TPCrashTest] 重新运行场景3")
                self?.testContextMenu()
            }
            return UIMenu(title: "测试菜单", children: [action1, action2, action3])
        }
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        print("[TPCrashTest] 📋 Context Menu 开始显示")
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        print("[TPCrashTest] 📋 Context Menu 即将关闭")
    }
}
#endif
```
### 使用说明
1. **添加代码位置**：`Chat/Chat/Feed/Controller/TPFeedContainerController.swift`
2. **所有代码**：包裹在 `#if DEBUG ... #endif` 中
3. **提交前删除**：Release 版本前删除所有测试代码
4. **依赖文件**：`TPTargetedPreviewCrashTest.swift`（测试工具类）

---

**文档版本**：v1.2**最后更新**：2025-10-23**作者**：fengcaifan