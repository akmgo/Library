#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🌊 流动书房主页 (UI 画布层)

struct HomeView: View {
    // MARK: - 📥 全局配置
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \BookAnnotation.createdAt, order: .reverse) private var annotations: [BookAnnotation]
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - 🎮 视图路由状态
    
    @Binding var selectedBook: Book? // 仅保留详情页绑定
    
    @State private var isEntranceAnimated: Bool = false

    private var dashboard: ReadingStatsCalculator.DashboardSnapshot {
        ReadingStatsCalculator.dashboardSnapshot(
            books: books,
            sessions: sessions,
            annotations: annotations
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                LazyVStack(spacing: 40) {
                    Spacer().frame(height: 120)
                        
                    // 🌟 Row 1: 核心操作区 (Hero Section) - UI 布局严格保留你的原样
                    HStack {
                        if let heroBook = dashboard.activeReadingBook {
                            ReadingHero(book: heroBook) {
                                // 点击右上角按钮：触发详情页
                                withAnimation(.appFluidSpring) { self.selectedBook = heroBook }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.appFluidSpring) { self.selectedBook = heroBook }
                            }
                            .onHover { isHovered in
                                if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        } else {
                            EmptyReadingHero()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        AmbientClock()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(height: 280)
                        
                    // 🌟 Row 2: 视觉数据双轨
                    VStack(spacing: 32) {
                        MomentumChart(dataPoints: dashboard.momentumPoints, totalMinutes: dashboard.momentumTotal)
                        HeatmapRibbon(columns: dashboard.heatmapColumns, activeDays: dashboard.heatmapActiveDays)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                        
                    // 🌟 Row 3: 思想碰撞与未来队列
                    HStack(spacing: 24) {
                        ResonanceWave(excerpts: dashboard.resonancePoints)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // ✨ 点击闭包：处理想读变在读，并发送阅读通知
                        QueueBookshelf(displayBooks: dashboard.queueBooks) { tappedBook in
                            startReadingFromQueue(book: tappedBook)
                        }
                    }
                    .frame(height: 300)

                    // 🌟 Row 4: 底部基石
                    KnowledgeSpectrum(dataPoints: dashboard.spectrumPoints)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(isEntranceAnimated ? 1.0 : 0.0)
            .offset(y: isEntranceAnimated ? 0 : 150)
            .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
            .animation(.appFluidSpring, value: isEntranceAnimated)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greeting)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        Text("Read as if you've never read...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : -200)
                    
                    Spacer()
                    
                    HStack(spacing: 32) {
                        MicroMetricRing(title: "本周打卡", current: dashboard.weekCount, target: 7, color: .pink, icon: "flame.fill")
                        MicroMetricRing(title: "本月历程", current: dashboard.monthlyDays, target: 30, color: .mint, icon: "calendar")
                        MicroMetricRing(title: "年度阅卷", current: dashboard.yearlyCount, target: yearTarget, color: .cyan, icon: "book.pages.fill")
                    }
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : 200)
                }
                .padding(.horizontal, 40)
                .padding(.top, 45)
                .padding(.bottom, 20)
                .animation(.appFluidSpring, value: isEntranceAnimated)
                
                Divider().background(Color.primary.opacity(0.05))
            }
            .frame(height: 130, alignment: .bottom)
            .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            guard !isEntranceAnimated else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.appFluidSpring) {
                    isEntranceAnimated = true
                }
            }
        }
    }
}

// MARK: - ⚙️ 异步数据调度引擎

extension HomeView {
    
    @MainActor
    private func startReadingFromQueue(book: Book) {
        if book.status == .planned {
            book.status = .reading
            book.startDate = Date()
            // ✨ 核心修复：一旦开始阅读，必须立即更新最后阅读时间，强制让它霸占焦点位！
            book.lastReadAt = Date()
            try? modelContext.save()
        }
        withAnimation(.appFluidSpring) { selectedBook = book }
    }
}

extension HomeView {
    private var yearTarget: Int { configs.first?.yearlyBooksGoal ?? 50 }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "晨光正好，宜卷开新章。" }
        else if hour < 14 { return "午后静谧，在文字中漫步。" }
        else if hour < 19 { return "夕阳西下，且将思想沉淀。" }
        else { return "夜色温润，伴书香入眠。" }
    }
}

private struct MicroMetricRing: View {
    let title: String; let current: Int; let target: Int; let color: Color; let icon: String
    var body: some View {
        let progress = min(Double(current) / Double(max(target, 1)), 1.0)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                Circle().trim(from: 0, to: CGFloat(progress)).stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.appFluidSpring, value: progress)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(color)
            }.frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(current)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    Text("/\(target)").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                }
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            }
        }
    }
}
#endif
