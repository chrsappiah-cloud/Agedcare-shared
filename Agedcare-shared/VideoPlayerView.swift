import SwiftUI
import AVKit

struct VideoPlayerView: View {
  let url: URL
  var title: String = "Incident Recording"
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VideoPlayer(player: AVPlayer(url: url))
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline.weight(.semibold))
        Text(url.lastPathComponent)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.white)
      .padding(14)
      .background(.black.opacity(0.55))
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding()

      Button(action: { dismiss() }) {
        Image(systemName: "xmark.circle.fill")
          .font(.title)
          .foregroundColor(.white)
          .shadow(radius: 4)
          .padding()
      }
    }
  }
}
