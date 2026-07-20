import SwiftUI
import AVFoundation
import Combine

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

    // MARK: 私有属性
    private var timerCancellable: AnyCancellable?          // 计时器订阅
    private var player: AVPlayer?                          // AVPlayer 音频播放器
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
                id: "pomowork", name: "番茄钟·专注", group: .daily, emoji: "🍅",
                primaryColor: Color(hex: "#7c2d12"), bgColor: Color(hex: "#fff8f0"),
                borderColor: Color(hex: "#ffd8a8"), accentColor: Color(hex: "#d35400"),
                progressColor: Color(hex: "#ff8c00"),
                frames: ["专注开始...","进入心流","保持专注...","深度工作中","思绪泉涌...","全神贯注","保持节奏...","即将完成"],
                statuses: ["专注中，保持心流...","深度工作，勿扰模式...","思绪如泉涌...","全神贯注...","渐入佳境...","心流状态...","保持节奏...","即将完成本轮..."],
                doneMessage: "本轮专注完成！休息一下吧~"
            )
        case .rest:
            return AppTheme(
                id: "pomobreak", name: "番茄钟·休息", group: .daily, emoji: "☕",
                primaryColor: Color(hex: "#14532d"), bgColor: Color(hex: "#f0fdf4"),
                borderColor: Color(hex: "#bbf7d0"), accentColor: Color(hex: "#15803d"),
                progressColor: .green,
                frames: ["休息开始...","泡杯热茶","深呼吸...","放松身心","眺望远方...","缓解疲劳","调整呼吸...","准备再战"],
                statuses: ["休息一下，泡杯茶...","深呼吸，放松身心...","眺望远方，缓解眼疲劳...","伸展一下，活动筋骨...","闭目养神片刻...","听听音乐，放松心情...","调整呼吸，准备下一轮...","休息即将结束..."],
                doneMessage: "休息结束！准备下一轮专注~"
            )
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

        // 普通模式：默认5分钟（TODO: 应解析 timeInput）
        let seconds = 5 * 60
        totalSeconds = seconds
        remainingSeconds = seconds
        frameIndex = 0
        isRunning = true
        isPaused = false
        showDoneMessage = false
        usedThemeIDs.insert(currentTheme.id)
        saveUsedThemes()

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

        startTicking()
        playMusic()
    }

    /// 暂停计时
    func pauseTimer() {
        isPaused = true
        timerCancellable?.cancel()
        pauseMusic()
    }

    /// 恢复计时
    func resumeTimer() {
        isPaused = false
        startTicking()
        playMusic()
    }

    /// 停止计时并重置状态
    func stopTimer() {
        timerCancellable?.cancel()
        isRunning = false
        isPaused = false
        showDoneMessage = false
        pauseMusic()
    }

    /// 重置番茄钟到初始状态
    func resetPomodoro() {
        currentCycle = 0
        pomoPhase = .work
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
        remainingSeconds -= 1
        frameIndex += 1

        if remainingSeconds <= 0 {
            completePhase()
        }
    }

    /// 当前阶段完成处理
    private func completePhase() {
        timerCancellable?.cancel()

        if timerMode == .pomodoro {
            // 番茄钟：专注→休息→专注 循环
            if pomoPhase == .work {
                currentCycle += 1
                checkAchievements()
                if currentCycle >= pomoCycles {
                    doneMessage = "恭喜！全部 \(pomoCycles) 轮番茄钟已完成！"
                    showDoneMessage = true
                    isRunning = false
                    pauseMusic()
                    return
                }
                pomoPhase = .rest
            } else {
                pomoPhase = .work
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
            // 秋主题计时超过25分钟收集一片红叶
            if currentTheme.id == "autumn" && totalSeconds >= 1500 {
                autumnLeaves += 1
            }
        }
    }

    // MARK: - 音乐控制

    /// 开始播放当前电台
    func playMusic() {
        guard player == nil else {
            player?.play()
            isMusicPlaying = true
            musicStatus = "正在播放: \(currentStation.name)"
            return
        }
        let item = AVPlayerItem(url: URL(string: currentStation.url)!)
        player = AVPlayer(playerItem: item)
        player?.volume = Float(volume)
        player?.play()
        isMusicPlaying = true
        musicStatus = "正在播放: \(currentStation.name)"

        // 监听播放结束，自动切台
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            if self?.autoSwitch == true {
                self?.nextStation()
            }
        }
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
        player?.replaceCurrentItem(with: AVPlayerItem(url: URL(string: currentStation.url)!))
        if isMusicPlaying { player?.play() }
    }

    /// 切换到上一电台
    func prevStation() {
        currentStationIndex = (currentStationIndex - 1 + RadioStation.allStations.count) % RadioStation.allStations.count
        player?.replaceCurrentItem(with: AVPlayerItem(url: URL(string: currentStation.url)!))
        if isMusicPlaying { player?.play() }
    }

    /// 设置音量
    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
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
