import UIKit

final class ImageListViewController: UITableViewController {
    private let imageLoader = ImageLoader() // 整个列表只有一个 Loader / 一个 OperationQueue。
    private let urls: [URL] = (1...60).compactMap {
        URL(string: "https://picsum.photos/seed/\($0)/240/160")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Image Loader Demo"
        tableView.register(ImageCell.self, forCellReuseIdentifier: "ImageCell")
        tableView.rowHeight = 100
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        urls.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "ImageCell", for: indexPath
        ) as? ImageCell else {
            fatalError("ImageCell registration is missing")
        }

        let url = urls[indexPath.row]
        let urlString = url.absoluteString
        cell.textLabel?.text = "Row \(indexPath.row)"
        cell.imageView?.image = UIImage(systemName: "photo")
        cell.representedURLString = urlString

        cell.imageRequest = imageLoader.loadImage(url: url) { [weak cell] image in
            // ImageLoader 保证 completion 在主线程，但 Cell 有可能已被复用。
            guard let cell, cell.representedURLString == urlString else { return }
            cell.imageView?.image = image
            cell.setNeedsLayout()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didEndDisplaying cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        // 比 prepareForReuse 更早停止无效工作；prepareForReuse 仍保留作兜底。
        (cell as? ImageCell)?.imageRequest?.cancel()
    }
}
