import SwiftUI

@main
struct MCarplayApp: App {
    // 全局状态管理器（连接手机控制台与后台 CarPlay 虚拟画布）
    @StateObject private var engine = EasyConnWiFiEngine.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1. 后台离屏渲染的 CarPlay 界面（尺寸适配 23款蒙迪欧 1280x720 比例）
                CarPlayDashboardView()
                    .environmentObject(engine)
                    .frame(width: 960, height: 540)
                    .background(CarPlayCaptureHostingView(engine: engine))
                    .opacity(0.01)
                    .allowsHitTesting(false)
                
                // 2. 手机前台显示的 MCarplay 控制台
                MCarplayConsoleView()
                    .environmentObject(engine)
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// 负责将 SwiftUI 视图实时转化为 UIImage/CVPixelBuffer 供 H.264 编码器推流
struct CarPlayCaptureHostingView: UIViewRepresentable {
    @ObservedObject var engine: EasyConnWiFiEngine
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 960, height: 540))
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            engine.attachCaptureTarget(view: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
