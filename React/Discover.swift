import SwiftUI

struct ImageFile: Identifiable, Decodable, Equatable {
    var id: String { url.absoluteString }
    let url: URL
    var access: Int
    var like: Int
    var date: Date
    var isFavorite: Bool = false

    var originalURL: URL {
        var urlString = url.absoluteString
        if let range = urlString.range(of: "/masonry/") {
            urlString.replaceSubrange(range, with: "/original/")
        }
        return URL(string: urlString) ?? url
    }

    enum CodingKeys: String, CodingKey {
        case url
        case access
        case like
        case date
    }
}

enum SortingOption: CaseIterable {
    case trending
    case new
    case mostFavorited
    case myFavorites
    
    var localizedName: String {
        switch self {
        case .myFavorites:
            return NSLocalizedString("Favorites", comment: "")
            
        case .trending:
            return NSLocalizedString("Trending", comment: "")
        
        case .mostFavorited:
            return NSLocalizedString("Top", comment: "")
            
        case .new:
            return NSLocalizedString("New", comment: "")
        }
    }
}

struct DiscoverView: View {
    @StateObject private var viewModel = ImageViewModel()
    @State private var selectedSortingOption: SortingOption = .trending
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var lastRefreshTime = Date()
    private let refreshInterval: TimeInterval = 300 // 5 minutes

    let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 145, maximum: 280), spacing: 16)
    ]

    var body: some View {
        VStack {
            if viewModel.isInitialLoad {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                ZStack {
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.displayedImages) { imageFile in
                                        RemoteImageView(
                                            thumbnailURL: imageFile.url,
                                            originalURL: imageFile.originalURL,
                                            isFavorite: imageFile.isFavorite,
                                            onCopy: { image in
                                                viewModel.handleImageCopy(imageFile: imageFile, image: image)
                                            },
                                            onFavorite: {
                                                viewModel.handleFavorite(imageFile: imageFile)
                                            }
                                        )
                                        .id(imageFile.id)
                                        .onAppear {
                                            viewModel.loadMoreIfNeeded(currentItem: imageFile)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .onAppear {
                                scrollViewProxy = proxy
                            }
                        }
                    }
                    .refreshable {
                        lastRefreshTime = Date()
                        await viewModel.refresh()
                    }
                    .animation(nil, value: viewModel.displayedImages)
                    
                    if viewModel.displayedImages.isEmpty {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                        }
                    }
                    
                    if viewModel.isLoadingMore {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                        }
                    }
                }
                .onChange(of: selectedSortingOption) { newValue in
                    viewModel.currentSortingOption = newValue
                    scrollViewProxy?.scrollTo(viewModel.displayedImages.first?.id, anchor: .top)
                    lastRefreshTime = Date()
                }

                Picker("Sort by", selection: $selectedSortingOption) {
                    ForEach(SortingOption.allCases, id: \.self) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding([.horizontal, .top])
            }
        }
        .navigationBarTitle("Discover", displayMode: .inline)
        .animation(nil, value: selectedSortingOption)
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView()
    }
}
