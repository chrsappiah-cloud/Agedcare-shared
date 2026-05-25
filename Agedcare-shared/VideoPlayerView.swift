import SwiftUI
import AVKit

struct VideoPlayerView: View {
  let url: URL
  var title: String = "Incident Recording"
  @Environment(\.dismiss) private var dismiss
  @State private var player: AVPlayer

  init(url: URL, title: String = "Incident Recording") {
    self.url = url
    self.title = title
    _player = State(initialValue: AVPlayer(url: url))
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VideoPlayer(player: player)
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
    .onAppear {
      player.replaceCurrentItem(with: AVPlayerItem(url: url))
      player.play()
    }
    .onDisappear {
      player.pause()
    }
  }
}
