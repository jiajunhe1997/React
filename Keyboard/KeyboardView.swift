import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Let the input system choose the US-keyboard-sized canvas for each device and orientation.
final class KeyboardViewController: UIInputViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let worker = DispatchQueue(label: "React.keyboard.images", qos: .userInitiated)
    private static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 12 * 1024 * 1024
        cache.countLimit = 60
        return cache
    }()
    private let decodeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var showsGlobe: Bool?
    private var categories: [Category] = []
    private var selectedID: UUID?
    private var paths: [String] = []
    private var lastSnapshot: Data?
    private var generation = 0
    private let categoryStack = UIStackView()
    private let keyRow = UIStackView()
    private let status = UILabel()
    private var collection: UICollectionView!
    private var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.PictoBoard.app")
    }

    override func loadView() {
        let keyboard = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        keyboard.allowsSelfSizing = false
        view = keyboard
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.setContentHuggingPriority(.defaultLow, for: .vertical)
        collection.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(PhotoKey.self, forCellWithReuseIdentifier: "photo")
        let categoryScroll = UIScrollView()
        categoryScroll.showsHorizontalScrollIndicator = false
        categoryStack.axis = .horizontal
        categoryStack.spacing = 6
        categoryScroll.addSubview(categoryStack)
        categoryStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            categoryStack.leadingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.leadingAnchor, constant: 8),
            categoryStack.trailingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.trailingAnchor, constant: -8),
            categoryStack.topAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.topAnchor),
            categoryStack.bottomAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.bottomAnchor),
            categoryStack.heightAnchor.constraint(equalTo: categoryScroll.frameLayoutGuide.heightAnchor)
        ])
        status.adjustsFontForContentSizeCategory = true
        status.font = .preferredFont(forTextStyle: .caption1)
        status.textAlignment = .center
        status.textColor = .secondaryLabel
        status.numberOfLines = 0
        status.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        status.text = NSLocalizedString("Loading boards…", comment: "Keyboard status")
        keyRow.axis = .horizontal
        keyRow.spacing = 6
        let stack = UIStackView(arrangedSubviews: [categoryScroll, collection, keyRow])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        status.translatesAutoresizingMaskIntoConstraints = false
        collection.addSubview(status)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            categoryScroll.heightAnchor.constraint(equalToConstant: 44),
            keyRow.heightAnchor.constraint(equalToConstant: 44),
            status.centerXAnchor.constraint(equalTo: collection.centerXAnchor),
            status.centerYAnchor.constraint(equalTo: collection.centerYAnchor),
            status.widthAnchor.constraint(lessThanOrEqualTo: collection.widthAnchor, constant: -24)
        ])
        refreshKeys()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshKeys()
        refreshBoards()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshKeys()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Fit two rows without imposing a fixed extension height or decoding large images.
        let layout = collection.collectionViewLayout as! UICollectionViewFlowLayout
        let available = max(1, collection.bounds.height - 12)
        let rows: CGFloat = available >= 80 ? 2 : 1
        let height = max(1, (available - (rows - 1) * 8) / rows)
        let size = CGSize(width: max(64, min(110, height * 1.25)), height: height)
        if layout.itemSize != size { layout.itemSize = size; layout.invalidateLayout() }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        Self.thumbnails.removeAllObjects()
    }

    private func key(_ title: String, symbol: String? = nil, localize: Bool = true, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        let label = localize ? NSLocalizedString(title, comment: "Keyboard control") : title
        config.title = symbol == nil ? label : nil
        config.image = symbol.flatMap { UIImage(systemName: $0) }
        config.baseBackgroundColor = .tertiarySystemBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        button.configuration = config
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func refreshKeys() {
        overrideUserInterfaceStyle = textDocumentProxy.keyboardAppearance == .dark ? .dark : .unspecified
        guard showsGlobe != needsInputModeSwitchKey else { return }
        showsGlobe = needsInputModeSwitchKey
        keyRow.arrangedSubviews.forEach { keyRow.removeArrangedSubview($0); $0.removeFromSuperview() }
        if needsInputModeSwitchKey {
            let globe = key("Next Keyboard", symbol: "globe") {}
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            keyRow.addArrangedSubview(globe)
            globe.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }
        let space = key("space") { [weak self] in self?.textDocumentProxy.insertText(" ") }
        keyRow.addArrangedSubview(space)
        let delete = key("Delete", symbol: "delete.left") { [weak self] in self?.textDocumentProxy.deleteBackward() }
        keyRow.addArrangedSubview(delete)
        delete.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let enter = key("return") { [weak self] in self?.textDocumentProxy.insertText("\n") }
        keyRow.addArrangedSubview(enter)
        enter.widthAnchor.constraint(equalToConstant: 84).isActive = true
    }

    private func refreshBoards() {
        guard let url = container?.appendingPathComponent("categories.json") else {
            status.text = NSLocalizedString("Open React to set up your shared boards.", comment: "Keyboard status")
            return
        }
        worker.async { [weak self] in
            guard let self else { return }
            let data = try? Data(contentsOf: url)
            let boards = data.flatMap { try? JSONDecoder().decode([Category].self, from: $0) }?.filter { !$0.isTrash } ?? []
            DispatchQueue.main.async {
                guard data != self.lastSnapshot || self.categories.isEmpty else { return }
                self.lastSnapshot = data
                self.categories = boards
                if !boards.contains(where: { $0.id == self.selectedID }) { self.selectedID = boards.first?.id }
                self.showSelectedBoard()
            }
        }
    }

    private func showSelectedBoard() {
        generation += 1
        decodeQueue.cancelAllOperations()
        paths = categories.first { $0.id == selectedID }?.imagePaths ?? []
        categoryStack.arrangedSubviews.forEach { categoryStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for board in categories {
            let button = key(board.name, localize: false) { [weak self] in
                self?.selectedID = board.id
                self?.showSelectedBoard()
            }
            if board.id == selectedID {
                button.configuration?.baseBackgroundColor = .systemGray
                button.configuration?.baseForegroundColor = .white
                button.accessibilityTraits.insert(.selected)
            }
            categoryStack.addArrangedSubview(button)
        }
        status.text = NSLocalizedString(categories.isEmpty ? "Add photos to a board in React to get started." : "This board has no photos yet.", comment: "Keyboard empty state")
        status.isHidden = !paths.isEmpty
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { paths.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath) as! PhotoKey
        let path = paths[indexPath.item]
        let token = generation
        cell.representedPath = path
        cell.image.image = nil
        cell.accessibilityLabel = String(format: NSLocalizedString("Copy photo %d", comment: "Keyboard photo"), indexPath.item + 1)
        guard let url = container?.appendingPathComponent("Images").appendingPathComponent(path) else { return cell }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak cell, weak operation] in
            guard operation?.isCancelled == false else { return }
            autoreleasepool {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let cacheKey = "\(path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)" as NSString
                var thumbnail = Self.thumbnails.object(forKey: cacheKey)
                if thumbnail == nil,
                   let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                   let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 240,
                    kCGImageSourceShouldCacheImmediately: true
                   ] as CFDictionary) {
                    thumbnail = UIImage(cgImage: cgImage)
                    Self.thumbnails.setObject(thumbnail!, forKey: cacheKey, cost: cgImage.bytesPerRow * cgImage.height)
                }
                let result = thumbnail
                DispatchQueue.main.async {
                    guard self?.generation == token, cell?.representedPath == path else { return }
                    cell?.image.image = result
                }
            }
        }
        decodeQueue.addOperation(operation)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard hasFullAccess else {
            status.text = NSLocalizedString("Enable Allow Full Access in Keyboard Settings to copy photos.", comment: "Keyboard status")
            status.isHidden = false
            return
        }
        guard paths.indices.contains(indexPath.item),
              let url = container?.appendingPathComponent("Images").appendingPathComponent(paths[indexPath.item]) else { return }
        worker.async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let type = CGImageSourceGetType(source) else { return }
            DispatchQueue.main.async {
                guard self?.hasFullAccess == true else { return }
                UIPasteboard.general.setData(data, forPasteboardType: type as String)
                self?.status.text = NSLocalizedString("Copied · Touch and hold the message field to paste", comment: "Keyboard status")
                self?.status.isHidden = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}

private final class PhotoKey: UICollectionViewCell {
    let image = UIImageView()
    var representedPath: String?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        contentView.backgroundColor = .tertiarySystemBackground
        contentView.layer.cornerRadius = 5
        contentView.clipsToBounds = true
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(image)
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
            image.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            image.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            image.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func prepareForReuse() { super.prepareForReuse(); representedPath = nil; image.image = nil }
}
