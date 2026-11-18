import UIKit

final class ImageCell: UITableViewCell {
    /// 本次 Cell 配置对应的 URL。它是抵御异步旧回调错图的最后一道保护。
    var representedURLString: String?
    var imageRequest: ImageRequest?

    override func prepareForReuse() {
        super.prepareForReuse()
        imageRequest?.cancel()
        imageRequest = nil
        representedURLString = nil
        imageView?.image = UIImage(systemName: "photo")
    }
}
