import SwiftUI
import SwiftData
import Photos

struct GroupedPhotoView: View {
    static var fetchDescriptor: FetchDescriptor<PhashMap> {
        var descriptor = FetchDescriptor<PhashMap>(
            predicate: #Predicate { $0.photoInfoList.count > 1 },
            sortBy: [
                .init(\.persistentModelID)
            ]
        )
        descriptor.fetchLimit = 50
        return descriptor
    }
    
    @Query(fetchDescriptor) private var phashMapList: [PhashMap]
    //@Query private var phashMapList: [PhashMap]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                //Text("右上の「選択」ボタンを押すと、削除したい画像を自分で選択できます。 一括で処理したい場合は、グループごとに「結合」や「削除」ボタンを押してください。")
                Text("一括処理で「結合」を押すと、一枚だけが残る。「削除」を押すと、グループごとに削除される")
                                .font(.subheadline)
                                .padding(.horizontal)
                ScrollView {
                    ForEach(phashMapList) { phashMap in
                        PhotoGroupView(
                            photoGroup: phashMap,
                            onMergeOrDelete: { phashMap, deleteFlag in
                                handleMergeOrDelete(phashMap: phashMap, deleteFlag: deleteFlag)
                            }
                        )
                    }
                }
            }
            .navigationBarTitle("重複項目", displayMode: .inline)
            /*
                        .navigationBarItems(trailing: Button(action: {
                            // Action for Select Dates button
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("選択")
                            }
                        })
             */
        }
    }
    
    private func handleMergeOrDelete(phashMap: PhashMap, deleteFlag: Bool) {
        mergeOrDelete(phashMap: phashMap, deleteFlag: deleteFlag)
        // Add your merge or delete logic here
    }
    
    private func mergeOrDelete(phashMap: PhashMap, deleteFlag: Bool) {
        let idList = getlocalIdentifiers(photoGroup: phashMap)
        let assetsToDelete = getDeleteAssets(localIdentifiers: idList, all: deleteFlag)
        
        var deleteIdList: [String] = []
        for asset in assetsToDelete {
            deleteIdList.append(asset.localIdentifier)
        }
        
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }
            deletePhotoInfo(idList: deleteIdList)
        } catch {
            print("Error deleting photos: \(error.localizedDescription)")
        }
    }
    
    private func getlocalIdentifiers(photoGroup: PhashMap) -> [String] {
        var idList: [String] = []
        for photoInfo in photoGroup.photoInfoList {
            idList.append(photoInfo.localID)
        }
        return idList
    }
    
    private func getDeleteAssets(localIdentifiers: [String], all: Bool) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: fetchOptions)
        var assetsToDelete: [PHAsset] = []
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        
        var highestQualityAsset: PHAsset?
        var highestQualityData: Data?
        
        assets.enumerateObjects { (asset, _, _) in
            if all {
                assetsToDelete.append(asset)
            } else {
                imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { (data, _, _, _) in
                    if let data = data {
                        if highestQualityData == nil || data.count > highestQualityData!.count {
                            if let highestQualityAsset = highestQualityAsset {
                                assetsToDelete.append(highestQualityAsset)
                            }
                            highestQualityAsset = asset
                            highestQualityData = data
                        } else {
                            assetsToDelete.append(asset)
                        }
                    }
                }
            }
        }
        return assetsToDelete
    }
    
    private func deletePhotoInfo(idList: [String]) {
        let descriptor = FetchDescriptor<PhotoInfo>(
            predicate: #Predicate { idList.contains($0.localID) }
        )
        do {
            let deleteList = try modelContext.fetch(descriptor)
            for photoInfo in deleteList {
                modelContext.delete(photoInfo)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct PhotoGroupView: View {
    @State var photoGroup: PhashMap
    var onMergeOrDelete: (PhashMap, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach($photoGroup.photoInfoList) { $photo in
                        PhotoView(photo: $photo)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack {
                Text("ハッシュ値：　" + photoGroup.phash)
                    .font(.headline)
                Spacer()
                Button("結合") {
                    onMergeOrDelete(photoGroup, false)
                }
                .font(.subheadline)
                Button("削除") {
                    onMergeOrDelete(photoGroup, true)
                }
                .font(.subheadline)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct PhotoView: View {
    @Binding var photo: PhotoInfo

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: getThumbnail(id: photo.localID))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
            /*
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(photo.isSelected ? Color.red : Color.clear, lineWidth: 2)
                )
             */
                .cornerRadius(10)
        }
        /*
        .onTapGesture {
            photo.isSelected.toggle()
        }
         */
    }
}

struct PhotoCardView: View {
    let photoInfo: PhotoInfo

    var body: some View {
        VStack(alignment: .leading) {
            PhotoThumbnailView(localID: photoInfo.localID)
            Text(photoInfo.timestamp.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding([.leading, .trailing, .bottom], 8)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct PhotoThumbnailView: View {
    let localID: String

    var body: some View {
        Image(uiImage: getThumbnail(id: localID))
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
    }
}

func getThumbnail(id: String) -> UIImage {
    let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    guard let firstAset = asset.firstObject else {
        return UIImage() // Return a default or placeholder image if no asset is found
    }
    
    let manager = PHCachingImageManager()
    let options = PHImageRequestOptions()
    options.version = .original
    var thumbnail = UIImage()
    options.isSynchronous = true
    manager.requestImage(for: firstAset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: options) { image, _ in
        if let img = image {
            thumbnail = img
        }
    }
    return thumbnail
}
