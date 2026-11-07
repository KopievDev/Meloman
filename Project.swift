import ProjectDescription

let project = Project(
    name: "Meloman",
    organizationName: "KopievDev",
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
    ],
    schemes: [
        .scheme(
            name: "Meloman",
            shared: true,
            buildAction: .buildAction(targets: ["Meloman"]),
            testAction: .targets(["MelomanDomainTests"]),
            runAction: .runAction(executable: "Meloman")
        ),
    ]
)
