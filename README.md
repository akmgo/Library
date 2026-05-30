# 卷牍 Library

个人阅读追踪与管理应用，支持 macOS 与 iOS 双端，基于 SwiftUI + SwiftData 构建。

## 功能概览

### 阅读主页

- **在读焦点**：展示当前在读的书籍封面、书名、作者和进度条；支持多本在读书籍之间切换
- **阅读计时器**：自由计时、定时阅读、手动录入三种模式；实时仪表盘显示今日阅读时长与目标进度
- **双周动能**：最近 14 天每日阅读分钟柱状图，今日高亮
- **思想共鸣**：随机轮播书摘卡片，20 秒自动切换，点击手动切换
- **想读焦点**：横向展示待读书籍封面，点击开始阅读
- **知识基因**：按摘录类别（科幻/文学/哲学等）展示知识面分布光谱

### 全景画廊

- 书籍网格展示，支持按状态筛选（未读/在读/已读/弃读/想读）
- 多种排序方式（时间/标题/进度）
- 封面尺寸可调节（小/中/大/特大）
- 批量选择和删除

### 摘录长廊

- 双列瀑布流或沉浸式轮播两种展示模式
- 支持书摘、笔记、诗歌、语录等多种类别
- 按类别筛选与排序
- 全屏阅读模式

### 年度轨迹

- 时间轴展示每年读完的书籍
- 时间线左侧书籍卡片 + 右侧日期标签交替排列
- 显示完成日期与评分
- 按年份切换

### 月度记录

- 日历网格展示每日阅读痕迹
- 每个格子显示日期、阅读分钟数、当日所读书籍
- 月份总阅读量统计（天数/分钟/连续/平均）
- 支持批量删除

### 全局搜索（⌘K）

- 跨书籍和摘录的全文搜索
- 搜索结果分类展示
- iOS 支持主页下拉唤起

## 架构

```
Library/
├── Shared/           # 跨平台共享代码
│   ├── Core/         # 计算引擎、校验器、通知
│   ├── Data/         # SwiftData 数据库、图片缓存
│   ├── DesignSystem/ # 颜色、间距、字体、圆角
│   ├── Models/       # Book, ReadingSession, Excerpt, UserConfig
│   └── UI/           # 共享 UI 组件
├── macOS/            # Mac 端
│   ├── App/          # 主入口与导航
│   ├── Features/     # 各功能模块视图
│   └── Platform/     # Sheets、搜索、UI 组件
├── iOS/              # iOS 端
│   ├── Features/     # 各功能模块视图
│   └── Platform/     # Sheets
└── LibraryWidgets/   # WidgetKit 小组件（7 个）
```

- **数据层**：SwiftData + CloudKit 同步
- **无 ViewModel**：computed properties + 静态 calculator 方法
- **平台守卫**：`#if os(macOS)` / `#if os(iOS)` 编译期隔离

## 数据模型

| 模型 | 说明 |
|------|------|
| `Book` | 书籍（书名、作者、封面、总页数、当前页数、状态、评分、标签） |
| `ReadingSession` | 阅读记录（开始/结束时间、时长、起止页码） |
| `Excerpt` | 摘录/笔记（正文、来源、分类、关联书籍） |
| `UserConfig` | 用户配置（每日阅读目标、年度书籍目标、馆藏目标） |

## 设计系统

- 自适应浅色/深色模式
- 语义化色彩（readingAmber、success、danger、selection）
- 统一间距体系（4–64pt）
- AppCard 卡片容器（毛玻璃背景 + 微阴影 + 描边）
- BookCoverView 跨平台封面组件（NSCache 缓存 + 异步加载）

## 技术特性

- **CloudKit 同步**：iOS 与 macOS 之间通过 iCloud 同步阅读数据
- **Live Activity**：iOS 阅读计时器的灵动岛与锁屏实时活动
- **WidgetKit 小组件**：桌面仪表盘、动能图、阅读焦点、知识光谱等
- **全局搜索**：基于 `SearchMatcher` 的本地全文搜索引擎
- **批量操作**：画廊和摘录长廊支持批量删除
- **运行计时器**：`ReadingTimerStore` 内存状态管理，支持 App 后台恢复

## 构建与运行

```bash
# macOS
xcodebuild -project Library.xcodeproj -scheme Library \
  -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -project Library.xcodeproj -scheme Library \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- **最低系统要求**：macOS 26.4 / iOS 26.4
- **Xcode**：26.x
- **Swift**：5.0

## 项目信息

- **Bundle ID**：com.akram.Library
- **App Group**：group.com.akram.library
- **App Store 分类**：图书（Books）
- **版本**：1.0
