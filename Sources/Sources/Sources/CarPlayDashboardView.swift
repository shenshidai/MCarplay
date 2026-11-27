import SwiftUI
import MapKit

struct CarPlayDashboardView: View {
    @EnvironmentObject var engine: EasyConnWiFiEngine
    @State private var currentTab: CarPlayTab = .dashboard
    @State private var currentTime: String = "17:58"
    @State private var currentDate: String = "MONDAY"
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
    )
    
    enum CarPlayTab {
        case dashboard
        case apps
        case mapFull
        case musicFull
    }
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            carPlayWallpaper
            
            HStack(spacing: 0) {
                leftDockBar
                
                ZStack {
                    switch currentTab {
                    case .dashboard:
                        splitDashboardView
                    case .apps:
                        appGridView
                    case .mapFull:
                        fullScreenMapView
                    case .musicFull:
                        fullScreenMusicView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
            }
        }
        .onReceive(timer) { _ in
            updateClock()
        }
    }
    
    private var carPlayWallpaper: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09)
            
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 0.8))
                    path.addCurve(
                        to: CGPoint(x: geo.size.width, y: geo.size.height * 0.2),
                        control1: CGPoint(x: geo.size.width * 0.35, y: geo.size.height * 0.9),
                        control2: CGPoint(x: geo.size.width * 0.65, y: geo.size.height * 0.1)
                    )
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.blue.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
    }
    
    private var leftDockBar: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(currentTime)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 3) {
                    Image(systemName: "cellularbars")
                        .font(.system(size: 9))
                    Text("5G")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.85))
                
                Image(systemName: "battery.75")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
            .padding(.top, 12)
            
            Spacer()
            
            dockAppIcon(icon: "map.fill", color: .blue) {
                currentTab = .mapFull
            }
            dockAppIcon(icon: "music.note", color: .green) {
                currentTab = .musicFull
            }
            dockAppIcon(icon: "phone.fill", color: .green) {
                openPhoneApp("tel://")
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentTab = (currentTab == .dashboard) ? .apps : .dashboard
                }
            }) {
                Image(systemName: currentTab == .dashboard ? "square.grid.2x2.fill" : "rectangle.split.2x1.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.bottom, 14)
        }
        .frame(width: 68)
        .background(Color.black.opacity(0.45))
    }
    
    private var splitDashboardView: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                Map(coordinateRegion: $mapRegion)
                    .disabled(true)
                
                HStack(spacing: 8) {
                    destinationBadge(icon: "house.fill", title: "回家 • 25min", color: .orange)
                    destinationBadge(icon: "briefcase.fill", title: "公司 • 37min", color: .blue)
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .onTapGesture {
                currentTab = .mapFull
            }
            
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.18, blue: 0.28), Color(red: 0.07, green: 0.10, blue: 0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("FORD")
                                    .font(.system(size: 11, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                Text("MONDEO 2023")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                            
                            Text("尊贵的车主，您好")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("一路顺风 • 胎压正常")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(currentDate)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                            Text(currentTime)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(16)
                }
                .frame(height: 130)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.14, green: 0.15, blue: 0.18))
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(engine.currentSongTitle)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(engine.currentArtist)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        
                        HStack(spacing: 36) {
                            Button(action: { engine.previousTrack() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 20))
                            }
                            Button(action: { engine.togglePlayPause() }) {
                                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 26))
                            }
                            Button(action: { engine.nextTrack() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 20))
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .padding(16)
                }
                .frame(maxHeight: .infinity)
                .onTapGesture {
                    currentTab = .musicFull
                }
            }
            .frame(width: 340)
        }
    }
    
    private var appGridView: some View {
        let apps: [(name: String, icon: String, color: Color, action: () -> Void)] = [
            ("高德地图", "location.north.fill", .blue, { currentTab = .mapFull }),
            ("QQ音乐", "music.quarternote.3", .green, { currentTab = .musicFull }),
            ("电话", "phone.fill", .green, { openPhoneApp("tel://") }),
            ("微信", "message.fill", .green, { openPhoneApp("weixin://") }),
            ("播放中", "waveform", .orange, { currentTab = .musicFull }),
            ("ChatGPT", "sparkles", .teal, { openPhoneApp("chatgpt://") }),
            ("网易云", "disc.fill", .red, { openPhoneApp("orpheus://") }),
            ("返回主页", "car.fill", .indigo, { currentTab = .dashboard })
        ]
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 24) {
            ForEach(0..<apps.count, id: \.self) { index in
                let item = apps[index]
                Button(action: item.action) {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(item.color.gradient)
                            .frame(width: 68, height: 68)
                            .overlay(
                                Image(systemName: item.icon)
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: item.color.opacity(0.4), radius: 8, y: 4)
                        
                        Text(item.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var fullScreenMapView: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $mapRegion, showsUserLocation: true)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(spacing: 10) {
                Button(action: {
                    mapRegion.span.latitudeDelta *= 0.6
                    mapRegion.span.longitudeDelta *= 0.6
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    mapRegion.span.latitudeDelta *= 1.4
                    mapRegion.span.longitudeDelta *= 1.4
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
            }
            .padding(16)
        }
    }
    
    private var fullScreenMusicView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.22, blue: 0.15), Color(red: 0.12, green: 0.09, blue: 0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 20) {
                Text(engine.currentSongTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                
                Text(engine.currentArtist)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.75))
                
                VStack(spacing: 6) {
                    ProgressView(value: engine.playbackProgress)
                        .tint(.white)
                        .frame(width: 420)
                    HStack {
                        Text("01:24")
                        Spacer()
                        Text("-03:18")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 420)
                }
                
                HStack(spacing: 50) {
                    Button(action: { engine.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                    }
                    Button(action: { engine.togglePlayPause() }) {
                        Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }
                    Button(action: { engine.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                    }
                }
                .foregroundColor(.white)
            }
        }
    }
    
    private func dockAppIcon(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 11)
                .fill(color.gradient)
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )
        }
    }
    
    private func destinationBadge(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.78))
        .cornerRadius(12)
    }
    
    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        currentDate = dayFormatter.string(from: Date()).uppercased()
    }
    
    private func openPhoneApp(_ scheme: String) {
        if let url = URL(string: scheme) {
            UIApplication.shared.open(url)
        }
    }
}
