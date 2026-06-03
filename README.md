# 阅读日记

一个 iOS-only 的书籍记录应用。

它只做四件事：

- 记录书
- 手动记录阅读时长
- 保存书摘
- 保存书籍笔记

它不是阅读器，不做计时器，不做小组件，不做跨端同步，也不收集和书无关的灵感碎片。

它也不做任何目标系统：没有每日阅读目标、年度目标、打卡达标、连续阅读任务或成就压力。所有数据只作为事实记录存在。

## 当前结构

```text
Library/
  LibraryApp.swift
  Assets.xcassets
  Info.plist
  PrivacyInfo.xcprivacy

iOS/
  App/       App 入口与 SwiftData 容器
  Models/    Book, ReadingLog, BookText
  Theme/     颜色、卡片、基础组件
  Views/     首页、书库、摘录、记录、详情
  Sheets/    添加书籍、记录阅读、添加摘录/笔记
```

## 数据模型

| 模型 | 说明 |
| --- | --- |
| `Book` | 书籍基础信息、状态、页数进度、评分 |
| `ReadingLog` | 手动阅读记录：日期、分钟、读到页码 |
| `BookText` | 书籍摘录或书籍笔记，必须关联一本书 |

## 构建

```bash
xcodebuild -scheme Library -destination 'generic/platform=iOS' build
```

## 原则

- iOS only
- SwiftUI + SwiftData
- 手动记录，不做计时
- 只记录事实，不设计目标
- 只和书有关
- UI 保持安静、高级、克制
