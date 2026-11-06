# Сборка release AAB для Google Play

Релизную сборку подписывает **ваш ключ загрузки (upload key)**. Ни ключа, ни паролей в
репозитории нет и быть не должно. Google хранит отдельный ключ подписи приложения (Play App
Signing) и переподписывает им APK, которые получают пользователи.

## 1. Что нужно установить

| Компонент | Версия | Где взять |
|---|---|---|
| Godot | **4.7.2** (стандартная сборка, не .NET) | https://godotengine.org/download/archive/ |
| Шаблоны экспорта | 4.7.2 | в редакторе: «Редактор → Управление шаблонами экспорта» |
| JDK | 17 (рекомендован Godot; 21 тоже работает — проверено) | https://adoptium.net |
| Android SDK | platform 36, build-tools 36.1.0, platform-tools | Android Studio или `sdkmanager` |

В Godot откройте «Редактор → Настройки редактора → Экспорт → Android» и укажите пути к
Android SDK и JDK.

## 2. Создание ключа загрузки (один раз)

Ключ создаётся на вашем компьютере. Не отправляйте его никому, не кладите в git и в облако
без шифрования.

```bash
keytool -genkeypair -v \
  -keystore ~/keys/timeprice-upload.jks \
  -alias timeprice-upload \
  -keyalg RSA -keysize 4096 -validity 10000
```

- `keytool` попросит пароль и данные владельца. Пароль хранится в менеджере паролей, а не
  в файлах проекта.
- Сделайте резервную копию `.jks` и пароля в двух надёжных местах. Если ключ загрузки
  потеряется, при Play App Signing его можно сбросить через поддержку Google. Но это долго,
  а без ключа обновления выпускать нельзя.
- `.jks`, `.keystore` и `export_credentials.cfg` в git не попадут: соответствующие правила
  есть в `.gitignore`.

## 3. Сборка AAB

### Вариант А — из командной строки (рекомендуется)

Ключ передаётся через переменные окружения. Godot читает их сам, в файлы проекта они не
записываются.

```bash
cd timeprice
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/keys/timeprice-upload.jks"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="timeprice-upload"
read -s -p "Пароль ключа: " GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; echo
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

# Первый раз — с установкой Gradle-шаблона (создаёт папку android/, она в .gitignore).
godot --headless --install-android-build-template --export-release "Android Release AAB" release/timeprice-1.0.0.aab
# Дальше — без установки шаблона:
# godot --headless --export-release "Android Release AAB" release/timeprice-1.0.0.aab

unset GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
```

Если Gradle пишет `429 Too Many Requests`, значит Maven Central временно ограничил
загрузки. Повторите сборку через минуту.

### Вариант Б — из редактора

«Проект → Экспорт → Android Release AAB → Keystore → Release» — укажите файл, alias и
пароль. Редактор сохранит их в `.godot/export_credentials.cfg`: этот файл не коммитится.
Затем нажмите «Экспортировать проект».

### Вариант В — подписать готовый неподписанный AAB

В `release/` лежит `timeprice-1.0.0-unsigned.aab`, собранный из того же кода.

```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore ~/keys/timeprice-upload.jks \
  -signedjar release/timeprice-1.0.0.aab \
  release/timeprice-1.0.0-unsigned.aab timeprice-upload
```

## 4. Проверка перед загрузкой

```bash
bundletool validate --bundle=release/timeprice-1.0.0.aab
bundletool dump manifest --bundle=release/timeprice-1.0.0.aab | grep -E "targetSdkVersion|versionCode|uses-permission|debuggable"
bundletool dump config --bundle=release/timeprice-1.0.0.aab | grep alignment   # PAGE_ALIGNMENT_16K
keytool -printcert -jarfile release/timeprice-1.0.0.aab                         # должен быть ВАШ ключ, не "Android Debug"
```

Ожидается: `targetSdkVersion="36"`, `versionCode="4"`, ни одного `uses-permission`, нет
`debuggable`.

## 5. Play App Signing

Для новых приложений Play App Signing включается автоматически при первой загрузке AAB.
Google создаёт ключ подписи приложения, а вы подписываете загрузки своим ключом загрузки.
В «Тестирование и выпуск → Целостность приложения → Подпись приложения» можно посмотреть
отпечатки обоих ключей.

## 6. Следующие версии

- В `export_presets.cfg` увеличьте `version/code` во **всех трёх** пресетах: он должен
  быть больше, чем у любой загруженной версии. Также обновите `version/name` и
  `application/config/version` в `project.godot`.
- Если нужно, обновите `PRIVACY_POLICY.md`, `DATA_SAFETY_GUIDE.md` и
  `CHANGELOG_PRE_RELEASE.md`.
- Прогоните тесты из `RELEASE_TEST_PLAN.md`.
