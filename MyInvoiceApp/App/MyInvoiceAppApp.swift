import SwiftUI

@main
struct MyInvoiceAppApp: App {
    
    @StateObject private var dbManager = DatabaseManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dbManager)
                .frame(minWidth: 1000, minHeight: 700)
        }
    }
}
