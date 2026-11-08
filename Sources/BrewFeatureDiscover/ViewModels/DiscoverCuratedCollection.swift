//
//  DiscoverCuratedCollection.swift
//  BrewFeatureDiscover
//
//

import Foundation

/// Curated collections and stacks of packages in Discover.
enum DiscoverCuratedCollection: String, CaseIterable, Identifiable, Sendable {
    case trending = "trending"
    case forYou = "forYou"
    case cliTools = "cliTools"
    case developer = "developer"
    case devops = "devops"
    case security = "security"
    case media = "media"
    case essentialCasks = "essentialCasks"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .trending:
            LocalizedStringResource("Trending", bundle: #bundle, comment: "Curated collection: trending packages")
        case .forYou:
            LocalizedStringResource("For You", bundle: #bundle, comment: "Curated collection: personalised recommendations")
        case .cliTools:
            LocalizedStringResource("CLI Power Tools", bundle: #bundle, comment: "Curated collection: command line power utilities")
        case .developer:
            LocalizedStringResource("Developer & Git", bundle: #bundle, comment: "Curated collection: developer tools and git")
        case .devops:
            LocalizedStringResource("DevOps & Cloud", bundle: #bundle, comment: "Curated collection: devops and cloud infrastructure")
        case .security:
            LocalizedStringResource("Security & Privacy", bundle: #bundle, comment: "Curated collection: security and cryptography")
        case .media:
            LocalizedStringResource("Media & Audio", bundle: #bundle, comment: "Curated collection: audio video and media processing")
        case .essentialCasks:
            LocalizedStringResource("Essential Apps", bundle: #bundle, comment: "Curated collection: macOS GUI applications")
        }
    }

    var iconName: String {
        switch self {
        case .trending: "flame.fill"
        case .forYou: "sparkles"
        case .cliTools: "terminal.fill"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .devops: "cloud.fill"
        case .security: "lock.shield.fill"
        case .media: "waveform"
        case .essentialCasks: "macwindow"
        }
    }

    var curatedPackageNames: [String] {
        switch self {
        case .trending, .forYou:
            []
        case .cliTools:
            ["ripgrep", "bat", "fd", "eza", "fzf", "btop", "zoxide", "jq"]
        case .developer:
            ["git", "gh", "neovim", "tmux", "lazygit", "difftastic", "starship"]
        case .devops:
            ["docker", "kubernetes-cli", "helm", "terraform", "awscli", "k9s"]
        case .security:
            ["gnupg", "age", "sops", "nmap", "trivy", "mkcert"]
        case .media:
            ["ffmpeg", "imagemagick", "yt-dlp", "mpv", "flac"]
        case .essentialCasks:
            ["visual-studio-code", "iterm2", "raycast", "alacritty", "ghostty", "orbstack"]
        }
    }
}
