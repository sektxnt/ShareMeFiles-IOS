# ShareMeFiles iOS

iOS-приложение для сервиса ShareMeFiles.

## О проекте

Приложение использует WKWebView для открытия официального сайта:

https://sharemefiles.com/

Серверная часть остаётся на существующем VPS. Приложение взаимодействует с сайтом и его API.

## Технологии

- Swift 5
- SwiftUI
- WebKit
- WKWebView
- UIKit
- Xcode
- GitHub Actions

## Возможности

- Открытие ShareMeFiles
- Работа с существующими комнатами
- Поддержка WebSocket через сайт
- Загрузка файлов через веб-интерфейс
- Скачивание файлов
- Системное меню «Поделиться»
- JavaScript Alert и Confirm
- Навигация назад и вперёд
- Обновление страницы
- Вставка ссылки приглашения

## Структура

```text
ShareMeFiles-IOS/
├── .github/
│   └── workflows/
│       └── build-unsigned-ipa.yml
├── ShareMeFiles.xcodeproj/
│   └── project.pbxproj
├── ShareMeFiles/
│   ├── ShareMeFilesApp.swift
│   ├── ContentView.swift
│   ├── ShareMeWebView.swift
│   └── Info.plist
├── PROJECT_INFO.json
├── .gitignore
└── README.md
