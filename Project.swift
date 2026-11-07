import ProjectDescription

let project = Project(
    name: "Meloman",
    organizationName: "KopievDev",
    packages: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", .exact("1.1.1")),
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
        ]
    ),
    targets: [
        .target(
            name: "MelomanDomain",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.kopiev.meloman.domain",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Modules/Core/MelomanDomain/Sources/**"],
            dependencies: []
        ),
        .target(
            name: "MediaPipeline",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.kopiev.meloman.media",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Modules/Core/MediaPipeline/Sources/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
            ]
        ),
        .target(
            name: "ProjectStore",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.kopiev.meloman.store",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Modules/Core/ProjectStore/Sources/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
            ]
        ),
        .target(
            name: "KaraokeEngine",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.kopiev.meloman.karaoke",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Modules/Core/KaraokeEngine/Sources/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
            ]
        ),
        .target(
            name: "LocalAI",
            destinations: .macOS,
            product: .framework,
            bundleId: "dev.kopiev.meloman.localai",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Modules/Core/LocalAI/Sources/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
                .package(product: "WhisperKit"),
            ]
        ),
        .target(
            name: "Meloman",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.kopiev.meloman",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "Meloman",
                    "LSApplicationCategoryType": "public.app-category.video",
                    "NSPrincipalClass": "NSApplication",
                    "NSHighResolutionCapable": true,
                ]
            ),
            sources: ["App/MelomanApp/Sources/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
                .target(name: "MediaPipeline"),
                .target(name: "ProjectStore"),
                .target(name: "KaraokeEngine"),
                .target(name: "LocalAI"),
            ]
        ),
        .target(
            name: "MelomanDomainTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.kopiev.meloman.domain.tests",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Tests/DomainTests/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
            ]
        ),
        .target(
            name: "ProjectStoreTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.kopiev.meloman.store.tests",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Tests/ProjectStoreTests/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
                .target(name: "ProjectStore"),
            ]
        ),
        .target(
            name: "KaraokeEngineTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.kopiev.meloman.karaoke.tests",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Tests/KaraokeEngineTests/**"],
            dependencies: [
                .target(name: "MelomanDomain"),
                .target(name: "KaraokeEngine"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "Meloman",
            shared: true,
            buildAction: .buildAction(targets: ["Meloman"]),
            testAction: .targets(["MelomanDomainTests", "ProjectStoreTests", "KaraokeEngineTests"]),
            runAction: .runAction(executable: "Meloman")
        ),
    ]
)
