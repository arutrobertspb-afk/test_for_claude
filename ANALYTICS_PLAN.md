# AzmyAI — План аналитических событий

> **Версия:** 1.0
> **Дата:** 4 декабря 2025
> **Цель:** Сбор данных о поведении пользователей для улучшения MVP

---

## Содержание

1. [Обзор архитектуры](#1-обзор-архитектуры)
2. [События чата и AI](#2-события-чата-и-ai)
3. [События голосового ввода](#3-события-голосового-ввода)
4. [События онбординга](#4-события-онбординга)
5. [События навигации](#5-события-навигации)
6. [События календаря](#6-события-календаря)
7. [События профиля и настроек](#7-события-профиля-и-настроек)
8. [События инсайтов и статистики](#8-события-инсайтов-и-статистики)
9. [Системные события](#9-системные-события)
10. [Рекомендации по реализации](#10-рекомендации-по-реализации)

---

## 1. Обзор архитектуры

### Текущее состояние
- **Аналитика:** Не реализована
- **Логирование:** Только `print()` для отладки
- **Персистентность:** UserDefaults для состояний

### Основные экраны приложения

| Экран | Файл | Описание |
|-------|------|----------|
| Home (Dashboard) | `HomeView.swift` | Главный дашборд с карточками |
| Chat | `ChatView.swift` | Чат с AI ассистентом |
| Calendar | `CalendarView.swift` | Календарь событий |
| Insights | `InsightsView.swift` | Аналитика здоровья |
| Statistics | `StatisticsView.swift` | Метрики активности |
| Profile | `ProfileView.swift` | Настройки и профиль |
| Onboarding | `OnboardingView.swift` | 6-шаговый онбординг |

---

## 2. События чата и AI

### Критически важные события для понимания взаимодействия с GPT

---

### 2.1 `chat_message_sent`
**Экран:** ChatView / HomeView (Page 1)
**Файл:** `ChatViewModel.swift` → `sendMessage()`
**Триггер:** Пользователь отправил сообщение

| Параметр | Тип | Описание |
|----------|-----|----------|
| `message_id` | String | UUID сообщения |
| `message_text` | String | Текст сообщения (с хэшированием для приватности) |
| `message_length` | Int | Количество символов |
| `word_count` | Int | Количество слов |
| `input_method` | String | `text` / `voice` |
| `conversation_turn` | Int | Номер сообщения в диалоге |
| `has_question_mark` | Bool | Содержит ли вопрос |
| `language` | String | Язык сообщения (определять автоматически) |
| `time_since_last_message` | Int | Секунд с прошлого сообщения |
| `session_id` | String | ID текущей сессии |

**Зачем:** Понять частоту и характер запросов к AI.

---

### 2.2 `chat_message_received`
**Экран:** ChatView / HomeView
**Файл:** `ChatViewModel.swift` → после ответа `AzmyAIService`
**Триггер:** AI ответил на сообщение

| Параметр | Тип | Описание |
|----------|-----|----------|
| `message_id` | String | UUID ответа |
| `response_length` | Int | Длина ответа в символах |
| `response_time_ms` | Int | Время ожидания ответа |
| `had_retry` | Bool | Были ли повторные попытки |
| `retry_count` | Int | Количество попыток |
| `has_suggestions` | Bool | Есть ли suggested actions |
| `suggestion_count` | Int | Количество предложенных действий |
| `used_tools` | [String] | Какие инструменты использовал AI |
| `conversation_turn` | Int | Номер ответа в диалоге |

**Зачем:** Оценить качество и скорость AI.

---

### 2.3 `chat_message_category` ⭐
**Экран:** ChatView
**Файл:** Новый сервис классификации
**Триггер:** После отправки сообщения (async)

| Параметр | Тип | Описание |
|----------|-----|----------|
| `message_id` | String | UUID сообщения |
| `category` | String | Категория запроса (см. ниже) |
| `subcategory` | String | Подкатегория |
| `intent` | String | Намерение пользователя |
| `sentiment` | String | `positive` / `neutral` / `negative` |
| `urgency` | String | `low` / `medium` / `high` |

**Категории запросов:**
```
productivity     - Задачи, планирование, работа
health           - Здоровье, сон, питание, спорт
calendar         - События, расписание, напоминания
learning         - Обучение, советы, информация
relationships    - Социальное, общение
mood             - Эмоции, настроение, стресс
reflection       - Самоанализ, цели
small_talk       - Общение, болтовня
technical        - Вопросы о приложении
other            - Прочее
```

**Зачем:** Главный источник инсайтов о том, что интересно пользователям!

---

### 2.4 `quick_prompt_tapped`
**Экран:** ChatView / HomeView
**Файл:** `ChatView.swift` → QuickPromptBar
**Триггер:** Нажатие на быстрый промпт

| Параметр | Тип | Описание |
|----------|-----|----------|
| `prompt_id` | String | ID промпта |
| `prompt_title` | String | Название ("Plan my day", etc.) |
| `prompt_category` | String | `planning` / `wellness` / `productivity` / `reflection` |
| `prompt_position` | Int | Позиция в списке (0-based) |
| `is_first_message` | Bool | Первое сообщение в чате? |

**Зачем:** Понять какие готовые промпты популярны.

---

### 2.5 `suggested_action_tapped`
**Экран:** ChatView
**Файл:** `ChatView.swift` → SuggestedActionButton
**Триггер:** Нажатие на предложенное действие

| Параметр | Тип | Описание |
|----------|-----|----------|
| `action_id` | String | ID действия |
| `action_type` | String | `createEvent` / `setReminder` / `suggestTask` / `viewInsight` / `quickReply` / `openQuiz` |
| `action_title` | String | Текст кнопки |
| `message_id` | String | ID сообщения с этим action |
| `position` | Int | Позиция среди других actions |
| `time_to_tap_ms` | Int | Время от появления до нажатия |

**Зачем:** Оценить полезность AI предложений.

---

### 2.6 `chat_error_occurred`
**Экран:** ChatView
**Файл:** `AzmyAIService.swift`
**Триггер:** Ошибка при запросе к AI

| Параметр | Тип | Описание |
|----------|-----|----------|
| `error_type` | String | Тип ошибки |
| `error_message` | String | Сообщение (без sensitive data) |
| `retry_attempt` | Int | Номер попытки |
| `will_retry` | Bool | Будет ли повтор |
| `conversation_turn` | Int | На каком ходе произошло |

**Зачем:** Мониторинг стабильности AI.

---

### 2.7 `chat_streaming_interaction`
**Экран:** ChatView
**Файл:** `ChatView.swift`
**Триггер:** Взаимодействие со streaming текстом

| Параметр | Тип | Описание |
|----------|-----|----------|
| `action` | String | `skip_streaming` / `wait_complete` |
| `characters_shown` | Int | Сколько символов было показано |
| `total_characters` | Int | Всего символов в ответе |
| `skip_percentage` | Float | % показанного при skip |

**Зачем:** Понять терпение пользователей.

---

### 2.8 `chat_conversation_cleared`
**Экран:** ChatView
**Файл:** `ChatViewModel.swift` → `clearChat()`
**Триггер:** Очистка истории чата

| Параметр | Тип | Описание |
|----------|-----|----------|
| `messages_count` | Int | Сколько сообщений было |
| `conversation_duration_min` | Int | Длительность диалога |
| `session_id` | String | ID сессии |

**Зачем:** Понять циклы использования.

---

## 3. События голосового ввода

### 3.1 `voice_recording_started`
**Экран:** ChatView / HomeView
**Файл:** `ChatView.swift` → VoiceRecordButton
**Триггер:** Начало записи голоса

| Параметр | Тип | Описание |
|----------|-----|----------|
| `session_id` | String | ID сессии |
| `is_first_voice_use` | Bool | Первое использование голоса? |
| `onboarding_shown` | Bool | Показан ли был тултип |
| `input_context` | String | `empty_chat` / `ongoing_chat` |

**Зачем:** Трекинг adoption голосовой функции.

---

### 3.2 `voice_recording_completed`
**Экран:** ChatView
**Файл:** `VoicePipelineManager.swift`
**Триггер:** Запись завершена и отправлена

| Параметр | Тип | Описание |
|----------|-----|----------|
| `duration_seconds` | Float | Длительность записи |
| `audio_level_avg` | Float | Средний уровень громкости |
| `was_cancelled` | Bool | Была ли отменена |
| `cancel_method` | String | `swipe` / `tap` / `none` |

**Зачем:** Понять паттерны голосового ввода.

---

### 3.3 `voice_transcription_completed`
**Экран:** ChatView
**Файл:** `VoxtralService.swift`
**Триггер:** Транскрипция завершена

| Параметр | Тип | Описание |
|----------|-----|----------|
| `transcription_time_ms` | Int | Время транскрипции |
| `raw_text_length` | Int | Длина сырого текста |
| `cleaned_text_length` | Int | Длина очищенного текста |
| `cleanup_ratio` | Float | Соотношение (показывает качество речи) |
| `word_count` | Int | Количество слов |
| `language_detected` | String | Определённый язык |

**Зачем:** Оценка качества голосового ввода.

---

### 3.4 `voice_transcription_error`
**Экран:** ChatView
**Файл:** `VoicePipelineManager.swift`
**Триггер:** Ошибка транскрипции

| Параметр | Тип | Описание |
|----------|-----|----------|
| `error_stage` | String | `recording` / `transcription` / `cleanup` |
| `error_type` | String | Тип ошибки |
| `duration_before_error` | Float | Длительность до ошибки |

**Зачем:** Мониторинг проблем с голосом.

---

### 3.5 `voice_onboarding_interaction`
**Экран:** ChatView
**Файл:** `ChatView.swift` → VoiceOnboardingTooltip
**Триггер:** Взаимодействие с тултипом

| Параметр | Тип | Описание |
|----------|-----|----------|
| `action` | String | `shown` / `dismissed` / `followed_instruction` |
| `time_visible_ms` | Int | Сколько был виден |
| `led_to_recording` | Bool | Привёл ли к записи |

**Зачем:** Эффективность онбординга голоса.

---

## 4. События онбординга

### 4.1 `onboarding_step_viewed`
**Экран:** OnboardingView
**Файл:** `OnboardingView.swift`
**Триггер:** Показ шага онбординга

| Параметр | Тип | Описание |
|----------|-----|----------|
| `step_number` | Int | 0-5 |
| `step_name` | String | `welcome` / `signin` / `goals` / `chronotype` / `workstyle` / `permissions` |
| `time_on_previous_step_sec` | Int | Время на предыдущем шаге |
| `is_returning` | Bool | Вернулся ли назад |

**Зачем:** Воронка онбординга.

---

### 4.2 `onboarding_step_completed`
**Экран:** OnboardingView
**Файл:** `OnboardingView.swift`
**Триггер:** Завершение шага

| Параметр | Тип | Описание |
|----------|-----|----------|
| `step_number` | Int | 0-5 |
| `step_name` | String | Название шага |
| `time_spent_sec` | Int | Время на шаге |
| `data_entered` | Object | Введённые данные (см. ниже) |

**Данные по шагам:**
- **Step 0 (Welcome):** `{ name_length: Int }`
- **Step 1 (SignIn):** `{ method: "google"/"apple"/"skipped" }`
- **Step 2 (Goals):** `{ goals: [String], count: Int }`
- **Step 3 (Chronotype):** `{ type: "earlyBird"/"nightOwl"/"neutral" }`
- **Step 4 (WorkStyle):** `{ style: "deepWork"/"collaborative"/"balanced" }`
- **Step 5 (Permissions):** `{ calendar: Bool, health: Bool, google_calendar: Bool }`

**Зачем:** Понять предпочтения пользователей.

---

### 4.3 `onboarding_completed`
**Экран:** OnboardingView
**Файл:** `OnboardingView.swift` → `completeOnboarding()`
**Триггер:** Онбординг завершён

| Параметр | Тип | Описание |
|----------|-----|----------|
| `total_time_sec` | Int | Общее время онбординга |
| `steps_completed` | Int | Количество завершённых шагов |
| `auth_method` | String | Метод авторизации |
| `goals_selected` | [String] | Выбранные цели |
| `chronotype` | String | Хронотип |
| `work_style` | String | Стиль работы |
| `permissions_granted` | Object | Какие разрешения даны |

**Зачем:** Профилирование новых пользователей.

---

### 4.4 `onboarding_abandoned`
**Экран:** OnboardingView
**Файл:** `OnboardingView.swift` (при закрытии/выходе)
**Триггер:** Пользователь покинул онбординг

| Параметр | Тип | Описание |
|----------|-----|----------|
| `last_step` | Int | Последний просмотренный шаг |
| `last_step_name` | String | Название последнего шага |
| `time_spent_sec` | Int | Общее время |
| `reason` | String | `app_closed` / `background` / `crash` |

**Зачем:** Выявить проблемные места онбординга.

---

### 4.5 `goal_selected` / `goal_deselected`
**Экран:** OnboardingView (Step 2)
**Файл:** `OnboardingView.swift`
**Триггер:** Выбор/снятие цели

| Параметр | Тип | Описание |
|----------|-----|----------|
| `goal` | String | Выбранная цель |
| `action` | String | `selected` / `deselected` |
| `current_selection_count` | Int | Текущее количество выбранных |
| `selection_order` | Int | Порядок выбора |

**Зачем:** Понять приоритеты пользователей.

---

## 5. События навигации

### 5.1 `screen_viewed`
**Экран:** Все
**Файл:** `ContentView.swift`, `HomeView.swift`
**Триггер:** Переход на экран

| Параметр | Тип | Описание |
|----------|-----|----------|
| `screen_name` | String | Название экрана |
| `previous_screen` | String | Предыдущий экран |
| `navigation_method` | String | `tab_tap` / `swipe` / `deep_link` / `push` |
| `time_on_previous_sec` | Int | Время на предыдущем экране |

**Зачем:** Карта навигации пользователей.

---

### 5.2 `tab_switched`
**Экран:** ContentView (TabView)
**Файл:** `ContentView.swift`
**Триггер:** Переключение таба

| Параметр | Тип | Описание |
|----------|-----|----------|
| `from_tab` | String | `home` / `calendar` / `insights` / `statistics` / `profile` |
| `to_tab` | String | Целевой таб |
| `tap_count_session` | Int | Количество переключений в сессии |

**Зачем:** Понять популярность разделов.

---

### 5.3 `home_page_swiped`
**Экран:** HomeView
**Файл:** `HomeView.swift`
**Триггер:** Свайп между dashboard и chat

| Параметр | Тип | Описание |
|----------|-----|----------|
| `from_page` | String | `dashboard` / `chat` |
| `to_page` | String | Целевая страница |
| `swipe_velocity` | Float | Скорость свайпа |
| `time_on_previous_sec` | Int | Время на предыдущей странице |

**Зачем:** Понять паттерн использования TikTok-навигации.

---

### 5.4 `dashboard_card_tapped`
**Экран:** HomeView (Dashboard)
**Файл:** `HomeView.swift`
**Триггер:** Нажатие на карточку дашборда

| Параметр | Тип | Описание |
|----------|-----|----------|
| `card_type` | String | `weather` / `tasks` / `sleep` / `ai_tip` / `quick_action` |
| `card_position` | Int | Позиция на экране |
| `card_data` | Object | Контекст карточки |

**Зачем:** Понять интерес к виджетам.

---

## 6. События календаря

### 6.1 `event_created`
**Экран:** CalendarView
**Файл:** `PlannerViewModel.swift` → `createEvent()`
**Триггер:** Создание события

| Параметр | Тип | Описание |
|----------|-----|----------|
| `event_id` | String | ID события |
| `creation_source` | String | `manual` / `ai_suggested` / `quick_action` |
| `has_title` | Bool | Есть ли название |
| `is_all_day` | Bool | Весь день? |
| `duration_minutes` | Int | Длительность |
| `days_in_future` | Int | Через сколько дней |
| `has_location` | Bool | Указано ли место |
| `category` | String | Категория события |

**Зачем:** Понять использование календаря.

---

### 6.2 `event_viewed`
**Экран:** CalendarView
**Файл:** `CalendarView.swift`
**Триггер:** Просмотр деталей события

| Параметр | Тип | Описание |
|----------|-----|----------|
| `event_id` | String | ID события |
| `event_source` | String | `local` / `google` / `ai_created` |
| `view_duration_sec` | Int | Время просмотра |

---

### 6.3 `calendar_date_selected`
**Экран:** CalendarView
**Файл:** `CalendarView.swift`
**Триггер:** Выбор даты в календаре

| Параметр | Тип | Описание |
|----------|-----|----------|
| `selected_date` | Date | Выбранная дата |
| `days_from_today` | Int | Дней от сегодня (+/-) |
| `events_on_date` | Int | Событий в этот день |
| `selection_method` | String | `tap` / `swipe` |

**Зачем:** Понять горизонт планирования.

---

## 7. События профиля и настроек

### 7.1 `permission_toggled`
**Экран:** ProfileView
**Файл:** `ProfileView.swift`
**Триггер:** Изменение разрешения

| Параметр | Тип | Описание |
|----------|-----|----------|
| `permission_type` | String | `calendar` / `health` / `microphone` / `google_calendar` |
| `new_state` | Bool | Новое состояние |
| `was_prompted` | Bool | Был ли системный промпт |

**Зачем:** Трекинг разрешений.

---

### 7.2 `notification_setting_changed`
**Экран:** ProfileView
**Файл:** `ProfileView.swift`
**Триггер:** Изменение настроек уведомлений

| Параметр | Тип | Описание |
|----------|-----|----------|
| `setting` | String | `enabled` / `morning_time` / `evening_time` |
| `old_value` | Any | Предыдущее значение |
| `new_value` | Any | Новое значение |

---

### 7.3 `logout_initiated`
**Экран:** ProfileView
**Файл:** `ProfileView.swift`
**Триггер:** Нажатие кнопки выхода

| Параметр | Тип | Описание |
|----------|-----|----------|
| `confirmed` | Bool | Подтверждён ли выход |
| `session_duration_min` | Int | Длительность сессии |
| `messages_sent_session` | Int | Сообщений за сессию |

**Зачем:** Понять retention.

---

### 7.4 `support_contacted`
**Экран:** ProfileView
**Файл:** `ProfileView.swift`
**Триггер:** Нажатие "Contact Us"

| Параметр | Тип | Описание |
|----------|-----|----------|
| `contact_method` | String | `email` |
| `session_context` | String | Контекст (после ошибки?) |

---

## 8. События инсайтов и статистики

### 8.1 `insights_viewed`
**Экран:** InsightsView
**Файл:** `InsightsView.swift`
**Триггер:** Просмотр раздела инсайтов

| Параметр | Тип | Описание |
|----------|-----|----------|
| `timeframe` | String | `week` / `month` / `year` |
| `data_available` | Object | Какие данные доступны |
| `scroll_depth` | Float | Глубина прокрутки (0-1) |

---

### 8.2 `quiz_started`
**Экран:** InsightsView / QuizView
**Файл:** `QuizViewModel.swift` → `startQuiz()`
**Триггер:** Начало квиза

| Параметр | Тип | Описание |
|----------|-----|----------|
| `quiz_id` | String | ID квиза |
| `quiz_type` | String | Тип квиза |
| `entry_point` | String | `insights` / `chat_suggestion` / `onboarding` |

---

### 8.3 `quiz_completed`
**Экран:** QuizView
**Файл:** `QuizViewModel.swift` → `submitQuiz()`
**Триггер:** Завершение квиза

| Параметр | Тип | Описание |
|----------|-----|----------|
| `quiz_id` | String | ID квиза |
| `completion_time_sec` | Int | Время прохождения |
| `answers_count` | Int | Количество ответов |
| `result_summary` | Object | Результаты |

---

### 8.4 `statistics_metric_viewed`
**Экран:** StatisticsView
**Файл:** `StatisticsView.swift`
**Триггер:** Просмотр метрики

| Параметр | Тип | Описание |
|----------|-----|----------|
| `metric_type` | String | `steps` / `energy` / `sleep` / `heart_rate` |
| `has_data` | Bool | Есть ли данные |
| `time_viewed_sec` | Int | Время просмотра |

**Зачем:** Понять интерес к здоровью.

---

## 9. Системные события

### 9.1 `app_opened`
**Экран:** —
**Файл:** `AzmyAIApp.swift`
**Триггер:** Запуск приложения

| Параметр | Тип | Описание |
|----------|-----|----------|
| `launch_type` | String | `cold` / `warm` / `background` |
| `time_since_last_open_hours` | Float | Часов с последнего запуска |
| `notification_triggered` | Bool | Запуск из уведомления? |
| `deep_link` | String? | Deep link если есть |
| `app_version` | String | Версия приложения |
| `os_version` | String | Версия iOS |
| `device_model` | String | Модель устройства |

---

### 9.2 `app_backgrounded`
**Экран:** —
**Файл:** `AzmyAIApp.swift`
**Триггер:** Уход в фон

| Параметр | Тип | Описание |
|----------|-----|----------|
| `session_duration_sec` | Int | Длительность сессии |
| `screens_visited` | [String] | Посещённые экраны |
| `messages_sent` | Int | Отправлено сообщений |
| `last_screen` | String | Последний экран |

---

### 9.3 `session_started`
**Экран:** —
**Файл:** `AzmyAIApp.swift`
**Триггер:** Начало сессии

| Параметр | Тип | Описание |
|----------|-----|----------|
| `session_id` | String | UUID сессии |
| `user_id` | String | ID пользователя (анонимный) |
| `is_first_session` | Bool | Первая сессия? |
| `days_since_install` | Int | Дней с установки |

---

### 9.4 `error_occurred`
**Экран:** Любой
**Файл:** Централизованный error handler
**Триггер:** Любая ошибка

| Параметр | Тип | Описание |
|----------|-----|----------|
| `error_domain` | String | `ai` / `network` / `auth` / `calendar` / `health` |
| `error_code` | String | Код ошибки |
| `error_message` | String | Сообщение (без PII) |
| `screen` | String | Текущий экран |
| `user_action` | String | Действие пользователя |

---

## 10. Рекомендации по реализации

### 10.1 Приоритеты событий

**🔴 Критические (реализовать первыми):**
1. `chat_message_sent` — основа понимания использования AI
2. `chat_message_category` — что спрашивают пользователи
3. `onboarding_completed` — профилирование
4. `app_opened` / `session_started` — базовая активность
5. `voice_recording_completed` — adoption голоса

**🟡 Важные (вторая очередь):**
6. `quick_prompt_tapped` — популярные промпты
7. `suggested_action_tapped` — эффективность AI
8. `screen_viewed` — навигация
9. `event_created` — использование календаря
10. `onboarding_step_completed` — воронка

**🟢 Желательные (третья очередь):**
- Остальные события для детальной аналитики

### 10.2 Архитектура аналитики

```swift
// Рекомендуемая структура

// 1. Протокол для событий
protocol AnalyticsEvent {
    var name: String { get }
    var parameters: [String: Any] { get }
    var timestamp: Date { get }
}

// 2. Сервис аналитики
class AnalyticsService {
    static let shared = AnalyticsService()

    func track(_ event: AnalyticsEvent) {
        // Отправка в бэкенд / Amplitude / Mixpanel
    }

    func setUserProperty(_ key: String, value: Any) {
        // Свойства пользователя
    }

    func startSession() { }
    func endSession() { }
}

// 3. Конкретные события
struct ChatMessageSentEvent: AnalyticsEvent {
    let name = "chat_message_sent"
    let messageId: String
    let messageLength: Int
    let inputMethod: String
    // ...

    var parameters: [String: Any] {
        return [
            "message_id": messageId,
            "message_length": messageLength,
            "input_method": inputMethod
        ]
    }
}
```

### 10.3 Privacy соображения

1. **НЕ собирать:**
   - Полный текст сообщений (только хэш/длина)
   - Личные данные из календаря
   - Данные здоровья без согласия
   - Точную геолокацию

2. **Анонимизировать:**
   - User ID — использовать UUID, не email
   - Сообщения — только категория и метаданные
   - События календаря — только факт создания

3. **Согласие:**
   - Добавить в онбординг опцию "Help improve the app"
   - Возможность отключить аналитику в настройках

### 10.4 Рекомендуемые инструменты

| Инструмент | Для чего | Примечание |
|------------|----------|------------|
| **Amplitude** | Основная аналитика | Хорош для воронок |
| **Mixpanel** | Альтернатива | Лучше для retention |
| **Firebase Analytics** | Бесплатный базовый | Хорош для старта |
| **PostHog** | Self-hosted опция | Open source |

---

## Приложение A: Сводная таблица событий

| # | Событие | Экран | Приоритет |
|---|---------|-------|-----------|
| 1 | `chat_message_sent` | Chat | 🔴 |
| 2 | `chat_message_received` | Chat | 🔴 |
| 3 | `chat_message_category` | Chat | 🔴 |
| 4 | `quick_prompt_tapped` | Chat | 🟡 |
| 5 | `suggested_action_tapped` | Chat | 🟡 |
| 6 | `chat_error_occurred` | Chat | 🔴 |
| 7 | `chat_streaming_interaction` | Chat | 🟢 |
| 8 | `chat_conversation_cleared` | Chat | 🟢 |
| 9 | `voice_recording_started` | Chat | 🟡 |
| 10 | `voice_recording_completed` | Chat | 🔴 |
| 11 | `voice_transcription_completed` | Chat | 🟡 |
| 12 | `voice_transcription_error` | Chat | 🟡 |
| 13 | `voice_onboarding_interaction` | Chat | 🟢 |
| 14 | `onboarding_step_viewed` | Onboarding | 🟡 |
| 15 | `onboarding_step_completed` | Onboarding | 🟡 |
| 16 | `onboarding_completed` | Onboarding | 🔴 |
| 17 | `onboarding_abandoned` | Onboarding | 🟡 |
| 18 | `goal_selected` | Onboarding | 🟢 |
| 19 | `screen_viewed` | All | 🟡 |
| 20 | `tab_switched` | Main | 🟡 |
| 21 | `home_page_swiped` | Home | 🟢 |
| 22 | `dashboard_card_tapped` | Home | 🟢 |
| 23 | `event_created` | Calendar | 🟡 |
| 24 | `event_viewed` | Calendar | 🟢 |
| 25 | `calendar_date_selected` | Calendar | 🟢 |
| 26 | `permission_toggled` | Profile | 🟡 |
| 27 | `notification_setting_changed` | Profile | 🟢 |
| 28 | `logout_initiated` | Profile | 🟡 |
| 29 | `support_contacted` | Profile | 🟢 |
| 30 | `insights_viewed` | Insights | 🟢 |
| 31 | `quiz_started` | Quiz | 🟢 |
| 32 | `quiz_completed` | Quiz | 🟢 |
| 33 | `statistics_metric_viewed` | Statistics | 🟢 |
| 34 | `app_opened` | — | 🔴 |
| 35 | `app_backgrounded` | — | 🟡 |
| 36 | `session_started` | — | 🔴 |
| 37 | `error_occurred` | Any | 🔴 |

---

## Приложение B: Ключевые метрики для дашборда

### Engagement (Вовлечённость)
- **DAU/MAU** — Daily/Monthly Active Users
- **Messages per session** — Сообщений за сессию
- **Session duration** — Длительность сессии
- **Voice adoption rate** — % использующих голос

### AI Quality (Качество AI)
- **Response time p50/p95** — Время ответа
- **Error rate** — Частота ошибок
- **Retry rate** — Частота повторов
- **Suggested action tap rate** — CTR предложений

### User Interests (Интересы)
- **Top message categories** — Популярные категории
- **Most used quick prompts** — Популярные промпты
- **Feature usage distribution** — Распределение по функциям

### Funnel (Воронка)
- **Onboarding completion rate** — Завершение онбординга
- **Step drop-off rates** — Отвал по шагам
- **Permission grant rates** — Выдача разрешений

### Retention
- **D1/D7/D30 retention** — Возврат пользователей
- **Churn prediction signals** — Сигналы оттока

---

*Документ подготовлен для команды AzmyAI*
