import SwiftUI
import WebKit
import LinkPresentation

// MARK: - Resource Model
struct Resource: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var url: String
    var faviconURL: String?
    var customColor: String? // Stored as hex string

    var color: Color {
        if let customColor, let color = Color(hex: customColor) {
            return color
        }
        return .accentColor
    }
}

// MARK: - Resources Manager
class ResourcesManager: ObservableObject {
    @Published var resources: [Resource] = []
    private let storageKey = "savedResources_v2"

    init() {
        loadResources()
    }

    func addResource(_ resource: Resource) {
        var newResource = resource
        if let faviconURL = generateFaviconURL(for: resource.url) {
            newResource.faviconURL = faviconURL
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            resources.append(newResource)
        }
        saveResources()
    }

    func updateResource(_ resource: Resource) {
        guard let index = resources.firstIndex(where: { $0.id == resource.id }) else { return }
        var updatedResource = resource
        if let faviconURL = generateFaviconURL(for: resource.url) {
            updatedResource.faviconURL = faviconURL
        }
        resources[index] = updatedResource
        saveResources()
    }

    func deleteResource(id: UUID) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            resources.removeAll { $0.id == id }
        }
        saveResources()
    }
    
    private func generateFaviconURL(for urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        return "https://www.google.com/s2/favicons?domain=\(host)&sz=128"
    }

    private func saveResources() {
        if let encoded = try? JSONEncoder().encode(resources) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadResources() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decodedResources = try? JSONDecoder().decode([Resource].self, from: savedData) {
            resources = decodedResources
            return
        }
        
        // Add some default resources for first-time users
        self.resources = [
            Resource(name: "Google Scholar", url: "https://scholar.google.com", customColor: Color.blue.toHex()),
            Resource(name: "Khan Academy", url: "https://www.khanacademy.org", customColor: Color.green.toHex()),
            Resource(name: "Coursera", url: "https://www.coursera.org", customColor: Color.purple.toHex()),
            Resource(name: "GitHub", url: "https://github.com", customColor: Color.gray.toHex())
        ]
        // Set favicons for defaults
        for i in 0..<resources.count {
            resources[i].faviconURL = generateFaviconURL(for: resources[i].url)
        }
        saveResources()
    }
}


// MARK: - Main Resources View
struct ResourcesView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var resourcesManager = ResourcesManager()
    @State private var showingAddResource = false
    @State private var editingResource: Resource?
    @State private var searchText = ""
    @State private var animationOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var filteredResources: [Resource] {
        if searchText.isEmpty {
            return resourcesManager.resources
        } else {
            return resourcesManager.resources.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            SpectacularBackground(themeManager: themeManager)
            
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                ScrollView {
                    contentView
                        .padding(.top, 10)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddResource) {
            AddResourceView(resourcesManager: resourcesManager)
                .environmentObject(themeManager)
        }
        .sheet(item: $editingResource) { resource in
            EditResourceView(resource: resource, resourcesManager: resourcesManager)
                .environmentObject(themeManager)
        }
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if !filteredResources.isEmpty {
            resourcesGrid
        } else if searchText.isEmpty {
            emptyStateView
        } else {
            noSearchResultsView
        }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.forma(.title2, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .background(Circle().fill(.regularMaterial).padding(2))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }

                Spacer()
                
                Text("Resources")
                    .font(.forma(.largeTitle, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Spacer()

                Button {
                    showingAddResource = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.title2, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .background(Circle().fill(.regularMaterial).padding(2))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
            }
            .padding(.top, 10)

            SearchBar(text: $searchText, placeholder: "Search resources...")
                .environmentObject(themeManager)
        }
    }

    private var resourcesGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(filteredResources.enumerated()), id: \.element.id) { index, resource in
                ResourceWidget(
                    resource: resource,
                    onEdit: { editingResource = resource },
                    onDelete: { resourcesManager.deleteResource(id: resource.id) }
                )
                .environmentObject(themeManager)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: filteredResources)
            }
            
            AddResourceWidget { showingAddResource = true }
                .environmentObject(themeManager)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.square.filled.on.square")
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Your Academic Toolkit")
                .font(.forma(.title2, weight: .bold))
            
            Text("Add links to your favorite study sites, research tools, and online resources to keep them handy.")
                .font(.forma(.subheadline))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button { showingAddResource = true } label: {
                Label("Add First Resource", systemImage: "plus")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Capsule().fill(themeManager.currentTheme.primaryColor))
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.4), radius: 10, y: 5)
            }
        }
        .padding(.top, 80)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results for '\(searchText)'")
                .font(.forma(.headline, weight: .semibold))
            
            Text("Check the spelling or try a different keyword.")
                .font(.forma(.subheadline))
                .foregroundColor(.secondary)
        }
        .padding(.top, 80)
    }
}

// MARK: - Resource Widgets
struct ResourceWidget: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let resource: Resource
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: openResource) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(resource.color.opacity(0.2))

                        AsyncImage(url: URL(string: resource.faviconURL ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(Circle())
                            case .failure:
                                Image(systemName: "globe")
                                    .foregroundColor(resource.color)
                            case .empty:
                                ProgressView()
                                    .tint(resource.color)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 44, height: 44)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.name)
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)

                    Text(URL(string: resource.url)?.host ?? "")
                        .font(.forma(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                Spacer()
            }
            .padding(12)
            .frame(height: 120)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(resource.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(SquishableButtonStyle(tint: resource.color))
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func openResource() {
        guard let url = URL(string: resource.url) else { return }
        UIApplication.shared.open(url)
    }
}

struct AddResourceWidget: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.forma(.title, weight: .semibold))
                    Text("Add Resource")
                        .font(.forma(.footnote, weight: .semibold))
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            .frame(height: 120)
        }
        .buttonStyle(SquishableButtonStyle(tint: themeManager.currentTheme.primaryColor))
    }
}

// MARK: - Add/Edit Views
struct AddResourceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var resourcesManager: ResourcesManager
    
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selectedColor: Color = .blue
    @State private var isFetchingMetadata = false
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            // Spectacular animated background
            spectacularBackground
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero header section
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        // Form content
                        formContent
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                        
                        // Preview section
                        if !name.isEmpty {
                            previewSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            
            // Floating action button
            floatingActionButton
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
                .font(.forma(.body))
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    .blur(radius: CGFloat(index * 2))
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .center, spacing: 8) {
                Text("Add New Resource")
                    .font(.forma(.title, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.forma(.caption))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    Text("Academic Resource")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(currentTheme.primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(currentTheme.primaryColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Add links to your favorite study sites, research tools, and online resources to keep them easily accessible.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.3),
                                    currentTheme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: currentTheme.primaryColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Form Content
    private var formContent: some View {
        VStack(spacing: 24) {
            // Resource Details Section
            VStack(spacing: 20) {
                Text("Resource Details")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    StunningFormField(
                        title: "Resource Name",
                        icon: "text.alignleft",
                        placeholder: "e.g., Khan Academy",
                        text: $name,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Please enter a resource name",
                        isFocused: false
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.forma(.subheadline))
                                .foregroundColor(currentTheme.primaryColor)
                            
                            Text("Website URL")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if isFetchingMetadata {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(currentTheme.primaryColor)
                            }
                        }
                        
                        TextField("https://example.com", text: $url)
                            .font(.forma(.body))
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                                currentTheme.primaryColor.opacity(0.2) :
                                                currentTheme.primaryColor.opacity(0.4),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .onChange(of: url) { _ in
                                fetchMetadata(for: url)
                            }
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Customization Section
            VStack(spacing: 20) {
                Text("Customization")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(selectedColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "paintpalette")
                                .font(.forma(.subheadline))
                                .foregroundColor(selectedColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accent Color")
                                .font(.forma(.body, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Choose a color to represent this resource")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .scaleEffect(1.2)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(spacing: 20) {
            Text("Preview")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                ResourceWidget(
                    resource: Resource(name: name, url: url, customColor: selectedColor.toHex()),
                    onEdit: {},
                    onDelete: {}
                )
                .environmentObject(themeManager)
                .buttonStyle(.plain)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: name)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: url)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedColor)
                
                Spacer()
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    Task { await addResource() }
                }) {
                    HStack(spacing: 12) {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isAdding {
                            Text("Add Resource")
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: !isValid ? [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                               [currentTheme.primaryColor, currentTheme.primaryColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isAdding && isValid {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: !isValid ? .clear : currentTheme.primaryColor.opacity(0.4),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .disabled(!isValid)
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isValid)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
    
    private func fetchMetadata(for urlString: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else { return }
        
        isFetchingMetadata = true
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            DispatchQueue.main.async {
                isFetchingMetadata = false
                if let metadata = metadata, name.isEmpty {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        name = metadata.title ?? ""
                    }
                }
            }
        }
    }
    
    private func addResource() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isAdding = true
        }
        
        errorMessage = nil
        
        do {
            var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                urlString = "https://" + urlString
            }
            let resource = Resource(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                url: urlString,
                customColor: selectedColor.toHex()
            )
            
            resourcesManager.addResource(resource)
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAdding = false
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to add resource: \(error.localizedDescription)"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAdding = false
            }
        }
    }
}

struct EditResourceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var resourcesManager: ResourcesManager
    
    let originalResource: Resource
    @State private var editedResource: Resource
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    init(resource: Resource, resourcesManager: ResourcesManager) {
        self.originalResource = resource
        self._editedResource = State(initialValue: resource)
        self.resourcesManager = resourcesManager
    }
    
    private var isValid: Bool {
        !editedResource.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editedResource.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            // Spectacular animated background
            spectacularBackground
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero header section
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        // Form content
                        formContent
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                        
                        // Preview section
                        previewSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            
            // Floating action button
            floatingActionButton
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
                .font(.forma(.body))
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    .blur(radius: CGFloat(index * 2))
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .center, spacing: 8) {
                Text("Edit Resource")
                    .font(.forma(.title, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 6) {
                    Text("Updating")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    
                    Text(originalResource.name)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(currentTheme.primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(currentTheme.primaryColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Update resource details and customize its appearance to keep your academic resources perfectly organized.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.3),
                                    currentTheme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: currentTheme.primaryColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Form Content
    private var formContent: some View {
        VStack(spacing: 24) {
            // Resource Details Section
            VStack(spacing: 20) {
                Text("Resource Details")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    StunningFormField(
                        title: "Resource Name",
                        icon: "text.alignleft",
                        placeholder: "Resource Name",
                        text: $editedResource.name,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !editedResource.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Please enter a resource name",
                        isFocused: false
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.forma(.subheadline))
                                .foregroundColor(currentTheme.primaryColor)
                            
                            Text("Website URL")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        TextField("https://example.com", text: $editedResource.url)
                            .font(.forma(.body))
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                editedResource.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                                currentTheme.primaryColor.opacity(0.2) :
                                                currentTheme.primaryColor.opacity(0.4),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Customization Section
            VStack(spacing: 20) {
                Text("Customization")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(editedResource.color.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(editedResource.color.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "paintpalette")
                                .font(.forma(.subheadline))
                                .foregroundColor(editedResource.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accent Color")
                                .font(.forma(.body, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Choose a color to represent this resource")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ColorPicker("", selection: Binding(
                            get: { editedResource.color },
                            set: { editedResource.customColor = $0.toHex() }
                        ), supportsOpacity: false)
                            .labelsHidden()
                            .scaleEffect(1.2)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(spacing: 20) {
            Text("Preview")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                ResourceWidget(resource: editedResource, onEdit: {}, onDelete: {})
                    .environmentObject(themeManager)
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: editedResource.name)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: editedResource.url)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: editedResource.color)
                
                Spacer()
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    Task { await updateResource() }
                }) {
                    HStack(spacing: 12) {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isUpdating {
                            Text("Save Changes")
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: !isValid ? [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                               [currentTheme.primaryColor, currentTheme.primaryColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isUpdating && isValid {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: !isValid ? .clear : currentTheme.primaryColor.opacity(0.4),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .disabled(!isValid)
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isValid)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
    
    private func updateResource() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isUpdating = true
        }
        
        errorMessage = nil
        
        do {
            var urlString = editedResource.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                urlString = "https://" + urlString
            }
            editedResource.url = urlString
            editedResource.name = editedResource.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            resourcesManager.updateResource(editedResource)
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isUpdating = false
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isUpdating = false
            }
        }
    }
}

// MARK: - Helper Components & Styles
struct SearchBar: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
            TextField(placeholder, text: $text)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .font(.forma(.body))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SquishableButtonStyle: ButtonStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: tint.opacity(configuration.isPressed ? 0.2 : 0.4),
                    radius: configuration.isPressed ? 4 : 8,
                    y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// Preview
struct ResourcesView_Previews: PreviewProvider {
    static var previews: some View {
        ResourcesView()
            .environmentObject(ThemeManager())
    }
}