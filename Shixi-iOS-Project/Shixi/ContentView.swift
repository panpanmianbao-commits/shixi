import SwiftUI
import PhotosUI

// MARK: - 主界面视图
/// 应用的主界面，包含计时器、主题选择、音乐播放、成就展示等功能
struct ContentView: View {
    @EnvironmentObject var vm: ShixiViewModel  // 全局视图模型，管理所有业务逻辑

    // MARK: 状态变量
    @State private var showThemePicker = true    // 控制主题选择面板的展开/收起
    @State private var showAchievements = false  // 控制成就墙的展开/收起
    @State private var showAvatarPicker = false   // 控制头像选择器显示
    @State private var selectedAvatarItem: PhotosPickerItem? // 头像选择项

    // MARK: 主布局
    var body: some View {
        NavigationStack {
            ZStack {
                // 全局背景色
                Color(hex: "#f5f5f5").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerView          // 顶部标题栏 + 用户菜单
                        modeSwitchView      // 普通计时 / 番茄钟模式切换

                        // 根据当前模式显示不同的输入区域
                        if vm.timerMode == .normal {
                            normalInputView
                        } else {
                            pomodoroSettingsView
                        }

                        countdownDisplay    // 倒计时展示卡片（含主题动画）
                        controlButtons      // 开始/暂停/停止控制按钮
                        musicPanel          // 音乐播放控制面板
                        collapsibleThemeSelector  // 可折叠的主题选择器
                        collapsibleAchievements   // 可折叠的成就墙
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $vm.isShowingAuth) {
            // 登录/注册弹窗
            AuthSheetView()
                .environmentObject(vm)
        }
        .photosPicker(isPresented: $showAvatarPicker, selection: $selectedAvatarItem, matching: .images)
        .onChange(of: selectedAvatarItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    vm.updateAvatar(data)
                }
            }
        }
        .onAppear {
            // 页面加载时读取本地保存的数据
            vm.loadSavedData()
        }
    }

    // MARK: 顶部标题栏
    /// 显示应用名称"时隙"，右侧为用户头像菜单
    var headerView: some View {
        HStack {
            Text("时隙")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .tracking(4)

            Spacer()

            // 用户菜单：已登录显示用户信息，未登录显示登录/注册选项
            Menu {
                if let user = vm.currentUser {
                    Text(user.username)
                        .font(.headline)
                    if !user.email.isEmpty {
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Divider()
                    Button("更换头像") {
                        showAvatarPicker = true
                    }
                    Button("退出登录", role: .destructive) {
                        vm.logout()
                    }
                } else {
                    Button("登录账号") {
                        vm.authMode = .login
                        vm.isShowingAuth = true
                    }
                    Button("注册账号") {
                        vm.authMode = .register
                        vm.isShowingAuth = true
                    }
                }
            } label: {
                AvatarView(user: vm.currentUser)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: 模式切换
    /// 普通倒计时 / 番茄钟 两种模式的切换按钮
    var modeSwitchView: some View {
        HStack(spacing: 8) {
            ForEach(Array(TimerMode.allCases.enumerated()), id: \.offset) { index, mode in
                Button {
                    withAnimation(.spring()) {
                        vm.timerMode = mode
                        vm.stopTimer()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .normal ? "clock" : "timer")
                            .font(.system(size: 14))
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: vm.timerMode == mode ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(vm.timerMode == mode ? Color(hex: "#1a1a1a") : Color.white)
                    .foregroundColor(vm.timerMode == mode ? .white : Color(hex: "#666666"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 普通模式输入区
    /// 时间输入框 + 快捷预设按钮（5分/10分/25分）
    var normalInputView: some View {
        HStack(spacing: 8) {
            TextField("输入时间: 5min / 10min / 30s", text: $vm.timeInput)
                .font(.system(size: 15, design: .serif))
                .padding(10)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
                )
                .cornerRadius(10)

            HStack(spacing: 6) {
                ForEach(Array(["5分", "10分", "25分"].enumerated()), id: \.offset) { index, preset in
                    Button {
                        vm.timeInput = preset.replacingOccurrences(of: "分", with: "min")
                    } label: {
                        Text(preset)
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(Color(hex: "#666666"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 番茄钟设置区
    /// 专注时长、休息时长、循环次数的设置 + 快捷预设
    var pomodoroSettingsView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                PomoField(title: "专注时长", value: $vm.pomoWorkMinutes, unit: "分钟")
                PomoField(title: "休息时长", value: $vm.pomoBreakMinutes, unit: "分钟")
                PomoField(title: "循环次数", value: $vm.pomoCycles, unit: "轮")
            }

            HStack(spacing: 6) {
                PomoPresetButton(title: "经典 25+5×4", action: {
                    vm.pomoWorkMinutes = 25; vm.pomoBreakMinutes = 5; vm.pomoCycles = 4
                })
                PomoPresetButton(title: "深度 50+10×2", action: {
                    vm.pomoWorkMinutes = 50; vm.pomoBreakMinutes = 10; vm.pomoCycles = 2
                })
                PomoPresetButton(title: "轻量 15+3×6", action: {
                    vm.pomoWorkMinutes = 15; vm.pomoBreakMinutes = 3; vm.pomoCycles = 6
                })
            }
        }
    }

    // MARK: 倒计时展示卡片
    /// 核心展示区域：主题名称、动画数字、进度条、状态文案、完成庆祝动画
    var countdownDisplay: some View {
        let theme = vm.timerMode == .pomodoro && vm.isRunning ? vm.pomoTheme : vm.currentTheme

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.borderColor, lineWidth: 1.5)
                )

            VStack(spacing: 10) {
                // 番茄钟模式下显示当前阶段和循环指示器
                if vm.timerMode == .pomodoro && vm.isRunning {
                    HStack(spacing: 8) {
                        Text(vm.pomoPhase.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(vm.pomoPhase == .work ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundColor(vm.pomoPhase == .work ? .orange : .green)
                            .cornerRadius(6)

                        // 循环进度小圆点
                        HStack(spacing: 4) {
                            ForEach(0..<vm.pomoCycles) { i in
                                Circle()
                                    .fill(i < vm.currentCycle ? Color.green : (i == vm.currentCycle && vm.isRunning ? Color(hex: "#1a1a1a") : Color(hex: "#e5e5e5")))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Spacer()

                        Text("第 \(min(vm.currentCycle + 1, vm.pomoCycles)) / \(vm.pomoCycles) 轮")
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .padding(.horizontal, 12)
                }

                Text(vm.isRunning ? theme.name : "选择主题开始计时")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryColor.opacity(0.7))

                // 动画数字时钟
                HStack(spacing: 2) {
                    let timeStr = formatTime(vm.remainingSeconds)
                    ForEach(Array(timeStr.enumerated()), id: \.offset) { index, char in
                        if char == ":" {
                            Text(":")
                                .font(.system(size: 48, weight: .medium, design: .serif))
                                .foregroundColor(theme.primaryColor)
                        } else {
                            AnimatedDigit(
                                digit: String(char),
                                color: theme.primaryColor,
                                shouldAnimate: vm.isRunning
                            )
                        }
                    }
                }

                // 主题动画帧和状态文案
                if !vm.showDoneMessage {
                    HStack(spacing: 6) {
                        Text(theme.emoji)
                        Text(vm.currentFrame)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.accentColor)
                    }
                    .frame(minHeight: 24)

                    Text(vm.currentStatus)
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(theme.primaryColor.opacity(0.6))
                        .frame(minHeight: 20)
                }

                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#f5f5f5"))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(vm.timerMode == .pomodoro ? (vm.pomoPhase == .work ? Color.orange : Color.green) : theme.progressColor)
                            .frame(width: geo.size.width * CGFloat(vm.progress), height: 8)
                            .animation(.linear(duration: 1), value: vm.progress)
                    }
                }
                .frame(height: 8)

                Text("\(vm.progress * 100, specifier: "%.1f")%")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(Color(hex: "#bbbbbb"))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // 完成时的庆祝效果
                if vm.showDoneMessage {
                    CelebrationEffect()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text(vm.doneMessage)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(theme.primaryColor)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
        }
        .frame(minHeight: 180)
    }

    // MARK: 控制按钮
    /// 开始/暂停/继续 和 停止 两个主按钮
    var controlButtons: some View {
        HStack(spacing: 8) {
            Button {
                vm.togglePlayPause()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.isRunning && !vm.isPaused ? "pause.fill" : "play.fill")
                    Text(vm.isRunning && !vm.isPaused ? "暂停" : (vm.isPaused ? "继续" : "开始"))
                }
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(vm.isRunning && !vm.isPaused ? Color(hex: "#f5f5f5") : Color(hex: "#1a1a1a"))
                .foregroundColor(vm.isRunning && !vm.isPaused ? Color(hex: "#1a1a1a") : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(vm.isRunning && !vm.isPaused ? Color(hex: "#e5e5e5") : Color.clear, lineWidth: 1.5)
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .pressEffect()

            Button {
                vm.stopTimer()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                    Text("停止")
                }
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "#f5f5f5"))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .pressEffect()
            .disabled(!vm.isRunning)
            .opacity(vm.isRunning ? 1 : 0.4)
        }
    }

    // MARK: 音乐面板
    /// 电台播放控制：播放/暂停、切台、自动轮播开关、音量调节
    var musicPanel: some View {
        VStack(spacing: 0) {
            // 当前电台信息和播放按钮
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#f5f5f5"))
                        .frame(width: 36, height: 36)

                    if vm.isMusicPlaying {
                        Image(systemName: "waveform")
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(Color(hex: "#888888"))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.currentStation.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(vm.musicStatus)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#bbbbbb"))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    vm.toggleMusic()
                } label: {
                    Image(systemName: vm.isMusicPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(vm.isMusicPlaying ? .white : Color(hex: "#666666"))
                        .frame(width: 36, height: 36)
                        .background(vm.isMusicPlaying ? Color(hex: "#1a1a1a") : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()
                .padding(.horizontal, 12)

            // 切台控制和自动轮播
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Button { vm.prevStation() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Text("\(vm.currentStationIndex + 1) / \(RadioStation.allStations.count)")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(Color(hex: "#888888"))
                        .frame(minWidth: 40)

                    Button { vm.nextStation() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        vm.autoSwitch.toggle()
                    } label: {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(vm.autoSwitch ? .green : Color(hex: "#bbbbbb"))
                            .frame(width: 28, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Text("自动轮播: \(vm.autoSwitch ? "开" : "关")")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#888888"))
                }
            }
            .padding(12)

            Divider()
                .padding(.horizontal, 12)

            // 音量滑块
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#bbbbbb"))

                Slider(value: Binding(
                    get: { vm.volume },
                    set: { vm.setVolume($0) }
                ), in: 0...1)

                Text("\(Int(vm.volume * 100))%")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(Color(hex: "#bbbbbb"))
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(12)
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(vm.isMusicPlaying ? Color(hex: "#1a1a1a") : Color(hex: "#e5e5e5"), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    // MARK: 可折叠主题选择器
    /// 按分组（Life / 季節感）展示所有可用主题
    var collapsibleThemeSelector: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showThemePicker.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 16))
                    Text("选择主题")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .rotationEffect(.degrees(showThemePicker ? 180 : 0))
                        .animation(.spring(), value: showThemePicker)
                }
                .foregroundColor(Color(hex: "#1a1a1a"))
                .padding(12)
            }
            .buttonStyle(.plain)

            if showThemePicker {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(ThemeGroup.allCases.enumerated()), id: \.offset) { index, group in
                        Text(group.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#bbbbbb"))
                            .tracking(1.5)
                            .padding(.leading, 4)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(AppTheme.allThemes.filter { $0.group == group }) { theme in
                                Button {
                                    withAnimation(.spring()) {
                                        vm.currentTheme = theme
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(theme.emoji)
                                        Text(theme.name)
                                            .font(.system(size: 14))
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(vm.currentTheme.id == theme.id ? Color.white : Color.clear)
                                    .foregroundColor(vm.currentTheme.id == theme.id ? Color(hex: "#1a1a1a") : Color(hex: "#666666"))
                                    .fontWeight(vm.currentTheme.id == theme.id ? .semibold : .regular)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(vm.currentTheme.id == theme.id ? Color(hex: "#1a1a1a") : Color(hex: "#e5e5e5"), lineWidth: 1.5)
                                    )
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                .disabled(vm.isRunning)  // 计时中不可切换主题
                                .scaleEffect(vm.currentTheme.id == theme.id ? 1.02 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.currentTheme.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    // MARK: 可折叠成就墙
    /// 展示用户解锁的成就列表和红叶收集进度
    var collapsibleAchievements: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showAchievements.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 16))
                    Text("成就墙")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()

                    let unlocked = vm.achievements.filter { $0.isUnlocked }.count
                    Text("\(unlocked)/\(vm.achievements.count)")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(unlocked > 0 ? .green : Color(hex: "#bbbbbb"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(unlocked > 0 ? Color.green.opacity(0.1) : Color(hex: "#f5f5f5"))
                        .cornerRadius(10)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .rotationEffect(.degrees(showAchievements ? 180 : 0))
                        .animation(.spring(), value: showAchievements)
                }
                .foregroundColor(Color(hex: "#1a1a1a"))
                .padding(12)
            }
            .buttonStyle(.plain)

            if showAchievements {
                VStack(spacing: 8) {
                    // 成就列表
                    ForEach(vm.achievements) { ach in
                        HStack(spacing: 10) {
                            Image(systemName: ach.isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                                .foregroundColor(ach.isUnlocked ? .green : Color(hex: "#bbbbbb"))
                            Text(ach.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(ach.description)
                                .font(.system(size: 12))
                                .italic()
                                .foregroundColor(Color(hex: "#bbbbbb"))
                            Text(ach.isUnlocked ? "已解锁" : "未解锁")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(ach.isUnlocked ? .green : Color(hex: "#bbbbbb"))
                        }
                        .padding(8)
                        .background(ach.isUnlocked ? Color.green.opacity(0.08) : Color(hex: "#f5f5f5"))
                        .cornerRadius(8)
                    }

                    // 红叶收集进度
                    VStack(spacing: 4) {
                        Text("\(vm.autumnLeaves)")
                            .font(.system(size: 24, weight: .medium, design: .serif))
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("红叶收藏 / 30片可「押し叶」")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#888888"))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#e5e5e5"))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange)
                                    .frame(width: geo.size.width * min(CGFloat(vm.autumnLeaves) / 30, 1), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.06))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    // MARK: 时间格式化
    /// 将秒数格式化为 HH:MM:SS 或 MM:SS 字符串
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 用户头像视图
/// 显示用户头像：优先显示上传的图片，否则显示用户名首字母或默认图标
struct AvatarView: View {
    let user: AppUser?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#f8f8f8"))
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color(hex: "#f0f0f0"), lineWidth: 2.5))

            if let user = user {
                if let data = user.avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text(String(user.username.prefix(1)))
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#1a1a1a"))
                        .clipShape(Circle())
                }
            } else {
                Image(systemName: "person")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#cccccc"))
            }
        }
    }
}

// MARK: - 动画数字组件
/// 单个数字的翻页动画效果：旧数字模糊淡出上移，新数字清晰淡入下移
struct AnimatedDigit: View {
    let digit: String
    let color: Color
    let shouldAnimate: Bool

    @State private var progress: Double = 0
    @State private var oldDigit: String = ""
    @State private var newDigit: String = ""
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            // 旧数字：模糊淡出 + 轻微缩小 + 上移
            Text(oldDigit)
                .font(.system(size: 48, weight: .medium, design: .serif))
                .foregroundColor(color)
                .opacity(1 - progress)
                .blur(radius: progress * 6)
                .offset(y: -progress * 4)
                .scaleEffect(1 - progress * 0.08)

            // 新数字：从模糊清晰 + 轻微放大 + 下移归位
            Text(newDigit)
                .font(.system(size: 48, weight: .medium, design: .serif))
                .foregroundColor(color)
                .opacity(progress)
                .blur(radius: (1 - progress) * 6)
                .offset(y: (1 - progress) * 4)
                .scaleEffect(0.92 + progress * 0.08)
        }
        .frame(width: 26, height: 56)
        .clipped()
        .onAppear {
            oldDigit = digit
            newDigit = digit
        }
        .onChange(of: digit) { newValue in
            guard shouldAnimate, newDigit != newValue, !isAnimating else {
                if !isAnimating {
                    oldDigit = newValue
                    newDigit = newValue
                    progress = 0
                }
                return
            }
            oldDigit = newDigit
            newDigit = newValue
            isAnimating = true
            progress = 0
            withAnimation(.easeInOut(duration: 0.45)) {
                progress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                oldDigit = newValue
                progress = 0
                isAnimating = false
            }
        }
    }
}

// MARK: - 番茄钟输入字段
/// 单个数值输入框，用于设置番茄钟的专注时长、休息时长、循环次数
struct PomoField: View {
    let title: String
    @Binding var value: Int
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#bbbbbb"))

            HStack(spacing: 0) {
                TextField("", value: $value, format: .number)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(height: 36)

                Text(unit)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#bbbbbb"))
                    .padding(.trailing, 8)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - 番茄钟预设按钮
/// 快捷设置番茄钟参数的按钮
struct PomoPresetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(Color(hex: "#666666"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#e5e5e5"), lineWidth: 1.5)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 庆祝动画效果
/// 倒计时完成时的粒子爆炸庆祝动画
struct CelebrationEffect: View {
    @State private var particles: [CelebrationParticle] = []

    /// 单个粒子数据模型
    struct CelebrationParticle: Identifiable {
        let id = UUID()
        let emoji: String
        let x: CGFloat
        let y: CGFloat
        let color: Color
        let size: CGFloat
        let angle: Double
        let distance: CGFloat
        let duration: Double
        let delay: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    CelebrationParticleView(particle: p, center: CGPoint(x: geo.size.width/2, y: geo.size.height/2))
                }
            }
            .onAppear {
                spawnParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    /// 生成20个随机方向的庆祝粒子
    func spawnParticles(in size: CGSize) {
        let emojis = ["✦", "✧", "✩", "✪", "✫", "✬", "✭", "✮", "✯"]
        let colors: [Color] = [.yellow, .orange, .pink, .cyan, .green, .purple, .red, .blue]

        for i in 0..<20 {
            let angle = Double(i) * (360.0 / 20.0) * .pi / 180.0
            let p = CelebrationParticle(
                emoji: emojis.randomElement()!,
                x: size.width / 2,
                y: size.height / 2,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 10...20),
                angle: angle,
                distance: CGFloat.random(in: 50...140),
                duration: Double.random(in: 0.8...1.8),
                delay: Double.random(in: 0...0.2)
            )
            particles.append(p)

            DispatchQueue.main.asyncAfter(deadline: .now() + p.duration + p.delay + 0.2) {
                particles.removeAll { $0.id == p.id }
            }
        }
    }
}

// MARK: - 单个庆祝粒子视图
/// 控制单个粒子的飞散、旋转、淡入淡出动画
struct CelebrationParticleView: View {
    let particle: CelebrationEffect.CelebrationParticle
    let center: CGPoint
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.3
    @State private var rotation: Double = 0

    var body: some View {
        Text(particle.emoji)
            .font(.system(size: particle.size))
            .foregroundColor(particle.color)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .scaleEffect(scale)
            .position(x: x, y: y)
            .onAppear {
                x = center.x
                y = center.y

                DispatchQueue.main.asyncAfter(deadline: .now() + particle.delay) {
                    let targetX = center.x + CGFloat(cos(particle.angle)) * particle.distance
                    let targetY = center.y + CGFloat(sin(particle.angle)) * particle.distance

                    withAnimation(.easeOut(duration: 0.3)) {
                        opacity = 1
                        scale = 1.1
                    }

                    withAnimation(.easeOut(duration: particle.duration)) {
                        x = targetX
                        y = targetY
                        rotation = Double.random(in: -180...180)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + particle.duration * 0.5) {
                        withAnimation(.easeIn(duration: particle.duration * 0.5)) {
                            opacity = 0
                            scale = 0.3
                        }
                    }
                }
            }
    }
}

// MARK: - 登录/注册弹窗
/// 用户登录和注册的底部弹窗，支持头像上传
struct AuthSheetView: View {
    @EnvironmentObject var vm: ShixiViewModel
    @Environment(\.dismiss) var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var password2 = ""
    @State private var error = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 登录/注册模式切换
                Picker("", selection: $vm.authMode) {
                    Text("登录").tag(ShixiViewModel.AuthMode.login)
                    Text("注册").tag(ShixiViewModel.AuthMode.register)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 注册模式下显示头像选择器
                if vm.authMode == .register {
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let data = avatarData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(hex: "#f5f5f5"))
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Image(systemName: "person")
                                            .foregroundColor(Color(hex: "#bbbbbb"))
                                    )
                                    .overlay(Circle().stroke(Color(hex: "#e5e5e5"), lineWidth: 2))
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    avatarData = data
                                }
                            }
                        }

                        Text("点击上传头像")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }

                // 输入表单
                Group {
                    TextField("用户名", text: $username)
                    if vm.authMode == .register {
                        TextField("邮箱（可选）", text: $email)
                            .keyboardType(.emailAddress)
                    }
                    SecureField("密码", text: $password)
                    if vm.authMode == .register {
                        SecureField("确认密码", text: $password2)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

                // 错误提示
                if !error.isEmpty {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                // 提交按钮
                Button {
                    if vm.authMode == .login {
                        if vm.login(username: username, password: password) {
                            dismiss()
                        } else {
                            error = "用户名或密码错误"
                        }
                    } else {
                        guard username.count >= 2 else { error = "用户名需2-16个字符"; return }
                        guard password.count >= 6 else { error = "密码至少6位"; return }
                        guard password == password2 else { error = "两次密码不一致"; return }

                        if vm.register(username: username, email: email, password: password, avatarData: avatarData) {
                            dismiss()
                        } else {
                            error = "用户名已被注册"
                        }
                    }
                } label: {
                    Text(vm.authMode == .login ? "登录" : "注册")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#1a1a1a"))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(vm.authMode == .login ? "欢迎回来" : "创建账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 按压效果修饰器
/// 为按钮添加按压时的缩放和透明度反馈
struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: TimeInterval.infinity, maximumDistance: CGFloat.infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

extension View {
    /// 应用按压效果修饰器
    func pressEffect() -> some View {
        modifier(PressEffectModifier())
    }
}
