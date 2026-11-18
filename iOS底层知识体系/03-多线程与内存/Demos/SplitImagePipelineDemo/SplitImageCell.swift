import UIKit

final class SplitImageCell: UITableViewCell {
    var representedURLString: String?
    var imageRequest: SplitImageRequest?

    override func prepareForReuse() {
        super.prepareForReuse()
        imageRequest?.cancel()
        imageRequest = nil
        representedURLString = nil
        imageView?.image = UIImage(systemName: "photo")
    }
}
