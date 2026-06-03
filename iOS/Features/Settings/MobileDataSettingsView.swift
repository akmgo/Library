#if os(iOS)
import SwiftUI

// MARK: - 🗄️ 3. 数据与安全页

struct MobileDataSettingsView: View {
    @Binding var systemMessage: AttributedString?
    @Environment(\.colorScheme) private var colorScheme

    @State private var isICloudAvailable: Bool = false
    @State private var currentCacheSizeMB: Double = 0.0
    
    var body: some View {
        Form {
            // ================= 1. 云端同步 =================
            Section {
                SettingsRow(icon: "icloud.fill", iconColor: .blue, title: "iCloud 同步", subtitle: "利用 CloudKit 在所有 Apple 设备间无缝流转数据", titleSize: 15, subtitleSize: 11, subtitleLineLimit: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isICloudAvailable ? AppColors.success : Color.red)
                            .frame(width: 8, height: 8)
                        Text(isICloudAvailable ? "已连接" : "未授权")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isICloudAvailable ? .primary : .red)
                    }
                }
            } header: { Text("云端服务") }

            // ================= 2. 存储管理 =================
            Section {
                SettingsRow(icon: "trash.fill", iconColor: .gray, title: "清理缓存", subtitle: "释放网络图片与接口在内存与磁盘中的临时文件", titleSize: 15, subtitleSize: 11, subtitleLineLimit: 2) {
                    // ✨ 优化：垂直布局对齐，且按钮样式 1:1 统一“清空历史”按钮
                    VStack(alignment: .trailing, spacing: 10) {
                        Text(String(format: "%.1f MB", currentCacheSizeMB))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button(action: performRealCacheClear) {
                            Text("清理缓存")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(currentCacheSizeMB <= 0.1 ? .secondary : .red)
                                .padding(.horizontal, AppSpacing.m)
                                .padding(.vertical, AppSpacing.xs)
                                .background(currentCacheSizeMB <= 0.1 ? AppColors.innerBlock(for: colorScheme) : AppColors.danger.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: { Text("存储管理") }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.primaryBackground(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkICloudStatus()
            calculateCacheSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSUbiquityIdentityDidChange)) { _ in checkICloudStatus() }
    }
    
    // MARK: - iCloud 探针 & 存储清理逻辑
    
    private func checkICloudStatus() {
        DispatchQueue.main.async { self.isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil }
    }

    private func calculateCacheSize() {
        DispatchQueue.global(qos: .userInitiated).async {
            let memoryCache = URLCache.shared.currentMemoryUsage
            let diskCache = URLCache.shared.currentDiskUsage
            var totalBytes = memoryCache + diskCache
            let tempDir = FileManager.default.temporaryDirectory
            if let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for fileURL in tempFiles {
                    if let dict = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = dict.fileSize { totalBytes += fileSize }
                }
            }
            let mbSize = Double(totalBytes) / 1024.0 / 1024.0
            DispatchQueue.main.async { self.currentCacheSizeMB = mbSize }
        }
    }

    private func performRealCacheClear() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let clearedSize = currentCacheSizeMB
        
        URLCache.shared.removeAllCachedResponses()
        let tempDir = FileManager.default.temporaryDirectory
        if let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for fileURL in tempFiles { try? FileManager.default.removeItem(at: fileURL) }
        }
        
        calculateCacheSize()
        showToast(String(format: "✨ 释放了 %.1f MB 缓存", clearedSize))
    }

    private func showToast(_ msg: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { systemMessage = AttributedString(msg) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { systemMessage = nil } }
    }
}

#if DEBUG
private struct PreviewDataSettings: View {
    @State private var msg: AttributedString? = nil
    var body: some View {
        PreviewWithData {
            MobileDataSettingsView(systemMessage: $msg)
        }
    }
}

#Preview("数据设置") {
    PreviewDataSettings()
}
#endif


#endif
