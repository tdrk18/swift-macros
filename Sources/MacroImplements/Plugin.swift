import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FileURLMacro.self,
        InitMacro.self,
        MockableMacro.self,
        StubMacro.self,
        URLMacro.self,
    ]
}
