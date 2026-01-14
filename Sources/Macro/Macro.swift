import Foundation

@freestanding(expression)
public macro FileURL(
    _ value: String
) -> URL = #externalMacro(module: "MacroImplements", type: "FileURLMacro")

@attached(member, names: named(init))
public macro Init(
    _ access: InitAccess = .internal
) = #externalMacro(module: "MacroImplements", type: "InitMacro")

@attached(peer, names: prefixed(Mock))
public macro Mockable() = #externalMacro(module: "MacroImplements", type: "MockableMacro")

@attached(member, names: named(stub))
public macro Stub() = #externalMacro(module: "MacroImplements", type: "StubMacro")

@freestanding(expression)
public macro URL(
    _ value: String
) -> URL = #externalMacro(module: "MacroImplements", type: "URLMacro")
