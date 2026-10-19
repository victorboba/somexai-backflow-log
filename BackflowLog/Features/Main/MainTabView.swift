import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RouteView()
                .tabItem { Label("Route", systemImage: "list.clipboard.fill") }
            NavigationStack { CustomerListView() }
                .tabItem { Label("Customers", systemImage: "building.2.fill") }
            TestListView()
                .tabItem { Label("Tests", systemImage: "doc.text.fill") }
        }
    }
}
