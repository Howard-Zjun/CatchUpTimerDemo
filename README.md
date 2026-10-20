# CatchUpTimerDemo

CatchUpTimer 的交互测试 Demo，用于检查计时控制、前后台补偿、策略切换及回调中的状态变更。

## 依赖

项目通过 CocoaPods 以本地路径引入 `CatchUpTimer`，另包含 SnapKit 依赖：

```ruby
pod 'CatchUpTimer', :path => './CatchUpTimer'
pod 'SnapKit'
```

确保组件位于项目根目录的 `CatchUpTimer/` 下，安装依赖后使用工作区打开工程：

```bash
pod install
open CatchUpTimerDemo.xcworkspace
```

## 测试入口

- **手动测试**：选择策略并启动，每秒回调一次；切到后台等待数秒，再回前台观察补偿日志。
- **控制操作**：检查暂停、恢复、连续恢复、取消及对象释放。
- **回归测试**：点击「运行回归测试」，执行 18 个场景，页面及控制台输出 PASS / FAIL。
- **启动参数**：添加 `-run-timer-tests`，启动后自动运行回归测试。

回归测试使用模拟生命周期通知，运行期间请保持 App 在前台；真实前后台切换通过手动测试验证。

## 相关项目

- [CatchUpTimer](https://github.com/Howard-Zjun/CatchUpTimer)：支持后台遗漏回调补偿的定时器组件。
