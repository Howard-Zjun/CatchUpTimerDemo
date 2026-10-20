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

## 相关项目

- [CatchUpTimer](https://github.com/Howard-Zjun/CatchUpTimer)：支持后台遗漏回调补偿的定时器组件。
