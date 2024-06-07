import SwiftUI
import PhotosUI
import SwiftData

struct PhotoPickerView: View {
    @Environment(PhashProcessor.self) private var phashProcessor
    @State var photoPicker = PhotoPicker()
    var body: some View {
        VStack {
            PhotosPicker(selection: $photoPicker.imageSelection,
                         matching: .images,
                         photoLibrary: .shared()
            ) {
                Text("検索したい写真を選択")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            Spacer()
            
            PickedImageView(imageState: photoPicker.imageState)
            
            SearchResultsView(imageState: photoPicker.imageState, phashProcessor: phashProcessor)
        }
        .padding()
    }
}

class DummyClass {}

struct SearchPhash : Identifiable{
    var id: ObjectIdentifier
    
    let distance: Int
    let photoList: [PhotoInfo]
}

struct SearchResultsView: View {
    @Environment(\.modelContext) private var modelContext
    
    let imageState: PhotoPicker.ImageState
    let phashProcessor: PhashProcessor
    
    @State private var searchPhashList: [SearchPhash] = []
    
    var body: some View {
        switch imageState {
        case .success(let uiimage):
            Text("検索結果")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(5)
                .onAppear(){
                    getPhashGroup(img: uiimage)
                }
            
            ScrollView {
                ForEach(searchPhashList) { searchPhash in
                    SearchPhotoGroupView(photoGroup: searchPhash.photoList, distance: searchPhash.distance)
                }
            }

        case .loading:
            ProgressView()
        case .empty:
            Image(systemName: "photo.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
    }
    
    private func getPhashGroup(img: UIImage) {
        if let phash = phashProcessor.calculatePHash(image: img) {
            let dictionaryResult = phashProcessor.phashBKtree.bkTree.search(query: phash, maxDistance: 10)
            //print(result)
            
            var sortedUniquePhashDictionary: [(Int, [String])] {
                // Sort the dictionary by keys and extract unique "phash" values
                var result: [(Int, [String])] = []
                
                let sortedKeys = dictionaryResult.keys.sorted()
                for key in sortedKeys {
                    if let list = dictionaryResult[key] {
                        var uniquePhashes: Set<String> = []
                        for item in list {
                            if let phash = item["phash"] as? String {
                                uniquePhashes.insert(phash)
                            }
                        }
                        result.append((key, Array(uniquePhashes)))
                    }
                }
                return result
            }
            
            if searchPhashList.isEmpty == false {
                searchPhashList.removeAll()
            }
            
            for (distance, phashList) in sortedUniquePhashDictionary {
                let phashList = checkPhash(phashList: phashList)
                var allPhotoList: [PhotoInfo] = []
                for phashmap in phashList {
                    allPhotoList = allPhotoList + phashmap.photoInfoList
                }
                if allPhotoList.isEmpty {
                    continue
                }
                let dummyInstance = DummyClass()
                searchPhashList.append(SearchPhash(id: ObjectIdentifier(dummyInstance), distance: distance, photoList: allPhotoList))
            }
        }
    }
    
    private func checkPhash(phashList: [String]) -> [PhashMap] {
        let descriptor = FetchDescriptor<PhashMap>(
            predicate: #Predicate { phashList.contains($0.phash) }
        )
        
        do {
            let existPhash = try modelContext.fetch(descriptor)
            return existPhash
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

struct SearchPhotoGroupView: View {
    @State var photoGroup: [PhotoInfo]
    @State var distance: Int

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("ハッシュのハミング距離： \(String(distance))")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach($photoGroup) { $photo in
                        PhotoView(photo: $photo)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct PickedImageView: View {
    let imageState: PhotoPicker.ImageState
    
    var body: some View {
        switch imageState {
        case .success(let uiimage):
            Image(uiImage: uiimage).resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .padding()
        case .loading:
            ProgressView()
        case .empty:
            Image(systemName: "photo.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
    }
}
