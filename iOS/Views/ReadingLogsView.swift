import SwiftUI

struct ReadingLogsView: View {
    let logs: [ReadingLog]
    let onAddLog: () -> Void

    private var totalMinutes: Int {
        logs.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        PageShell(title: "记录", subtitle: "只记录手动输入的阅读时长") {
            AppCard {
                HStack {
                    MetricValue(value: "\(totalMinutes)", label: "总分钟")
                    Spacer()
                    MetricValue(value: "\(logs.count)", label: "记录")
                    Spacer()
                    MetricValue(value: "\(readingDays)", label: "天")
                }
            }

            if logs.isEmpty {
                AppCard {
                    EmptyHint(title: "还没有阅读记录", message: "阅读之后手动记录时长即可，不做计时器。")
                    Button(action: onAddLog) {
                        Label("记录阅读", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(logs) { log in
                        AppCard(padding: 16) {
                            ReadingLogRow(log: log)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddLog) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var readingDays: Int {
        Set(logs.map { Calendar.current.startOfDay(for: $0.date) }).count
    }
}

struct ReadingLogRow: View {
    let log: ReadingLog

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: log.date))")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(log.date.formatted(.dateTime.month(.narrow)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(log.book?.title ?? "未知书籍")
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text("\(log.minutes) 分钟")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                if log.pageAfterReading > 0 {
                    Text("读到第 \(log.pageAfterReading) 页")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
    }
}

private struct MetricValue: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
