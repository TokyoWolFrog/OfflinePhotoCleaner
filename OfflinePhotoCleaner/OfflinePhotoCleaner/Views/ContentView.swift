import SwiftUI
import SwiftData
import Photos

struct ContentView: View {
    @State private var phashProcessor = PhashProcessor()
    var body: some View {
        TabView {
            ScanPhotoView()
                .tabItem {
                    Image(systemName: "camera")
                    Text("画像処理")
                }
                .environment(phashProcessor)

            GroupedPhotoView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("重複項目")
                }
            
            PhotoPickerView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("画像検索")
                }
                .environment(phashProcessor)
        }
    }
}

 #Preview {
     ContentView()
 }
