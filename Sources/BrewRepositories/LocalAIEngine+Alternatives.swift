//
//  LocalAIEngine+Alternatives.swift
//  BrewRepositories
//
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

extension LocalAIEngine {
    // MARK: - Modern Alternatives & Complements

    public func suggestAlternatives(for package: BrewPackage) async -> [AIPackageAlternative] {
        let name = package.name.lowercased()
        let lookupKey: String = switch name {
        case "findutils": "find"
        case "gnu-sed": "sed"
        case "coreutils": "ls"
        default: name
        }
        if let direct = Self.alternativesCatalog[lookupKey] ?? Self.alternativesCatalog[name] {
            return direct
        }
        return fallbackAlternatives(for: package)
    }

    private func fallbackAlternatives(for package: BrewPackage) -> [AIPackageAlternative] {
        let name = package.name.lowercased()
        let desc = package.description.lowercased()

        if desc.contains("json"), !name.contains("jq") {
            return [jqAlternative]
        }
        if desc.contains("diff"), !name.contains("delta") {
            return [deltaAlternative]
        }
        if desc.contains("git") || name.contains("git"), name != "lazygit" {
            return [lazygitAlternative]
        }
        if name.contains("python") {
            return [uvAlternative]
        }
        return []
    }

    private var jqAlternative: AIPackageAlternative {
        AIPackageAlternative(
            name: "jq",
            relationship: "Standard JSON Processor",
            headline: "Lightweight and flexible command-line JSON processor",
            keyAdvantages: [
                "Universal standard for shell scripting and JSON slicing",
                "Zero runtime dependencies",
                "Powerful stream filters and transformation language",
            ],
            installCommand: "brew install jq",
        )
    }

    private var deltaAlternative: AIPackageAlternative {
        AIPackageAlternative(
            name: "git-delta",
            relationship: "Syntax Pager Complement",
            headline: "Syntax-highlighting pager for git, diff, and grep output",
            keyAdvantages: [
                "Side-by-side split diff views in terminal",
                "Word-level intra-line change highlighting",
                "Integrates seamlessly with Git config",
            ],
            installCommand: "brew install git-delta",
        )
    }

    private var lazygitAlternative: AIPackageAlternative {
        AIPackageAlternative(
            name: "lazygit",
            relationship: "Visual Terminal UI",
            headline: "Simple terminal UI for git commands that simplifies staging and rebasing",
            keyAdvantages: [
                "Interactive visual hunk and line staging",
                "One-key interactive rebasing, squash, and commit amending",
                "Visual branch and stash navigator",
            ],
            installCommand: "brew install lazygit",
        )
    }

    private var uvAlternative: AIPackageAlternative {
        AIPackageAlternative(
            name: "uv",
            relationship: "Ultra-Fast Package Manager",
            headline: "Extremely fast Python package and project manager written in Rust",
            keyAdvantages: [
                "10x to 100x faster than pip and pip-tools",
                "Replaces pip, virtualenv, poetry, and pyenv in one single binary",
                "Global caching with zero redundant disk downloads",
            ],
            installCommand: "brew install uv",
        )
    }

    private static let alternativesCatalog: [String: [AIPackageAlternative]] = [
        "grep": [
            AIPackageAlternative(
                name: "ripgrep",
                relationship: "Modern Rust Replacement",
                headline: "Blazing fast search that respects .gitignore and skips binary files automatically",
                keyAdvantages: [
                    "Up to 10x faster execution using multi-threaded SIMD acceleration",
                    "Automatically ignores hidden files and .gitignore patterns",
                    "Full Unicode support with coloured matched output",
                ],
                installCommand: "brew install ripgrep",
            ),
            AIPackageAlternative(
                name: "ugrep",
                relationship: "Feature-Rich Alternative",
                headline: "Ultra-fast grep with interactive query UI and archive scanning",
                keyAdvantages: [
                    "Built-in TUI query browser for live regex refinement",
                    "Searches inside zip, tar, and compressed archives directly",
                    "Compatibility with GNU/BSD grep flags",
                ],
                installCommand: "brew install ugrep",
            ),
        ],
        "ripgrep": [
            AIPackageAlternative(
                name: "fd",
                relationship: "Recommended File-Finding Complement",
                headline: "Fast, intuitive replacement for find that pairs seamlessly with ripgrep",
                keyAdvantages: [
                    "Search file names and paths as quickly as ripgrep searches file contents",
                    "Colourised output matching file types",
                    "Simple, human-friendly regex syntax",
                ],
                installCommand: "brew install fd",
            ),
            AIPackageAlternative(
                name: "bat",
                relationship: "Recommended File-Viewing Complement",
                headline: "Cat clone with syntax highlighting to inspect matching files",
                keyAdvantages: [
                    "Syntax highlights code across 200+ languages",
                    "Integrated Git diff indicators in gutter",
                    "Automatic paging for long files",
                ],
                installCommand: "brew install bat",
            ),
            AIPackageAlternative(
                name: "fzf",
                relationship: "Interactive Fuzzy Matching Complement",
                headline: "Interactive command-line fuzzy finder for files, history, and processes",
                keyAdvantages: [
                    "Real-time interactive fuzzy searching",
                    "Terminal keyboard shortcuts (Ctrl+R, Ctrl+T)",
                    "Pipes ripgrep results directly into fuzzy picker",
                ],
                installCommand: "brew install fzf",
            ),
        ],
        "cat": [
            AIPackageAlternative(
                name: "bat",
                relationship: "Modern Rust Replacement",
                headline: "Cat clone with syntax highlighting and Git integration",
                keyAdvantages: [
                    "Syntax highlighting for virtually all programming languages",
                    "Git modifications shown in the gutter",
                    "Automatic paging when content exceeds window height",
                ],
                installCommand: "brew install bat",
            ),
        ],
        "find": [
            AIPackageAlternative(
                name: "fd",
                relationship: "Modern Rust Replacement",
                headline: "Simple, fast and user-friendly alternative to find",
                keyAdvantages: [
                    "Intuitive syntax without remembering complex exec flags",
                    "Parallel directory traversal for superior speed",
                    "Ignores hidden files and respects .gitignore by default",
                ],
                installCommand: "brew install fd",
            ),
        ],
        "ls": [
            AIPackageAlternative(
                name: "eza",
                relationship: "Modern Rust Replacement",
                headline: "Modern replacement for ls with colours, Git status, and tree views",
                keyAdvantages: [
                    "Displays file metadata and Git status in colourised table",
                    "Built-in tree view replaces the need for the tree command",
                    "Displays extended file attributes and security contexts",
                ],
                installCommand: "brew install eza",
            ),
        ],
        "top": [
            AIPackageAlternative(
                name: "btop",
                relationship: "Feature-Rich TUI Monitor",
                headline: "Resource monitor that shows usage and stats for processor, memory, disks, and network",
                keyAdvantages: [
                    "Responsive game-like terminal user interface with mouse support",
                    "Real-time graphs for CPU, RAM, disk I/O, and network",
                    "Process filtering, tree view, and signal termination",
                ],
                installCommand: "brew install btop",
            ),
            AIPackageAlternative(
                name: "htop",
                relationship: "Standard Interactive Monitor",
                headline: "Classic interactive process viewer with configurable metres",
                keyAdvantages: [
                    "Lightweight and reliable across all Unix platforms",
                    "Full colour process list with thread hierarchy",
                    "Low CPU overhead during background monitoring",
                ],
                installCommand: "brew install htop",
            ),
        ],
        "curl": [
            AIPackageAlternative(
                name: "httpie",
                relationship: "Human-Friendly CLI Client",
                headline: "Modern command-line HTTP client with intuitive JSON syntax and colourisation",
                keyAdvantages: [
                    "Natural syntax: http GET api.example.com/items",
                    "Built-in JSON support with syntax highlighting",
                    "Persistent sessions and file upload formatting",
                ],
                installCommand: "brew install httpie",
            ),
            AIPackageAlternative(
                name: "curlie",
                relationship: "Power of Curl + Ergonomics of HTTPie",
                headline: "Front-end to curl that adds the ease of use of HTTPie without sacrificing features",
                keyAdvantages: [
                    "Uses curl under the hood with all flags supported",
                    "Pretty-prints JSON responses and headers like HTTPie",
                    "Zero Python runtime overhead",
                ],
                installCommand: "brew install curlie",
            ),
        ],
        "du": [
            AIPackageAlternative(
                name: "dust",
                relationship: "Intuitive Rust Replacement",
                headline: "More intuitive version of du written in Rust",
                keyAdvantages: [
                    "Visual bar charts showing space distribution across directories",
                    "Instantly spots disk hogs without manual sorting pipes",
                    "Fast multi-threaded traversal",
                ],
                installCommand: "brew install dust",
            ),
            AIPackageAlternative(
                name: "ncdu",
                relationship: "Interactive NCurses Disk Usage",
                headline: "Interactive disk usage analyser with terminal navigation",
                keyAdvantages: [
                    "Browse directory sizes with arrow keys",
                    "Delete files and folders directly from the TUI",
                    "Lightweight and fast scanning",
                ],
                installCommand: "brew install ncdu",
            ),
        ],
        "sed": [
            AIPackageAlternative(
                name: "sd",
                relationship: "Intuitive Find & Replace",
                headline: "Intuitive find & replace CLI tool with standard regex",
                keyAdvantages: [
                    "Simple find and replace syntax: sd <pattern> <replacement>",
                    "Consistent regex engine without BSD vs GNU sed flag confusion",
                    "In-place file editing by default",
                ],
                installCommand: "brew install sd",
            ),
        ],
        "git": [
            AIPackageAlternative(
                name: "lazygit",
                relationship: "Visual Terminal UI",
                headline: "Simple terminal UI for git commands that simplifies staging and rebasing",
                keyAdvantages: [
                    "Interactive visual hunk and line staging",
                    "One-key interactive rebasing, squash, and commit amending",
                    "Visual branch and stash navigator",
                ],
                installCommand: "brew install lazygit",
            ),
            AIPackageAlternative(
                name: "git-delta",
                relationship: "Syntax-Highlighting Pager",
                headline: "Syntax-highlighting pager for git, diff, and grep output",
                keyAdvantages: [
                    "Side-by-side split diff views in terminal",
                    "Word-level intra-line change highlighting",
                    "Integrates seamlessly with Git config",
                ],
                installCommand: "brew install git-delta",
            ),
            AIPackageAlternative(
                name: "gh",
                relationship: "Official GitHub Terminal CLI",
                headline: "GitHub's official command line tool for pull requests and issues",
                keyAdvantages: [
                    "Review, checkout, and merge pull requests from terminal",
                    "Create releases and trigger GitHub Actions workflows",
                    "Manage repo settings, secrets, and issues",
                ],
                installCommand: "brew install gh",
            ),
        ],
        "docker": [
            AIPackageAlternative(
                name: "orbstack",
                relationship: "Lightweight Native Alternative",
                headline: "Fast, light, and simple way to run Docker containers and Linux machines",
                keyAdvantages: [
                    "Instant startup with a fraction of Docker Desktop's memory usage",
                    "Up to 2x faster build and volume read/write performance",
                    "Minimal battery consumption on Apple Silicon",
                ],
                installCommand: "brew install --cask orbstack",
                isFormula: false,
            ),
            AIPackageAlternative(
                name: "colima",
                relationship: "Open Source Container Runtime",
                headline: "Container runtimes on macOS with minimal setup via Lima",
                keyAdvantages: [
                    "Free and open-source command-line container environment",
                    "Supports both Docker and Kubernetes runtimes",
                    "Configurable CPU, RAM, and disk allocations",
                ],
                installCommand: "brew install colima",
            ),
        ],
        "iterm2": [
            AIPackageAlternative(
                name: "ghostty",
                relationship: "Fast Native Terminal",
                headline: "GPU-accelerated terminal emulator designed for macOS",
                keyAdvantages: [
                    "Sub-millisecond input latency powered by Metal",
                    "Native macOS user interface with tabs and split panes",
                    "Rich font rendering with ligatures and Kitty graphics protocol",
                ],
                installCommand: "brew install --cask ghostty",
                isFormula: false,
            ),
            AIPackageAlternative(
                name: "alacritty",
                relationship: "Minimalist High-Speed Terminal",
                headline: "Cross-platform, GPU-accelerated terminal emulator written in Rust",
                keyAdvantages: [
                    "Extreme rendering performance and low memory footprint",
                    "Configured via simple TOML file",
                    "Focused on speed without unnecessary bloat",
                ],
                installCommand: "brew install --cask alacritty",
                isFormula: false,
            ),
        ],
        "vim": [
            AIPackageAlternative(
                name: "neovim",
                relationship: "Modern Extensible Evolution",
                headline: "Vim-fork focused on extensibility, Lua scripting, and modern LSP",
                keyAdvantages: [
                    "Built-in Language Server Protocol (LSP) client",
                    "First-class Lua configuration and plugin ecosystem",
                    "Async job control and modern terminal integration",
                ],
                installCommand: "brew install neovim",
            ),
        ],
        "python": [
            AIPackageAlternative(
                name: "uv",
                relationship: "Ultra-Fast Package Manager",
                headline: "Extremely fast Python package and project manager written in Rust",
                keyAdvantages: [
                    "10x to 100x faster than pip and pip-tools",
                    "Replaces pip, virtualenv, poetry, and pyenv in one single binary",
                    "Global caching with zero redundant disk downloads",
                ],
                installCommand: "brew install uv",
            ),
        ],
    ]
}
