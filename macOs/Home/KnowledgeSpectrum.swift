#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 🧠 知识基因图谱

/// 全宽铺开的知识维度光谱彩带。
///
/// 最高排名的 5 个维度将被映射为长度不等、颜色绚丽的光滑胶囊条，呈现用户的宏观知识面分布。
struct FluidKnowledgeSpectrumCard: View {
    let readBooks: [Book]
    @State private var data: [(String, Double, Color)] = []
    let colors: [Color] = [.purple, .indigo, .teal, .orange, .blue]
    
    var body: some View {
        GroupBox {
            if data.isEmpty {
                VStack(spacing: 8) { Image(systemName: "chart.pie").font(.system(size: 24)).foregroundColor(.secondary.opacity(0.4)); Text("缺乏数据").font(.system(size: 13)).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    GeometryReader { geo in
                        HStack(spacing: 4) {
                            ForEach(0..<data.count, id: \.self) { i in
                                Rectangle().fill(data[i].2.gradient).frame(width: max(0, geo.size.width * (data[i].1 / 100.0) - 4))
                            }
                        }
                        .clipShape(Capsule())
                    }.frame(height: 18)
                    
                    HStack(spacing: 40) {
                        ForEach(0..<data.count, id: \.self) { i in
                            HStack(spacing: 8) {
                                Circle().fill(data[i].2).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(data[i].0).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                                    Text("\(Int(data[i].1))%").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        } label: {
            HStack { Text("知识基因").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary); Spacer(); Image(systemName: "chart.pie.fill").foregroundColor(.purple) }
        }
        .groupBoxStyle(NativeWidgetGroupBoxStyle())
        .onAppear { process() }.onChange(of: readBooks) { _, _ in process() }
    }
    
    private func process() {
        var counts: [String: Double] = [:]; var total = 0.0
        for b in readBooks { for t in b.tags ?? [] { counts[t, default: 0] += 1; total += 1 } }
        guard total > 0 else { data = []; return }
        data = counts.sorted { $0.value > $1.value }.prefix(5).enumerated().map { ($0.element.key, ($0.element.value / total) * 100.0, colors[$0.offset % colors.count]) }
    }
}
#endif
