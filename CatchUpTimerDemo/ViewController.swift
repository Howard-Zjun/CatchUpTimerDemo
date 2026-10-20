//
//  ViewController.swift
//  CatchUpTimerDemo
//
//  Created by Howard-Zjun on 2026/10/20.
//

import UIKit
import CatchUpTimer

class ViewController: UIViewController {

    private let policyControl = UISegmentedControl(items: ["逐次补发", "仅最新计数"])
    private let countLabel = UILabel()
    private let logView = UITextView()
    private let controls = UIStackView()
    private let testButton = UIButton(type: .system)
    private var timer: CatchUpTimer?
    private var testTask: Task<Void, Never>?
    private var logLines: [String] = []
    private var startedAt = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        NotificationCenter.default.addObserver(self, selector: #selector(stopTestsForBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        if ProcessInfo.processInfo.arguments.contains("-run-timer-tests") {
            runTests()
        }
    }

    deinit {
        testTask?.cancel()
        timer?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        let titleLabel = UILabel()
        titleLabel.text = "CatchUpTimer 测试"
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        let instructions = UILabel()
        instructions.text = "手动测试：每秒回调一次。选择策略后启动，切到后台等待数秒再回来，观察补偿日志。回归测试使用模拟生命周期通知，请保持 App 在前台。"
        instructions.font = .preferredFont(forTextStyle: .subheadline)
        instructions.numberOfLines = 0
        policyControl.selectedSegmentIndex = 0
        policyControl.addTarget(self, action: #selector(policyChanged), for: .valueChanged)
        countLabel.text = "当前计数：0"
        countLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .medium)

        controls.axis = .vertical
        controls.spacing = 8
        let actions: [(String, Selector)] = [
            ("启动 / 重新开始", #selector(startTimer)),
            ("暂停", #selector(pauseTimer)),
            ("恢复", #selector(resumeTimer)),
            ("连续恢复 3 次", #selector(resumeRepeatedly)),
            ("取消", #selector(cancelTimer)),
            ("释放对象", #selector(releaseTimer))
        ]
        for rowStart in stride(from: 0, to: actions.count, by: 2) {
            let row = UIStackView()
            row.distribution = .fillEqually
            row.spacing = 8
            for (title, action) in actions[rowStart..<min(rowStart + 2, actions.count)] {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.addTarget(self, action: action, for: .touchUpInside)
                row.addArrangedSubview(button)
            }
            controls.addArrangedSubview(row)
        }
        testButton.setTitle("运行回归测试", for: .normal)
        testButton.addTarget(self, action: #selector(runTests), for: .touchUpInside)
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.backgroundColor = .secondarySystemBackground
        logView.accessibilityIdentifier = "timerTestLog"
        let stack = UIStackView(arrangedSubviews: [titleLabel, instructions, policyControl, countLabel, controls, testButton, logView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    @objc private func startTimer() {
        timer?.cancel()
        startedAt = Date()
        countLabel.text = "当前计数：0"
        let policy: CatchUpTimer.MissedResponsePolicy = policyControl.selectedSegmentIndex == 0 ? .replayAll : .latestOnly
        timer = CatchUpTimer(timeInterval: 1, usesCommonRunLoopModes: true, missedResponsePolicy: policy) { [weak self] count in
            self?.countLabel.text = "当前计数：\(count)"
            self?.appendLog("回调 #\(count)")
        }
        appendLog("启动：\(policyControl.titleForSegment(at: policyControl.selectedSegmentIndex) ?? "")")
    }

    @objc private func policyChanged() {
        cancelTimer()
        appendLog("策略已切换，点击启动生效")
    }

    @objc private func pauseTimer() {
        timer?.pause()
        appendLog("暂停")
    }

    @objc private func resumeTimer() {
        guard timer != nil else { appendLog("请先启动"); return }
        timer?.resume()
        appendLog("恢复")
    }

    @objc private func resumeRepeatedly() {
        guard timer != nil else { appendLog("请先启动"); return }
        for _ in 0..<3 { timer?.resume() }
        appendLog("连续调用 resume() 3 次，预期仍每秒一次")
    }

    @objc private func cancelTimer() {
        timer?.cancel()
        countLabel.text = "当前计数：0"
        appendLog("取消，计数归零")
    }

    @objc private func releaseTimer() {
        weak var releasedTimer = timer
        timer = nil
        appendLog(releasedTimer == nil ? "PASS 对象已释放" : "FAIL 对象仍被持有")
        countLabel.text = "当前计数：0"
    }

    @objc private func runTests() {
        guard testTask == nil else { return }
        timer?.cancel()
        timer = nil
        logLines.removeAll()
        startedAt = Date()
        countLabel.text = "回归测试中…"
        controls.isUserInteractionEnabled = false
        policyControl.isEnabled = false
        testButton.isEnabled = false
        testTask = Task { [weak self] in
            guard let self = self else { return }
            defer {
                self.controls.isUserInteractionEnabled = true
                self.policyControl.isEnabled = true
                self.testButton.isEnabled = true
                self.testTask = nil
            }
            var passed = 0
            let cases = CatchUpTimerDemoTests.allCases
            for testCase in cases {
                do {
                    try Task.checkCancellation()
                    let result = try await CatchUpTimerDemoTests.run(testCase)
                    if result { passed += 1 }
                    self.appendLog("\(result ? "PASS" : "FAIL") \(testCase.rawValue)")
                } catch {
                    self.appendLog("测试已中止，请保持 App 在前台后重试")
                    self.countLabel.text = "测试已中止"
                    return
                }
            }
            let summary = "测试结果：\(passed)/\(cases.count) 通过"
            self.countLabel.text = summary
            self.appendLog(summary)
        }
    }

    @objc private func stopTestsForBackground(_ notification: Notification) {
        // 模拟通知只影响本轮测试；真正进入后台时停止整套测试，避免时间断言失真。
        if UIApplication.shared.applicationState != .active {
            testTask?.cancel()
        }
    }

    private func appendLog(_ message: String) {
        let line = String(format: "[%6.2fs] %@", Date().timeIntervalSince(startedAt), message)
        logLines.append(line)
        if logLines.count > 200 { logLines.removeFirst(logLines.count - 200) }
        logView.text = logLines.joined(separator: "\n")
        logView.scrollRangeToVisible(NSRange(location: logView.text.utf16.count, length: 0))
        print(line)
    }
}

@MainActor
private enum CatchUpTimerDemoTests: String, CaseIterable {
    case basic = "启动、递增与取消清零"
    case pauseResume = "暂停停止回调，恢复等待完整间隔"
    case repeatedResume = "重复恢复不创建多个定时器"
    case release = "运行中的对象可直接释放"
    case replayAll = "后台遗漏逐次补发"
    case latestOnly = "后台遗漏只回调最新计数"
    case cancelReplay = "逐次补发中取消立即停止"
    case cancelLatest = "最新计数回调中取消保留清零状态"
    case restartReplay = "逐次补发中重启不覆盖新状态"
    case restartLatest = "最新计数回调中重启不覆盖新状态"
    case cadence = "回前台后按剩余时间触发"
    case backgroundPauseReplay = "逐次策略后台暂停后恢复不补发暂停时间"
    case backgroundPauseLatest = "最新策略后台暂停后恢复不补发暂停时间"
    case invalidInterval = "无效间隔不能通过启动或恢复运行"
    case backgroundStartReplay = "逐次策略后台启动后正确补偿"
    case backgroundStartLatest = "最新策略后台启动后正确补偿"
    case backgroundResumeReplay = "逐次策略后台恢复后正确补偿"
    case backgroundResumeLatest = "最新策略后台恢复后正确补偿"

    static func run(_ testCase: Self) async throws -> Bool {
        var counts: [Int] = []
        var timestamps: [Date] = []
        var timer: CatchUpTimer?
        defer {
            timer?.cancel()
            timer = nil
            // 即使用例失败或中止，也恢复模拟的前台状态。
            postForeground()
        }
        switch testCase {
        case .backgroundStartReplay, .backgroundStartLatest, .backgroundResumeReplay, .backgroundResumeLatest:
            let latest = [.backgroundStartLatest, .backgroundResumeLatest].contains(testCase)
            let resumes = [.backgroundResumeReplay, .backgroundResumeLatest].contains(testCase)
            timer = CatchUpTimer(timeInterval: 0.1, missedResponsePolicy: latest ? .latestOnly : .replayAll) {
                counts.append($0)
            }
            if resumes { timer?.pause() } else { timer?.cancel() }
            postBackground()
            try await wait(0.15)
            if resumes { timer?.resume() } else { timer?.start() }
            try await wait(0.36)
            guard counts.isEmpty else { return false }
            postForeground()
            if latest {
                return counts.count == 1 && (counts.first ?? 0) >= 3 && timer?.currentResponseCount == counts.last
            }
            return counts.count >= 3 && counts == Array(1...counts.count) && timer?.currentResponseCount == counts.last

        case .invalidInterval:
            for interval in [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity] {
                timer = CatchUpTimer(timeInterval: interval) { counts.append($0) }
                timer?.start()
                timer?.resume()
                postBackground()
                try await wait(0.03)
                postForeground()
                try await wait(0.03)
                guard counts.isEmpty, timer?.currentResponseCount == 0 else { return false }
                timer?.cancel()
                timer = nil
            }
            return true

        case .backgroundPauseReplay, .backgroundPauseLatest:
            timer = CatchUpTimer(timeInterval: 0.2, missedResponsePolicy: testCase == .backgroundPauseReplay ? .replayAll : .latestOnly) {
                counts.append($0)
            }
            postBackground()
            timer?.pause()
            try await wait(0.35)
            postForeground()
            timer?.resume()
            guard counts.isEmpty, timer?.currentResponseCount == 0 else { return false }
            try await wait(0.08)
            guard counts.isEmpty else { return false }
            try await wait(0.25)
            return !counts.isEmpty && counts == Array(1...counts.count) && timer?.currentResponseCount == counts.last

        case .release:
            timer = CatchUpTimer(timeInterval: 0.1) { _ in }
            weak var releasedTimer = timer
            timer = nil
            return releasedTimer == nil

        case .basic, .pauseResume, .repeatedResume:
            timer = CatchUpTimer(timeInterval: 0.2) { count in
                counts.append(count)
                timestamps.append(Date())
            }
            if testCase == .repeatedResume {
                timer?.pause()
                for _ in 0..<3 { timer?.resume() }
            }
            try await wait(0.75)
            guard counts.count >= 2, counts == Array(1...counts.count) else { return false }
            if testCase == .pauseResume {
                timer?.pause()
                let pausedCount = counts.count
                try await wait(0.35)
                guard counts.count == pausedCount else { return false }
                timer?.resume()
                try await wait(0.08)
                guard counts.count == pausedCount else { return false }
                try await wait(0.25)
                return counts.count > pausedCount
            }
            if testCase == .repeatedResume {
                return zip(timestamps, timestamps.dropFirst()).allSatisfy { $1.timeIntervalSince($0) > 0.1 }
            }
            timer?.cancel()
            let cancelledCount = counts.count
            try await wait(0.3)
            return timer?.currentResponseCount == 0 && counts.count == cancelledCount

        case .cadence:
            let start = Date()
            timer = CatchUpTimer(timeInterval: 2) { counts.append($0) }
            postBackground()
            try await wait(1.2)
            postForeground()
            guard counts.isEmpty else { return false }
            try await wait(1.2)
            return counts == [1] && Date().timeIntervalSince(start) < 3.2

        default:
            let latest = [.latestOnly, .cancelLatest, .restartLatest].contains(testCase)
            let cancels = [.cancelReplay, .cancelLatest].contains(testCase)
            let restarts = [.restartReplay, .restartLatest].contains(testCase)
            var didMutate = false
            timer = CatchUpTimer(timeInterval: 0.1, missedResponsePolicy: latest ? .latestOnly : .replayAll) { count in
                counts.append(count)
                if !didMutate && (cancels || restarts) {
                    didMutate = true
                    if cancels { timer?.cancel() } else { timer?.start() }
                }
            }
            postBackground()
            try await wait(0.36)
            guard counts.isEmpty else { return false }
            postForeground()
            if cancels || restarts {
                guard counts.count == 1, timer?.currentResponseCount == 0 else { return false }
                try await wait(0.16)
                if cancels { return counts.count == 1 && timer?.currentResponseCount == 0 }
                return counts.count == 2 && counts.last == 1 && timer?.currentResponseCount == 1
            }
            if latest {
                return counts.count == 1 && (counts.first ?? 0) >= 3 && timer?.currentResponseCount == counts.last
            }
            return counts.count >= 3 && counts == Array(1...counts.count) && timer?.currentResponseCount == counts.last
        }
    }

    private static func wait(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private static func postBackground() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private static func postForeground() {
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

