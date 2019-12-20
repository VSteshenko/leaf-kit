import Vapor

extension Application {
    public var leaf: Leaf {
        .init(application: self)
    }

    public struct Leaf {
        final class Storage {
            var configuration: LeafConfiguration
            var cache: LeafCache

            init(application: Application) {
                self.configuration = .init(rootDirectory: application.directory.viewsDirectory)
                self.cache = DefaultLeafCache()
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        public var renderer: LeafRenderer {
            .init(
                configuration: self.configuration,
                cache: self.cache,
                fileio: self.application.fileio,
                eventLoop: self.application.eventLoopGroup.next(),
                application: self.application
            )
        }
        
        public func renderer(configuration: LeafConfiguration) -> LeafRenderer {
            self.configuration = configuration
            return .init(
                configuration: self.configuration,
                cache: self.cache,
                fileio: self.application.fileio,
                eventLoop: self.application.eventLoopGroup.next(),
                application: self.application
            )
        }

        public var configuration: LeafConfiguration {
            get {
                self.storage.configuration
            }
            nonmutating set {
                self.storage.configuration = newValue
            }
        }
        
        public var cache: LeafCache {
            self.storage.cache
        }

        var storage: Storage {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let new = Storage(application: self.application)
                self.application.storage[Key.self] = new
                return new
            }
        }

        public let application: Application
    }
}

extension Request {
    var leaf: LeafRenderer {
        .init(
            configuration: self.application.leaf.configuration,
            cache: self.application.leaf.cache,
            fileio: self.application.fileio,
            eventLoop: self.eventLoop,
            application: self.application
        )
    }
}

extension LeafRenderer: ViewRenderer {
    public func `for`(_ request: Request) -> ViewRenderer {
        LeafRenderer(
            configuration: self.configuration,
            cache: self.cache,
            fileio: self.fileio,
            eventLoop: request.eventLoop,
            application: self.application
        )
    }
    
    public func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View>
        where E: Encodable
    {
        let data: [String: LeafData]
        do {
            data = try LeafEncoder().encode(context)
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
        return self.render(path: name, context: data).map { buffer in
            return View(data: buffer)
        }
    }
}

extension Application.Views.Provider {
    public static var leaf: Self {
        .init {
            $0.views.use {
                $0.leaf.renderer
            }
        }
    }
    public static func leaf(configuration: LeafConfiguration) -> Self {
        .init {
            $0.views.use {
                $0.leaf.renderer(configuration: configuration)
            }
        }
    }
}
