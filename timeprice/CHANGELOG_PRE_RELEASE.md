# Изменения при подготовке к релизу (0.3.0 → 1.0.0)

Резервная точка до изменений — коммит `ba1de71e` (локальная метка
`timeprice-v0.3.0-godot4.3`). Функции приложения не удалялись, формат пользовательских
данных (схема v3) не менялся.

## Движок и сборка

| Изменение | Причина | Номер в аудите |
|---|---|---|
| Godot 4.3 → **4.7.2** | шаблон 4.3 собирает под targetSdk 34; Google Play требует 36. Шаблон 4.7.2: compileSdk/targetSdk 36, minSdk 24, NDK r29 | C1 |
| Нативные библиотеки arm64 выровнены по 16 КБ | требование Google Play для обновлений с 01.02.2027; встроено в Godot 4.5+ | H1 |
| minSdk 21 → **24** (Android 7.0) | минимальная версия шаблона Godot 4.7.2 | — |
| Три пресета: `Android` (debug APK), `Android Release AAB`, `Android Release APK` | для Google Play нужна релизная сборка в AAB | C2 |
| Подпись release только через `GODOT_ANDROID_KEYSTORE_RELEASE_*` | пароли не хранятся в файлах проекта | C2 |
| Версия **1.0.0**, versionCode **4** | решение владельца | L4 |
| `package/app_category` = Productivity → `isGame=false` | приложение было помечено как игра | H5 |
| `screen/edge_to_edge` = вкл. | на Android 16 режим «от края до края» обязателен; отступы считает `main.gd` | H2 |
| Жест «Назад» | Godot 4.7.2 использует `OnBackPressedDispatcher` (AndroidX), совместимый с новым жестом. Временное отключение не понадобилось. **На устройстве не проверено** | H3 |
| В `.gitignore` добавлены `*.jks`, `*.keystore`, `*.p12`, `*.pem`, `keystore.properties` | защита ключей | C2 |
| Из сборки исключены `release/`, `dist/`, `docs/`, `google_play_assets/` | в AAB только код и ресурсы | — |

## Приложение

| Изменение | Файлы | Номер в аудите |
|---|---|---|
| Экран «Конфиденциальность и о приложении»: полный текст политики (офлайн), правовая оговорка, контакт anonrusa@gmail.com, лицензии Godot и сторонних компонентов | `scenes/settings/about_screen.*`, `scripts/content/legal_text.gd` | C3 |
| Ссылка на политику на экране приветствия | `scenes/onboarding/onboarding_screen.gd` | C3 |
| **Резервная копия в файл и восстановление** через системное окно Android, без разрешений. Перед восстановлением текущие данные сохраняются в `user://timeprice_data.before_import.json`. Чужие и более новые файлы отклоняются | `scripts/services/backup_service.gd`, `scripts/ui/file_picker.gd`, `settings_screen.gd`, `data_manager.gd`, `settings_manager.gd` | M2 (вариант «в») |
| Новые значки: адаптивный передний план в безопасной зоне, фирменный фон, монохромный слой, 192 px, 512 px для Play | `resources/icons/launcher/` | H4 |
| Запись данных: переименование поверх основного файла вместо удаления; проверка результата `store_string` (нехватка места) | `scripts/services/json_storage.gd` | M3 |
| Черновики экранов (депозит, кредит, рассрочка, кэшбэк, привычка, симулятор) сохраняются и при сворачивании | `base_screen.gd`, `main.gd`, экраны сервисов | M5 |
| Колонка контента не шире 640 px на планшетах и в ландшафте | `scripts/core/base_screen.gd` | M1 |
| Кнопки-значки 48 px, чипы 44 px | `ui.gd` и экраны | M4 |
| Кэши значков и темы освобождаются при выходе (без предупреждений об утечках) | `icon_library.gd`, `app_theme.gd`, `main.gd` | — |
| Уменьшен верхний отступ экрана приветствия: ссылка на политику помещается на экране | `onboarding_screen.gd` | — |

## Тесты

- Новые модульные тесты резервной копии и записи поверх существующего файла: всего
  **111**, все проходят.
- Сквозная проверка дополнена экспортом и импортом и экраном «О приложении». Проходит в
  800×1720, 720×1280 и 1280×800.
- Сценарии для витрины Play: `tests/store_screenshots/` (скриншоты и Feature Graphic).

## Документы

`PRE_RELEASE_AUDIT.md`, `PRIVACY_POLICY.md` и `docs/privacy/index.html`,
`DATA_SAFETY_GUIDE.md`, `PERMISSIONS_AUDIT.md`, `FINANCIAL_FEATURES_DECLARATION.md`,
`RELEASE_TEST_PLAN.md`, `GOOGLE_PLAY_CONSOLE_CHECKLIST.md`, `KAZAKHSTAN_COMPLIANCE.md`,
`MONETIZATION_RECOMMENDATIONS.md`, `RELEASE_BUILD.md`, `google_play_assets/*`.

## Что сознательно не менялось

- Концепция, дизайн и набор функций.
- Package ID `kz.timeprice.app`.
- Формат данных — схема v3, без миграции.
- Сеть, аналитика, реклама, Firebase, авторизация — не добавлялись.
- Существующая debug-сборка `dist/timeprice-0.3.0-debug.apk` осталась на месте.
