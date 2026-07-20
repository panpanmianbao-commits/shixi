import SwiftUI
import AVFoundation

// MARK: - 应用入口
/// 时隙 App 的主入口，配置全局环境对象和音频会话
@main
struct ShixiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ShixiViewModel())  // 注入全局视图模型
        }
    }
}

// MARK: - 应用代理
/// 处理应用生命周期事件，配置后台音频播放能力
class AppDelegate: NSObject, UIApplicationDelegate {
    /// 应用启动时配置音频会话，支持后台播放和与其他音频混音
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let session = AVAudioSession.sharedInstance()
        // 设置为播放模式，允许与其他应用音频同时播放
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        return true
    }
}
