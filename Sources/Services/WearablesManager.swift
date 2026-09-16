import SwiftUI
import Combine
import QuartzCore
import MWDATCore
import MWDATCamera

@MainActor
public final class WearablesManager: ObservableObject {
    public static let shared = WearablesManager()
    
    @Published public var isConfigured: Bool = false
    @Published public var isRegistered: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var isStreaming: Bool = false
    @Published public var statusMessage: String = "Инициализация очков..."
    @Published public var latestFrame: UIImage?
    @Published public var lastCapturedPhoto: UIImage?
    @Published public var errorMessage: String?
    
    private var wearables: WearablesInterface { Wearables.shared }
    private var deviceSession: DeviceSession?
    private var camera: Camera?
    private var stream: MWDATCamera.Stream?
    
    private var registrationTask: Task<Void, Never>?
    private var devicesTask: Task<Void, Never>?
    private var sessionTask: Task<Void, Never>?
    private var frameListenerToken: Any?
    private var stateListenerToken: Any?
    
    private var lastFrameTime: TimeInterval = 0
    private let minFrameInterval: TimeInterval = 0.08 // Throttle UI rendering to ~12 FPS to conserve RAM & battery
    
    public init() {}
    
    public func configureSDK(force: Bool = false) {
        if isConfigured && !force { return }
        do {
            try Wearables.configure()
            isConfigured = true
            statusMessage = "SDK очков готово"
            errorMessage = nil
            observeRegistration()
            observeDevices()
        } catch {
            isConfigured = false
            errorMessage = "Ошибка SDK: \(error)"
            statusMessage = "SDK не сконфигурировано"
        }
    }
    
    public func checkDevicesStatus() {
        configureSDK()
        let devices = Wearables.shared.devices
        if devices.isEmpty {
            statusMessage = "Очки не найдены в Bluetooth"
            errorMessage = "Убедитесь, что очки надеты/открыты и подключены в Meta AI"
        } else {
            statusMessage = "Найдено очков: \(devices.count)"
            errorMessage = nil
            Task {
                await self.connectAndStartStreaming()
            }
        }
    }
    
    public func startRegistration() {
        configureSDK()
        statusMessage = "Открытие Meta View..."
        
        let bundleId = "com.rayban.meta.ai"
        let encodedName = "Ray-Ban AI".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Ray-BanAI"
        let encodedScheme = "raybanmetaai://".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "raybanmetaai://"
        
        let deepLinkUrls = [
            "fb-viewapp://stella/dat/registration?appPackage=\(bundleId)&appName=\(encodedName)&action=register&metaAppId=1077803035118164&appLinkUrlScheme=\(encodedScheme)",
            "fb-viewapp://stella/dat/registration?appPackage=\(bundleId)&appName=\(encodedName)&action=register&metaAppId=0&appLinkUrlScheme=\(encodedScheme)",
            "fb-viewapp://dat/register?app_id=1077803035118164&app_name=\(encodedName)&app_link_url_scheme=\(encodedScheme)",
            "fb-viewapp://"
        ]
        
        for urlStr in deepLinkUrls {
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        self.statusMessage = "Запрос передан в Meta View!"
                    }
                }
                return
            }
        }
        
        if let fallback = URL(string: "fb-viewapp://") {
            UIApplication.shared.open(fallback)
        }
    }
    
    public func handleUrl(_ url: URL) async {
        do {
            let handled = try await Wearables.shared.handleUrl(url)
            if handled {
                self.statusMessage = "Очки успешно авторизованы!"
                self.isRegistered = true
                await self.connectAndStartStreaming()
            }
        } catch {
            errorMessage = "Ошибка обработки токена Meta: \(error.localizedDescription)"
        }
    }
    
    private func observeRegistration() {
        registrationTask?.cancel()
        registrationTask = Task { [weak self] in
            for await state in Wearables.shared.registrationStateStream() {
                guard let self = self else { return }
                switch state {
                case .registered:
                    self.isRegistered = true
                    self.statusMessage = "Очки зарегистрированы"
                    await self.connectAndStartStreaming()
                case .registering:
                    self.statusMessage = "Идет регистрация..."
                default:
                    self.isRegistered = false
                    self.isConnected = false
                    self.statusMessage = "Очки не зарегистрированы"
                }
            }
        }
    }
    
    private func observeDevices() {
        devicesTask?.cancel()
        devicesTask = Task { [weak self] in
            for await devices in Wearables.shared.devicesStream() {
                guard let self = self else { return }
                if !devices.isEmpty {
                    self.statusMessage = "Очки обнаружены (\(devices.count))"
                    self.isConnected = true
                    await self.connectAndStartStreaming()
                }
            }
        }
    }
    
    public func connectAndStartStreaming() async {
        guard isConfigured else { return }
        
        do {
            statusMessage = "Подключение к очкам..."
            let selector = AutoDeviceSelector(wearables: wearables)
            let session = try wearables.createSession(deviceSelector: selector)
            self.deviceSession = session
            
            sessionTask?.cancel()
            let initialStateStream = session.stateStream()
            try session.start()
            
            // Wait for this session to start before adding camera capabilities.
            for await state in initialStateStream {
                if state == .started {
                    isConnected = true
                    statusMessage = "Очки подключены"
                    break
                }
                if state == .stopped {
                    isConnected = false
                    statusMessage = "Сессия остановлена"
                    return
                }
            }
            
            // Keep observing the lifecycle after the initial start.
            sessionTask = Task { [weak self] in
                for await state in session.stateStream() {
                    guard let self = self else { return }
                    switch state {
                    case .started:
                        self.isConnected = true
                        self.statusMessage = "Очки подключены"
                    case .stopped:
                        self.isConnected = false
                        self.isStreaming = false
                        self.statusMessage = "Сессия остановлена"
                    default:
                        break
                    }
                }
            }
            
            let config = StreamConfiguration(
                videoCodec: .raw,
                resolution: .medium,
                frameRate: 15
            )
            
            guard let camera = try session.addCamera(config: config) else {
                statusMessage = "Не удалось добавить камеру"
                return
            }
            
            self.camera = camera
            let cameraStream = camera.stream
            self.stream = cameraStream
            
            // Listen to video frames with autoreleasepool and throttling
            self.frameListenerToken = cameraStream.videoFramePublisher.listen { [weak self] frame in
                autoreleasepool {
                    guard let image = frame.makeUIImage() else { return }
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        let now = CACurrentMediaTime()
                        guard now - self.lastFrameTime >= self.minFrameInterval else { return }
                        self.lastFrameTime = now
                        self.latestFrame = image
                    }
                }
            }
            
            // Listen to stream state
            self.stateListenerToken = cameraStream.statePublisher.listen { [weak self] state in
                Task { @MainActor [weak self] in
                    switch state {
                    case .streaming:
                        self?.isStreaming = true
                        self?.statusMessage = "Камера очков активна (Live)"
                    case .paused:
                        self?.isStreaming = false
                        self?.statusMessage = "Поток камеры приостановлен"
                    case .stopped:
                        self?.isStreaming = false
                        self?.statusMessage = "Камера остановлена"
                    default:
                        break
                    }
                }
            }
            
            await cameraStream.start()
            
        } catch {
            errorMessage = "Ошибка подключения: \(error.localizedDescription)"
            statusMessage = "Ошибка подключения к очкам"
        }
    }
    
    public func stopStreaming() {
        AntiLostSentinelTool.shared.markIntentionalDisconnect()
        Task {
            await stream?.stop()
            try? deviceSession?.stop()
            isStreaming = false
            isConnected = false
            latestFrame = nil
            statusMessage = "Отключено"
        }
    }
    
    public func captureSnapshot() -> UIImage? {
        if let frame = latestFrame {
            lastCapturedPhoto = frame
            return frame
        }
        return nil
    }
    
    public func purgeFrameBuffers() {
        latestFrame = nil
        lastCapturedPhoto = nil
    }
}
