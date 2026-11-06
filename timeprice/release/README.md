# Release-сборки TIMEPRICE 1.0.0

Файлы `.aab` и `.apk` в git не хранятся (правило в `.gitignore`). Их передают отдельно
или собирают по `RELEASE_BUILD.md`.

| Файл | Для чего | Подпись |
|---|---|---|
| `timeprice-1.0.0-unsigned.aab` | **для Google Play** после подписи вашим ключом загрузки (`RELEASE_BUILD.md`, вариант В) | не подписан |
| `timeprice-1.0.0-release-TEST-debugkey.apk` | проверка релизной конфигурации на телефоне и **перенос данных** со старой версии 0.3.0 (ставится поверх неё) | отладочный ключ — **в Google Play не загружать** |

Отладочная сборка 1.0.0 лежит отдельно: `build/android/timeprice-1.0.0-debug.apk`.
Прежняя `dist/timeprice-0.3.0-debug.apk` не тронута.

Проверка файлов: `RELEASE_TEST_PLAN.md`, раздел 1. Контрольные суммы — в
`SHA256SUMS.txt` рядом.
