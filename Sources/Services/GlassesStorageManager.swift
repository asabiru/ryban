import Foundation
import UIKit
import Combine
@preconcurrency import MachO

public struct StorageReport {
    public let cacheSizeMB: Double
    public let tempSizeMB: Double
    public let appMemoryMB: Double
    public let freeDiskSpaceGB: Double
    public let statusDescription: String
}

public struct CleanupResult {
    public let freedMB: Double
    public let filesDeleted: Int
    public let memoryUsageAfterMB: Double
    public let message: String
}

@MainActor
public final class GlassesStorageManager: ObservableObject {
    public static let shared = GlassesStorageManager()
    
    @Published public var currentReport: StorageReport?
    @Published public var isCleaning: Bool = false
    
    private init() {
        setupMemoryWarningObserver()
        updateReport()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.autoEmergencyCleanup()
            }
        }
    }
    
    public func updateReport() {
        let cacheSize = calculateFolderSize(folderPath: getCacheDirectoryPath())
        let tempSize = calculateFolderSize(folderPath: NSTemporaryDirectory())
        let appRam = getAppRAMUsageMB()
        let freeDisk = getFreeDiskSpaceGB()
        
        let status: String
        if appRam > 250 || (cacheSize + tempSize) > 200 {
            status = "Требуется оптимизация"
        } else {
            status = "Память в норме"
        }
        
        currentReport = StorageReport(
            cacheSizeMB: cacheSize,
            tempSizeMB: tempSize,
            appMemoryMB: appRam,
            freeDiskSpaceGB: freeDisk,
            statusDescription: status
        )
    }
    
    public func clearMemoryAndCache() -> CleanupResult {
        isCleaning = true
        let beforeRam = getAppRAMUsageMB()
        let beforeDisk = calculateFolderSize(folderPath: getCacheDirectoryPath()) + calculateFolderSize(folderPath: NSTemporaryDirectory())
        
        var deletedCount = 0
        
        // 1. Clear Temp Directory
        deletedCount += clearFolder(at: NSTemporaryDirectory())
        
        // 2. Clear Caches Directory
        deletedCount += clearFolder(at: getCacheDirectoryPath())
        
        // 3. Clear URL Cache & Image Caches
        URLCache.shared.removeAllCachedResponses()
        
        // 4. Release latest frame buffers in WearablesManager
        WearablesManager.shared.latestFrame = nil
        WearablesManager.shared.lastCapturedPhoto = nil
        
        // 5. Trim Chat History thumbnails (freeing UIImage memory)
        for i in 0..<AppState.shared.messages.count {
            AppState.shared.messages[i].image = nil
        }
        
        let afterRam = getAppRAMUsageMB()
        let afterDisk = calculateFolderSize(folderPath: getCacheDirectoryPath()) + calculateFolderSize(folderPath: NSTemporaryDirectory())
        let freedMB = max(0.1, (beforeDisk - afterDisk) + max(0, beforeRam - afterRam))
        
        updateReport()
        isCleaning = false
        
        let msg = "Очищено \(String(format: "%.1f", freedMB)) МБ кэша и буферов очков. Удалено \(deletedCount) временных файлов. Оперативная память: \(Int(afterRam)) МБ."
        return CleanupResult(
            freedMB: freedMB,
            filesDeleted: deletedCount,
            memoryUsageAfterMB: afterRam,
            message: msg
        )
    }
    
    private func autoEmergencyCleanup() {
        print("⚠️ Emergency Memory Warning: purging video buffers and caches...")
        _ = clearMemoryAndCache()
    }
    
    private func getCacheDirectoryPath() -> String {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""
    }
    
    private func calculateFolderSize(folderPath: String) -> Double {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        
        if let files = try? fileManager.subpathsOfDirectory(atPath: folderPath) {
            for file in files {
                let fullPath = (folderPath as NSString).appendingPathComponent(file)
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath) {
                    if let size = attrs[.size] as? UInt64 {
                        totalSize += size
                    }
                }
            }
        }
        
        return Double(totalSize) / (1024.0 * 1024.0)
    }
    
    private func clearFolder(at path: String) -> Int {
        let fileManager = FileManager.default
        var count = 0
        guard let files = try? fileManager.contentsOfDirectory(atPath: path) else { return 0 }
        
        for file in files {
            let fullPath = (path as NSString).appendingPathComponent(file)
            do {
                try fileManager.removeItem(atPath: fullPath)
                count += 1
            } catch {
                // Ignore locked files
            }
        }
        return count
    }
    
    private func getAppRAMUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        }
        return 0.0
    }
    
    private func getFreeDiskSpaceGB() -> Double {
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? UInt64 {
            return Double(freeSize) / (1024.0 * 1024.0 * 1024.0)
        }
        return 0.0
    }
}
