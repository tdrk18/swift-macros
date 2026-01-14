import Macro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import MacroImplements

private let macros = [
    "Stub": StubMacro.self
]

final class StubMacroTests: XCTestCase {
    func testStubMacro() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let id: Int
                let name: String
                let tags: [String]
                let values: [String: Any]
                let note: String?
                let birthday: Date
                let uuid: UUID
                let homepage: URL
            }
            """,
            expandedSource:
                """
                struct User {
                    let id: Int
                    let name: String
                    let tags: [String]
                    let values: [String: Any]
                    let note: String?
                    let birthday: Date
                    let uuid: UUID
                    let homepage: URL

                    static func stub(
                        id: Int = 0,
                        name: String = "",
                        tags: [String] = [],
                        values: [String: Any] = [:],
                        note: String? = nil,
                        birthday: Date = Date(timeIntervalSince1970: 0),
                        uuid: UUID = UUID(),
                        homepage: URL = URL(string: "https://example.com")!
                    ) -> Self {
                        Self(
                            id: id, name: name, tags: tags, values: values, note: note, birthday: birthday, uuid: uuid, homepage: homepage
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithGenericContainers() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let tags: Set<String>
                let aliases: Array<String>
                let map: Dictionary<String, Any>
                let nickname: Optional<String>
                let urls: Swift.Array<Foundation.URL>
            }
            """,
            expandedSource:
                """
                struct User {
                    let tags: Set<String>
                    let aliases: Array<String>
                    let map: Dictionary<String, Any>
                    let nickname: Optional<String>
                    let urls: Swift.Array<Foundation.URL>

                    static func stub(
                        tags: Set<String> = Set(),
                        aliases: Array<String> = [],
                        map: Dictionary<String, Any> = [:],
                        nickname: Optional<String> = nil,
                        urls: Swift.Array<Foundation.URL> = []
                    ) -> Self {
                        Self(
                            tags: tags, aliases: aliases, map: map, nickname: nickname, urls: urls
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithCustomDictionaryKey() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                struct Key: Hashable {}

                let map: Dictionary<Key, String>
            }
            """,
            expandedSource:
                """
                struct User {
                    struct Key: Hashable {}

                    let map: Dictionary<Key, String>

                    static func stub(
                        map: Dictionary<Key, String> = [:]
                    ) -> Self {
                        Self(
                            map: map
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithMemberTypeOptional() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let name: Swift.Optional<String>
            }
            """,
            expandedSource:
                """
                struct User {
                    let name: Swift.Optional<String>

                    static func stub(
                        name: Swift.Optional<String> = nil
                    ) -> Self {
                        Self(
                            name: name
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithFoundationOptionalURL() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let homepage: Foundation.Optional<Foundation.URL>
            }
            """,
            expandedSource:
                """
                struct User {
                    let homepage: Foundation.Optional<Foundation.URL>

                    static func stub(
                        homepage: Foundation.Optional<Foundation.URL> = nil
                    ) -> Self {
                        Self(
                            homepage: homepage
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithMemberTypeSet() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let ids: Swift.Set<Int>
            }
            """,
            expandedSource:
                """
                struct User {
                    let ids: Swift.Set<Int>

                    static func stub(
                        ids: Swift.Set<Int> = Set()
                    ) -> Self {
                        Self(
                            ids: ids
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithMemberTypeDictionary() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let map: Swift.Dictionary<String, Int>
            }
            """,
            expandedSource:
                """
                struct User {
                    let map: Swift.Dictionary<String, Int>

                    static func stub(
                        map: Swift.Dictionary<String, Int> = [:]
                    ) -> Self {
                        Self(
                            map: map
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithMemberTypeSetOfMemberType() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let links: Swift.Set<Foundation.URL>
            }
            """,
            expandedSource:
                """
                struct User {
                    let links: Swift.Set<Foundation.URL>

                    static func stub(
                        links: Swift.Set<Foundation.URL> = Set()
                    ) -> Self {
                        Self(
                            links: links
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithNestedGenericTypes() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let names: Swift.Array<Swift.Optional<String>>
                let groups: Swift.Dictionary<String, Swift.Array<Int>>
            }
            """,
            expandedSource:
                """
                struct User {
                    let names: Swift.Array<Swift.Optional<String>>
                    let groups: Swift.Dictionary<String, Swift.Array<Int>>

                    static func stub(
                        names: Swift.Array<Swift.Optional<String>> = [],
                        groups: Swift.Dictionary<String, Swift.Array<Int>> = [:]
                    ) -> Self {
                        Self(
                            names: names, groups: groups
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithNestedSet() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let ids: Set<Set<Int>>
            }
            """,
            expandedSource:
                """
                struct User {
                    let ids: Set<Set<Int>>

                    static func stub(
                        ids: Set<Set<Int>> = Set()
                    ) -> Self {
                        Self(
                            ids: ids
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithMixedContainerTypes() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let map: Dictionary<String, Set<Int>>
            }
            """,
            expandedSource:
                """
                struct User {
                    let map: Dictionary<String, Set<Int>>

                    static func stub(
                        map: Dictionary<String, Set<Int>> = [:]
                    ) -> Self {
                        Self(
                            map: map
                        )
                    }
                }
                """,
            macros: macros,
        )
    }

    func testStubMacroWithOptionalSet() {
        assertMacroExpansion(
            """
            @Stub
            struct User {
                let links: Optional<Set<URL>>
            }
            """,
            expandedSource:
                """
                struct User {
                    let links: Optional<Set<URL>>

                    static func stub(
                        links: Optional<Set<URL>> = nil
                    ) -> Self {
                        Self(
                            links: links
                        )
                    }
                }
                """,
            macros: macros,
        )
    }
}
