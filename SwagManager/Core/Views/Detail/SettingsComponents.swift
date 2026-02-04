import SwiftUI

// MARK: - Clean macOS Settings Components
// Minimal, professional Apple-style detail views

// MARK: - Settings Container

struct SettingsContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Settings Group

struct SettingsGroup<Content: View>: View {
    let header: String?
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(header: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header = header {
                Text(header)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let footer = footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Settings Row (Simple label/value)

struct SettingsRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .secondary
    var mono: Bool = false
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Settings Row with Custom Trailing

struct SettingsRowCustom<Trailing: View>: View {
    let label: String
    var icon: String? = nil
    var iconColor: Color = .secondary
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Settings Button

struct SettingsButton: View {
    let label: String
    var icon: String? = nil
    var iconColor: Color = .secondary
    var value: String? = nil
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(destructive ? .red : iconColor)
                        .frame(width: 20)
                }

                Text(label)
                    .foregroundStyle(destructive ? .red : .primary)

                Spacer()

                if let value = value {
                    Text(value)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Navigation Link

struct SettingsLink<Destination: Hashable>: View {
    let label: String
    var icon: String? = nil
    var iconColor: Color = .secondary
    var value: String? = nil
    let destination: Destination

    var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                        .frame(width: 20)
                }

                Text(label)
                    .foregroundStyle(.primary)

                Spacer()

                if let value = value {
                    Text(value)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple Icon (no gradient background)

struct SettingsIcon: View {
    let icon: String
    var color: Color = .secondary
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size))
            .foregroundStyle(color)
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var leadingInset: CGFloat = 12

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Settings Header

struct SettingsDetailHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .secondary
    var image: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let image = image {
                AsyncImage(url: URL(string: image)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .quaternaryLabelColor))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.title2.weight(.semibold))

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Badge Row

struct SettingsBadgeRow: View {
    let label: String
    let badge: String
    let badgeColor: Color
    var icon: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            Text(badge)
                .font(.caption.weight(.medium))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Toggle Row

struct SettingsToggle: View {
    let label: String
    @Binding var isOn: Bool
    var icon: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }

            Toggle(label, isOn: $isOn)
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Stat Card (Simple)

struct SettingsStatCard: View {
    let label: String
    let value: String
    var icon: String? = nil
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - View Extension for Dividers

extension View {
    @ViewBuilder
    func settingsDivider(if condition: Bool = true, leadingInset: CGFloat = 12) -> some View {
        if condition {
            VStack(spacing: 0) {
                SettingsDivider(leadingInset: leadingInset)
                self
            }
        } else {
            self
        }
    }
}
