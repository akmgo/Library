#if os(macOS)
import SwiftUI

struct DataSettingsView: View {
    @Binding var systemMessage: AttributedString?
    @Environment(\.colorScheme) private var colorScheme

    // ================= 状态与存储 =================
    @State private var isICloudAvailable: Bool = false
    @State private var currentCacheSizeMB: Double = 0.0

    var body: some View {
        Form {
            // ================= 1. 云端同步 =================
            Section {
                SettingsRow(icon: "icloud.fill", iconColor: .blue, title: "iCloud 同步", subtitle: "利用 CloudKit 在所有 Apple 设备间无缝流转数据") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isICloudAvailable ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                            .shadow(color: isICloudAvailable ? Color.green : Color.red, radius: 2)
                        Text(isICloudAvailable ? "已连接" : "未授权")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isICloudAvailable ? .primary : .red)
                    }
                }
            } header: { Text("云端服务").font(.system(size: 13, weight: .bold)) }

            // ================= 2. 存储管理 =================
            Section {
                SettingsRow(icon: "trash.fill", iconColor: .gray, title: "清理网络与图片缓存", subtitle: "释放网络图片与接口在内存与磁盘中的临时文件") {
                    HStack(spacing: 12) {
                        Text(String(format: "%.1f MB", currentCacheSizeMB)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.secondary).frame(width: 60, alignment: .trailing)
                        Button(action: performRealCacheClear) {
                            Text("清理缓存").font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(AppColors.innerBlock(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1))
                        .disabled(currentCacheSizeMB <= 0.1)
                        .opacity(currentCacheSizeMB <= 0.1 ? 0.4 : 1.0)
                    }
                }
            } header: { Text("存储管理").font(.system(size: 13, weight: .bold)) }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.primaryBackground(for: colorScheme))
        .onAppear {
            checkICloudStatus()
            calculateCacheSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in checkICloudStatus() }
    }
    
    // MARK: - iCloud 探针 & 存储逻辑
    
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
        let clearedSize = currentCacheSizeMB
        URLCache.shared.removeAllCachedResponses()
        let tempDir = FileManager.default.temporaryDirectory
        if let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for fileURL in tempFiles {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        calculateCacheSize()
        showToast(String(format: "✨ 清理完成！释放了 %.1f MB 的缓存。", clearedSize))
    }

    private func showToast(_ msg: String) {
        withAnimation { systemMessage = AttributedString(msg) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { systemMessage = nil } }
    }
}
#endif
