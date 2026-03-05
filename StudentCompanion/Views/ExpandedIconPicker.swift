import SwiftUI

struct ExpandedIconPicker: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedIconName: String
    @Binding var selectedEmoji: String?
    let color: Color

    @State private var searchText = ""
    @State private var selectedTab = 0

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    private let iconCategories: [(name: String, icons: [String])] = [
        ("Academic", [
            "book.closed.fill", "book.fill", "books.vertical.fill", "text.book.closed.fill",
            "magazine.fill", "newspaper.fill", "doc.text.fill", "doc.richtext.fill",
            "note.text", "graduationcap.fill", "studentdesk", "pencil", "pencil.circle.fill",
            "highlighter", "eraser.fill", "paperclip", "pin.fill", "paperplane.fill"
        ]),
        ("Science", [
            "atom", "testtube.2", "flask.fill", "microscope", "laser.burst.fill",
            "dna", "fossil.shell.fill", "pill.fill", "cross.case.fill", "stethoscope",
            "lungs.fill", "brain.head.profile", "eye.fill", "drop.fill"
        ]),
        ("Math & Tech", [
            "function", "x.squareroot", "sum", "divide", "multiply", "percent",
            "equal", "number", "calculator.fill", "laptopcomputer", "desktopcomputer",
            "keyboard.fill", "cpu.fill", "memorychip.fill", "terminal.fill"
        ]),
        ("Arts & Creative", [
            "paintbrush.fill", "paintpalette.fill", "photo.fill", "camera.fill",
            "music.note", "music.mic", "pianokeys.fill", "guitars.fill", "theatermasks.fill",
            "film.fill", "video.fill", "waveform", "speaker.wave.3.fill"
        ]),
        ("Sports & Activities", [
            "figure.run", "sportscourt.fill", "figure.walk", "figure.basketball",
            "soccerball", "football.fill", "tennis.racket", "basketball.fill",
            "dumbbell.fill", "figure.strengthtraining.traditional", "figure.yoga", "trophy.fill"
        ]),
        ("Business & Work", [
            "briefcase.fill", "suitcase.fill", "creditcard.fill", "dollarsign.circle.fill",
            "chart.bar.fill", "chart.line.uptrend.xyaxis", "chart.pie.fill",
            "building.2.fill", "building.columns.fill", "banknote.fill", "signature"
        ]),
        ("World & Culture", [
            "globe.americas.fill", "globe.europe.africa.fill", "globe.asia.australia.fill",
            "map.fill", "location.fill", "mappin.circle.fill", "airplane", "car.fill",
            "bus.fill", "tram.fill", "flag.fill", "building.fill"
        ]),
        ("Nature & Environment", [
            "leaf.fill", "tree.fill", "cloud.fill", "cloud.sun.fill", "snowflake",
            "flame.fill", "drop.fill", "tornado", "hurricane", "bolt.fill",
            "moon.stars.fill", "sun.max.fill", "pawprint.fill", "hare.fill"
        ]),
        ("Tools & Objects", [
            "hammer.fill", "wrench.fill", "screwdriver.fill", "gearshape.fill",
            "cube.fill", "box.fill", "shippingbox.fill", "basket.fill",
            "cart.fill", "bag.fill", "gift.fill", "tag.fill"
        ]),
        ("Communication", [
            "bubble.left.fill", "bubble.right.fill", "envelope.fill", "phone.fill",
            "message.fill", "text.bubble.fill", "megaphone.fill", "speaker.fill",
            "bell.fill", "mic.fill", "video.fill", "antenna.radiowaves.left.and.right"
        ])
    ]

    private let emojiCategories: [(name: String, emojis: [String])] = [
        ("Academic", [
            "📚", "📖", "📝", "✏️", "📒", "📓", "📔", "📕", "📗", "📘", "📙",
            "🎓", "🖊️", "🖍️", "📐", "📏", "🔬", "🧪", "🧬", "🔭", "📊"
        ]),
        ("Science & Tech", [
            "⚗️", "🔬", "🧬", "🧪", "🔭", "💻", "⌨️", "🖥️", "💾", "💿",
            "🔧", "🔨", "⚙️", "🛠️", "🔩", "⚡", "💡", "🔋", "🔌"
        ]),
        ("Arts & Music", [
            "🎨", "🖌️", "🖍️", "✏️", "🎭", "🎪", "🎬", "🎤", "🎧", "🎼",
            "🎹", "🎸", "🎺", "🎷", "🥁", "🎻", "📷", "📸", "🎥"
        ]),
        ("Sports & Activities", [
            "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏉", "🥏", "🎱", "🏓",
            "🏸", "🏒", "🏑", "🥍", "🏏", "🥊", "🥋", "⛳", "🏹", "🎣"
        ]),
        ("Nature", [
            "🌳", "🌲", "🌱", "🌿", "🍀", "🌾", "🌵", "🌴", "🌻", "🌺",
            "🌸", "🌼", "🌷", "🍁", "🍂", "🍃", "⭐", "🌟", "✨", "💫"
        ]),
        ("Food & Drink", [
            "☕", "🍎", "🍕", "🍔", "🌮", "🍿", "🧃", "🥤", "🍵", "🧋",
            "🍰", "🧁", "🍪", "🍩", "🍦", "🍇", "🍊", "🍋", "🍌"
        ]),
        ("Objects", [
            "📱", "⌚", "🎒", "💼", "👔", "👗", "👟", "👓", "🎩", "👑",
            "💎", "💍", "🔑", "🔓", "🔒", "🏆", "🎖️", "🏅", "🎁"
        ]),
        ("Symbols", [
            "❤️", "💙", "💚", "💛", "💜", "🧡", "🖤", "🤍", "💗", "💖",
            "⭐", "✨", "💫", "🌟", "🔥", "💧", "☀️", "🌙", "⚡"
        ])
    ]

    private var filteredIcons: [(name: String, icons: [String])] {
        if searchText.isEmpty {
            return iconCategories
        }
        return iconCategories.compactMap { category in
            let filtered = category.icons.filter { $0.localizedCaseInsensitiveContains(searchText) }
            return filtered.isEmpty ? nil : (category.name, filtered)
        }
    }

    private var filteredEmojis: [(name: String, emojis: [String])] {
        if searchText.isEmpty {
            return emojiCategories
        }
        return emojiCategories.compactMap { category in
            let filtered = category.emojis.filter { $0.contains(searchText) }
            return filtered.isEmpty ? nil : (category.name, filtered)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        color.opacity(colorScheme == .dark ? 0.15 : 0.05),
                        color.opacity(colorScheme == .dark ? 0.08 : 0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Tab selector
                    Picker("Icon Type", selection: $selectedTab) {
                        Text("Symbols").tag(0)
                        Text("Emojis").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Content
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                            if selectedTab == 0 {
                                ForEach(filteredIcons, id: \.name) { category in
                                    iconCategorySection(category: category)
                                }
                            } else {
                                ForEach(filteredEmojis, id: \.name) { category in
                                    emojiCategorySection(category: category)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(currentTheme.primaryColor)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.forma(.body))

            TextField("Search icons...", text: $searchText)
                .font(.forma(.body))
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func iconCategorySection(category: (name: String, icons: [String])) -> some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(category.icons, id: \.self) { iconName in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedIconName = iconName
                            selectedEmoji = nil
                            dismiss()
                        }
                    } label: {
                        Image(systemName: iconName)
                            .font(.forma(.title3))
                            .foregroundColor(selectedIconName == iconName ? .white : color)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedIconName == iconName ? color : color.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                color.opacity(selectedIconName == iconName ? 0.5 : 0.2),
                                                lineWidth: selectedIconName == iconName ? 2 : 1
                                            )
                                    )
                            )
                            .scaleEffect(selectedIconName == iconName ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text(category.name)
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
    }

    private func emojiCategorySection(category: (name: String, emojis: [String])) -> some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(category.emojis, id: \.self) { emoji in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedEmoji = emoji
                            selectedIconName = ""
                            dismiss()
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedEmoji == emoji ? color.opacity(0.15) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                color.opacity(selectedEmoji == emoji ? 0.5 : 0.2),
                                                lineWidth: selectedEmoji == emoji ? 2 : 1
                                            )
                                    )
                            )
                            .scaleEffect(selectedEmoji == emoji ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text(category.name)
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
    }
}
