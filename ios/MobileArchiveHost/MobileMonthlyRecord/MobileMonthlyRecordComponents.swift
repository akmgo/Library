#if os(iOS)
import SwiftUI
import SwiftData
import Charts

// MARK: - 📱 单日微型画廊卡片

/// 月度日历中的原子组件，负责呈现每一天的阅读摘要。
///
/// **视觉反馈：**
/// 若当日有阅读记录，不仅会高亮显示，如果达到 60 分钟 (1小时)，还会触发 `.orange` 和 `.pink` 混合的庆祝发光光斑 (`isCelebration`)。
struct MobileDayCardView: View {
    let date: Date
    let record: ReadingRecord?
    
    var body: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let hasRead = record != nil
        let dateString = "\(calendar.component(.day, from: date))"
        
        let totalSeconds = Int(record?.readingDuration ?? 0)
        let dailyMinutes = totalSeconds > 0 ? max(1, totalSeconds / 60) : 0
        
        ZStack {
            // 1. 极简呼吸感底板
            if !hasRead {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isToday ? Color.red.opacity(0.4) : Color.primary.opacity(0.03), lineWidth: isToday ? 1.5 : 1)
                    )
            }
            
            // 2. 封面渲染
            if let book = record?.book {
                let safeTitle = book.title ?? "未知书名"
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
            } else if hasRead {
                // 有记录但没关联封面时的降级兜底
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.teal.opacity(0.15))
                    .overlay(Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundColor(.teal))
            }
            
            // 3. 日期数字渲染
            if hasRead {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            if isToday {
                                Capsule()
                                    .fill(Color.red.gradient)
                                    .frame(width: 18, height: 14)
                                    .shadow(color: Color.red.opacity(0.3), radius: 2, y: 1)
                            }
                            Text(dateString)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: isToday ? .clear : .black.opacity(0.6), radius: 1, y: 1)
                        }
                    }
                }
                .padding(4)
            } else {
                ZStack {
                    if isToday {
                        Text(dateString).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(.red)
                    } else {
                        Text(dateString).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        .onTapGesture {
            if hasRead {
                let impact = UIImpactFeedbackGenerator(style: .soft)
                impact.impactOccurred()
            }
        }
    }
}
#endif
