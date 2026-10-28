import Foundation
import AVFoundation
import SwiftUI




struct AudioFile: Identifiable, Decodable {
    var id: String { url.absoluteString }
    let url: URL
    var isPlaying: Bool = false
    var isFavorite: Bool = false // This will be set locally
    var access: Int
    var like: Int
    var date: Date

    var fileName: String {
        return url.lastPathComponent
    }

    var displayName: String {
        // Remove file extension
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        // Remove unwanted characters and replace with spaces
        let cleanedName = nameWithoutExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return cleanedName
    }

    enum CodingKeys: String, CodingKey {
        case url
        case access
        case like
        case date
    }
}

// MARK: - AudioViewModel
class AudioViewModel: ObservableObject {
    @Published var audioFiles: [AudioFile] = []
    @Published var currentSortingOption: SortingOption = .trending
    @Published var isRefreshing: Bool = false

    @Published var fileToShare: URL? = nil
    @Published var isShareSheetPresented: Bool = false
    @Published var showShareError: Bool = false
    @Published var shareErrorMessage: String = ""

    // New property for search query
    @Published var searchQuery: String = ""

    // Computed property for sorted audio files based on the current sorting option
    var sortedAudioFiles: [AudioFile] {
        var files = audioFiles

        switch currentSortingOption {
        case .trending:
            files.sort {
                if $0.access == $1.access {
                    return $0.date > $1.date
                }
                return $0.access > $1.access
            }
        case .new:
            files.sort { $0.date > $1.date }
        case .mostFavorited:
            files.sort {
                if $0.like == $1.like {
                    return $0.date > $1.date
                }
                return $0.like > $1.like
            }
        case .myFavorites:
            files = files.filter { $0.isFavorite }
            files.sort { $0.date > $1.date }
        }
        return files
    }

    // Computed property for filtered audio files
    var filteredAudioFiles: [AudioFile] {
        let files = sortedAudioFiles
        if searchQuery.isEmpty {
            return files
        } else {
            return files.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    private var audioPlayer: AVPlayer?
    private var currentAudioFileID: String?

    // Updated backend URL with sheet parameter
    private let backendURL = "https://script.google.com/macros/s/AKfycbwvSzhXq3levZLc41LHKyTdTcJczuhnJl2dzhfolnY6uitLfBU6iM4Fphk4Ov4g_kSqNg/exec?sheet=AUDIO" // Replace with your deployment ID

    // Store favorite audio IDs locally
    private var favoriteAudioIDs: Set<String> = []
    private let favoritesKey = "FavoriteAudioIDs"

    // Observer token for AVPlayerItemDidPlayToEndTime
    private var playbackObserver: Any?

    init() {
        loadFavorites()
        fetchAudioData()
    }

    // Load favorites from UserDefaults
    private func loadFavorites() {
        if let savedFavorites = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteAudioIDs = Set(savedFavorites)
        }
    }

    // Save favorites to UserDefaults
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteAudioIDs), forKey: favoritesKey)
    }

    // Fetch Audio Data from Google Sheets
    func fetchAudioData() {
        guard let url = URL(string: backendURL) else {
            print("Invalid backend URL")
            return
        }

        isRefreshing = true

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isRefreshing = false
            }

            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received from backend")
                return
            }

            do {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                var fetchedAudioFiles = try decoder.decode([AudioFile].self, from: data)

                // Set isFavorite based on local favorites
                fetchedAudioFiles = fetchedAudioFiles.map { audioFile in
                    var mutableAudioFile = audioFile
                    mutableAudioFile.isFavorite = self?.favoriteAudioIDs.contains(audioFile.id) ?? false
                    return mutableAudioFile
                }

                DispatchQueue.main.async {
                    self?.audioFiles = fetchedAudioFiles
                }
            } catch {
                print("Error decoding data: \(error)")
            }
        }.resume()
    }

    // Update Counts to Backend
    func updateAudioCount(audioFile: AudioFile, type: String) {
        guard let url = URL(string: backendURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let postData: [String: Any] = ["url": audioFile.url.absoluteString, "type": type]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: postData, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error serializing data: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error updating count: \(error.localizedDescription)")
                return
            }
            print("Successfully updated \(type) count for \(audioFile.displayName)")
        }.resume()
    }

    // Play/Pause
    func togglePlayPause(for audioFile: AudioFile) {
        if let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) {
            if audioFiles[index].isPlaying {
                audioPlayer?.pause()
                audioFiles[index].isPlaying = false
                currentAudioFileID = nil
                print("Paused: \(audioFile.displayName)")

                // Remove playback observer if exists
                if let observer = playbackObserver {
                    NotificationCenter.default.removeObserver(observer)
                    playbackObserver = nil
                }
            } else {
                // Stop any currently playing audio
                if let currentPlayer = audioPlayer {
                    currentPlayer.pause()
                    if let currentIndex = audioFiles.firstIndex(where: { $0.isPlaying }) {
                        audioFiles[currentIndex].isPlaying = false
                        print("Stopped playing: \(audioFiles[currentIndex].displayName)")
                    }
                }

                audioPlayer = AVPlayer(url: audioFile.url)
                audioPlayer?.play()
                audioFiles[index].isPlaying = true
                currentAudioFileID = audioFile.id
                print("Playing: \(audioFile.displayName)")

                // Add observer for when the audio finishes playing
                playbackObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: audioPlayer?.currentItem,
                    queue: .main
                ) { [weak self] _ in
                    guard let self = self else { return }
                    if let finishedIndex = self.audioFiles.firstIndex(where: { $0.id == audioFile.id }) {
                        self.audioFiles[finishedIndex].isPlaying = false
                        self.currentAudioFileID = nil
                        print("Finished playing: \(audioFile.displayName)")
                    }
                    // Remove observer
                    if let observer = self.playbackObserver {
                        NotificationCenter.default.removeObserver(observer)
                        self.playbackObserver = nil
                    }
                }

                // Update access count
                updateAudioCount(audioFile: audioFile, type: "access")

                // Update local count
                audioFiles[index].access += 1
            }
        }
    }

    // Favorite
    func toggleFavorite(for audioFile: AudioFile) {
        if let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) {
            audioFiles[index].isFavorite.toggle()

            // Update local favorites
            if audioFiles[index].isFavorite {
                favoriteAudioIDs.insert(audioFile.id)
            } else {
                favoriteAudioIDs.remove(audioFile.id)
            }
            saveFavorites()

            // Update like count
            let type = audioFiles[index].isFavorite ? "like" : "unlike"
            updateAudioCount(audioFile: audioFile, type: type)

            // Update local count
            if audioFiles[index].isFavorite {
                audioFiles[index].like += 1
            } else {
                audioFiles[index].like = max(audioFiles[index].like - 1, 0)
            }
        }
    }

    // Share Functionality remains unchanged...
    func initiateShare(for audioFile: AudioFile) {
        print("Initiating share for: \(audioFile.displayName)")
        shareAudioFile(audioFile) { [weak self] localURL in
            guard let self = self else { return }

            if let localURL = localURL {
                DispatchQueue.main.async {
                    print("File downloaded successfully: \(localURL)")
                    self.fileToShare = localURL
                    self.isShareSheetPresented = true
                }
            } else {
                DispatchQueue.main.async {
                    print("Failed to download file for sharing.")
                    self.shareErrorMessage = "Failed to prepare audio file for sharing."
                    self.showShareError = true
                }
            }
        }
    }

    private func shareAudioFile(_ audioFile: AudioFile, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.downloadTask(with: audioFile.url) { tempLocalURL, response, error in
            if let error = error {
                print("Error downloading file: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let tempLocalURL = tempLocalURL else {
                print("No file URL")
                completion(nil)
                return
            }

            // Move the downloaded file to a temporary location in the app's directory
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            let destinationURL = tempDirectory.appendingPathComponent(audioFile.fileName)

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempLocalURL, to: destinationURL)
                print("File moved to: \(destinationURL)")
                completion(destinationURL)
            } catch {
                print("Error moving file: \(error.localizedDescription)")
                completion(nil)
            }
        }
        task.resume()
    }
}

// MARK: - Custom SearchBar view
struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false

    var body: some View {
        HStack {
            TextField(NSLocalizedString("Search by title...", comment: "Search bar placeholder"), text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)

                        if isEditing && !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .onTapGesture {
                    self.isEditing = true
                }
                .animation(.default, value: isEditing)

            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Text(NSLocalizedString("Cancel", comment: "Cancel button"))
                }
                .padding(.trailing, 8)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isEditing)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: -  AudioBoardView
struct AudioBoardView: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var selectedSortingOption: SortingOption = .trending

    var body: some View {
        VStack {
            SearchBar(text: $viewModel.searchQuery)

            List {
                ForEach(viewModel.filteredAudioFiles) { audioFile in
                    HStack {
                        // Play/Pause Button
                        Button(action: {
                            viewModel.togglePlayPause(for: audioFile)
                        }) {
                            Image(systemName: audioFile.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.accentColor)
                        }

                        // Display Name
                        Text(audioFile.displayName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Heart Button
                        Button(action: {
                            viewModel.toggleFavorite(for: audioFile)
                        }) {
                            Image(systemName: audioFile.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(audioFile.isFavorite ? .red : .gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        // Share Button
                        Button(action: {
                            viewModel.initiateShare(for: audioFile)
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 5)
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                viewModel.fetchAudioData()
            }
            .onAppear {
                viewModel.currentSortingOption = selectedSortingOption
            }
            .onChange(of: selectedSortingOption) { newValue in
                viewModel.currentSortingOption = newValue
            }
            
            Picker("Sort by", selection: $selectedSortingOption) {
                ForEach(SortingOption.allCases, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.horizontal, .top])
            
            // Present the share sheet when `isShareSheetPresented` is true
            .sheet(isPresented: $viewModel.isShareSheetPresented, onDismiss: {
                if let fileURL = viewModel.fileToShare {
                    // Delete the temporary file after sharing
                    try? FileManager.default.removeItem(at: fileURL)
                    viewModel.fileToShare = nil
                    print("Temporary file deleted: \(fileURL)")
                }
            }) {
                if let fileURL = viewModel.fileToShare {
                    ShareSheet(activityItems: [fileURL])
                        .presentationDetents([.medium])
                }
            }
            // Present an alert if sharing fails
            .alert(isPresented: $viewModel.showShareError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.shareErrorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationBarTitle("Sounds", displayMode: .inline)
    }
}

// Preview
struct AudioBoardView_Previews: PreviewProvider {
    static var previews: some View {
        AudioBoardView(viewModel: AudioViewModel())
    }
}

