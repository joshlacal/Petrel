import AuthenticationServices
import Petrel
import SwiftUI

public struct RootContentView: View {
    @State private var model = AtmosphereSessionModel()
    @State private var showingComposer = false
    @State private var showingMetadataSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if model.isSignedIn {
                    TimelineFeedView(model: model, showingComposer: $showingComposer)
                } else {
                    SignInLandingView(model: model, showingMetadataSheet: $showingMetadataSheet)
                }
            }
            .navigationTitle("Petrel OAuth Starter")
            .toolbar {
                if model.isSignedIn {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            showingComposer = true
                        } label: {
                            Label("New Post", systemImage: "square.and.pencil")
                        }

                        Button("Sign Out", role: .destructive) {
                            Task {
                                await model.signOut()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                ComposePostSheet(model: model)
            }
            .sheet(isPresented: $showingMetadataSheet) {
                ClientMetadataPreviewSheet(model: model)
            }
            .task {
                await model.bootstrapSessionIfAvailable()
            }
        }
    }
}

private struct SignInLandingView: View {
    @Bindable var model: AtmosphereSessionModel
    @Binding var showingMetadataSheet: Bool

    @Environment(\.openURL) private var openURL
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        Form {
            Section("1. Choose OAuth Client Mode") {
                Picker("OAuth Mode", selection: Binding(
                    get: { model.preset },
                    set: { newValue in
                        Task {
                            await model.switchPreset(newValue)
                        }
                    }
                )) {
                    ForEach(AtmosphereSessionModel.AuthConfigurationPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                if model.preset == .loopbackDev {
                    Text("Uses OAuthConfig.loopback(port: 8765) — works immediately on macOS and iOS Simulator with zero deployed client-metadata.json.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Uses an https:// client-metadata.json URL + ASWebAuthenticationSession custom URL scheme.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Preview Generated oauth-client-metadata.json") {
                        showingMetadataSheet = true
                    }
                    .font(.footnote)
                }
            }

            Section("2. Account Handle or Hosting Provider") {
                TextField("alice.bsky.social (leave blank for bsky.social)", text: $model.handleInput)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        if model.preset == .loopbackDev {
                            await model.signInWithLoopback { authURL in
                                openURL(authURL)
                            }
                        } else {
                            do {
                                let authURL = try await model.prepareCustomSchemeAuthorizationURL()
                                let callbackURL = try await webAuthenticationSession.authenticate(
                                    using: authURL,
                                    callback: .customScheme("com.example.atmosphere"),
                                    preferredBrowserSession: .shared,
                                    additionalHeaderFields: [:]
                                )
                                await model.completeOAuthCallback(url: callbackURL)
                            } catch {
                                model.errorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    HStack {
                        if model.isBusy {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(model.isBusy ? "Waiting for OAuth Redirect…" : "Sign In with AT Protocol OAuth")
                    }
                }
                .disabled(model.isBusy)
            }

            if let error = model.errorMessage {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct TimelineFeedView: View {
    @Bindable var model: AtmosphereSessionModel
    @Binding var showingComposer: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.activeHandle.map { "@\($0)" } ?? "Signed In")
                        .font(.headline)
                    if let did = model.activeDID {
                        Text(did)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let pds = model.activePDSURL {
                        Text("PDS: \(pds.absoluteString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Home Timeline (\(model.timelinePosts.count))") {
                ForEach(model.timelinePosts, id: \.post.uri) { item in
                    FeedPostRow(item: item)
                }

                if model.timelineCursor != nil {
                    Button("Load More") {
                        Task {
                            await model.loadMoreTimeline()
                        }
                    }
                    .disabled(model.isBusy)
                }
            }
        }
        .refreshable {
            do {
                try await model.refreshTimeline()
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct FeedPostRow: View {
    let item: AppBskyFeedDefs.FeedViewPost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: item.post.author.displayName ?? "@\(item.post.author.handle.description)")
                    .font(.subheadline.weight(.semibold))
                Text(verbatim: "@\(item.post.author.handle.description)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let postRecord = item.post.record.decoded(AppBskyFeedPost.self) {
                RichTextSegmentsView(richText: RichText(post: postRecord))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RichTextSegmentsView: View {
    let richText: RichText

    var body: some View {
        let rendered = richText.segments().reduce(Text("")) { partial, segment in
            if segment.isMention || segment.isLink || segment.isTag {
                return partial + Text(segment.text).foregroundColor(.accentColor)
            } else {
                return partial + Text(segment.text)
            }
        }
        rendered.font(.body)
    }
}

private struct ComposePostSheet: View {
    let model: AtmosphereSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftText = ""
    @State private var isPublishing = false
    @State private var localError: String?

    private var previewRichText: RichText {
        var rt = RichText(text: draftText)
        rt.detectFacetsWithoutResolution()
        return rt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Compose Bluesky Post") {
                    TextEditor(text: $draftText)
                        .frame(minHeight: 120)

                    let rt = previewRichText
                    HStack {
                        Text("\(rt.graphemeLength) / \(RichText.maxPostGraphemes) graphemes")
                            .foregroundStyle(rt.exceedsPostLimits ? .red : .secondary)
                        Spacer()
                        Text("\(rt.utf8Length) UTF-8 bytes")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospacedDigit())
                }

                let detectedFacets = previewRichText.segments().filter {
                    $0.isMention || $0.isLink || $0.isTag
                }
                if !detectedFacets.isEmpty {
                    Section("Detected UTF-8 RichText Facets") {
                        ForEach(Array(detectedFacets.enumerated()), id: \.offset) { _, seg in
                            HStack {
                                Text(seg.isMention ? "Mention" : (seg.isLink ? "Link" : "Tag"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(seg.text)
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                }

                if let localError {
                    Section("Error") {
                        Text(localError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        isPublishing = true
                        localError = nil
                        Task {
                            do {
                                try await model.publishPost(text: draftText)
                                dismiss()
                            } catch {
                                localError = error.localizedDescription
                            }
                            isPublishing = false
                        }
                    }
                    .disabled(
                        isPublishing ||
                            draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            previewRichText.exceedsPostLimits
                    )
                }
            }
        }
        .frame(minWidth: 460, minHeight: 360)
    }
}

private struct ClientMetadataPreviewSheet: View {
    let model: AtmosphereSessionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text((try? model.productionClientMetadataJSON()) ?? "{}")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("oauth-client-metadata.json")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 380)
    }
}
