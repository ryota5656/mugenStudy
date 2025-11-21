import SwiftUI
import StoreKit
import UIKit

// MARK: - Subscription Management launcher (file-private, reusable)
fileprivate func openManageSubscriptionsGlobal() {
    if let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first {
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    await UIApplication.shared.open(url)
                }
            }
        }
    } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
        Task {
            await UIApplication.shared.open(url)
        }
    }
}

struct SettingsView: View {
    @AppStorage("isSubscribed") private var isSubscribed: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showPaywall: Bool = false
    @State private var notificationsEnabled: Bool = true
    @State private var hapticsEnabled: Bool = true
    @State private var animateCTA: Bool = false
    @StateObject private var skManager = StoreKitSubscriptionManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("アカウント")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ゲストユーザー").font(.headline)
                            Text(isSubscribed ? "サブスク: 有効" : "サブスク: 未加入")
                                .font(.subheadline)
                                .foregroundStyle(isSubscribed ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("アプリ設定")) {
                    Toggle("テーマを変更（ダークモード）", isOn: $isDarkMode)
                }
                
                Section(header: Text("サブスクリプション")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSubscribed ? "ご利用中のプラン: プラス" : "プラスプラン未加入")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if isSubscribed {
                            Button {
                                openManageSubscriptionsGlobal()
                            } label: {
                                Label("プランを管理", systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                ZStack {
                                    // リッチなグラデーション背景
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [
                                                Color(hex: 0x6D4AFF),
                                                Color(hex: 0x9B5CFF),
                                                Color(hex: 0xFF6AD5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .shadow(color: Color(hex: 0x6D4AFF).opacity(0.35), radius: 16, x: 0, y: 10)
                                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                    
                                    // 外枠の微光
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(LinearGradient(
                                            colors: [Color.white.opacity(0.8), Color.white.opacity(0.15)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ), lineWidth: 1.5)
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: "crown.fill")
                                            .font(.title3.bold())
                                            .foregroundStyle(.yellow)
                                            .shadow(color: .yellow.opacity(0.6), radius: 6, x: 0, y: 0)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("サブスクリプションに加入")
                                                .font(.headline.bold())
                                                .foregroundStyle(.white)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.white.opacity(0.9))
                                            .font(.headline)
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)

                                }
                                .frame(maxWidth: .infinity)
                                .onAppear { animateCTA = true }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            
            // App Review 対応: サブスク表示義務（タイトル/期間/価格/単価）
            Section(header: Text("サブスクリプションの詳細")) {
                if let product = skManager.products.first {
                    LabeledContent("タイトル", value: product.displayName)
                    LabeledContent("期間", value: subscriptionPeriodText(product))
                    LabeledContent("価格", value: product.displayPrice)
                    if let unitPrice = unitPricePerMonthText(product) {
                        LabeledContent("単価換算", value: unitPrice)
                    }
                } else {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("価格情報を読み込み中…").foregroundStyle(.secondary)
                    }
                    .task { await skManager.loadProducts() }
                }
            }
            
            // App Review 対応: プライバシーポリシー / 利用規約 へのリンク
            Section(header: Text("ポリシー")) {
                if let privacyURL = URL(string: "https://note.com/quirky_magpie934/n/nf837a51b90bc"),
                   let termsURL = URL(string: "https://note.com/quirky_magpie934/n/nd429b96dc394") {
                    Link("プライバシーポリシー", destination: privacyURL)
                    Link("利用規約（EULA）", destination: termsURL)
                }
            }
                
            }
            .navigationTitle("設定")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isSubscribed: $isSubscribed)
                .environmentObject(skManager)
        }
    }
}

// MARK: - Helpers
private extension SettingsView {
    func subscriptionPeriodText(_ product: Product) -> String {
        guard let p = product.subscription?.subscriptionPeriod else { return "-" }
        let unit: String
        switch p.unit {
        case .day: unit = "日"
        case .week: unit = "週"
        case .month: unit = "か月"
        case .year: unit = "年"
        @unknown default: unit = ""
        }
        return "\(p.value)\(unit)"
    }
    
    func unitPricePerMonthText(_ product: Product) -> String? {
        guard let p = product.subscription?.subscriptionPeriod else { return nil }
        // 年額または複数月のプランを月額換算で表示
        var divisor: Int?
        switch p.unit {
        case .year: divisor = 12
        case .month where p.value > 1: divisor = p.value
        default: divisor = nil
        }
        guard let d = divisor, d > 0 else { return nil }
        let total = NSDecimalNumber(decimal: product.price)
        let per = total.dividing(by: NSDecimalNumber(value: d)).decimalValue
        let formatted = per.formatted(product.priceFormatStyle)
        return "\(formatted) / 月"
    }
}

private struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isSubscribed: Bool
    @EnvironmentObject private var skManager: StoreKitSubscriptionManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("MUGEN STUDY PLUS").font(.title.bold())
                    Text("機能制限解除・広告非表示")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("機能制限解除", systemImage: "sparkles")
                    Label("広告が表示されません（開発中）", systemImage: "nosign")
                    Label("分析機能も開発中", systemImage: "sparkles")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("いつでもキャンセル可能").font(.footnote).foregroundStyle(.secondary)
                }
                
                // StoreKit2: 購入ボタン（商品読み込み→購入）
                Group {
                    if let product = skManager.products.first {
                        Button {
                            Task {
                                let ok = await skManager.purchase(product)
                                if ok {
                                    isSubscribed = true
                                    dismiss()
                                }
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [
                                            Color(hex: 0x6D4AFF),
                                            Color(hex: 0x9B5CFF),
                                            Color(hex: 0xFF6AD5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .shadow(color: Color(hex: 0x6D4AFF).opacity(0.35), radius: 16, x: 0, y: 10)
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(LinearGradient(
                                        colors: [Color.white.opacity(0.8), Color.white.opacity(0.15)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ), lineWidth: 1.5)
                                HStack(spacing: 10) {
                                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                    Text("\(product.displayPrice)で今すぐ開始")
                                        .bold()
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                        }
                        .frame(maxHeight: 50)
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    } else {
                        Button {
                            Task { await skManager.loadProducts() }
                        } label: {
                            Label("価格を読み込み", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        .disabled(skManager.isLoading)
                    }
                }
                
                // 購入を復元
                Button {
                    Task {
                        await skManager.restorePurchases()
                        if skManager.isSubscribed {
                            isSubscribed = true
                            dismiss()
                        }
                    }
                } label: {
                    Text("購入を復元").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                
                // サブスク解約/管理（App Storeの管理画面へ）
                Button {
                    openManageSubscriptionsGlobal()
                } label: {
                    Text("サブスクリプションを管理（解約）").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                
                Button {
                    dismiss()
                } label: {
                    Text("閉じる").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 12)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.white)
        }
        .task {
            if skManager.products.isEmpty {
                await skManager.loadProducts()
            }
        }
    }
}

#Preview {
    SettingsView()
}
