import Foundation

public final class AgentToolManager: @unchecked Sendable {
    public static let shared = AgentToolManager()
    
    private init() {}
    
    public var toolDeclarations: [[String: Any]] {
        return [
            [
                "name": "start_eye_gymnastics",
                "description": "Запускает 1-минутный комплекс упражнений для расслабления и отдыха глаз после работы за экраном с голосовым сопровождением. Вызывай при фразах 'Гимнастика для глаз', 'Глаза устали', 'Упражнения для зрения'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "get_posture_tip",
                "description": "Дает голосовую подсказку по контролю осанки и положению шеи при ходьбе или работе.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "analyze_speech",
                "description": "Анализирует подготовленную речь: темп, слова-паразиты и рекомендации по подаче.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "text": [
                            "type": "string",
                            "description": "Текст речи для анализа"
                        ],
                        "duration_seconds": [
                            "type": "number",
                            "description": "Длительность речи в секундах"
                        ]
                    ],
                    "required": ["text"]
                ]
            ],
            [
                "name": "calculate_bill_split",
                "description": "Считает чаевые и делит итоговый счет между людьми. Сначала извлеки сумму с изображения чека, если она есть.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "total": [
                            "type": "number",
                            "description": "Итоговая сумма счета без чаевых"
                        ],
                        "tip_percent": [
                            "type": "number",
                            "description": "Процент чаевых"
                        ],
                        "people": [
                            "type": "integer",
                            "description": "Количество людей"
                        ]
                    ],
                    "required": ["total", "people"]
                ]
            ],
            [
                "name": "get_last_glasses_location",
                "description": "Показывает на карте последнее известное местоположение очков перед разрывом связи (Анти-потеря). Вызывай при вопросах 'Где я забыл очки?', 'Где очки отключились?'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "direct_photo_composition",
                "description": "Оценивает ракурс, свет и композицию в кадре перед снимком и дает совет по постановке идеального фото.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "start_city_trivia",
                "description": "Генерирует увлекательную викторину или загадку о городе, здании или памятнике вокруг. Вызывай при фразах 'Сыграем в квиз', 'Загадай загадку о городе'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "find_my_phone",
                "description": "Включает громкую сирену и мигает вспышкой на телефоне, чтобы пользователь мог найти его в комнате. Вызывай при фразах 'Где мой телефон?', 'Найди телефон', 'Позвони на телефон'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "start_workout_rest",
                "description": "Запускает таймер отдыха между подходами на тренировке с голосовыми отсчетами в ухо. Вызывай при фразах 'Таймер отдыха на минуту/90 секунд', 'Отдых между подходами'.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "seconds": [
                            "type": "integer",
                            "description": "Количество секунд отдыха (например 60, 90, 120)"
                        ]
                    ]
                ]
            ],
            [
                "name": "find_gas_station",
                "description": "Ищет ближайшие заправки и строит к ним маршрут. Вызывай при фразах 'Найди заправку', 'Где заправиться?'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "find_car_wash",
                "description": "Ищет ближайшие автомойки. Вызывай при фразах 'Найди автомойку', 'Где помыть машину?'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "start_meeting_recording",
                "description": "Начинает фоновую запись деловой встречи, совещания или лекции для последующего составления выжимки и списка задач. Вызывай при фразах 'Записывай встречу', 'Начни запись лекции', 'Фиксируй совещание'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "finish_meeting_recording",
                "description": "Завершает запись встречи, генерирует структурированную выжимку (главные тезисы, решения, задачи) и автоматически сохраняет её в Заметки. Вызывай при фразах 'Заверши встречу', 'Итоги встречи', 'Что решили на встрече?'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "set_whisper_mode",
                "description": "Включает или выключает режим шепота / невидимки (агент говорит тихо и ультра-кратко в ухо).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "enabled": [
                            "type": "boolean",
                            "description": "true — включить шепот, false — выключить"
                        ]
                    ],
                    "required": ["enabled"]
                ]
            ],
            [
                "name": "identify_music",
                "description": "Распознает музыку, играющую вокруг пользователя (Шазам через очки).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "context_hint": [
                            "type": "string",
                            "description": "Подсказка о месте или стиле музыки"
                        ]
                    ]
                ]
            ],
            [
                "name": "clean_glasses_memory",
                "description": "Очищает оперативную память, видео-буферы, кэш снимков и временные файлы очков и приложения для освобождения памяти и ускорения работы. Вызывай при фразах 'Очисти память очков', 'Освободи память', 'Очисти кэш', 'Очисти буфер'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "get_storage_info",
                "description": "Проверяет состояние оперативной памяти, размер кэша и свободное место на устройстве. Вызывай при вопросах 'Сколько памяти свободно?', 'Проверь память очков'.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "start_live_interpreter",
                "description": "Включает режим синхронного живого переводчика диалога между пользователем и иностранцем в реальном времени. Вызывай при фразах 'Я начинаю диалог с иностранцем', 'Помоги мне поговорить с иностранцем', 'Включи переводчик с английского/испанского/китайского' и т.д.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "foreign_language": [
                            "type": "string",
                            "description": "Язык иностранного собеседника (например 'Английский', 'Испанский', 'Китайский', 'Немецкий', 'Турецкий')"
                        ]
                    ]
                ]
            ],
            [
                "name": "stop_live_interpreter",
                "description": "Выключает режим синхронного переводчика диалога.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "control_home_device",
                "description": "Управляет устройствами умного дома Apple HomeKit (свет, кондиционер, выключатели, розетки, замки).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "device_type": [
                            "type": "string",
                            "description": "Тип или название устройства (например 'свет', 'люстра', 'кондиционер')"
                        ],
                        "room": [
                            "type": "string",
                            "description": "Название комнаты (например 'гостиная', 'спальня', 'кухня')"
                        ],
                        "action": [
                            "type": "string",
                            "description": "Действие: 'включить' или 'выключить'"
                        ]
                    ],
                    "required": ["device_type", "action"]
                ]
            ],
            [
                "name": "get_health_stats",
                "description": "Получает данные о физической активности пользователя за сегодня из Apple Health (шаги, пройденные километры, сожженные активные калории).",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "save_voice_note",
                "description": "Сохраняет быструю голосовую мысль, идею, список покупок или заметку.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Краткий заголовок заметки"
                        ],
                        "content": [
                            "type": "string",
                            "description": "Текст заметки или мысли"
                        ],
                        "category": [
                            "type": "string",
                            "description": "Категория: 'Идеи', 'Покупки', 'Работа', 'Мысли'"
                        ]
                    ],
                    "required": ["title", "content"]
                ]
            ],
            [
                "name": "get_voice_notes",
                "description": "Читает сохраненные заметки или идеи пользователя.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "category": [
                            "type": "string",
                            "description": "Категория для фильтрации (например 'Идеи')"
                        ]
                    ]
                ]
            ],
            [
                "name": "save_person_info",
                "description": "Запоминает информацию о новом человеке, знакомом или коллеге (имя, должность, внешность, контакты).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Имя человека"
                        ],
                        "role": [
                            "type": "string",
                            "description": "Кем приходится или должность (например 'коллега', 'дизайнер', 'сосед')"
                        ],
                        "details": [
                            "type": "string",
                            "description": "Любые важные детали (внешность, контекст встречи, темы для разговора)"
                        ]
                    ],
                    "required": ["name", "role", "details"]
                ]
            ],
            [
                "name": "recall_person_info",
                "description": "Ищет информацию о человеке по имени или контексту ('кто передо мной', 'расскажи про Максима').",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Имя человека для поиска"
                        ]
                    ],
                    "required": ["name"]
                ]
            ],
            [
                "name": "get_latest_news",
                "description": "Получает актуальную сводку новостей и мировых событий.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "topic": [
                            "type": "string",
                            "description": "Тематика (например 'технологии', 'автомобили', 'спорт', 'главное')"
                        ]
                    ]
                ]
            ],
            [
                "name": "set_alarm",
                "description": "Устанавливает будильник на заданное время. Вызывай при просьбах 'поставь будильник', 'разбуди меня в 7:30'.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "hour": [
                            "type": "integer",
                            "description": "Час от 0 до 23"
                        ],
                        "minute": [
                            "type": "integer",
                            "description": "Минута от 0 до 59"
                        ],
                        "label": [
                            "type": "string",
                            "description": "Текст будильника"
                        ],
                        "tomorrow": [
                            "type": "boolean",
                            "description": "Установить на завтра"
                        ]
                    ],
                    "required": ["hour", "minute"]
                ]
            ],
            [
                "name": "set_timer",
                "description": "Устанавливает таймер на указанное количество секунд с названием. Вызывай, когда пользователь просит поставить таймер (например на 5 минут, 10 секунд и т.д.).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "seconds": [
                            "type": "integer",
                            "description": "Количество секунд для таймера (например 600 для 10 минут)"
                        ],
                        "label": [
                            "type": "string",
                            "description": "Название таймера, например 'Варка пасты', 'Сон'"
                        ]
                    ],
                    "required": ["seconds"]
                ]
            ],
            [
                "name": "get_calendar_events",
                "description": "Получает список событий из календаря пользователя на сегодня или ближайшие дни. Вызывай при вопросах 'Что у меня на сегодня?', 'Какие планы?' и т.д.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "days_ahead": [
                            "type": "integer",
                            "description": "Количество дней для проверки (по умолчанию 1)"
                        ]
                    ]
                ]
            ],
            [
                "name": "create_calendar_event",
                "description": "Создает новое событие или встречу в календаре.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Название встречи или события"
                        ],
                        "minutes_from_now": [
                            "type": "integer",
                            "description": "Через сколько минут от текущего момента начнется событие (например 60 если через час, 1440 если завтра)"
                        ],
                        "duration_minutes": [
                            "type": "integer",
                            "description": "Длительность в минутах (по умолчанию 60)"
                        ]
                    ],
                    "required": ["title"]
                ]
            ],
            [
                "name": "add_reminder",
                "description": "Добавляет задачу в список напоминаний пользователя.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Текст напоминания, например 'Купить молоко'"
                        ]
                    ],
                    "required": ["title"]
                ]
            ],
            [
                "name": "control_music",
                "description": "Управляет воспроизведением музыки в плеере устройства (пауза, следующий трек, воспроизведение, предыдущий).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "description": "Команда: 'play', 'pause', 'next', 'previous'"
                        ]
                    ],
                    "required": ["action"]
                ]
            ],
            [
                "name": "send_message",
                "description": "Отправляет или подготавливает сообщение в Telegram, WhatsApp или СМС.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "platform": [
                            "type": "string",
                            "description": "Платформа: 'telegram', 'whatsapp' или 'sms'"
                        ],
                        "text": [
                            "type": "string",
                            "description": "Текст сообщения для отправки"
                        ],
                        "recipient": [
                            "type": "string",
                            "description": "Имя получателя или номер телефона (для СМС)"
                        ]
                    ],
                    "required": ["platform", "text"]
                ]
            ],
            [
                "name": "make_phone_call",
                "description": "Совершает телефонный звонок по номеру телефона.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "phone_number": [
                            "type": "string",
                            "description": "Номер телефона для набора"
                        ]
                    ],
                    "required": ["phone_number"]
                ]
            ],
            [
                "name": "get_exchange_rates",
                "description": "Получает актуальные курсы валют (доллар, евро, юань, дирхам к рублю).",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "get_crypto_prices",
                "description": "Получает актуальные цены основных криптовалют (Bitcoin, Ethereum, TON, Solana).",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "get_weather",
                "description": "Получает актуальную информацию о текущей погоде и осадках.",
                "parameters": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "log_object_location",
                "description": "Запоминает, где был оставлен или увиден предмет (ключи, кошелек, парковочное место, документ).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "object_name": [
                            "type": "string",
                            "description": "Название предмета (например 'ключи от квартиры', 'паспорт')"
                        ],
                        "location_description": [
                            "type": "string",
                            "description": "Где находится предмет (например 'на тумбочке в коридоре')"
                        ]
                    ],
                    "required": ["object_name", "location_description"]
                ]
            ],
            [
                "name": "find_object",
                "description": "Ищет информацию о том, где пользователь оставил вещь (ключи, документы, кошелек).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Что ищем (например 'ключи', 'кошелек')"
                        ]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "save_memory",
                "description": "Сохраняет важный факт, заметку, код или воспоминание в постоянную память (например где припаркована машина, код от двери, имя знакомого).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "key": [
                            "type": "string",
                            "description": "Ключ/тема памяти, например 'парковка', 'код домофона', 'друг Андрей'"
                        ],
                        "value": [
                            "type": "string",
                            "description": "Информация для запоминания, например 'место B12 на подземной парковке'"
                        ]
                    ],
                    "required": ["key", "value"]
                ]
            ],
            [
                "name": "recall_memory",
                "description": "Ищет в памяти сохраненные факты, заметки, пароли, коды или локации.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Что нужно вспомнить, например 'где машина', 'код от двери'"
                        ]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "open_maps",
                "description": "Открывает карты и ищет места поблизости (кофейня, аптека, адрес, заправка).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Запрос поиска, например 'ближайшая кофейня' или адрес"
                        ]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "trigger_sos_alert",
                "description": "Отправляет экстренный сигнал тревоги с текущими GPS-координатами.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "contact_phone": [
                            "type": "string",
                            "description": "Номер телефона экстренного контакта"
                        ]
                    ]
                ]
            ]
        ]
    }
    
    @MainActor
    public func executeTool(name: String, arguments: [String: Any]) async -> String {
        switch name {
        case "start_eye_gymnastics":
            return EyeAndPostureCoachTool.shared.startEyeGymnastics()
            
        case "get_posture_tip":
            return EyeAndPostureCoachTool.shared.getPostureTip()
            
        case "analyze_speech":
            let text = arguments["text"] as? String ?? ""
            let duration = arguments["duration_seconds"] as? Double ?? 30.0
            return SpeechCoachTool.shared.analyzeSpeech(text: text, durationSeconds: duration)
            
        case "calculate_bill_split":
            let total = arguments["total"] as? Double ?? 0
            let tip = arguments["tip_percent"] as? Double ?? 0
            let people = arguments["people"] as? Int ?? 1
            return BillCalculatorTool.shared.split(total: total, tipPercent: tip, people: people)
            
        case "get_last_glasses_location":
            return AntiLostSentinelTool.shared.getLastKnownGlassesLocation()
            
        case "direct_photo_composition":
            return await PhotoDirectorTool.shared.directPhotoComposition()
            
        case "start_city_trivia":
            return await CityTriviaTool.shared.startCityTrivia()
            
        case "find_my_phone":
            return FindMyPhoneTool.shared.triggerFindPhoneAlarm()
            
        case "start_workout_rest":
            let secs = arguments["seconds"] as? Int ?? 60
            return WorkoutCoachTool.shared.startRestTimer(seconds: secs)
            
        case "find_gas_station":
            return DriverCopilotTool.shared.findGasStation()
            
        case "find_car_wash":
            return DriverCopilotTool.shared.findCarWash()
            
        case "start_meeting_recording":
            return MeetingTranscriberTool.shared.startMeetingRecording()
            
        case "finish_meeting_recording":
            return await MeetingTranscriberTool.shared.finishMeetingAndSummarize()
            
        case "set_whisper_mode":
            let enabled = arguments["enabled"] as? Bool ?? true
            return WhisperModeTool.shared.setWhisperMode(enabled: enabled)
            
        case "identify_music":
            let hint = arguments["context_hint"] as? String
            return await MusicIdentifierTool.shared.identifyMusic(contextHint: hint)
            
        case "clean_glasses_memory":
            let result = GlassesStorageManager.shared.clearMemoryAndCache()
            return result.message
            
        case "get_storage_info":
            GlassesStorageManager.shared.updateReport()
            if let rep = GlassesStorageManager.shared.currentReport {
                return "Состояние памяти: Кэш очков: \(String(format: "%.1f", rep.cacheSizeMB + rep.tempSizeMB)) МБ, Оперативная память приложения: \(Int(rep.appMemoryMB)) МБ, Свободно на диске: \(String(format: "%.1f", rep.freeDiskSpaceGB)) ГБ. Статус: \(rep.statusDescription)."
            }
            return "Память очков проверена, состояние стабильное."
            
        case "start_live_interpreter":
            let lang = arguments["foreign_language"] as? String ?? "Английский"
            LiveInterpreterService.shared.startInterpreter(foreignLanguage: lang)
            return "Режим живого переводчика (\(lang)) активирован."
            
        case "stop_live_interpreter":
            LiveInterpreterService.shared.stopInterpreter()
            return "Режим переводчика выключен."
            
        case "control_home_device":
            let dev = arguments["device_type"] as? String ?? "свет"
            let room = arguments["room"] as? String
            let action = arguments["action"] as? String ?? "включить"
            return await HomeKitTool.shared.controlDevice(room: room, deviceType: dev, action: action)
            
        case "get_health_stats":
            return await HealthKitTool.shared.getTodayHealthStats()
            
        case "save_voice_note":
            let title = arguments["title"] as? String ?? "Заметка"
            let content = arguments["content"] as? String ?? ""
            let cat = arguments["category"] as? String ?? "Идеи"
            return VoiceNotesTool.shared.saveNote(title: title, content: content, category: cat)
            
        case "get_voice_notes":
            let cat = arguments["category"] as? String
            return VoiceNotesTool.shared.getNotes(category: cat)
            
        case "save_person_info":
            let name = arguments["name"] as? String ?? "Знакомый"
            let role = arguments["role"] as? String ?? "контакт"
            let details = arguments["details"] as? String ?? ""
            return PeopleMemoryTool.shared.savePerson(name: name, role: role, details: details)
            
        case "recall_person_info":
            let name = arguments["name"] as? String ?? ""
            return PeopleMemoryTool.shared.recallPerson(name: name)
            
        case "get_latest_news":
            let topic = arguments["topic"] as? String
            return await NewsAndWebTool.shared.getLatestNews(topic: topic)
            
        case "set_alarm":
            let hour = arguments["hour"] as? Int ?? 7
            let minute = arguments["minute"] as? Int ?? 0
            let label = arguments["label"] as? String ?? "Будильник"
            let tomorrow = arguments["tomorrow"] as? Bool ?? false
            return await AlarmTool.shared.setAlarm(hour: hour, minute: minute, label: label, tomorrow: tomorrow)
            
        case "set_timer":
            let seconds = arguments["seconds"] as? Int ?? 60
            let label = arguments["label"] as? String ?? "Таймер"
            return await TimerTool.shared.setTimer(seconds: seconds, label: label)
            
        case "get_calendar_events":
            let days = arguments["days_ahead"] as? Int ?? 1
            return await CalendarTool.shared.getEvents(daysAhead: days)
            
        case "create_calendar_event":
            let title = arguments["title"] as? String ?? "Новое событие"
            let minutesAhead = arguments["minutes_from_now"] as? Int ?? 60
            let duration = arguments["duration_minutes"] as? Int ?? 60
            let date = Date().addingTimeInterval(TimeInterval(minutesAhead * 60))
            return await CalendarTool.shared.createEvent(title: title, startDate: date, durationMinutes: duration)
            
        case "add_reminder":
            let title = arguments["title"] as? String ?? "Напоминание"
            return await RemindersTool.shared.addReminder(title: title)
            
        case "control_music":
            let action = arguments["action"] as? String ?? "play"
            return MusicTool.shared.control(action: action)
            
        case "send_message":
            let platform = arguments["platform"] as? String ?? "telegram"
            let text = arguments["text"] as? String ?? ""
            let recipient = arguments["recipient"] as? String
            return CommunicationTool.shared.sendMessage(platform: platform, text: text, recipient: recipient)
            
        case "make_phone_call":
            let phone = arguments["phone_number"] as? String ?? ""
            return CommunicationTool.shared.makeCall(phoneNumber: phone)
            
        case "get_exchange_rates":
            return await FinanceTool.shared.getExchangeRates()
            
        case "get_crypto_prices":
            return await FinanceTool.shared.getCryptoPrices()
            
        case "get_weather":
            let loc = LocationTool.shared.lastLocation?.coordinate
            let lat = loc?.latitude ?? 55.7558
            let lon = loc?.longitude ?? 37.6173
            return await WeatherTool.shared.getWeather(latitude: lat, longitude: lon)
            
        case "log_object_location":
            let obj = arguments["object_name"] as? String ?? "Предмет"
            let loc = arguments["location_description"] as? String ?? "не указано"
            return ObjectFinderTool.shared.logObjectLocation(objectName: obj, locationDescription: loc)
            
        case "find_object":
            let q = arguments["query"] as? String ?? ""
            return ObjectFinderTool.shared.findObject(query: q)
            
        case "save_memory":
            let key = arguments["key"] as? String ?? "Заметка"
            let val = arguments["value"] as? String ?? ""
            return MemoryTool.shared.saveMemory(key: key, value: val)
            
        case "recall_memory":
            let q = arguments["query"] as? String ?? ""
            return MemoryTool.shared.recallMemory(query: q)
            
        case "open_maps":
            let q = arguments["query"] as? String ?? "кофейня"
            return LocationTool.shared.openMaps(query: q)
            
        case "trigger_sos_alert":
            let phone = arguments["contact_phone"] as? String
            return SOSSentinelTool.shared.triggerSOSAlert(contactPhone: phone)
            
        default:
            return "Инструмент \(name) не поддерживается."
        }
    }
}
