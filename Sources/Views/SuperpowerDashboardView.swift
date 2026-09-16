import SwiftUI

public struct SuperpowerDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var antiLost = AntiLostSentinelTool.shared
    @State private var currencyInfo: String = "Загрузка курсов..."
    @State private var cryptoInfo: String = "Загрузка крипты..."
    @State private var healthInfo: String = "Загрузка шагов..."
    @State private var storageInfo: String = "Память в норме"
    @State private var notes: [VoiceNotesTool.VoiceNote] = []
    @State private var people: [PeopleMemoryTool.PersonEntry] = []
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Banner
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⚡ Суперспособности Агента")
                                .font(.title3.bold())
                            Text("Все инструменты доступны голосом через очки")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Grid of Live Widgets
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        // Find My Phone Card
                        SuperpowerCard(
                            icon: "iphone.radiowaves.left.and.right",
                            iconColor: .pink,
                            title: "Где телефон?",
                            subtitle: "«Найди телефон» (Сирена и вспышка)"
                        ) {
                            _ = FindMyPhoneTool.shared.triggerFindPhoneAlarm()
                        }
                        
                        // Anti-Lost Glasses Location Card
                        SuperpowerCard(
                            icon: "shield.lefthalf.filled.badge.checkmark",
                            iconColor: .cyan,
                            title: "Анти-потеря очков",
                            subtitle: "Связь: \(antiLost.lastKnownTimestamp)"
                        ) {
                            _ = antiLost.getLastKnownGlassesLocation()
                        }
                        
                        // Eye Health & Rest Coach Card
                        SuperpowerCard(
                            icon: "eye.fill",
                            iconColor: .green,
                            title: "Гимнастика глаз",
                            subtitle: "1-минутный комплекс"
                        ) {
                            _ = EyeAndPostureCoachTool.shared.startEyeGymnastics()
                        }
                        
                        // Workout / Rest Coach Card
                        SuperpowerCard(
                            icon: "timer",
                            iconColor: .teal,
                            title: "Таймер отдыха",
                            subtitle: "«Отдых 60 секунд»"
                        ) {
                            _ = WorkoutCoachTool.shared.startRestTimer(seconds: 60)
                        }
                        
                        // Health / Fitness Card
                        SuperpowerCard(
                            icon: "flame.fill",
                            iconColor: .orange,
                            title: "Активность",
                            subtitle: healthInfo
                        ) {
                            Task {
                                healthInfo = await HealthKitTool.shared.getTodayHealthStats()
                            }
                        }
                        
                        // Storage & Memory Cleaner Card
                        SuperpowerCard(
                            icon: "cpu.fill",
                            iconColor: .purple,
                            title: "Память очков",
                            subtitle: storageInfo
                        ) {
                            let res = GlassesStorageManager.shared.clearMemoryAndCache()
                            storageInfo = "Очищено! RAM: \(Int(res.memoryUsageAfterMB)) МБ"
                        }
                        
                        // Smart Home Card
                        SuperpowerCard(
                            icon: "house.fill",
                            iconColor: .blue,
                            title: "HomeKit",
                            subtitle: "«Выключи свет в спальне»"
                        ) {
                            Task {
                                _ = await HomeKitTool.shared.controlDevice(room: nil, deviceType: "свет", action: "включить")
                            }
                        }
                        
                        // Finance Card
                        SuperpowerCard(
                            icon: "dollarsign.circle.fill",
                            iconColor: .indigo,
                            title: "Курсы валют",
                            subtitle: currencyInfo
                        ) {
                            Task {
                                currencyInfo = await FinanceTool.shared.getExchangeRates()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Section: Voice Notes
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.blue)
                            Text("Банк идей и Заметки")
                                .font(.headline)
                            Spacer()
                        }
                        
                        if notes.isEmpty {
                            Text("Нет заметок. Скажите в очки: «Запиши идею: ...»")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(notes.prefix(3)) { note in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(note.title)
                                            .font(.subheadline.bold())
                                        Text(note.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(note.timestamp)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Section: People Memory
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.green)
                            Text("Память о людях")
                                .font(.headline)
                            Spacer()
                        }
                        
                        if people.isEmpty {
                            Text("Память пуста. Скажите: «Запомни: Максим — наш архитектор»")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(people.prefix(3)) { person in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.name)
                                            .font(.subheadline.bold())
                                        Text("\(person.role) • \(person.details)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // SOS Emergency Button
                    Button(action: {
                        _ = SOSSentinelTool.shared.triggerSOSAlert()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "sos.circle.fill")
                                .font(.title2)
                            Text("Экстренный сигнал SOS (GPS координаты)")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                .padding(.vertical)
            }
            .navigationTitle("Панель инструментов")
            .navigationBarItems(trailing: Button("Готово") {
                dismiss()
            })
            .onAppear {
                loadAllData()
            }
        }
    }
    
    private func loadAllData() {
        notes = VoiceNotesTool.shared.getAllNotes()
        people = PeopleMemoryTool.shared.getAllPeople()
        
        Task {
            healthInfo = await HealthKitTool.shared.getTodayHealthStats()
            currencyInfo = await FinanceTool.shared.getExchangeRates()
            cryptoInfo = await FinanceTool.shared.getCryptoPrices()
            
            GlassesStorageManager.shared.updateReport()
            if let rep = GlassesStorageManager.shared.currentReport {
                storageInfo = "Кэш: \(String(format: "%.1f", rep.cacheSizeMB)) МБ • RAM: \(Int(rep.appMemoryMB)) МБ"
            }
        }
    }
}

private struct SuperpowerCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }
}
