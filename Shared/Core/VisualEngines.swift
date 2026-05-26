import SwiftUI

/// 🎨 全局视觉与计算引擎
struct VisualEngines {
    
    // MARK: - 🔥 跨模块：阅读热力图计算引擎
    
    struct ReadingHeatmap {
        
        /// 核心归一化逻辑：将分钟数转换为 0~6 的等级档位
        static func level(for minutes: Int) -> Int {
            switch minutes {
            case 0: return 0
            case 1...10: return 1
            case 11...20: return 2
            case 21...30: return 3
            case 31...40: return 4
            case 41...50: return 5
            default: return 6 // > 50 分钟
            }
        }
        
        /// (主页模块用) 计算热力点透明度 Intensity
        static func intensity(for minutes: Int) -> Double {
            switch level(for: minutes) {
            case 1: return 0.25
            case 2: return 0.40
            case 3: return 0.55
            case 4: return 0.70
            case 5: return 0.85
            case 6: return 1.00
            default: return 0.00
            }
        }
        
        /// (月度模块用) 计算对应的热力渐变色
        static func gradient(for minutes: Int) -> LinearGradient {
            switch level(for: minutes) {
            case 1: return LinearGradient(colors: [.teal.opacity(0.4), .cyan.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
            case 2: return LinearGradient(colors: [.cyan.opacity(0.6), .blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
            case 3: return LinearGradient(colors: [.blue.opacity(0.8), .indigo.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            case 4: return LinearGradient(colors: [.indigo.opacity(0.9), .purple.opacity(0.9)], startPoint: .leading, endPoint: .trailing)
            case 5: return LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
            case 6: return LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing)
            default: return LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing)
            }
        }
        
        /// (月度模块用) 计算热力柱物理高度
        static func height(for minutes: Int) -> CGFloat {
            switch level(for: minutes) {
            case 1: return 12
            case 2: return 20
            case 3: return 28
            case 4: return 36
            case 5: return 44
            case 6: return 52
            default: return 0
            }
        }
        
        /// (月度模块用) 计算热力光晕颜色
        static func shadowColor(for minutes: Int) -> Color {
            switch level(for: minutes) {
            case 1: return .teal
            case 2: return .cyan
            case 3: return .blue
            case 4: return .indigo
            case 5: return .purple
            case 6: return .orange
            default: return .clear
            }
        }
    }
}

