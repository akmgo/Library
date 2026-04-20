#if os(iOS)
import ActivityKit
import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

/// 灵动岛及锁屏活动的极简封面提取视图。
struct LiveActivityCoverView: View {
    let coverFilePath: String? // ✨ 接收路径
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15))
            
            if let path = coverFilePath,
               let uiImage = UIImage(contentsOfFile: path)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.orange.opacity(0.8))
                    .font(.system(size: 36))
            }
        }
    }
}

/// ==================================================
/// ⏱️ 实时活动：三分层结构 (触顶 160pt 方案)
/// ==================================================
struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingTimerAttributes.self) { context in
            HStack(spacing: 16) {
                // ================= 左侧：144pt 极限封面 =================
                LiveActivityCoverView(coverFilePath: context.attributes.coverFilePath)
                    .frame(width: 96, height: 144)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                
                // ================= 右侧：三层信息与控制区 =================
                VStack(alignment: .leading, spacing: 0) {
                    // ---------------- 1. 顶层：书名与作者 ----------------
                    HStack(alignment: .top) {
                        Text(context.attributes.bookTitle)
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        Text(context.attributes.author)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                    }
                    .padding(.top, 5)
                    
                    Spacer(minLength: 0) // 弹性空间 1
                    
                    // ---------------- 2. 中层：进度 (左) + 结束按钮 (中) + 计时器与进度段 (右) ----------------
                    HStack(alignment: .center, spacing: 12) {
                        // ✨ 左侧：阅读进度，紧贴封面
                        Text("\(context.attributes.bookProgress)%")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.orange)
                            .lineLimit(1) // 🚫 绝对不允许换行
                            .fixedSize(horizontal: true, vertical: false) // 🚫 强制系统在一行显示完整，宁可突破边界也绝不上下折叠！
                            .minimumScaleFactor(0.8)
                            .offset(y: 30) // 你的核心微调
                                                                    
                        // ✨ 核心弹簧：把进度顶在左侧，把按钮和倒计时死死推向右侧
                        Spacer(minLength: 0)
                                                                    
                        // ✨ 中间：结束按钮，紧贴数字
                        Button(intent: StopTimerIntent(bookTitle: context.attributes.bookTitle)) {
                            Image(systemName: "stop.circle.fill")
                                .resizable()
                                .frame(width: 46, height: 46) // 稍微收缩至 48，保障各种屏幕绝不越界
                                .foregroundColor(.red.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                                                                    
                        // ✨ 右侧：上下布局 (上数字，下圆点)
                        VStack(alignment: .trailing, spacing: 8) {
                            // 右上：倒计时器
                            Text(timerInterval: Date()...context.state.cycleEndTime, countsDown: true)
                                .font(.system(size: 48, weight: .semibold, design: .rounded)) // 微调字号，防爆屏
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .multilineTextAlignment(.trailing)
                                .padding(.bottom, -6)
                                .frame(width: 130, alignment: .trailing) // ✨ 极其重要：锁死宽度，防止数字变化引起 UI 左右抖动
                                                                                
                            // 右下：计时段圆点
                            HStack(spacing: 12) { // 缩小圆点间距防越界
                                ForEach(0 ..< 5, id: \.self) { index in
                                    Circle()
                                        .fill(index < context.state.completedCycles ? Color.orange : Color.gray.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 25)
                        }
                    }
                    .padding(.horizontal, 5)
                    
                    Spacer(minLength: 0) // 弹性空间 2
                    
                    // ---------------- 3. 底层：纯条形进度条 ----------------
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: max(0, geometry.size.width * CGFloat(context.attributes.bookProgress) / 100.0), height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.bottom, 5)
                }
                .frame(height: 144)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .activityBackgroundTint(Color.clear)
            
        } dynamicIsland: { context in
            // (灵动岛代码保持不变)
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.2)).frame(width: 45, height: 45)
                        Image(systemName: "book.fill").font(.system(size: 22)).foregroundColor(.orange)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.cycleEndTime, countsDown: true)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 95, alignment: .trailing)
                        .padding(.horizontal, 3)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(context.attributes.bookTitle)
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer(minLength: 16)
                            Text(context.attributes.author)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            ForEach(0 ..< 5, id: \.self) { index in
                                Capsule()
                                    .fill(index < context.state.completedCycles ? Color.orange : Color.white.opacity(0.15))
                                    .frame(height: 6)
                            }
                        }
                    }
                    .padding(.top, 5).padding(.bottom, 8).padding(.leading, 4).padding(.horizontal, 3)
                }
            } compactLeading: {
                Image(systemName: "book.fill").foregroundColor(.orange).frame(minWidth: 24, alignment: .leading)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.cycleEndTime, countsDown: true)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.orange)
                    .frame(maxWidth: 44, alignment: .trailing)
            } minimal: {
                Image(systemName: "timer").foregroundColor(.orange)
            }
        }
    }
}

// MARK: - 🎨 实时活动 & 灵动岛专属预览

#Preview("锁屏卡片外观", as: .content, using: ReadingTimerAttributes(bookTitle: "百年孤独", author: "加西亚·马尔克斯")) {
    ReadingLiveActivity()
} contentStates: {
    ReadingTimerAttributes.ContentState(cycleEndTime: Date().addingTimeInterval(15 * 60), completedCycles: 2)
}
#endif
