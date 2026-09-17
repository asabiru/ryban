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
    
    public func requestCameraPermissionAndConnect() async {
        configureSDK()
        statusMessage = "Проверка разрешений очков..."
        errorMessage = nil
        do {
            let status = try await Wearables.shared.checkPermissionStatus(.camera)
            if status == .granted {
                self.isRegistered = true
                self.statusMessage = "Разрешение камеры получено!"
                await self.connectAndStartStreaming()
                return
            }
            
            self.statusMessage = "Запрос доступа к камере Meta AI..."
            let newStatus = try await Wearables.shared.requestPermission(.camera)
            if newStatus == .granted {
                self.isRegistered = true
                self.statusMessage = "Доступ разрешен! Запуск очков..."
                await self.connectAndStartStreaming()
            } else {
                self.statusMessage = "Статус камеры: \(newStatus)"
            }
        } catch {
            errorMessage = "Ошибка разрешений: \(error.localizedDescription)"
            statusMessage = "Ошибка доступа к камере"
        }
    }
    
    public func startRegistration() {
        configureSDK()
        statusMessage = "Запрос регистрации в Meta AI..."
        errorMessage = nil
        
        Task { @MainActor in
            do {
                try await Wearables.shared.startRegistration()
            } catch RegistrationError.alreadyRegistered {
                self.isRegistered = true
                self.statusMessage = "Очки уже зарегистрированы!"
                await self.connectAndStartStreaming()
            } catch {
                self.errorMessage = "Ошибка: \(error.localizedDescription)"
                self.statusMessage = "Ошибка регистрации"
            }
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
        configureSDK()
        do {
            statusMessage = "Подключение к очкам..."
            errorMessage = nil
            let selector = AutoDeviceSelector(wearables: Wearables.shared)
            let session = try Wearables.shared.createSession(deviceSelector: selector)
            self.deviceSession = session
            
            sessionTask?.cancel()
            let initialStateStream = session.stateStream()
            try session.start()
            
            // Wait for this session to start before adding camera capabilities.
            for await state in initialStateStream {
                if state == .started {
                    isConnected = true
                    statusMessage = "Очки подключены!"
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
                        self.statusMessage = "Очки подключены!"
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
                        self.isStreaming = true
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
                        self?.statusMessage = "Поток остановлен"
                    default:
                        break
                    }
                }
            }
            
            cameraStream.start()
            statusMessage = "Поток очков запущен!"
        } catch {
            errorMessage = "Ошибка подключения: \(error.localizedDescription)"
            statusMessage = "Ошибка сессии очков"
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
