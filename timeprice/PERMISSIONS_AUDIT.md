# Аудит разрешений Android

Источник: итоговый манифест релизного AAB версии 1.0.0 (Godot 4.7.2, Gradle-сборка),
снятый командой `bundletool dump manifest`. Дата проверки — 6 ноября 2026.

## Запрашиваемые разрешения (`uses-permission`)

**Нет ни одного.** Приложение не запрашивает:

| Разрешение или доступ | Запрашивается | Комментарий |
|---|---|---|
| INTERNET, ACCESS_NETWORK_STATE | нет | приложение полностью офлайн |
| Местоположение | нет | |
| Контакты | нет | |
| Камера | нет | |
| Микрофон | нет | |
| SMS, журнал звонков, телефон | нет | |
| Фото и медиа (READ_MEDIA_*) | нет | |
| Все файлы (MANAGE_EXTERNAL_STORAGE), READ/WRITE_EXTERNAL_STORAGE | нет | экспорт и импорт идут через системное окно выбора файла (Storage Access Framework), разрешение для этого не нужно |
| Уведомления (POST_NOTIFICATIONS) | нет | |
| Банковские и платёжные данные | нет | |
| QUERY_ALL_PACKAGES | нет | |

В пресетах экспорта `permissions/internet=false`, остальные разрешения не отмечены.
Плагинов Godot (`addons/`) и Android-плагинов в проекте нет, поэтому неявно добавленных
разрешений тоже нет. Это подтверждено итоговым манифестом.

## Компоненты в манифесте

Компоненты добавлены шаблоном Godot и библиотеками AndroidX.

| Компонент | Открыт наружу (`exported`) | Назначение | Риск |
|---|---|---|---|
| `com.godot.game.GodotApp` (activity) | false | главное окно приложения | нет |
| `com.godot.game.GodotAppLauncher` (activity-alias) | true | значок в лаунчере (MAIN/LAUNCHER) — стандартно | нет |
| `org.godotengine.godot.utils.ProcessPhoenix` | false | служебный перезапуск движка | нет |
| `androidx.core.content.FileProvider` | false | служебный провайдер файлов Godot | нет |
| `androidx.startup.InitializationProvider` | false | инициализация библиотек AndroidX | нет |
| `androidx.profileinstaller.ProfileInstallReceiver` | true, но защищён `android.permission.DUMP` | установка профиля производительности (Baseline Profile); вызвать его могут только системные инструменты (adb, Play) | нет |

`android.permission.DUMP` у приёмника — это требование к **вызывающему**: обратиться к
нему может только система. Само приложение это разрешение не запрашивает.

## Прочие атрибуты

| Атрибут | Значение | Почему |
|---|---|---|
| `android:allowBackup` | false | облачное резервное копирование Android отключено; данные переносятся только через ручной экспорт |
| `android:debuggable` | отсутствует в release | отладка выключена |
| `android:isGame` | false | приложение не игра |
| `android:appCategory` | productivity | |
| `uses-feature glEsVersion 0x30000` | required | OpenGL ES 3.0, нужен рендереру Godot |
| `screenOrientation` | portrait | на экранах от 600dp Android 16 эту настройку игнорирует; интерфейс адаптирован (колонка шириной до 640) |
| `supportsPictureInPicture` | true | значение шаблона Godot по умолчанию; TIMEPRICE режим «картинка в картинке» не использует, вреда нет |

## Как проверить самостоятельно

```bash
bundletool dump manifest --bundle=release/timeprice-1.0.0.aab | grep -E "uses-permission|debuggable"
```

Пустой вывод означает, что разрешений нет и отладка выключена.
