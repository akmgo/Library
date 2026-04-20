#if os(iOS)
import SwiftUI
import SwiftData
import Charts

// MARK: - 📈 动能折线组件

/// 横向拉满的双周动能折线面积图。
///
/// 利用 `Swift Charts` 对前 14 天的阅读秒数进行按日平滑插值渲染 (`.catmullRom`)。
struct MobileMomentumChartCard: View {
    let allRecords: [ReadingRecord]
    
    @State private var dailyData: [(date: Date, minutes: Double)] = []
    @State private var totalDays = 0; @State private var totalMinutes = 0; @State private var maxMinutes = 0; @State private var avgMinutes = 0
    
    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                // 上部：四大指标
                HStack(alignment: .center, spacing: 0) {
                    MomentumAppStat(title: "阅读天数", value: "\(totalDays)", unit: "天")
                    Spacer(minLength: 5)
                    MomentumAppStat(title: "总计时间", value: "\(totalMinutes)", unit: "分")
                    Spacer(minLength: 5)
                    MomentumAppStat(title: "单日最高", value: "\(maxMinutes)", unit: "分")
                    Spacer(minLength: 5)
                    MomentumAppStat(title: "日均阅读", value: "\(avgMinutes)", unit: "分")
                }
                .padding(.bottom, 16)
                
                // 下部：折线面积图
                if dailyData.isEmpty {
                    VStack { Text("暂无数据").font(.system(size: 14)).foregroundColor(.secondary) }.frame(maxWidth: .infinity, minHeight: 70)
                } else {
                    Chart(dailyData, id: \.date) { item in
                        AreaMark(x: .value("Day", item.date), y: .value("Minutes", item.minutes))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", item.date), y: .value("Minutes", item.minutes))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                            AxisValueLabel(format: .dateTime.day()).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.secondary)
                        }
                    }
                    .frame(height: 70)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Text("双周动能").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "waveform.path.ecg").foregroundColor(.blue)
            }
        }
        .onAppear { processData() }
        .onChange(of: allRecords) { _, _ in processData() }
    }
    
    private func processData() {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date()); let startDate = cal.date(byAdding: .day, value: -13, to: today)!
        var dailyMap: [Date: Double] = [:]
        for record in allRecords {
            let recDay = cal.startOfDay(for: record.date ?? .distantPast)
            if recDay >= startDate, recDay <= today { dailyMap[recDay, default: 0] += (record.readingDuration / 60.0) }
        }
        
        var tempData: [(Date, Double)] = []; var daysRead = 0; var tMin = 0.0; var mMin = 0.0
        for i in 0..<14 {
            let d = cal.date(byAdding: .day, value: i, to: startDate)!
            let mins = dailyMap[d] ?? 0.0
            tempData.append((d, mins))
            if mins > 0 { daysRead += 1 }
            if mins > mMin { mMin = mins }
            tMin += mins
        }
        dailyData = tempData; totalDays = daysRead; totalMinutes = Int(tMin); maxMinutes = Int(mMin)
        avgMinutes = daysRead > 0 ? Int(tMin / Double(daysRead)) : 0
    }
}

private struct MomentumAppStat: View {
    let title: String; let value: String; let unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text(unit).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}
#endif
