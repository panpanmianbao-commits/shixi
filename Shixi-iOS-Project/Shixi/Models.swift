import SwiftUI

// MARK: - 计时器模式枚举
/// 应用支持的两种计时模式
enum TimerMode: String, CaseIterable {
    case normal = "倒计时"     // 普通倒计时模式
    case pomodoro = "番茄钟"   // 番茄工作法模式
}

// MARK: - 番茄钟阶段枚举
/// 番茄钟的当前阶段：专注或休息
enum PomodoroPhase: String {
    case work = "专注中"   // 专注工作阶段
    case rest = "休息中"   // 休息放松阶段
}

// MARK: - 主题分组枚举
/// 主题的分类分组
enum ThemeGroup: String, CaseIterable {
    case daily = "Life"      // 日常生活主题
    case season = "季節感"    // 季节感主题（日文风格）
}

// MARK: - 应用主题模型
/// 定义一个计时主题的完整配置：视觉风格、动画帧、状态文案等
struct AppTheme: Identifiable, Hashable {
    let id: String              // 唯一标识
    let name: String            // 主题名称
    let group: ThemeGroup       // 所属分组
    let emoji: String           // 主题表情符号
    let primaryColor: Color     // 主色调
    let bgColor: Color          // 背景色
    let borderColor: Color      // 边框色
    let accentColor: Color      // 强调色
    let progressColor: Color    // 进度条颜色
    let frames: [String]        // 计时过程中的动画帧文案
    let statuses: [String]      // 计时过程中的状态描述文案
    let doneMessage: String     // 计时完成时的祝贺文案
}

// MARK: - 预定义主题
extension AppTheme {
    /// 小蜜蜂采蜜主题 - 日常类
    static let bee = AppTheme(
        id: "bee", name: "小蜜蜂采蜜", group: .daily, emoji: "🐝",
        primaryColor: Color(hex: "#5c4033"), bgColor: Color(hex: "#fffbeb"),
        borderColor: Color(hex: "#f5deb3"), accentColor: Color(hex: "#b8860b"),
        progressColor: .green,
        frames: ["寻找第一朵花...","采集中","飞向下一朵花...","采集中","继续飞行...","采集中","满载返回...","酿造蜂蜜"],
        statuses: ["嗡嗡嗡～飞向第一朵花...","采集花蜜中...","嗡嗡嗡～继续飞行...","采集花蜜中...","嗡嗡嗡～飞向第三朵花...","采集花蜜中...","满载而归～飞向蜂巢...","酿造蜂蜜中..."],
        doneMessage: "采蜜完成！蜂蜜酿造成功！"
    )

    /// 火箭发射主题 - 日常类
    static let rocket = AppTheme(
        id: "rocket", name: "火箭发射", group: .daily, emoji: "🚀",
        primaryColor: Color(hex: "#1e3a5f"), bgColor: Color(hex: "#f0f7ff"),
        borderColor: Color(hex: "#bfdbfe"), accentColor: Color(hex: "#2563eb"),
        progressColor: Color(hex: "#1890ff"),
        frames: ["T-Minus 8...","T-Minus 7...","T-Minus 6...","T-Minus 5...","T-Minus 4...","T-Minus 3...","T-Minus 2...","登陆成功"],
        statuses: ["引擎点火中...","喷射推进...","穿越大气层...","进入太空...","接近月球...","准备着陆...","正在着陆...","插上旗帜!"],
        doneMessage: "登陆成功！插上旗帜！"
    )

    /// 小猫钓鱼主题 - 日常类
    static let fish = AppTheme(
        id: "fish", name: "小猫钓鱼", group: .daily, emoji: "🎣",
        primaryColor: Color(hex: "#0c4a6e"), bgColor: Color(hex: "#f0f9ff"),
        borderColor: Color(hex: "#bae6fd"), accentColor: Color(hex: "#0284c7"),
        progressColor: Color(hex: "#1890ff"),
        frames: ["等待上钩...","水面波动...","有鱼靠近...","鱼竿颤动！","收线中","鱼儿上钩！","大鱼上岸！","收获满满"],
        statuses: ["等待鱼儿上钩...","水面波动...","有鱼靠近！","鱼竿颤动！","收线中...","鱼儿上钩！","大鱼上岸！","今晚加餐！"],
        doneMessage: "钓到大鱼！今晚加餐！"
    )

    /// 大厨烹饪主题 - 日常类
    static let cook = AppTheme(
        id: "cook", name: "大厨烹饪", group: .daily, emoji: "👨‍🍳",
        primaryColor: Color(hex: "#5c1a1a"), bgColor: Color(hex: "#fff5f5"),
        borderColor: Color(hex: "#fecaca"), accentColor: Color(hex: "#c0392b"),
        progressColor: Color(hex: "#ff8c8c"),
        frames: ["满桌盛宴...","开始享用...","品味美食...","大快朵颐...","消灭过半...","接近尾声...","盘中所剩无几...","心满意足"],
        statuses: ["米其林三星盛宴摆满餐桌...","拿起筷子，开始享用...","细细品味每一道料理...","美味在口中化开...","餐桌上的料理渐渐减少...","只剩最后几道菜了...","最后一小口...","心满意足地放下筷子..."],
        doneMessage: "盛宴完美结束！心满意足！"
    )

    /// 樱花进度条主题 - 季节感类
    static let sakura = AppTheme(
        id: "sakura", name: "樱花进度条", group: .season, emoji: "🌸",
        primaryColor: Color(hex: "#7b1e4a"), bgColor: Color(hex: "#fff0f3"),
        borderColor: Color(hex: "#ffd1dc"), accentColor: Color(hex: "#db2777"),
        progressColor: Color(hex: "#ffb6c1"),
        frames: ["花苞微颤...","初绽枝头","花瓣纷飞...","春风拂面...","花吹雪","漫天飞舞...","樱吹满地","春樱烂漫..."],
        statuses: ["春风轻拂，枝头花苞微颤...","第一朵樱花悄然绽放...","花瓣开始随风纷飞...","漫天粉白，春风拂面...","花吹雪，如梦似幻...","樱花瓣漫天飞舞...","满地落樱，铺成粉色地毯...","樱花纷飞中，春梦正酣..."],
        doneMessage: "樱花满开！春日美梦成真！"
    )

    /// 梅雨之窗主题 - 季节感类
    static let rainy = AppTheme(
        id: "rainy", name: "梅雨の窓", group: .season, emoji: "🌧️",
        primaryColor: Color(hex: "#2c3e50"), bgColor: Color(hex: "#f0f4f8"),
        borderColor: Color(hex: "#c5d3e0"), accentColor: Color(hex: "#4a6fa5"),
        progressColor: Color(hex: "#b0c4de"),
        frames: ["雨滴滑落...","远处雷鸣...","雨丝绵绵","窗上水雾...","雨意渐浓...","ぱしゃぱしゃ","梅雨静谧...","雨声入耳"],
        statuses: ["雨痕缓缓滑落窗玻璃...","远处传来隐约雷鸣...","雨丝绵绵，润物无声...","窗上水雾，朦胧如画...","雨意渐浓，心事如烟...","ぱしゃぱしゃ...雨靴踩过水洼...","梅雨时节，静谧悠长...","雨声入耳，万籁俱寂..."],
        doneMessage: "雨过天晴，梅雨渐收..."
    )

    /// 红叶之信主题 - 季节感类
    static let autumn = AppTheme(
        id: "autumn", name: "红叶の便り", group: .season, emoji: "🍁",
        primaryColor: Color(hex: "#7c2d12"), bgColor: Color(hex: "#fff8f0"),
        borderColor: Color(hex: "#ffd8a8"), accentColor: Color(hex: "#d35400"),
        progressColor: Color(hex: "#ff8c00"),
        frames: ["一叶知秋...","秋意渐浓","红叶纷飞...","层林尽染","霜叶红透...","秋风起兮","落叶归根...","秋思满怀"],
        statuses: ["一叶知秋，岁月静美...","秋意渐浓，层林尽染...","红叶纷飞，秋光正好...","秋风起兮，白云飞...","霜叶红于二月花...","秋深似海，思念如潮...","落叶归根，岁月静好...","红叶便り，秋思满怀..."],
        doneMessage: "又一片红叶飘落，珍藏这份秋意..."
    )

    /// 雪落之声主题 - 季节感类
    static let winter = AppTheme(
        id: "winter", name: "雪の積もる音", group: .season, emoji: "❄️",
        primaryColor: Color(hex: "#334155"), bgColor: Color(hex: "#f8fafc"),
        borderColor: Color(hex: "#d1d5db"), accentColor: Color(hex: "#475569"),
        progressColor: Color(hex: "#b0c4de"),
        frames: ["初雪飘落...","雪片纷飞","窗外积雪...","素白世界","雪夜静谧...","こたつ中","雪积无声...","冬夜深沉"],
        statuses: ["初雪飘落，万籁俱寂...","雪片纷飞，如梦如幻...","窗外积雪，渐覆大地...","素白世界，纯净无瑕...","雪夜静谧，暖桌微温...","こたつ中，茶香袅袅...","雪积无声，时光缓缓...","冬夜深沉，静待春归..."],
        doneMessage: "远方寺钟一声... 计时完成..."
    )

    /// 所有可用主题的集合
    static let allThemes: [AppTheme] = [.bee, .rocket, .fish, .cook, .sakura, .rainy, .autumn, .winter]
}

// MARK: - 电台模型
/// 网络电台/音乐流媒体配置
struct RadioStation: Identifiable {
    let id = UUID()
    let name: String    // 电台名称
    let url: String     // 流媒体播放地址（M3U8/MP3）
}

extension RadioStation {
    /// 预置电台列表：经典音乐、古典、民谣、怀旧等
    static let allStations: [RadioStation] = [
        RadioStation(name: "CNR 经典音乐广播", url: "http://ngcdn004.cnr.cn/live/dszs/index.m3u8"),
        RadioStation(name: "上海经典947", url: "http://lhttp.qingting.fm/live/267/64k.mp3"),
        RadioStation(name: "河南古典音乐·天籁", url: "http://stream.hndt.com/live/gudian/playlist.m3u8"),
        RadioStation(name: "河南网络广播·民谣", url: "http://stream3.hndt.com/now/DTK5qc83/playlist.m3u8"),
        RadioStation(name: "河南网络广播·天籁古典", url: "http://stream3.hndt.com/now/MdOpB4zP/playlist.m3u8"),
        RadioStation(name: "Asia FM 亚洲经典台", url: "https://lhttp.qingting.fm/live/5021912/64k.mp3"),
        RadioStation(name: "CRI 怀旧金曲频道", url: "https://lhttp.qingting.fm/live/5022038/64k.mp3"),
        RadioStation(name: "清晨音乐台", url: "http://lhttp.qingting.fm/live/4915/64k.mp3")
    ]
}

// MARK: - 成就模型
/// 用户可解锁的成就项
struct AchievementItem: Identifiable, Codable {
    let id: String
    let name: String           // 成就名称
    let description: String    // 成就描述
    var isUnlocked: Bool       // 是否已解锁
}

// MARK: - 用户模型
/// 应用用户数据模型，支持头像存储
struct AppUser: Codable {
    var username: String
    var email: String
    var avatarData: Data?      // 头像图片的二进制数据
    var password: String
}

// MARK: - Color 扩展
/// 支持从十六进制字符串创建 SwiftUI Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  // 3位简写，如 #FFF
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // 6位标准，如 #FFFFFF
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // 8位含透明度，如 #FFFFFFFF
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
