import SwiftUI

struct ReadingLogsView: View {
    let logs: [ReadingLog]
    let onAddLog: () -> Void

    private var totalMinutes: Int {
        logs.reduce(0) { $0 + $1.minutes }
    }

    private var readingDays: Int {
        Set(logs.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var groupedLogs: [LogDayGroup] {
        let groups = Dictionary(grouping: logs) { Calendar.current.startOfDay(for: $0.date) }
        return groups
            .map { day, items in
                LogDayGroup(day: day, logs: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        PageShell {
            AppCard {
                HStack(spacing: 18) {
                    FactPill(value: "\(totalMinutes)", label: "分钟")
                    FactPill(value: "\(logs.count)", label: "记录")
                    FactPill(value: "\(readingDays)", label: "天")
                }
            }

            if logs.isEmpty {
                AppCard {
                    EmptyHint(
                        title: "还没有阅读记录",
                        message: "读完一段之后，手动记下这次阅读了多久、读到哪一页。",
                        systemImage: "calendar"
                    )
                    PrimaryActionButton(title: "记录阅读", systemImage: "plus", action: onAddLog)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(groupedLogs) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: group.title, subtitle: "\(group.minutes) 分钟")
                            AppCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(group.logs) { log in
                                        if let book = log.book {
                                            NavigationLink {
                                                BookDetailView(book: book)
                                            } label: {
                                                ReadingLogRow(log: log)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            ReadingLogRow(log: log)
                                        }

                                        if log.id != group.logs.last?.id {
                                            Divider()
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddLog) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("记录阅读")
            }
        }
        .animation(AppTheme.contentAnimation, value: groupedLogs.map(\.id))
    }
}

struct ReadingLogRow: View {
    let log: ReadingLog

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: log.date))")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(log.date.formatted(.dateTime.month(.narrow)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text(log.book?.title ?? "未知书籍")
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(log.minutes) 分钟")
                    if log.pageAfterReading > 0 {
                        Text("读到第 \(log.pageAfterReading) 页")
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if log.book != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct LogDayGroup: Identifiable {
    let day: Date
    let logs: [ReadingLog]

    var id: Date { day }

    var title: String {
        if Calendar.current.isDateInToday(day) {
            return "今天"
        }
        if Calendar.current.isDateInYesterday(day) {
            return "昨天"
        }
        return day.formatted(.dateTime.month(.wide).day())
    }

    var minutes: Int {
        logs.reduce(0) { $0 + $1.minutes }
    }
}
