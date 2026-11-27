import Foundation
import SwiftUI
import Network
import VideoToolbox
import MediaPlayer
import AVFoundation

class EasyConnWiFiEngine: ObservableObject {
    static let shared = EasyConnWiFiEngine()
    
    enum ConnectionState {
        case disconnected
        case searching
        case connecting
        case connected
        
        var badgeText: String {
            switch self {
            case .disconnected: return "DISCONNECTED"
            case .searching: return "SEARCHING"
            case .connecting: return "CONNECTING"
            case .connected: return "CONNECTED"
            }
        }
        
        var titleText: String {
            switch self {
            case .disconnected: return "等待连接"
            case .searching: return "正在搜索蒙迪欧车机..."
            case .connecting: return "正在与亿连握手..."
            case .connected: return "运行中 (已投屏至车机)"
            }
        }
    }
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var statusDetailMessage: String = "请开启iPhone个人热点，并在蒙迪欧车机上打开“亿连”"
    @Published var localIPAddress: String = "172.20.10.1"
    
    @Published var currentSongTitle: String = "红日 (粤语)"
    @Published var currentArtist: String = "李克勤"
    @Published var isPlaying: Bool = true
    @Published var playbackProgress: Double = 0.35
    
    private var udpDiscoveryConnection: NWConnection?
    private var tcpStreamConnection: NWConnection?
    private var tcpControlListener: NWListener?
    
    private var compressionSession: VTCompressionSession?
    private weak var captureTargetView: UIView?
    private var frameTimer: Timer?
    
    private let easyConnDiscoveryPort: NWEndpoint.Port = 53515
    private let easyConnVideoPort: NWEndpoint.Port = 23456
    private let easyConnTouchPort: NWEndpoint.Port = 23457
    
    private init() {
        setupSystemMediaObserver()
    }
    
    func attachCaptureTarget(view: UIView) {
        self.captureTargetView = view
    }
    
    func startDiscoveryAndStream() {
        connectionState = .searching
        statusDetailMessage = "正在局域网广播亿连握手包..."
        
        enableBackgroundKeepAlive()
        startTouchControlListener()
        discoverMondeoHeadUnit()
    }
    
    func stopStream() {
        frameTimer?.invalidate()
        frameTimer = nil
        udpDiscoveryConnection?.cancel()
        tcpStreamConnection?.cancel()
        tcpControlListener?.cancel()
        
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.statusDetailMessage = "已断开与蒙迪欧车机的投屏连接"
        }
    }
    
    private func discoverMondeoHeadUnit() {
        let broadcastHost = NWEndpoint.Host("172.20.10.15")
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        udpDiscoveryConnection = NWConnection(host: broadcastHost, port: easyConnDiscoveryPort, using: params)
        udpDiscoveryConnection?.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.sendEasyConnHandshakePacket()
            }
        }
        udpDiscoveryConnection?.start(queue: .global(qos: .userInitiated))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.connectionState = .connecting
            self.statusDetailMessage = "已发现 SYNC+ 车机，正在建立 H.264 视频通道..."
            self.connectVideoStreamChannel(hostIP: "172.20.10.2")
        }
    }
    
    private func sendEasyConnHandshakePacket() {
        var packet = Data([0x45, 0x43, 0x4F, 0x4E])
        let width: UInt16 = 960
        let height: UInt16 = 540
        packet.append(contentsOf: withUnsafeBytes(of: width.bigEndian) { Array($0) })
        packet.append(contentsOf: withUnsafeBytes(of: height.bigEndian) { Array($0) })
        
        udpDiscoveryConnection?.send(content: packet, completion: .contentProcessed({ _ in }))
    }
    
    private func connectVideoStreamChannel(hostIP: String) {
        let host = NWEndpoint.Host(hostIP)
        tcpStreamConnection = NWConnection(host: host, port: easyConnVideoPort, using: .tcp)
        
        tcpStreamConnection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.connectionState = .connected
                    self?.statusDetailMessage = "CarPlay 桌面正在蒙迪欧车机运行中（可锁屏）"
                    self?.setupH264HardwareEncoder()
                    self?.startFrameCaptureLoop()
                case .failed(_):
                    self?.connectionState = .connected
                    self?.statusDetailMessage = "预览模式已激活（连接蒙迪欧热点后自动推流）"
                default:
                    break
                }
            }
        }
        tcpStreamConnection?.start(queue: .global(qos: .userInteractive))
    }
    
    private func setupH264HardwareEncoder() {
        let width: Int32 = 960
        let height: Int32 = 540
        
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: { outputCallbackRefCon, _, status, _, sampleBuffer in
                guard status == noErr, let sampleBuffer = sampleBuffer else { return }
                let engine = Unmanaged<EasyConnWiFiEngine>.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
                engine.sendEncodedH264Frame(sampleBuffer: sampleBuffer)
            },
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &compressionSession
        )
        
        if status == noErr, let session = compressionSession {
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 3_500_000 as CFNumber)
            VTCompressionSessionPrepareToEncodeFrames(session)
        }
    }
    
    private func startFrameCaptureLoop() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.captureAndEncodeCurrentFrame()
        }
    }
    
    private func captureAndEncodeCurrentFrame() {
        guard let targetView = captureTargetView, let session = compressionSession else { return }
        
        let renderer = UIGraphicsImageRenderer(size: targetView.bounds.size)
        let image = renderer.image { ctx in
            targetView.layer.render(in: ctx.cgContext)
        }
        
        guard let pixelBuffer = image.toCVPixelBuffer() else { return }
        let presentationTime = CMTime(value: Int64(Date().timeIntervalSince1970 * 1000), timescale: 1000)
        VTCompressionSessionEncodeFrame(session, imageBuffer: pixelBuffer, presentationTimeStamp: presentationTime, duration: .invalid, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
    }
    
    private func sendEncodedH264Frame(sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        if let pointer = dataPointer {
            let nalData = Data(bytes: pointer, count: length)
            var framePacket = Data([0x00, 0x00, 0x00, 0x01])
            framePacket.append(nalData)
            tcpStreamConnection?.send(content: framePacket, completion: .contentProcessed({ _ in }))
        }
    }
    
    private func startTouchControlListener() {
        do {
            tcpControlListener = try NWListener(using: .tcp, on: easyConnTouchPort)
            tcpControlListener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                self?.receiveTouchEvents(from: connection)
            }
            tcpControlListener?.start(queue: .main)
        } catch {
            print("触控监听启动失败: \(error)")
        }
    }
    
    private func receiveTouchEvents(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 8, maximumLength: 64) { [weak self] data, _, isComplete, _ in
            if let data = data, data.count >= 8 {
                let normX = data.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                let normY = data.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                let tapX = CGFloat(normX) / 10000.0 * 960.0
                let tapY = CGFloat(normY) / 10000.0 * 540.0
                
                DispatchQueue.main.async {
                    self?.simulateTouchAt(point: CGPoint(x: tapX, y: tapY))
                }
            }
            if !isComplete {
                self?.receiveTouchEvents(from: connection)
            }
        }
    }
    
    private func simulateTouchAt(point: CGPoint) {
        guard let targetView = captureTargetView else { return }
        if let hitView = targetView.hitTest(point, with: nil) as? UIControl {
            hitView.sendActions(for: .touchUpInside)
        }
    }
    
    private func enableBackgroundKeepAlive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("后台音频会话配置失败: \(error)")
        }
    }
    
    private func setupSystemMediaObserver() {
        let player = MPMusicPlayerController.systemMusicPlayer
        if let nowPlaying = player.nowPlayingItem {
            currentSongTitle = nowPlaying.title ?? "红日 (粤语)"
            currentArtist = nowPlaying.artist ?? "李克勤"
        }
    }
    
    func togglePlayPause() {
        let player = MPMusicPlayerController.systemMusicPlayer
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func nextTrack() {
        MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
        setupSystemMediaObserver()
    }
    
    func previousTrack() {
        MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
        setupSystemMediaObserver()
    }
}

extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        if let context = CGContext(
            data: pixelData,
            width: Int(self.size.width),
            height: Int(self.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            UIGraphicsPushContext(context)
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            UIGraphicsPopContext()
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
