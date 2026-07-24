import SwiftUI
import AVFoundation
import UserNotifications

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
/// 处理应用生命周期事件，配置后台音频播放能力和本地通知
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// 应用启动时配置音频会话和通知中心
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 配置音频会话，支持后台播放和与其他音频混音
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }

        // 配置 UNUserNotificationCenter 代理
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    /// 前台时也能显示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
