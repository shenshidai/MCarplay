import SwiftUI

struct MCarplayConsoleView: View {
    @EnvironmentObject var engine: EasyConnWiFiEngine
    @State private var showFullScreenPreview = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.14),
                    Color(red: 0.02, green: 0.03, blue: 0.06)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                headerBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        previewCard
                        connectionCenterCard
                        vehicleControlCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPreview) {
            ZStack(alignment: .topTrailing) {
                CarPlayDashboardView()
                    .environmentObject(engine)
                    .ignoresSafeArea()
                
                Button(action: { showFullScreenPreview = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(20)
                }
            }
        }
    }
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MCarplay")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("v2.023.MONDEO.PRO • 亿连WiFi直连版")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.cyan.opacity(0.8))
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
    
    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            
            if engine.connectionState == .connected {
                CarPlayDashboardView()
                    .environmentObject(engine)
                    .scaleEffect(0.36)
                    .frame(height: 185)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture {
                        showFullScreenPreview = true
                    }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Label("点击全屏预览", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(8)
                            .padding(10)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("未开始投屏 • 请确保车机已连接手机热点并打开亿连")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(height: 185)
            }
        }
    }
    
    private var connectionCenterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.cyan)
                Text("CarPlay 连接中心")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(engine.connectionState.badgeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .cornerRadius(12)
            }
            
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.connectionState.titleText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(engine.statusDetailMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("连接链路")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack {
                    linkNode(icon: "iphone", title: "iPhone", active: true)
                    linkLine(active: engine.connectionState != .disconnected)
                    linkNode(icon: "wifi", title: "个人热点", active: engine.connectionState != .disconnected)
                    linkLine(active: engine.connectionState == .connected)
                    linkNode(icon: "cpu", title: "亿连协议", active: engine.connectionState == .connected)
                    linkLine(active: engine.connectionState == .connected)
                    linkNode(icon: "car.fill", title: "23蒙迪欧", active: engine.connectionState == .connected)
                }
            }
            
            HStack(spacing: 10) {
                statusGridItem(icon: "wifi", title: "热点网络", value: engine.localIPAddress, active: true)
                statusGridItem(icon: "hand.tap.fill", title: "反向触控", value: engine.connectionState == .connected ? "已就绪" : "等待中", active: engine.connectionState == .connected)
                statusGridItem(icon: "moon.zzz.fill", title: "锁屏保活", value: "后台运行", active: true)
            }
            
            Button(action: {
                if engine.connectionState == .disconnected {
                    engine.startDiscoveryAndStream()
                } else {
                    engine.stopStream()
                }
            }) {
                HStack {
                    Image(systemName: engine.connectionState == .disconnected ? "play.fill" : "xmark")
                    Text(engine.connectionState == .disconnected ? "开始连接蒙迪欧车机" : "断开连接")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    engine.connectionState == .disconnected
                    ? LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.red.opacity(0.8), Color.orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(red: 0.08, green: 0.11, blue: 0.18))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var vehicleControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.side.fill")
                    .foregroundColor(.cyan)
                Text("23款蒙迪欧快捷控车")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("福特派快捷指令")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 12) {
                controlButton(title: "解锁", icon: "lock.open.fill", color: .green, shortcutName: "蒙迪欧解锁")
                controlButton(title: "锁车", icon: "lock.fill", color: .orange, shortcutName: "蒙迪欧锁车")
                controlButton(title: "远程启动", icon: "engine.combustion.fill", color: .cyan, shortcutName: "蒙迪欧启动")
                controlButton(title: "寻车鸣笛", icon: "speaker.wave.3.fill", color: .purple, shortcutName: "蒙迪欧寻车")
            }
        }
        .padding(16)
        .background(Color(red: 0.08, green: 0.11, blue: 0.18))
        .cornerRadius(18)
    }
    
    private var statusColor: Color {
        switch engine.connectionState {
        case .disconnected: return .gray
        case .searching, .connecting: return .orange
        case .connected: return .green
        }
    }
    
    private var statusIcon: String {
        switch engine.connectionState {
        case .disconnected: return "bolt.slash.fill"
        case .searching, .connecting: return "dot.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        }
    }
    
    private func linkNode(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(active ? .cyan : .gray)
                .frame(width: 36, height: 36)
                .background(active ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(10)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(active ? .white : .gray)
        }
    }
    
    private func linkLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.cyan : Color.white.opacity(0.1))
            .frame(height: 2)
            .padding(.bottom, 16)
    }
    
    private func statusGridItem(icon: String, title: String, value: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(active ? .cyan : .gray)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(active ? .green : .gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
    
    private func controlButton(title: String, icon: String, color: Color, shortcutName: String) -> some View {
        Button(action: {
            if let encoded = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
