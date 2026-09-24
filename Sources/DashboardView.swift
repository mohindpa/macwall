import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Note: `@State` is not used anywhere in this file on purpose — the
// command-line toolchain used for this build is missing the SwiftUIMacros
// plugin, so all local view state lives in DashboardModel (@Published).

func lwDuration(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

// MARK: - Root

struct DashboardView: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }

    var body: some View {
        ZStack {
            PixelSceneView(theme: theme)
            HStack(spacing: 0) {
                DashboardSidebar(model: model)
                Rectangle().fill(theme.stroke).frame(width: 1)
                DashboardMain(model: model)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(theme.bg)
        .preferredColorScheme(.dark)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.dropTargeted) { providers in
            loadDroppedURLs(providers)
            return true
        }
        .overlay {
            if model.dropTargeted {
                Rectangle().stroke(theme.accent, lineWidth: 3).allowsHitTesting(false)
            }
        }
        .sheet(isPresented: Binding(get: { model.showSupport }, set: { model.showSupport = $0 })) {
            SupportPanel(model: model)
        }
    }

    private func loadDroppedURLs(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let direct = item as? URL {
                    url = direct
                }
                if let url = url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            model.onImportURLs(urls)
        }
    }
}

// MARK: - Pixel building blocks

struct ThemeSwatch: View {
    let swatchTheme: PixelTheme
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(swatchTheme.bg)
                Rectangle().fill(swatchTheme.accent).frame(width: 8, height: 8).offset(x: 4, y: 4)
                Rectangle().fill(swatchTheme.card).frame(width: 6, height: 6).offset(x: 16, y: 16)
                Rectangle().fill(swatchTheme.accentSecondary).frame(width: 6, height: 6).offset(x: 4, y: 16)
            }
            .frame(width: 26, height: 26)
            .overlay(
                Rectangle().stroke(selected ? Color.white.opacity(0.9) : Color.white.opacity(0.15),
                                   lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(swatchTheme.name)
    }
}

// MARK: - Sidebar

struct DashboardSidebar: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Rectangle().fill(theme.accent)
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(width: 32, height: 32)
                .background(Rectangle().fill(Color.black.opacity(0.5)).offset(x: 3, y: 3))
                VStack(alignment: .leading, spacing: 3) {
                    Text("MACWALL").font(pixelFont(10)).foregroundColor(theme.text)
                    Text("Video Wallpapers · @mohind").font(.system(size: 10)).foregroundColor(theme.dim)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 30)
            .padding(.bottom, 16)

            NavRow(model: model, section: .myVideos, icon: "square.grid.2x2.fill", count: model.videos.count)
            NavRow(model: model, section: .favorites, icon: "star.fill", count: model.videos.filter { $0.isFavorite }.count)

            Rectangle().fill(theme.stroke).frame(height: 1).padding(.horizontal, 16).padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 9) {
                Text("THEME").font(pixelFont(7)).tracking(2).foregroundColor(theme.dim)
                HStack(spacing: 4) {
                    ForEach(PixelTheme.all, id: \.key) { item in
                        ThemeSwatch(swatchTheme: item, selected: model.themeKey == item.key) {
                            model.onSetTheme(item.key)
                        }
                    }
                }

                Rectangle().fill(theme.stroke).frame(height: 1).padding(.top, 2)

                Text("SETTINGS").font(pixelFont(7)).tracking(2).foregroundColor(theme.dim)

                Toggle(isOn: Binding(get: { model.fill }, set: { model.onToggleFill($0) })) {
                    Text("Fill Screen").font(.system(size: 12)).foregroundColor(theme.text)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(theme.accent)

                Toggle(isOn: Binding(get: { model.startAtLogin }, set: { model.onToggleLogin($0) })) {
                    Text("Start at Login").font(.system(size: 12)).foregroundColor(theme.text)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(theme.accent)

                HStack {
                    Text("Rotate every").font(.system(size: 12)).foregroundColor(theme.text)
                    Spacer()
                    Picker("", selection: Binding(get: { model.rotationMinutes }, set: { model.onSetRotation($0) })) {
                        Text("Off").tag(0)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("60 min").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 92)
                    .controlSize(.small)
                    .tint(theme.accent)
                }

                Rectangle().fill(theme.stroke).frame(height: 1).padding(.top, 2)

                Toggle(isOn: Binding(get: { model.screensaverEnabled }, set: { model.onToggleScreensaver($0) })) {
                    Text("Video Screensaver").font(.system(size: 12)).foregroundColor(theme.text)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(theme.accent)

                HStack {
                    Text("After idle").font(.system(size: 12)).foregroundColor(theme.text)
                    Spacer()
                    Picker("", selection: Binding(get: { model.screensaverMinutes }, set: { model.onSetScreensaverDelay($0) })) {
                        Text("1 min").tag(1)
                        Text("2 min").tag(2)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                    }
                    .labelsHidden()
                    .frame(width: 92)
                    .controlSize(.small)
                    .tint(theme.accent)
                }
                .disabled(!model.screensaverEnabled)
                .opacity(model.screensaverEnabled ? 1 : 0.4)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 10)

            SupportFooter(model: model)
            NowPlayingFooter(model: model)
        }
        .frame(width: 246)
        .background(theme.panel.opacity(0.95))
    }
}

struct NavRow: View {
    @ObservedObject var model: DashboardModel
    let section: SidebarSection
    let icon: String
    let count: Int

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }
    private var selected: Bool { model.section == section }
    private var hover: Bool { model.hoveredNav == section.rawValue }

    var body: some View {
        Button {
            model.section = section
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(section.rawValue.uppercased())
                    .font(pixelFont(9))
                Spacer()
                Text("\(count)")
                    .font(pixelFont(9))
                    .foregroundColor(selected ? Color.black.opacity(0.75) : theme.dim)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Rectangle().fill(selected ? theme.accent : (hover ? Color.white.opacity(0.06) : Color.clear))
            )
            .foregroundColor(selected ? .black : theme.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .onHover { isHovering in
            model.hoveredNav = isHovering ? section.rawValue : (model.hoveredNav == section.rawValue ? nil : model.hoveredNav)
        }
    }
}

struct NowPlayingFooter: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Rectangle().fill(theme.stroke).frame(height: 1)
            Text("NOW PLAYING").font(pixelFont(7)).tracking(2).foregroundColor(theme.dim)
            HStack(spacing: 9) {
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.5))
                    if let path = model.nowPlayingPath, let thumb = model.thumbs[path] {
                        Image(nsImage: thumb).resizable().scaledToFill()
                    } else {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 12)).foregroundColor(theme.dim)
                    }
                }
                .frame(width: 46, height: 28)
                .clipped()
                .overlay(Rectangle().stroke(theme.stroke, lineWidth: 1))
                Text(model.nowPlayingName ?? "Nothing playing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(model.nowPlayingName == nil ? theme.dim : theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: 7) {
                FooterButton(icon: model.isPaused ? "play.fill" : "pause.fill", theme: theme) { model.onTogglePause() }
                FooterButton(icon: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", theme: theme) { model.onToggleMute() }
                Slider(value: Binding(get: { model.volume }, set: { model.onSetVolume($0) }), in: 0...1)
                    .controlSize(.mini)
                    .tint(theme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.black.opacity(0.25))
    }
}

struct FooterButton: View {
    let icon: String
    let theme: PixelTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 22)
                .background(Rectangle().fill(Color.white.opacity(0.08)))
                .overlay(Rectangle().stroke(theme.stroke, lineWidth: 1))
                .foregroundColor(theme.text)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main area

struct DashboardMain: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(model.section.rawValue.uppercased())
                    .font(pixelFont(13)).foregroundColor(theme.text)
                Text("\(model.visibleVideos.count)")
                    .font(pixelFont(9)).foregroundColor(theme.dim)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Rectangle().fill(Color.white.opacity(0.08)))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(theme.dim)
                    TextField("Search", text: $model.search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(theme.text)
                        .frame(width: 140)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Rectangle().fill(Color.white.opacity(0.06)))
                .overlay(Rectangle().stroke(theme.stroke, lineWidth: 1))

                Button {
                    model.onAddVideos()
                } label: {
                    Text("+ ADD VIDEOS...")
                        .font(pixelFont(9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            ZStack {
                                Rectangle().fill(Color.black.opacity(0.5)).offset(x: 3, y: 3)
                                Rectangle().fill(theme.accent)
                            }
                        )
                        .foregroundColor(.black)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .padding(.bottom, 16)

            Rectangle().fill(theme.stroke).frame(height: 1)

            HStack {
                Text("Wallpaper = live desktop video · Screensaver = plays while idle · Lock Screen = still frame on the lock screen")
                    .font(.system(size: 11))
                    .foregroundColor(theme.dim)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)

            if model.visibleVideos.isEmpty {
                EmptyState(model: model)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 18)], spacing: 18) {
                        ForEach(model.visibleVideos) { item in
                            VideoCard(model: model, item: item)
                        }
                    }
                    .padding(22)
                }
            }
        }
    }
}

struct EmptyState: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 40)).foregroundColor(theme.accent)
            Text(model.search.isEmpty ? "ADD YOUR OWN VIDEOS" : "NO MATCHES")
                .font(pixelFont(12)).foregroundColor(theme.text)
            Text("Your videos loop as the desktop wallpaper.\nFiles stay exactly where they are — nothing is copied or moved.")
                .font(.system(size: 12)).foregroundColor(theme.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Button {
                model.onAddVideos()
            } label: {
                Text("ADD VIDEOS...")
                    .font(pixelFont(10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        ZStack {
                            Rectangle().fill(Color.black.opacity(0.5)).offset(x: 3, y: 3)
                            Rectangle().fill(theme.accent)
                        }
                    )
                    .foregroundColor(.black)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("or drag & drop video files anywhere in this window")
                .font(.system(size: 11)).foregroundColor(theme.dim.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card

struct VideoCard: View {
    @ObservedObject var model: DashboardModel
    let item: VideoItem

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }
    private var selected: Bool { model.selection == item.path }
    private var playing: Bool { model.nowPlayingPath == item.path }
    private var hover: Bool { model.hoveredPath == item.path }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            thumbnail
            Text(item.name)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(theme.text)
                .lineLimit(1).truncationMode(.middle)
            HStack(spacing: 6) {
                if let w = item.width, let h = item.height { MetaChip(text: "\(w)×\(h)", theme: theme) }
                if let size = item.fileSize { MetaChip(text: size, theme: theme) }
                if item.url == nil { MetaChip(text: "missing", theme: theme, tint: Color.orange) }
            }
            roleRow
        }
        .padding(10)
        .background(
            ZStack {
                Rectangle().fill(Color.black.opacity(0.45)).offset(x: 4, y: 4)
                Rectangle().fill(hover ? theme.cardHover : theme.card.opacity(0.96))
            }
        )
        .overlay(
            Rectangle().stroke(selected ? theme.accent : theme.stroke, lineWidth: selected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovering in
            model.hoveredPath = isHovering ? item.path : (model.hoveredPath == item.path ? nil : model.hoveredPath)
        }
        .onTapGesture(count: 2) { model.onSetWallpaper(item.path) }
        .onTapGesture { model.selection = item.path }
        .contextMenu { cardMenu }
        .onAppear { model.requestThumb(for: item) }
    }

    private var thumbnail: some View {
        ZStack {
            Rectangle().fill(Color.black.opacity(0.4))
            if let thumb = model.thumbs[item.path] {
                Image(nsImage: thumb).resizable().scaledToFill()
            } else {
                Image(systemName: "film").font(.system(size: 22)).foregroundColor(theme.dim.opacity(0.6))
            }
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(
            Rectangle().stroke(playing ? theme.accent : theme.stroke, lineWidth: playing ? 2 : 1)
        )
        .overlay(alignment: .topLeading) { favoriteButton }
        .overlay(alignment: .topTrailing) { if playing { playingBadge } }
        .overlay(alignment: .bottomTrailing) { if let d = item.duration { MetaChip(text: lwDuration(d), theme: theme, dark: true).padding(7) } }
    }

    private var favoriteButton: some View {
        Button {
            model.onToggleFavorite(item.path)
        } label: {
            Image(systemName: item.isFavorite ? "star.fill" : "star")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(item.isFavorite ? theme.accent : Color.white.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(Rectangle().fill(Color.black.opacity(0.5)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(7)
    }

    private var playingBadge: some View {
        HStack(spacing: 5) {
            Rectangle().fill(theme.accent).frame(width: 6, height: 6)
            Text("PLAYING").font(pixelFont(7))
        }
        .foregroundColor(theme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Rectangle().fill(Color.black.opacity(0.65)))
        .padding(7)
    }

    private var roleRow: some View {
        HStack(spacing: 5) {
            RoleChip(label: "WALLPAPER", tooltip: "Play this video as the live desktop wallpaper", active: model.nowPlayingPath == item.path, color: theme.accent) {
                model.onSetWallpaper(item.path)
            }
            RoleChip(label: "SCREENSAVER", tooltip: "Play this video while the Mac is idle", active: model.screensaverPath == item.path, color: Color(red: 0.42, green: 0.66, blue: 1.0)) {
                model.onSetSaverVideo(model.screensaverPath == item.path ? nil : item.path)
            }
            RoleChip(label: "LOCK SCREEN", tooltip: "Show a still frame of this video on the lock screen", active: model.lockScreenPath == item.path, color: Color(red: 0.74, green: 0.55, blue: 1.0)) {
                model.onSetLockVideo(model.lockScreenPath == item.path ? nil : item.path)
            }
        }
    }

    @ViewBuilder private var cardMenu: some View {
        Button("Set as Wallpaper") { model.onSetWallpaper(item.path) }
        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") { model.onToggleFavorite(item.path) }
        Divider()
        Button(model.screensaverPath == item.path ? "Stop Using for Screensaver" : "Use for Screensaver") {
            model.onSetSaverVideo(model.screensaverPath == item.path ? nil : item.path)
        }
        Button(model.lockScreenPath == item.path ? "Stop Using for Lock Screen" : "Use for Lock Screen (still)") {
            model.onSetLockVideo(model.lockScreenPath == item.path ? nil : item.path)
        }
        Divider()
        Button("Reveal in Finder") { model.onReveal(item.path) }
        Button("Remove from List") { model.onRemove(item.path) }
    }
}

struct RoleChip: View {
    let label: String
    let tooltip: String
    let active: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(pixelFont(7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(active ? .black : Color.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(Rectangle().fill(active ? color : Color.white.opacity(0.07)))
                .overlay(Rectangle().stroke(active ? color : Color.white.opacity(0.15), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct MetaChip: View {
    let text: String
    let theme: PixelTheme
    var tint: Color? = nil
    var dark: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(tint ?? (dark ? Color.white : theme.dim))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Rectangle().fill(dark ? Color.black.opacity(0.7) : Color.white.opacity(0.07))
            )
    }
}

// MARK: - Support (donations · custom requests · wallpaper list)

struct SupportFooter: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }

    var body: some View {
        HStack(spacing: 6) {
            SupportChip(icon: "heart.fill", label: "SUPPORT", theme: theme) {
                model.showSupport = true
            }
            .help("Support MacWall · request a custom wallpaper · browse the free wallpaper list")

            SupportChip(icon: "square.grid.2x2.fill", label: "WALLPAPERS", theme: theme) {
                if let url = Support.wallpaperListURL {
                    Support.open(url)
                } else {
                    model.showSupport = true
                }
            }
            .help("Browse the free MacWall wallpaper list")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

struct SupportChip: View {
    let icon: String
    let label: String
    let theme: PixelTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(pixelFont(7)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Rectangle().fill(Color.white.opacity(0.06)))
            .overlay(Rectangle().stroke(theme.stroke, lineWidth: 1))
            .foregroundColor(theme.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SupportPanel: View {
    @ObservedObject var model: DashboardModel

    private var theme: PixelTheme { PixelTheme.theme(for: model.themeKey) }
    private var listURL: URL? { Support.wallpaperListURL }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SUPPORT MACWALL").font(pixelFont(12)).foregroundColor(theme.text)
                Spacer()
                Button { model.showSupport = false } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Rectangle().fill(Color.white.opacity(0.08)))
                        .foregroundColor(theme.text)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            Text("MacWall is a side project — free, no subscriptions, no accounts. If you like it, a small donation keeps me motivated to keep building the kind of apps that usually cost heavy money — and giving them away for free.")
                .font(.system(size: 13))
                .foregroundColor(theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                PixelActionButton(title: "DONATE VIA PAYPAL", icon: "heart.fill", accent: true, theme: theme) {
                    Support.open(Support.donateURL)
                }
                PixelActionButton(title: "BROWSE WALLPAPERS", icon: "square.grid.2x2.fill", enabled: listURL != nil, theme: theme) {
                    if let url = listURL { Support.open(url) }
                }
            }

            Text(listURL == nil
                 ? "The free wallpaper list link is coming soon — until then, email a request and it gets made for you."
                 : "The wallpaper list is free — download anything you like.")
                .font(.system(size: 11))
                .foregroundColor(theme.dim)

            Rectangle().fill(theme.stroke).frame(height: 1)

            Text("WANT A CUSTOM WALLPAPER?").font(pixelFont(9)).foregroundColor(theme.accent)
            Text("Email \(Support.supportEmail) with what you want — theme, colors, vibe. Every requested wallpaper gets added to the free wallpaper list with the requester's name on it, so your name ships with the wallpaper.")
                .font(.system(size: 12))
                .foregroundColor(theme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            PixelActionButton(title: "EMAIL A REQUEST", icon: "envelope.fill", theme: theme) {
                Support.open(Support.mailtoURL)
            }

            Spacer(minLength: 0)

            Text("Thanks for using MacWall — sharing it with a friend helps just as much.  @mohind")
                .font(.system(size: 11))
                .foregroundColor(theme.dim)
        }
        .padding(24)
        .frame(width: 500)
        .background(theme.bg)
        .preferredColorScheme(.dark)
    }
}

struct PixelActionButton: View {
    let title: String
    var icon: String? = nil
    var accent = false
    var enabled = true
    let theme: PixelTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                }
                Text(title).font(pixelFont(8)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.5)).offset(x: 3, y: 3)
                    Rectangle().fill(accent ? theme.accent : Color.white.opacity(0.10))
                }
            )
            .overlay(Rectangle().stroke(accent ? theme.accent : theme.stroke, lineWidth: 1))
            .foregroundColor(accent ? .black : theme.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
