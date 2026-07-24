import SwiftUI

// MARK: - 诗词展示视图
/// 在计时过程中显示从网络获取的古今中外诗词
struct ThemeAnimationView: View {
    let themeID: String

    @State private var poem: Poem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.secondary)
            } else if let message = errorMessage {
                VStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task { await fetchPoem() }
                    }
                    .font(.caption)
                }
            } else if let poem = poem {
                Text(poem.content)
                    .font(.system(size: 16, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundColor(.primary)

                Text("—— \(poem.author) · 《\(poem.source)》")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await fetchPoem() }
        }
    }

    // MARK: - 网络请求
    private func fetchPoem() async {
        isLoading = true
        errorMessage = nil
        poem = nil

        do {
            guard let url = URL(string: "https://v2.jinrishici.com/one.json") else {
                throw URLError(.badURL)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(JinriResponse.self, from: data)
            poem = Poem(
                content: response.data.content,
                author: response.data.origin.author,
                source: response.data.origin.title
            )
        } catch {
            // 网络异常时使用一首经典诗词作为备选
            poem = Poem(
                content: "床前明月光，疑是地上霜。\n举头望明月，低头思故乡。",
                author: "李白",
                source: "静夜思"
            )
        }

        isLoading = false
    }
}

// MARK: - 数据模型
struct Poem {
    let content: String
    let author: String
    let source: String
}

// 今日诗词 API 的返回结构
struct JinriResponse: Codable {
    struct DataItem: Codable {
        let content: String
        struct Origin: Codable {
            let title: String
            let dynasty: String
            let author: String
            let content: [String]
        }
        let origin: Origin
    }
    let data: DataItem
}
