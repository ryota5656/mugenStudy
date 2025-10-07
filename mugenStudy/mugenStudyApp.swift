//
//  mugenStudyApp.swift
//  mugenStudy
//
//  Created by ryota.saito on 2025/09/05.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import RealmSwift
import Realm

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    // Enable Firestore offline persistence explicitly
    let settings = FirestoreSettings()
    settings.isPersistenceEnabled = true
    Firestore.firestore().settings = settings

    // Realm migration: bump schema when AnswerHistoryObject fields changed
    let realmConfig = Realm.Configuration(
      schemaVersion: 1,
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView { ToeicPart5View() }
                    .tabItem {
                        Label("出題", systemImage: "doc.text.magnifyingglass")
                    }
                NavigationView { SavedQuestionListView() }
                    .tabItem {
                        Label("保存", systemImage: "tray.full")
                    }
                NavigationView { AnswerHistoryView() }
                    .tabItem {
                        Label("履歴", systemImage: "clock.arrow.circlepath")
                    }
            }
        }
    }
}

