import SwiftUI
import AVFoundation
import Combine
import UserNotifications

// MARK: - 主视图模型
/// 管理应用所有业务逻辑：计时器、番茄钟、音乐播放、用户认证、成就系统
class ShixiViewModel: ObservableObject {

    // MARK: 计时器状态
    @Published var timerMode: TimerMode = .normal        // 当前计时模式
    @Published var isRunning = false                     // 是否正在计时
    @Published var isPaused = false                      // 是否暂停中
    @Published var remainingSeconds = 0                  // 剩余秒数
    @Published var totalSeconds = 0                      // 总秒数（用于计算进度）
    @Published var frameIndex = 0                        // 当前动画帧索引
    @Published var doneMessage = ""                      // 完成提示文案
    @Published var showDoneMessage = false               // 是否显示完成提示

    // MARK: 番茄钟设置
    @Published var pomoWorkMinutes = 25                  // 专注时长（分钟）
    @Published var pomoBreakMinutes = 5                   // 休息时长（分钟）
    @Published var pomoCycles = 4                        // 循环轮数
    @Published var timeInput: String = "5min"              // 用户输入的计时时间
    @Published var currentCycle = 0                      // 当前轮次（从0开始）
    @Published var pomoPhase: PomodoroPhase = .work      // 当前阶段

    // MARK: 主题
    @Published var currentTheme: AppTheme = .bee          // 当前选中的主题
    @Published var usedThemeIDs: Set<String> = []        // 已使用过的主题ID集合（用于成就统计）

    // MARK: 音乐
    @Published var isMusicPlaying = false                // 音乐是否正在播放
    @Published var currentStationIndex = 0               // 当前电台索引
    @Published var volume: Double = 0.4                  // 音量（0.0 ~ 1.0）
    @Published var autoSwitch = false                    // 是否自动轮播电台
    @Published var musicStatus = "点击播放，享受专注时光"   // 音乐状态文案

    // MARK: 用户认证
    @Published var currentUser: AppUser?                  // 当前登录用户
    @Published var isShowingAuth = false                  // 是否显示登录弹窗
    @Published var authMode: AuthMode = .login            // 当前认证模式

    // MARK: 成就系统
    @Published var achievements: [AchievementItem] = [    // 成就列表
        AchievementItem(id: "first", name: "初次计时", description: "完成第一次倒计时", isUnlocked: false),
        AchievementItem(id: "five", name: "专注五分钟", description: "完成5分钟计时", isUnlocked: false),
        AchievementItem(id: "ten", name: "深度专注", description: "完成10分钟计时", isUnlocked: false),
        AchievementItem(id: "hour", name: "持久战士", description: "完成1小时计时", isUnlocked: false),
        AchievementItem(id: "custom", name: "自定义大师", description: "使用自定义计时", isUnlocked: false),
        AchievementItem(id: "explorer", name: "主题探索者", description: "尝试3种不同主题", isUnlocked: false),
        AchievementItem(id: "pomodoro", name: "番茄钟达人", description: "使用番茄钟完成一次计时", isUnlocked: false),
        AchievementItem(id: "pomopro", name: "番茄钟专家", description: "番茄钟完成4轮以上", isUnlocked: false)
    ]
    @Published var autumnLeaves = 0                       // 红叶收集数量（秋主题专属）

    // MARK: 后台计时支持
    private var timerEndDate: Date?                        // 计时结束时间点
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: 私有属性
    private var timerCancellable: AnyCancellable?          // 计时器订阅
    private var player: AVPlayer?                          // AVPlayer 音频播放器（复用）
    private var playerObserver: Any?                       // 播放器观察者
    private var autoSwitchTimer: Timer?                    // 自动切台定时器

    // MARK: 认证模式枚举
    enum AuthMode {
        case login    // 登录模式
        case register // 注册模式
    }

    // MARK: 计算属性

    /// 当前选中的电台
    var currentStation: RadioStation {
        RadioStation.allStations[currentStationIndex]
    }

    /// 当前计时进度（0.0 ~ 1.0）
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    /// 当前动画帧文案（根据计时进度循环切换）
    var currentFrame: String {
        guard isRunning else { return "" }
        let theme = timerMode == .pomodoro ? pomoTheme : currentTheme
        let idx = frameIndex % theme.frames.count
        return theme.frames[idx]
    }

    /// 当前状态文案（根据计时进度循环切换）
    var currentStatus: String {
        guard isRunning else { return timerMode == .pomodoro ? "设置好专注和休息时间，点击开始" : "准备开始..." }
        let theme = timerMode == .pomodoro ? pomoTheme : currentTheme
        let idx = frameIndex % theme.statuses.count
        return theme.statuses[idx]
    }

    /// 番茄钟专用主题（专注/休息阶段不同配色）
    var pomoTheme: AppTheme {
        switch pomoPhase {
        case .work:
            return AppTheme(
                id: "pomowork", name: "番茄钟·专注", group: .daily, iconName: "pomowork",
                primaryColor: Color(hex: "#7c2d12"), bgColor: Color(hex: "#fff8f0"),
                borderColor: Color(hex: "#ffd8a8"), accentColor: Color(hex: "#d35400"),
                progressColor: Color(hex: "#ff8c00"),
                frames: ["专注开始...","进入心流","保持专注...","深度工作中","思绪泉涌...","全神贯注","保持节奏...","即将完成"],
                statuses: ["专注中，保持心流...","深度工作，勿扰模式...","思绪如泉涌...","全神贯注...","渐入佳境...","心流状态...","保持节奏...","即将完成本轮..."],
                doneMessage: "本轮专注完成！休息一下吧~"
            )
        case .rest:
            return AppTheme(
                id: "pomobreak", name: "番茄钟·休息", group: .daily, iconName: "pomobreak",
                primaryColor: Color(hex: "#14532d"), bgColor: Color(hex: "#f0fdf4"),
                borderColor: Color(hex: "#bbf7d0"), accentColor: Color(hex: "#15803d"),
                progressColor: .green,
                frames: ["休息开始...","泡杯热茶","深呼吸...","放松身心","眺望远方...","缓解疲劳","调整呼吸...","准备再战"],
                statuses: ["休息一下，泡杯茶...","深呼吸，放松身心...","眺望远方，缓解眼疲劳...","伸展一下，活动筋骨...","闭目养神片刻...","听听音乐，放松心情...","调整呼吸，准备下一轮...","休息即将结束..."],
                doneMessage: "休息结束！准备下一轮专注~"
            )
        }
    }

    // MARK: - 初始化
    init() {
        // 初始化 AVPlayer（复用，避免内存泄漏）
        let item = AVPlayerItem(url: URL(string: RadioStation.allStations[0].url)!)
        player = AVPlayer(playerItem: item)
        player?.volume = Float(volume)

        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // 监听播放失败
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFail),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )

        // 请求通知权限
        requestNotificationPermission()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timerCancellable?.cancel()
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }

    // MARK: - 通知权限
    /// 请求本地通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error)")
            }
        }
    }

    /// 发送计时完成通知
    private func sendTimerNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "shixi-timer-\(UUID().uuidString)",
            content: content,
            trigger: nil // 立即发送
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error)")
            }
        }
    }

    // MARK: - 计时器控制

    /// 切换播放/暂停/继续状态
    func togglePlayPause() {
        if !isRunning {
            startTimer()
        } else if isPaused {
            resumeTimer()
        } else {
            pauseTimer()
        }
    }

    /// 开始计时（普通模式或番茄钟模式）
    func startTimer() {
        if timerMode == .pomodoro {
            resetPomodoro()
            startPomodoroPhase()
            return
        }

        // 普通模式：解析用户输入的时间
        let seconds = parseTimeInput(timeInput) ?? 300
        totalSeconds = seconds
        remainingSeconds = seconds
        frameIndex = 0
        isRunning = true
        isPaused = false
        showDoneMessage = false
        usedThemeIDs.insert(currentTheme.id)
        saveUsedThemes()

        // 记录结束时间点，支持后台计时
        timerEndDate = Date().addingTimeInterval(TimeInterval(seconds))

        // 注册后台任务
        registerBackgroundTask()

        startTicking()
        playMusic()
    }

    /// 开始番茄钟的某一阶段（专注或休息）
    func startPomodoroPhase() {
        if pomoPhase == .work {
            totalSeconds = pomoWorkMinutes * 60
        } else {
            totalSeconds = pomoBreakMinutes * 60
        }
        remainingSeconds = totalSeconds
        frameIndex = 0
        isRunning = true
        isPaused = false
        showDoneMessage = false

        // 记录结束时间点
        timerEndDate = Date().addingTimeInterval(TimeInterval(totalSeconds))

        // 注册后台任务
        registerBackgroundTask()

        startTicking()
        playMusic()
    }

    /// 暂停计时
    func pauseTimer() {
        isPaused = true
        timerCancellable?.cancel()
        timerEndDate = nil
        pauseMusic()
        endBackgroundTask()
    }

    /// 恢复计时
    func resumeTimer() {
        isPaused = false
        // 重新计算结束时间
        if remainingSeconds > 0 {
            timerEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            registerBackgroundTask()
        }
        startTicking()
        playMusic()
    }

    /// 停止计时并重置状态
    func stopTimer() {
        timerCancellable?.cancel()
        isRunning = false
        isPaused = false
        showDoneMessage = false
        timerEndDate = nil
        pauseMusic()
        endBackgroundTask()
    }

    /// 重置番茄钟到初始状态
    func resetPomodoro() {
        currentCycle = 0
        pomoPhase = .work
    }

    /// 注册后台任务，确保计时器在后台继续运行
    private func registerBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ShixiTimer") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    /// 结束后台任务
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    /// 启动每秒定时器
    private func startTicking() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    /// 每秒 tick：减少剩余时间，切换动画帧
    private func tick() {
        // 使用 Date 差值计算，支持后台存活
        if let endDate = timerEndDate {
            let remaining = Int(endDate.timeIntervalSinceNow)
            if remaining != remainingSeconds && remaining >= 0 {
                remainingSeconds = remaining
                frameIndex += 1
            } else if remaining <= 0 {
                remainingSeconds = 0
                completePhase()
                return
            }
        } else {
            remainingSeconds -= 1
            frameIndex += 1
        }

        if remainingSeconds <= 0 {
            completePhase()
        }
    }

    /// 当前阶段完成处理
    private func completePhase() {
        timerCancellable?.cancel()
        endBackgroundTask()

        if timerMode == .pomodoro {
            // 番茄钟：专注→休息→专注 循环
            if pomoPhase == .work {
                currentCycle += 1
                checkAchievements()

                // 发送专注完成通知
                sendTimerNotification(
                    title: "专注完成！",
                    body: "第 \(currentCycle)/\(pomoCycles) 轮专注结束，休息一下吧~"
                )

                if currentCycle >= pomoCycles {
                    doneMessage = "恭喜！全部 \(pomoCycles) 轮番茄钟已完成！"
                    showDoneMessage = true
                    isRunning = false
                    pauseMusic()

                    // 发送全部完成通知
                    sendTimerNotification(
                        title: "🎉 番茄钟全部完成！",
                        body: "恭喜完成全部 \(pomoCycles) 轮番茄钟！"
                    )
                    return
                }
                pomoPhase = .rest
            } else {
                pomoPhase = .work

                // 发送休息完成通知
                sendTimerNotification(
                    title: "休息结束",
                    body: "准备开始第 \(currentCycle + 1) 轮专注~"
                )
            }
            // 2秒后自动开始下一阶段
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.startPomodoroPhase()
            }
        } else {
            // 普通模式：显示完成信息
            isRunning = false
            doneMessage = currentTheme.doneMessage
            showDoneMessage = true
            pauseMusic()
            checkAchievements()

            // 发送计时完成通知
            sendTimerNotification(
                title: "⏰ 计时完成！",
                body: currentTheme.doneMessage
            )

            // 秋主题计时超过25分钟收集一片红叶
            if currentTheme.id == "autumn" && totalSeconds >= 1500 {
                autumnLeaves += 1
            }
        }
    }

    // MARK: - 音乐控制

    /// 开始播放当前电台（复用 player，避免内存泄漏）
    func playMusic() {
        guard let player = player else { return }

        let stationURL = URL(string: currentStation.url)
        guard let url = stationURL else {
            musicStatus = "电台地址无效"
            return
        }

        // 复用同一个 player，只替换 currentItem
        let newItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: newItem)
        player.volume = Float(volume)
        player.play()
        isMusicPlaying = true
        musicStatus = "正在播放: \(currentStation.name)"
    }

    /// 暂停音乐
    func pauseMusic() {
        player?.pause()
        isMusicPlaying = false
        musicStatus = "已暂停"
    }

    /// 切换音乐播放状态
    func toggleMusic() {
        if isMusicPlaying {
            pauseMusic()
        } else {
            playMusic()
        }
    }

    /// 切换到下一电台
    func nextStation() {
        currentStationIndex = (currentStationIndex + 1) % RadioStation.allStations.count
        if isMusicPlaying {
            playMusic() // 复用 player 切换
        } else {
            // 预加载但不播放
            let url = URL(string: currentStation.url)
            if let url = url {
                let newItem = AVPlayerItem(url: url)
                player?.replaceCurrentItem(with: newItem)
            }
        }
    }

    /// 切换到上一电台
    func prevStation() {
        currentStationIndex = (currentStationIndex - 1 + RadioStation.allStations.count) % RadioStation.allStations.count
        if isMusicPlaying {
            playMusic() // 复用 player 切换
        } else {
            let url = URL(string: currentStation.url)
            if let url = url {
                let newItem = AVPlayerItem(url: url)
                player?.replaceCurrentItem(with: newItem)
            }
        }
    }

    /// 设置音量
    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }

    /// 播放结束回调（自动切台）
    @objc private func playerDidFinishPlaying() {
        if autoSwitch {
            nextStation()
        }
    }

    /// 播放失败回调
    @objc private func playerDidFail() {
        musicStatus = "播放失败，请切换电台"
        isMusicPlaying = false
    }

    // MARK: - 用户认证

    /// 注册新用户，用户名不可重复
    func register(username: String, email: String, password: String, avatarData: Data?) -> Bool {
        var users = loadUsers()
        guard !users.contains(where: { $0.username == username }) else { return false }
        let user = AppUser(username: username, email: email, avatarData: avatarData, password: password)
        users.append(user)
        saveUsers(users)
        currentUser = user
        return true
    }

    /// 用户登录验证
    func login(username: String, password: String) -> Bool {
        let users = loadUsers()
        guard let user = users.first(where: { $0.username == username && $0.password == password }) else { return false }
        currentUser = user
        return true
    }

    /// 退出登录
    func logout() {
        currentUser = nil
    }

    /// 从 UserDefaults 读取用户列表
    private func loadUsers() -> [AppUser] {
        guard let data = UserDefaults.standard.data(forKey: "shixi_users") else { return [] }
        return (try? JSONDecoder().decode([AppUser].self, from: data)) ?? []
    }

    /// 保存用户列表到 UserDefaults
    private func saveUsers(_ users: [AppUser]) {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: "shixi_users")
        }
    }

    /// 更新当前用户头像
    func updateAvatar(_ data: Data) {
        guard var user = currentUser else { return }
        user.avatarData = data
        currentUser = user
        var users = loadUsers()
        if let idx = users.firstIndex(where: { $0.username == user.username }) {
            users[idx] = user
            saveUsers(users)
        }
    }

    // MARK: - 成就系统

    /// 检查并更新成就解锁状态
    func checkAchievements() {
        if !achievements[0].isUnlocked { achievements[0].isUnlocked = true }  // 初次计时
        if totalSeconds >= 300 { achievements[1].isUnlocked = true }          // 5分钟
        if totalSeconds >= 600 { achievements[2].isUnlocked = true }          // 10分钟
        if totalSeconds >= 3600 { achievements[3].isUnlocked = true }         // 1小时
        achievements[4].isUnlocked = true                                      // 自定义
        if usedThemeIDs.count >= 3 { achievements[5].isUnlocked = true }      // 3种主题
        if timerMode == .pomodoro { achievements[6].isUnlocked = true }       // 番茄钟
        if currentCycle >= 4 { achievements[7].isUnlocked = true }            // 4轮番茄钟
        saveAchievements()
    }

    /// 保存已使用主题到本地
    private func saveUsedThemes() {
        UserDefaults.standard.set(Array(usedThemeIDs), forKey: "used_themes")
    }

    // MARK: - 时间输入解析

    /// 支持 "5min", "10m", "30s", "1h" 等格式，返回秒数
    func parseTimeInput(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 正则匹配：数字 + 可选的单位后缀
        let pattern = "^([0-9]+)([a-zA-Z]*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) else {
            return nil
        }

        let nsString = trimmed as NSString
        let numberStr = nsString.substring(with: match.range(at: 1))
        let unitStr = nsString.substring(with: match.range(at: 2)).lowercased()

        guard let number = Int(numberStr), number > 0 else { return nil }

        switch unitStr {
        case "", "min", "m":      // 分钟（默认）
            return number * 60
        case "s", "sec", "secs":  // 秒
            return number
        case "h", "hr", "hrs":    // 小时
            return number * 3600
        default:
            return nil
        }
    }

    // MARK: - 成就系统

    /// 保存成就数据到本地
    private func saveAchievements() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: "achievements")
        }
    }

    /// 从本地加载保存的数据（主题使用记录、成就）
    func loadSavedData() {
        if let saved = UserDefaults.standard.stringArray(forKey: "used_themes") {
            usedThemeIDs = Set(saved)
        }
        if let data = UserDefaults.standard.data(forKey: "achievements") {
            achievements = (try? JSONDecoder().decode([AchievementItem].self, from: data)) ?? achievements
        }
    }
}
