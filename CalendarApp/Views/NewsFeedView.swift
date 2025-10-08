import SwiftUI
import AppKit

struct NewsFeedView: View {
    @StateObject private var newsManager = NewsManager()
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "newspaper")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Text("TODAY'S HEADLINES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if newsManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            if newsManager.headlines.isEmpty && !newsManager.isLoading {
                Text("No headlines available")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(newsManager.headlines) { article in
                        Button(action: {
                            NSWorkspace.shared.open(article.url)
                        }) {
                            HStack(spacing: 6) {
                                Text("•")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)

                                Text("\(article.title) [\(article.source)]")
                                    .font(.system(size: 11 * calendarManager.fontSize.scale))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()

                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }

            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .onAppear {
            newsManager.fetchHeadlines()
        }
    }
}
