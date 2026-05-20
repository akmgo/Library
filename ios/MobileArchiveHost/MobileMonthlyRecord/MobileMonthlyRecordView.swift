#if os(iOS)
import SwiftUI
import SwiftData
import Charts

// MARK: - 🗓️ 核心月度记录视图 (原生秒开版)

struct MobileMonthlyRecordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    
    let daysOfWeek = ["一", "二", "三", "四", "五", "六", "日"]

    private var monthlySnapshot: ReadingStatsCalculator.MonthlyArchiveSnapshot {
        ReadingStatsCalculator.monthlyArchiveSnapshot(sessions: sessions)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 32, pinnedViews: [.sectionHeaders]) {
                    ForEach(monthlySnapshot.sections) { section in
                        Section(header: monthSectionHeader(section)) {
                            monthGrid(section: section)
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 16)
                // 因为没有了悬浮 Header，顶部留白可以大大缩减，更紧凑
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            // 完全摒弃 opacity 和 offset 动画，原生直出
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(monthlySnapshot.currentMonthID, anchor: .top)
                }
            }
        }
    }
    
    // MARK: - ✨ UI 组件模块
    
    private func monthSectionHeader(_ section: ReadingStatsCalculator.ReadingMonthSection) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text("\(String(section.year))年")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Text("\(section.month)月")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 计算该月总时长
            let totalMins = section.days.compactMap { d -> Int? in
                guard let date = d, let duration = monthlySnapshot.durationByDay[Calendar.current.startOfDay(for: date)] else { return nil }
                return Int(duration / 60)
            }.reduce(0, +)
            
            if totalMins > 0 {
                Text("\(totalMins / 60)h \(totalMins % 60)m")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        .background(AppColors.primaryBackground(for: colorScheme)) // 吸顶时不透明
    }
    
    private func monthGrid(section: ReadingStatsCalculator.ReadingMonthSection) -> some View {
        VStack(spacing: 12) {
            // 星期表头
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary.opacity(0.5)).frame(maxWidth: .infinity)
                }
            }
            
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<section.days.count, id: \.self) { index in
                    if let date = section.days[index] {
                        MobileDayCardView(
                            date: date,
                            duration: monthlySnapshot.durationByDay[Calendar.current.startOfDay(for: date)]
                        )
                    } else {
                        Color.clear.frame(height: 70)
                    }
                }
            }
        }
    }
}

// MARK: - ✨ 单日卡片 (精准应用 VisualEngines)

struct MobileDayCardView: View {
    let date: Date
    let duration: TimeInterval?
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isPressed = false
    
    var body: some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let mins = Int((duration ?? 0) / 60)
        
        ZStack {
            // 底板
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .fill(duration != nil ? AppColors.secondaryBackground(for: colorScheme) : Color.secondary.opacity(0.04))
            
            // ✨ 视觉引擎：热力柱渲染
            if duration != nil, mins > 0 {
                VStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(VisualEngines.ReadingHeatmap.gradient(for: mins))
                        // 移动端高度适配：在 Mac 规范基础上乘以 0.8
                        .frame(height: VisualEngines.ReadingHeatmap.height(for: mins) * 0.8)
                        .padding(4)
                        .shadow(color: VisualEngines.ReadingHeatmap.shadowColor(for: mins).opacity(0.3), radius: 4, y: 2)
                }
            }
            
            // 日期数字
            VStack {
                HStack {
                    ZStack {
                        if isToday { Circle().fill(Color.red).frame(width: 18, height: 18) }
                        Text("\(cal.component(.day, from: date))")
                            .font(.system(size: 12, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundColor(isToday ? .white : (duration != nil ? .primary : .secondary.opacity(0.4)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(6)
        }
        .frame(height: 72)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onTapGesture {
            if duration != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring()) { isPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { isPressed = false } }
            }
        }
    }
}

#endif
