import SwiftUI
import MWDATCore

@main
struct RayBanMetaAIApp: App {
    
    init() {
        #if !FREE_BUILD
        WearablesManager.shared.configureSDK()
        #endif
        // Initialize app-level observers (including Anti-Lost) at launch, not only when a view opens.
        _ = AppState.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    Task {
                        await WearablesManager.shared.handleUrl(url)
                    }
                }
        }
    }
}
