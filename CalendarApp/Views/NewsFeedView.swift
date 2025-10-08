import SwiftUI
import AppKit

struct NewsFeedView: View {
    @StateObject private var newsManager = NewsManager()
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "newspaper")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text("TODAY'S HEADLINES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if newsManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if newsManager.headlines.isEmpty && !newsManager.isLoading {
                Text("No headlines available")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(newsManager.headlines) { article in
                        Button(action: {
                            NSWorkspace.shared.open(article.url)
                        }) {
                            HStack(spacing: 8) {
                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(article.title)
                                        .font(.system(size: 12 * calendarManager.fontSize.scale))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text(article.source)
                                        .font(.system(size: 10 * calendarManager.fontSize.scale))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
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
                .padding(.bottom, 8)
            }

            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .onAppear {
            newsManager.fetchHeadlines()
        }
    }
}
