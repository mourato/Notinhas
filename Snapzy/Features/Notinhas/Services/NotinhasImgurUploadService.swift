import AppKit
import Foundation

enum NotinhasImgurUploadError: LocalizedError, Equatable {
  case missingClientID
  case invalidImageData
  case invalidResponse
  case apiError(String)

  var errorDescription: String? {
    switch self {
    case .missingClientID:
      NotinhasL10n.imgurMissingClientID
    case .invalidImageData:
      NotinhasL10n.imgurInvalidImageData
    case .invalidResponse:
      NotinhasL10n.imgurInvalidResponse
    case let .apiError(message):
      message
    }
  }
}

struct NotinhasImgurUploadResult: Equatable {
  let link: String
  let deleteHash: String?
}

actor NotinhasImgurUploadService {
  static let shared = NotinhasImgurUploadService()

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func upload(image: NSImage, clientID: String) async throws -> NotinhasImgurUploadResult {
    let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedClientID.isEmpty else {
      throw NotinhasImgurUploadError.missingClientID
    }

    guard let pngData = image.pngData() else {
      throw NotinhasImgurUploadError.invalidImageData
    }

    var request = URLRequest(url: URL(string: "https://api.imgur.com/3/image")!)
    request.httpMethod = "POST"
    request.setValue("Client-ID \(trimmedClientID)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "image": pngData.base64EncodedString(),
      "type": "base64",
    ])

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw NotinhasImgurUploadError.invalidResponse
    }

    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    if !(200 ... 299).contains(http.statusCode) {
      let message = (json?["data"] as? [String: Any])?["error"] as? String
        ?? String(data: data, encoding: .utf8)
        ?? NotinhasL10n.imgurInvalidResponse
      throw NotinhasImgurUploadError.apiError(message)
    }

    guard
      let dataObject = json?["data"] as? [String: Any],
      let link = dataObject["link"] as? String
    else {
      throw NotinhasImgurUploadError.invalidResponse
    }

    return NotinhasImgurUploadResult(
      link: link,
      deleteHash: dataObject["deletehash"] as? String
    )
  }
}

private extension NSImage {
  func pngData() -> Data? {
    guard let tiff = tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
      return nil
    }
    return bitmap.representation(using: .png, properties: [:])
  }
}
