import Foundation
import UIKit
import CoreLocation

// MARK: - Finance & Crypto Tool
public final class FinanceTool {
    public static let shared = FinanceTool()
    private init() {}
    
    public func getExchangeRates() async -> String {
        // Free open exchange rate API
        let urlStr = "https://open.er-api.com/v6/latest/USD"
        guard let url = URL(string: urlStr) else { return "Ошибка валютного сервиса." }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = json["rates"] as? [String: Double] else {
                return "Не удалось обновить курсы валют."
            }
            
            let rub = rates["RUB"] ?? 92.5
            let eur = rates["EUR"] ?? 0.92
            let cny = rates["CNY"] ?? 7.23
            let aed = rates["AED"] ?? 3.67
            
            let eurToRub = rub / eur
            let cnyToRub = rub / cny
            let aedToRub = rub / aed
            
            return "Курсы валют: Доллар: \(String(format: "%.2f", rub)) ₽, Евро: \(String(format: "%.2f", eurToRub)) ₽, Юань: \(String(format: "%.2f", cnyToRub)) ₽, Дирхам: \(String(format: "%.2f", aedToRub)) ₽."
        } catch {
            return "Курсы валют: Доллар около 92 ₽, Евро около 99 ₽, Юань около 12.6 ₽."
        }
    }
    
    public func getCryptoPrices() async -> String {
        // Free CoinGecko API
        let urlStr = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,the-open-network,solana&vs_currencies=usd,rub"
        guard let url = URL(string: urlStr) else { return "Ошибка крипто-сервиса." }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "Не удалось получить цены криптовалют."
            }
            
            let btc = (json["bitcoin"] as? [String: Any])?["usd"] as? Double ?? 0
            let eth = (json["ethereum"] as? [String: Any])?["usd"] as? Double ?? 0
            let ton = (json["the-open-network"] as? [String: Any])?["usd"] as? Double ?? 0
            let sol = (json["solana"] as? [String: Any])?["usd"] as? Double ?? 0
            
            return "Криптовалюты: Bitcoin: $\(Int(btc)), Ethereum: $\(Int(eth)), TON: $\(String(format: "%.2f", ton)), Solana: $\(Int(sol))."
        } catch {
            return "Не удалось обновить курсы криптовалют."
        }
    }
}

// MARK: - Visual Object Finder & Log
public final class ObjectFinderTool {
    public static let shared = ObjectFinderTool()
    private let defaultsKey = "visual_object_logs"
    
    private var objectLogs: [[String: String]] {
        get {
            UserDefaults.standard.array(forKey: defaultsKey) as? [[String: String]] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
        }
    }
    
    private init() {}
    
    public func logObjectLocation(objectName: String, locationDescription: String) -> String {
        var logs = objectLogs
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru-RU")
        formatter.dateFormat = "d MMMM в HH:mm"
        let timeStr = formatter.string(from: Date())
        
        let newEntry = [
            "object": objectName,
            "location": locationDescription,
            "time": timeStr
        ]
        
        logs.append(newEntry)
        if logs.count > 50 { logs.removeFirst() }
        objectLogs = logs
        
        return "Запомнил местоположение: «\(objectName)» — \(locationDescription) (\(timeStr))."
    }
    
    public func findObject(query: String) -> String {
        let lower = query.lowercased()
        let logs = objectLogs
        
        let matches = logs.filter { entry in
            let obj = entry["object"]?.lowercased() ?? ""
            let loc = entry["location"]?.lowercased() ?? ""
            return obj.contains(lower) || lower.contains(obj) || loc.contains(lower)
        }
        
        if let lastMatch = matches.last {
            let obj = lastMatch["object"] ?? "Предмет"
            let loc = lastMatch["location"] ?? "неизвестно"
            let time = lastMatch["time"] ?? ""
            return "\(obj) был замечен: \(loc) (\(time))."
        }
        
        return "В журнале наблюдений предмет «\(query)» не найден. Вы можете сказать: «Запомни, что ключи лежат на столе»."
    }
}

// MARK: - SOS Sentinel Tool
public final class SOSSentinelTool {
    public static let shared = SOSSentinelTool()
    private init() {}
    
    @MainActor
    public func triggerSOSAlert(contactPhone: String? = nil) -> String {
        let loc = LocationTool.shared.lastLocation?.coordinate
        let lat = loc?.latitude ?? 0.0
        let lon = loc?.longitude ?? 0.0
        let mapsLink = "https://maps.google.com/?q=\(lat),\(lon)"
        
        let sosText = "ЭКСТРЕННЫЙ СИГНАЛ SOS! Мне нужна помощь. Мои координаты: \(mapsLink)"
        
        _ = CommunicationTool.shared.sendMessage(platform: "sms", text: sosText, recipient: contactPhone)
        
        return "Экстренное сообщение с вашими GPS-координатами сформировано."
    }
}
