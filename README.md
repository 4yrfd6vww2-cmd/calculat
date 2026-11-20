# Калькулятор (iOS, SwiftUI)

Нативное приложение для iPhone. `.ipa` собирается на GitHub, без Mac.

## Как получить .ipa

1. Залейте проект в репозиторий на GitHub (ветка `main`).
2. Откройте вкладку **Actions** и дождитесь зелёной галочки у запуска «Build IPA». Запустить вручную: Actions → Build IPA → Run workflow.
3. Готовый `Calculator.ipa` лежит в разделе **Releases** (и в артефактах запуска).

IPA собирается без подписи. Перед установкой его нужно подписать вашим способом (AltStore, Sideloadly, ESign и т. п.).

## Структура

- `project.yml` — описание проекта для XcodeGen (`.xcodeproj` генерируется при сборке)
- `Sources/` — код на SwiftUI и иконка
- `.github/workflows/build.yml` — сборка на macOS-раннере
