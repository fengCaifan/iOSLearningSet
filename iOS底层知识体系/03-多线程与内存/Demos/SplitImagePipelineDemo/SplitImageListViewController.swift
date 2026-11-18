import UIKit

final class SplitImageListViewController: UITableViewController {
    private let imagePipeline = SplitImagePipeline()
    private let urls: [URL] = (1...60).compactMap {
        URL(string: "https://picsum.photos/seed/split-\($0)/240/160")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Split Image Pipeline"
        tableView.register(SplitImageCell.self, forCellReuseIdentifier: "SplitImageCell")
        tableView.rowHeight = 100
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { urls.count }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "SplitImageCell", for: indexPath
        ) as? SplitImageCell else { fatalError("Cell registration is missing") }

        let url = urls[indexPath.row]
        let representedURLString = url.absoluteString
        cell.textLabel?.text = "Row \(indexPath.row)"
        cell.imageView?.image = UIImage(systemName: "photo")
        cell.representedURLString = representedURLString

        cell.imageRequest = imagePipeline.loadImage(url: url) { [weak cell] image in
            // completion 由 CacheWriteOperation 切到 main，但仍要阻止旧 URL 覆盖复用后的 Cell。
            guard let cell, cell.representedURLString == representedURLString else { return }
            cell.imageView?.image = image
            cell.setNeedsLayout()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didEndDisplaying cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        (cell as? SplitImageCell)?.imageRequest?.cancel()
    }
}
