import SwiftUI
import FirebaseCore
import FirebaseFirestore
import RealmSwift
import Realm
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    // Enable Firestore offline persistence explicitly
    let settings = FirestoreSettings()
    settings.isPersistenceEnabled = true
    Firestore.firestore().settings = settings
    //キャッシュ削除
//    settings.isPersistenceEnabled = false
    Firestore.firestore().clearPersistence()
      
    // adMob SDK初期化
    MobileAds.shared.start(completionHandler: nil)

    // Realm migration: bump schema when AnswerHistoryObject fields changed
    let realmConfig = Realm.Configuration(
      schemaVersion: 2,
      migrationBlock: { migration, oldSchemaVersion in
        if oldSchemaVersion < 1 {
          migration.enumerateObjects(ofType: AnswerHistoryObject.className()) { oldObject, newObject in
            // Old schema may have had 'isCorrect' Bool instead of counters
            let wasCorrect = (oldObject?["isCorrect"] as? Bool) ?? false
            // Initialize new counters
            newObject?["totalCount"] = (newObject?["totalCount"] as? Int) ?? 1
            newObject?["totalCorrect"] = (newObject?["totalCorrect"] as? Int) ?? (wasCorrect ? 1 : 0)
            // Initialize timestamps
            let created = (oldObject?["createdAt"] as? Date) ?? Date()
            newObject?["createdAt"] = (newObject?["createdAt"] as? Date) ?? created
            newObject?["updatedAt"] = (newObject?["updatedAt"] as? Date) ?? created
          }
        }
      }
    )
    Realm.Configuration.defaultConfiguration = realmConfig

    return true
  }
}

@main
struct MugenStudyApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView { ToeicMainView() }
                    .tabItem {
                        Label("ホーム", systemImage: "clock.arrow.circlepath")
                    }
                NavigationView { SettingsView() }
                    .tabItem {
                        Label("設定", systemImage: "gearshape")
                    }
            }
            BannerAdView(adUnitID: Bundle.main.object(forInfoDictionaryKey: "GGAD_AT_HOME_BOTTOM_BANNER") as? String)
                .frame(height: 50)
                .background(Color.clear)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

