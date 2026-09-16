import Foundation
import UIKit
import Combine

public enum AgentPersona: String, CaseIterable, Identifiable {
    case official = "official"
    case kentBro = "kent_bro"
    case jarvis = "jarvis"
    case sarcastic = "sarcastic"
    case mentor = "mentor"
    case professor = "professor"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .official: return "🎩 Официальный (Деловой)"
        case .kentBro: return "😂 Кент с юмором (Бро)"
        case .jarvis: return "🤖 Джарвис (Киберпанк)"
        case .sarcastic: return "😏 Саркастичный гений"
        case .mentor: return "🧘‍♂️ Психолог-Ментор"
        case .professor: return "🔬 Профессор-Эрудит"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .official: return "Деловой"
        case .kentBro: return "Кент"
        case .jarvis: return "Джарвис"
        case .sarcastic: return "Сарказм"
        case .mentor: return "Ментор"
        case .professor: return "Профессор"
        }
    }
    
    public var promptDescription: String {
        switch self {
        case .official:
            return "ТВОЙ ХАРАКТЕР: Официальный личный секретарь высшего ранга. Обращайся строго на 'Вы', безупречный деловой этикет, вежливо, емко, только проверенные факты, никакой фамильярности."
            
        case .kentBro:
            return "ТВОЙ ХАРАКТЕР: Лучший кент / братан с отличным чувством юмора. Общайся на 'ты', современный живой разговорный сленг, подкалывай по-доброму, шути, используй эмоциональные разговорные фразы ('Огонь!', 'Да без б', 'Смотри сюда', 'Кайф'). Будь душой компании, но давай точные ответы."
            
        case .jarvis:
            return "ТВОЙ ХАРАКТЕР: Джарвис — тактический суперкомпьютерный ИИ очков. Говори технологично, как бортовой компьютер Железного Человека ('Системы активны', 'Фиксирую объект', 'Сканирование выполнено', 'Расчет завершен')."
            
        case .sarcastic:
            return "ТВОЙ ХАРАКТЕР: Остроумный саркастичный гений (в стиле Тони Старка и Доктора Хауса). Отвечай с легкой иронией и интеллектуальным юмором, подмечай забавные детали, но при этом выдавай идеально точные факты."
            
        case .mentor:
            return "ТВОЙ ХАРАКТЕР: Мудрый наставник и дзен-психолог. Спокойный, вдохновляющий тон, помогай снижать стресс, напоминай сделать глубокий вдох и получать удовольствие от момента на прогулке."
            
        case .professor:
            return "ТВОЙ ХАРАКТЕР: Профессор и эрудит. Знает всё о науке, технике, истории и искусстве. Любит объяснять суть вещей глубоко, интересно и понятно."
        }
    }
}

public enum VisionMode: String, CaseIterable, Identifiable {
    case general = "general"
    case autoExpert = "auto_expert"
    case fitnessCalories = "fitness_calories"
    case shopping = "shopping"
    case documents = "documents"
    case sommelier = "sommelier"
    case diyRepair = "diy_repair"
    case billSplit = "bill_split"
    case photoDirector = "photo_director"
    case trivia = "trivia"
    case chess = "chess"
    case driver = "driver"
    case prompter = "prompter"
    case translator = "translator"
    case tourGuide = "tour_guide"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .general: return "✨ Общий"
        case .autoExpert: return "🚗 Авто-эксперт"
        case .fitnessCalories: return "🥗 Калории и Еда"
        case .shopping: return "🛍️ Шоппинг и Цены"
        case .documents: return "📄 Документы и Лекарства"
        case .sommelier: return "🍷 Сомелье и Меню"
        case .diyRepair: return "🔧 Ремонт и Техника"
        case .billSplit: return "🧮 Чек и Калькулятор"
        case .photoDirector: return "📸 Фоторежиссер"
        case .trivia: return "🎮 Городской Квиз"
        case .chess: return "♟️ Шахматы и Логика"
        case .driver: return "🛣️ Штурман / Водитель"
        case .prompter: return "💼 Секретный Суфлер"
        case .translator: return "🌐 Переводчик текста"
        case .tourGuide: return "🏛️ Гид-экскурсовод"
        }
    }
    
    public var modeInstruction: String {
        switch self {
        case .general:
            return "Анализируй изображение в кадре и отвечай на вопрос пользователя."
        case .autoExpert:
            return "РЕЖИМ АВТО-ЭКСПЕРТ: Точно определи марку, модель, поколение/кузов автомобиля в кадре, укажи его тип двигателя, мощность и примерную рыночную стоимость."
        case .fitnessCalories:
            return "РЕЖИМ ЕДА И КАЛОРИИ: Оцени блюдо в кадре, назови ингредиенты, рассчитай примерный вес, калорийность (ккал) и БЖУ (белки, жиры, углеводы)."
        case .shopping:
            return "РЕЖИМ ШОППИНГ И ЦЕНЫ: Распознай товар (одежда, обувь, техника, часы, косметика), назови точный бренд/модель и сравни среднюю стоимость в магазинах и на маркетплейсах."
        case .documents:
            return "РЕЖИМ ДОКУМЕНТЫ И МЕДИЦИНА: Внимательно проанализируй текст договора (найди скрытые комиссии, неустойки) или упаковку препарата (дозировка, применение, противопоказания)."
        case .sommelier:
            return "РЕЖИМ СОМЕЛЬЕ И РЕСТОРАН: Проанализируй винную этикетку или блюдо в меню. Опиши сорт, регион, вкусовые ноты и посоветуй идеальное гастрономическое сочетание."
        case .diyRepair:
            return "РЕЖИМ РЕМОНТ И ТЕХНИКА: Проанализируй код ошибки прибора, схему проводки, деталь автомобиля или узел техники и дай пошаговую инструкцию по исправлению."
        case .billSplit:
            return "РЕЖИМ ЧЕК И КАЛЬКУЛЯТОР: Считай чек ресторана или магазина, выдели итоговую сумму, посчитай чаевые и раздели счет на указанное количество человек."
        case .photoDirector:
            return "РЕЖИМ ФОТОРЕЖИССЕР: Оцени композицию, свет, перспективу и положение объектов в кадре. Подскажи, как лучше повернуть голову для классного кадра."
        case .trivia:
            return "РЕЖИМ ГОРОДСКОЙ КВИЗ: Придумай короткий увлекательный вопрос-загадку о месте, памятнике или здании в кадре."
        case .chess:
            return "РЕЖИМ ШАХМАТНЫЙ ПОДСКАЗЧИК: Оцени позицию на шахматной доске в кадре и подскажи лучший тактический ход за текущую сторону в шахматной нотации."
        case .driver:
            return "РЕЖИМ ШТУРМАН: Концентрируйся на дороге, знаках, разметке и дорожной обстановке. Подсказывай полезные факты для водителя."
        case .prompter:
            return "РЕЖИМ СЕКРЕТНЫЙ СУФЛЕР: Слушай собеседника и подсказывай пользователю в ухо сильные аргументы, факты, статистику и остроумные ответы для переговоров."
        case .translator:
            return "РЕЖИМ ПЕРЕВОДЧИК ВЫВЕСОК: Найди любой иностранный текст на изображении (вывески, этикетки, меню, документы) и озвучь его точный перевод на русский язык."
        case .tourGuide:
            return "РЕЖИМ ЭКСКУРСОВОД: Расскажи краткий и захватывающий исторический/архитектурный факт о достопримечательности, здании или месте в кадре."
        }
    }
}

@MainActor
public final class ProactiveAgentManager: ObservableObject {
    public static let shared = ProactiveAgentManager()
    
    @Published public var greetingEnabled: Bool = true
    private var hasGreetedThisSession: Bool = false
    
    private init() {}
    
    public func onGlassesConnected() async {
        guard greetingEnabled, !hasGreetedThisSession else { return }
        hasGreetedThisSession = true
        
        let greeting = await generateWelcomeBrief()
        VoiceSynthesisService.shared.speak(text: greeting)
    }
    
    public func resetSession() {
        hasGreetedThisSession = false
    }
    
    public func generateWelcomeBrief() async -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "Доброе утро"
        case 12..<18: timeOfDay = "Добрый день"
        case 18..<23: timeOfDay = "Добрый вечер"
        default: timeOfDay = "Доброй ночи"
        }
        
        // Fetch weather
        let loc = LocationTool.shared.lastLocation?.coordinate
        let lat = loc?.latitude ?? 55.7558
        let lon = loc?.longitude ?? 37.6173
        let weather = await WeatherTool.shared.getWeather(latitude: lat, longitude: lon)
        
        // Fetch schedule
        let events = await CalendarTool.shared.getEvents(daysAhead: 1)
        let scheduleBrief: String
        if events.contains("Ваши события:") {
            scheduleBrief = "В вашем календаре есть запланированные дела."
        } else {
            scheduleBrief = "В календаре на сегодня свободно."
        }
        
        let persona = AppState.shared.selectedPersona
        let agentName = AppState.shared.effectiveAgentName
        switch persona {
        case .kentBro:
            return "Здорово, бро! Я \(agentName), очки на базе, заряд в порядке. На улице \(weather). \(scheduleBrief) Что замутим?"
        case .official:
            return "\(timeOfDay)! Я \(agentName). Системы очков подключены. Погода: \(weather). \(scheduleBrief) Готов к выполнению задач."
        case .jarvis:
            return "\(timeOfDay), сэр. Я \(agentName). Тактический интерфейс Ray-Ban активен. За бортом \(weather). \(scheduleBrief) Жду указаний."
        case .sarcastic:
            return "\(timeOfDay). Я \(agentName); очки надеты, мир вокруг всё ещё существует. На улице \(weather). \(scheduleBrief) Чем удивишь?"
        case .mentor:
            return "\(timeOfDay)! Я \(agentName), рад снова быть рядом. За окном \(weather). Сделай глубокий вдох, день обещает быть отличным."
        case .professor:
            return "\(timeOfDay)! Я \(agentName). Оптические сенсоры функционируют. Метеоданные: \(weather). \(scheduleBrief) К каким исследованиям приступим?"
        }
    }
}
