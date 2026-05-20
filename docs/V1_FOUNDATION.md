# V1_FOUNDATION.md

# 阅读记录 App V1 基础参数与数据模型文档

## 0. 文档定位

本文档只规定两个部分：

1. 全局基础参数规范
2. V1 数据模型设计

本文档不规定：

- 侧边栏结构
- 页面信息架构
- 具体 UI 页面方案
- 旧项目模块继承策略
- 开发完成标准
- 具体代码实现

---

# 1. 全局基础参数规范

## 1.1 视觉风格

V1 的视觉风格为：

**Quiet Glass / Apple Minimal / Paper Warmth**

关键词：

- 安静
- 克制
- 清澈
- 留白
- 轻质
- 有秩序
- 有纸质阅读感
- 不复古

避免：

- 木纹
- 羊皮纸
- 仿真书架
- 过度拟物
- 大量彩色标签
- 复杂图表堆叠
- 网页式重阴影
- 非原生毛玻璃模拟

---

## 1.2 颜色系统

### 浅色模式

主背景：

```text
#F7F5F1
```

次级背景：

```text
#FFFFFF
```

三级背景：

```text
#EEEAE3
```

主文字：

```text
#1C1C1E
```

次级文字：

```text
#6E6E73
```

弱文字：

```text
#A1A1A6
```

### 深色模式

主背景：

```text
#111113
```

次级背景：

```text
#1A1A1D
```

三级背景：

```text
#242428
```

主文字：

```text
#F5F5F7
```

次级文字：

```text
#A1A1A6
```

弱文字：

```text
#6F6F76
```

---

## 1.3 强调色

主强调色：Reading Amber

```text
#C89B5A
```

使用场景：

- 选中状态
- 当前阅读进度
- 今日阅读时间
- 主按钮
- 完成进度
- 统计主色

弱强调背景：

浅色模式：

```text
#F1E4D0
```

深色模式：

```text
#3A2B19
```

功能色：

```text
Success: #6FAF8C
Warning: #D6A04F
Danger: #D96C6C
```

功能色应克制使用。

---

## 1.4 Liquid Glass / Material 规范

不要通过固定 rgba + blur 自行模拟玻璃。

开发时应优先使用 Apple 原生 Material、Liquid Glass、Visual Effect 和系统控件自带材质。

设计层只定义玻璃语义：

```text
Glass / Background
Glass / Card
Glass / Detail
Glass / Modal
Glass / Control
```

语义说明：

```text
Glass / Background
用于大面积背景层或主窗口底层材质。

Glass / Card
用于书籍卡片、统计卡片、阅读记录卡片。

Glass / Detail
用于书籍详情、信息面板、重点展示区域。

Glass / Modal
用于添加书籍、记录阅读、完成阅读等弹窗。

Glass / Control
用于按钮、输入框、分段控件、状态标签。
```

使用要求：

- 优先使用系统材质。
- 文本必须保持足够对比度。
- 不要所有组件都使用强玻璃效果。
- 玻璃用于层级，不用于炫技。
- 浅灰背景下的玻璃应保持清澈、轻薄。

---

## 1.5 圆角系统

```text
XS: 6
S: 8
M: 14
L: 20
XL: 28
```

使用规则：

```text
6   小图标容器、微型标签
8   标签、页码胶囊、小按钮
14  输入框、普通按钮、小卡片
20  书籍卡片、统计卡片、阅读记录卡片
28  主面板、大型玻璃浮层、弹窗
```

默认参数：

```text
Card Radius: 20
Panel Radius: 28
Button Radius: 14
Tag Radius: Capsule 或 8
Book Cover Radius: 8–12
```

---

## 1.6 间距系统

基于 4pt 网格：

```text
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64
```

使用规则：

```text
4   图标与文字极小间隔
8   标签内边距、小控件间距
12  卡片内部小组间距
16  标准控件间距
20  卡片内边距
24  内容组之间
32  页面区块之间
40  大模块之间
48  页面顶部留白
64  空状态或仪表盘留白
```

常用参数：

```text
窗口外边距: 24 或 32
大页面横向 padding: 40 或 60
卡片内边距: 20 或 24
模块间距: 24 / 32 / 40
顶部 Header 下内容偏移: 120–140
```

---

## 1.7 字体系统

使用系统字体。

```text
中文: PingFang SC
英文与数字: SF Pro
```

字号层级：

```text
Display Large: 48 / Semibold
Display Medium: 36 / Semibold
Page Title: 32 / Heavy 或 Semibold
Title Large: 28 / Semibold
Title Medium: 22 / Semibold
Title Small: 18 / Medium
Body: 15 / Regular
Body Small: 13 / Regular
Caption: 12 / Regular
Micro: 11 / Medium
```

使用规则：

- 大数字用于阅读时间、阅读页数、年度读完数量等核心指标。
- 书名使用 Medium，不要过粗。
- 说明文字使用弱层级。
- 数字与单位应分层展示，例如 `42` 使用 Display Large，`分钟` 使用 Caption 或 Body Small。

---

## 1.8 阴影与边框

阴影必须轻。

浅色模式：

```text
Soft: 0 4 16 rgba(0, 0, 0, 0.04)
Medium: 0 8 30 rgba(0, 0, 0, 0.06)
Elevated: 0 18 50 rgba(0, 0, 0, 0.10)
```

深色模式：

```text
Soft Dark: 0 6 20 rgba(0, 0, 0, 0.24)
Medium Dark: 0 12 36 rgba(0, 0, 0, 0.32)
Elevated Dark: 0 22 60 rgba(0, 0, 0, 0.45)
```

边框：

```text
Light Border: rgba(0, 0, 0, 0.06)
Glass Light Border: rgba(255, 255, 255, 0.72)
Dark Border: rgba(255, 255, 255, 0.08)
Accent Border: rgba(200, 155, 90, 0.36)
```

边框默认 1pt。

---

## 1.9 组件尺寸

按钮高度：

```text
Small: 28
Medium: 36
Large: 44
Hero: 52
```

输入框高度：

```text
Small: 32
Medium: 40
Large: 48
```

书籍卡片：

```text
小卡: 120 宽
中卡: 160 宽
大卡: 200 宽
超大卡: 260 宽
封面比例: 2:3
```

书籍封面：

```text
封面比例: 2:3
圆角: 8–12
```

主要展示卡片：

```text
高度: 220–280
Radius: 28
Padding: 24–28
```

---

## 1.10 图标系统

使用 SF Symbols。

尺寸：

```text
Small: 14
Medium: 18
Large: 22
XL: 28
```

建议图标语义：

```text
书籍: books.vertical.fill 或 book.closed
记录: timer 或 clock
统计: chart.bar 或 calendar
摘录: quote.opening 或 text.quote
设置: gearshape
想读: bookmark
在读: book.fill
已读: checkmark.circle
弃读: xmark.circle
页码: number
时间: timer
```

---

## 1.11 状态标签

阅读状态固定五个：

```text
unread: 未读
finished: 已读
reading: 在读
abandoned: 弃读
planned: 想读
```

注意：`planned` 的展示文案必须是“想读”，不是“计划阅读”。

标签样式：

```text
Height: 24
Horizontal Padding: 8
Radius: Capsule
Font: 12 Medium
```

状态颜色建议：

```text
在读: Accent Primary
已读: Success
未读: Secondary Text
弃读: Tertiary Text
想读: Accent Soft
```

---

## 1.12 进度视觉

线性进度：

```text
Height: 3 或 4
Radius: Capsule
Fill: Accent Primary
Track: 低透明灰色
```

环形进度：

```text
Stroke: 6
Size: 72 / 96 / 120
Line Cap: Round
```

页码显示优先：

```text
86 / 356 页
已读 86 页 · 剩余 270 页
```

不要只显示百分比。

---

## 1.13 动效系统

```text
Fast: 120ms
Normal: 220ms
Slow: 360ms
```

使用：

- 按钮点击轻微缩放到 0.98。
- 卡片 hover 上移 2–4pt。
- 封面轻微缩放。
- 进度条平滑增长。
- 计时器数字平滑刷新。
- 弹窗轻微放大 + 淡入。

避免：

- 大幅弹跳
- 复杂翻页动画
- 粒子效果
- 强烈发光

---

# 2. 数据模型设计

## 2.1 模型总览

V1 数据模型包括：

```text
BookStatus
ProgressUnit
AnnotationType
ReadingInputMode

Book
ReadingSession
BookAnnotation
UserConfig
Snippet
SnippetCategory
```

核心关系：

```text
Book
├── ReadingSession[]
└── BookAnnotation[]

ReadingSession
└── belongs to Book

BookAnnotation
└── belongs to Book

UserConfig
└── 全局配置

Snippet
└── 独立泛摘录模块，V1 暂不接入主流程
```

---

## 2.2 BookStatus

阅读状态固定为五个：

```text
unread
finished
reading
abandoned
planned
```

语义：

```text
unread: 未读，已经加入书库但尚未开始
finished: 已读完
reading: 正在阅读
abandoned: 弃读
planned: 想读
```

显示名：

```text
unread → 未读
finished → 已读
reading → 在读
abandoned → 弃读
planned → 想读
```

---

## 2.3 ProgressUnit

V1 只支持三个进度单位：

```text
page
percent
chapter
```

语义：

```text
page: 页数
percent: 百分比
chapter: 章节
```

使用规则：

```text
纸质书默认 page
电子书或只方便查看进度百分比的场景使用 percent
章节型内容使用 chapter
```

---

## 2.4 AnnotationType

V1 只支持：

```text
excerpt
note
```

语义：

```text
excerpt: 摘录
note: 笔记
```

---

## 2.5 ReadingInputMode

V1 阅读记录支持两种输入模式：

```text
timer
manual
```

语义：

```text
timer: 计时器记录
manual: 手动记录
```

---

# 3. Book 模型

## 3.1 模型定位

`Book` 表示一个阅读对象。

它不代表电子书文件，不保存阅读器文件路径，也不保存 EPUB 解析结果。

V1 必须移除阅读器字段：

```text
localFileName
format
lastReadLocation
totalCharacters
spineWeightMap
```

---

## 3.2 字段

```text
id: String

title: String
author: String
coverData: Data?

createdAt: Date

status: BookStatus

rating: Int
tags: [String]

startDate: Date?
finishDate: Date?
lastReadAt: Date?

progressUnit: ProgressUnit
totalAmount: Double
currentAmount: Double

summary: String

sessions: [ReadingSession]?
annotations: [BookAnnotation]?
```

---

## 3.3 字段规则

```text
title 必填。
author 可为空。
coverData 可为空，应使用外部存储保存图片。
createdAt 表示加入书库时间。
Book 不需要 updatedAt。
status 默认 unread。
rating 范围为 0–7，0 表示未评分。
tags 使用字符串数组，V1 不建立 Tag 模型。
progressUnit 默认 page。
totalAmount 表示总页数、100%、总章节数。
currentAmount 表示当前页、当前百分比、当前章节。
summary 用于读后总结，V1 可保留字段但不必作为主流程。
```

---

## 3.4 计算属性

Book 应具备以下计算能力：

```text
progressRatio = currentAmount / totalAmount
remainingAmount = totalAmount - currentAmount
isFinishedByProgress = currentAmount >= totalAmount
displayProgress = 根据 progressUnit 格式化当前进度
```

规则：

```text
progressRatio 不入库。
progressRatio 需要限制在 0–1 之间。
当 totalAmount <= 0 时，progressRatio = 0。
```

---

# 4. ReadingSession 模型

## 4.1 模型定位

`ReadingSession` 表示一次阅读行为。

它必须和某一本 Book 绑定。

它回答：

```text
哪一天读的
读的是哪本书
从什么时候开始
什么时候结束
读了多久
从哪个进度读到哪个进度
是计时器记录还是手动记录
```

`ReadingSession` 不是每日唯一记录。每日、每月、每年统计都应从多条 ReadingSession 聚合。

---

## 4.2 字段

```text
id: String

date: Date
inputMode: ReadingInputMode

startedAt: Date
endedAt: Date
duration: TimeInterval

progressUnit: ProgressUnit
startAmount: Double
endAmount: Double

createdAt: Date

book: Book?
```

---

## 4.3 字段规则

```text
date 是统计归属日期，保存为当天零点。
startedAt 必须有值。
endedAt 必须有值。
duration 必须有值，单位秒。
progressUnit 通常等于 Book.progressUnit，但需要在 Session 中单独保存。
book 在 SwiftData 中可选，但业务逻辑中必须非空。
ReadingSession 不包含备注字段。
```

---

## 4.4 计时器记录规则

当 `inputMode = timer`：

```text
startedAt = 用户点击开始计时时的时间
endedAt = 用户点击结束计时时的时间
duration = endedAt - startedAt
date = startedAt 所在日期
```

结束后用户填写 `endAmount`。

系统生成：

```text
startAmount = Book.currentAmount
endAmount = 用户输入结束进度
```

保存后更新：

```text
Book.currentAmount = endAmount
Book.lastReadAt = endedAt
Book.status = reading
```

如果：

```text
Book.startDate == nil
```

则：

```text
Book.startDate = date
```

---

## 4.5 手动记录规则

当 `inputMode = manual`：

用户输入：

```text
开始时间
阅读时长
结束进度
```

系统计算：

```text
endedAt = startedAt + duration
date = startedAt 所在日期
startAmount = Book.currentAmount
endAmount = 用户输入结束进度
```

保存后更新 Book，规则同计时器记录。

---

## 4.6 计算属性

ReadingSession 应具备：

```text
deltaAmount = endAmount - startAmount
displayDuration = duration 格式化为分钟或小时
displayTimeRange = startedAt - endedAt
displayDelta = 根据 progressUnit 格式化进度变化
```

---

# 5. BookAnnotation 模型

## 5.1 模型定位

`BookAnnotation` 是读书摘录或读书笔记。

V1 必须保持极简。

它只记录：

```text
摘录内容
属于哪本书
日期
类型
```

不要记录：

```text
页码
章节
CFI
用户评论
session 关系
复杂标签
```

---

## 5.2 字段

```text
id: String
content: String
type: AnnotationType
createdAt: Date
book: Book?
```

---

## 5.3 字段规则

```text
content 不为空。
type 为 excerpt 或 note。
book 在业务逻辑中必须非空。
```

---

# 6. UserConfig 模型

## 6.1 模型定位

`UserConfig` 保存全局设置。

V1 设置不包含每日页数目标，也不包含每日进度目标。

只保留阅读时间相关目标和书籍目标。

---

## 6.2 字段

```text
dailyMinutesGoal: Int
yearlyBooksGoal: Int
libraryBooksGoal: Int
defaultProgressUnit: ProgressUnit
updatedAt: Date
```

---

## 6.3 默认值

```text
dailyMinutesGoal = 30
yearlyBooksGoal = 20
libraryBooksGoal = 100
defaultProgressUnit = page
```

---

## 6.4 校验规则

```text
dailyMinutesGoal >= 0
yearlyBooksGoal >= 0
libraryBooksGoal >= 0
```

---

# 7. Snippet 泛摘录模型

## 7.1 模型定位

`Snippet` 是泛摘录模块，用于诗歌、词曲、短文、语录、网页摘录、电影台词等。

V1 暂不修改，不接入阅读记录主流程。

---

## 7.2 保留策略

```text
保留 SnippetCategory。
保留 Snippet。
不和 Book 关联。
不和 ReadingSession 关联。
不影响阅读记录主模型。
```

---

## 7.3 SnippetCategory

```text
poetry: 诗歌
lyric: 词曲
prose: 短文
quote: 语录
web: 拾遗
movie: 台词
```

---

## 7.4 Snippet 字段

```text
id: String
content: String
title: String
author: String
dynasty: String
annotation: String
category: SnippetCategory
addedDate: Date
```

---

# 8. 统计口径

V1 不建立统计表。

所有统计从 `ReadingSession` 和 `Book` 聚合。

---

## 8.1 今日阅读时间

```text
筛选 date == 今天的 ReadingSession
累加 duration
```

---

## 8.2 今日阅读记录数

```text
筛选 date == 今天的 ReadingSession
统计数量
```

---

## 8.3 今日阅读页数

```text
筛选 date == 今天
筛选 progressUnit == page
累加 max(endAmount - startAmount, 0)
```

---

## 8.4 今日阅读百分比变化

```text
筛选 date == 今天
筛选 progressUnit == percent
累加 max(endAmount - startAmount, 0)
```

百分比变化不能和页数混加。

---

## 8.5 今日阅读章节数

```text
筛选 date == 今天
筛选 progressUnit == chapter
累加 max(endAmount - startAmount, 0)
```

---

## 8.6 本周 / 本月 / 本年阅读时间

```text
筛选 date 在指定时间范围内
累加 duration
```

---

## 8.7 阅读天数

```text
按 date 去重
统计至少有一条 ReadingSession 的天数
```

---

## 8.8 连续阅读天数

```text
从今天或最近一次阅读日期开始向前查找
每天至少有一条 ReadingSession 即算阅读日
连续计数
```

---

## 8.9 年度读完书籍

```text
筛选 Book.status == finished
筛选 finishDate 在当前年份
统计数量
```

---

## 8.10 书籍总阅读时间

```text
筛选某本 Book 的 ReadingSession
累加 duration
```

---

## 8.11 书籍阅读次数

```text
统计某本 Book 的 ReadingSession 数量
```

---

# 9. 日期与时间规则

## 9.1 date 与 createdAt

`date` 表示阅读行为归属日期。

`createdAt` 表示记录创建时间。

补记场景：

```text
用户 5 月 20 日补记 5 月 18 日阅读
ReadingSession.date = 5 月 18 日 00:00
ReadingSession.createdAt = 5 月 20 日当前时间
```

---

## 9.2 startedAt 与 endedAt

每条 ReadingSession 必须拥有：

```text
startedAt
endedAt
duration
```

即使是手动记录，也必须通过开始时间 + 阅读时长计算结束时间。

---

## 9.3 跨天阅读

V1 简单处理：

```text
ReadingSession.date = startedAt 所在日期
```

例如 23:40–00:20 的阅读记录，归属为开始日期。

---

# 10. 校验规则

## 10.1 Book 校验

```text
title 不为空
rating 在 0–7 之间
totalAmount >= 0
currentAmount >= 0
currentAmount <= totalAmount，除非 totalAmount == 0
```

---

## 10.2 ReadingSession 校验

```text
book 不为空
endedAt >= startedAt
duration > 0
endAmount >= 0
startAmount >= 0
progressUnit 有效
```

建议：

```text
endAmount >= startAmount
```

如果用户输入低于当前进度，V1 先提示确认，不做复杂回读模型。

---

## 10.3 BookAnnotation 校验

```text
book 不为空
content 不为空
type 有效
```

---

## 10.4 UserConfig 校验

```text
dailyMinutesGoal >= 0
yearlyBooksGoal >= 0
libraryBooksGoal >= 0
```

---

# 11. 明确不进入本模型的内容

以下内容不进入 V1 基础模型：

```text
内置 EPUB 阅读器
PDF 阅读器
TXT 阅读器
Apple Books 进度读取
Kindle 进度读取
文件导入解析
CFI 定位
字符数统计
spine 权重进度
复杂摘录位置
摘录页码
阅读备注
回读模式
重读周期
标签独立模型
统计缓存表
iCloud 同步字段
日历同步字段
AI 总结字段
年度报告导出字段
```

---

# 12. 后续扩展预留

## 12.1 Calendar Sync

未来可以将 ReadingSession 同步到系统日历。

当前字段已具备：

```text
startedAt
endedAt
duration
book.title
```

未来可新增：

```text
calendarEventID
isSyncedToCalendar
```

V1 不添加。

---

## 12.2 iCloud Sync

未来可基于 SwiftData + CloudKit 扩展。

V1 先保证本地模型稳定。

---

## 12.3 ReadingCycle

未来支持重读时可新增：

```text
ReadingCycle
```

V1 不添加。

---

## 12.4 Tag 模型

未来标签系统复杂后可从 `[String]` 迁移到独立 `Tag` 模型。

V1 不添加。

---

# 13. 核心总结

V1 的基础参数目标是：

**苹果原生、极简高级、安静克制、轻玻璃、有纸质阅读感。**

V1 的核心数据模型是：

```text
Book 保存书籍状态和当前进度。
ReadingSession 保存每一次真实阅读的时间与进度变化。
BookAnnotation 只保存最简单的读书摘录或笔记。
UserConfig 只保存阅读时间目标和基础目标设置。
Snippet 保留为独立泛摘录模型，但不接入阅读记录主流程。
```

一句话：

**Book 记录“我在读什么”，ReadingSession 记录“我这次读了多久、读到哪里”，BookAnnotation 记录“我从这本书里留下了什么”。**
