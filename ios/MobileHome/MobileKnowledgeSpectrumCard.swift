#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 🧠 知识图谱条带

/// 提取已读书籍偏好标签，构建可视化的知识结构光谱。
///
/// **数据特征：**
/// 该组件只会扫描 `status == .finished` 的书籍。通过聚合这些书籍身上的 `tags` 集合，
/// 提取出频率最高的 4 个标签，并在 UI 层以不同宽度的彩色 `Capsule` 展示个人的读书知识图谱。
struct MobileKnowledgeSpectrumCard: View {
    let readBooks: [Book]
    
    @State private var spectrumData: [(name: String, value: Double, color: Color)] = []
    let palette: [Color] = [.purple, .indigo, .teal, .orange, .blue]
    
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                if spectrumData.isEmpty {
                    Text("缺乏数据建立图谱")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(minHeight: 60)
                } else {
                    // 光谱条形图
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(spectrumData, id: \.name) { item in
                                Rectangle()
                                    .fill(item.color.gradient)
                                    .frame(width: max(geo.size.width * CGFloat(item.value / 100.0) - 2, 0))
                            }
                        }
                        .clipShape(Capsule())
                    }.frame(height: 12)
                    
                    // 下方色块文字图例
                    HStack(spacing: 16) {
                        ForEach(spectrumData, id: \.name) { item in
                            HStack(spacing: 4) {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text(item.name).font(.system(size: 11, weight: .bold))
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("知识图谱")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
            }
        }
        .onAppear { process() }
        .onChange(of: readBooks) { _, _ in process() }
    }
    
    // MARK: - 标签频率统计算法
    
    private func process() {
        var counts: [String: Double] = [:]
        var total = 0.0
        
        for book in readBooks {
            for tag in book.tags ?? [] {
                let c = tag.trimmingCharacters(in: .whitespaces)
                if !c.isEmpty {
                    counts[c, default: 0] += 1
                    total += 1
                }
            }
        }
        
        guard total > 0 else {
            spectrumData = []
            return
        }
        
        // 提取最高频的前 4 个标签并计算百分比，附着独立色彩
        spectrumData = counts
            .sorted { $0.value > $1.value }
            .prefix(4)
            .enumerated()
            .map {
                ($0.element.key, ($0.element.value / total) * 100.0, palette[$0.offset % palette.count])
            }
    }
}
#endif
