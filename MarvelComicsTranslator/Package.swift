// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarvelComicsTranslator",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MarvelComicsTranslator",
            targets: ["MarvelComicsTranslator"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MarvelComicsTranslator",
            dependencies: [],
            path: ".",
            exclude: ["Info.plist", "Resources"],
            sources: [
                "MarvelComicsTranslatorApp.swift",
                "Models",
                "Services",
                "Views",
                "ViewModels"
            ]
        ),
    ]
)
