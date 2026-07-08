import ArgumentParser

@main
struct DemoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "petrel-cab-demo",
    abstract: "End-to-end demo client for petrel-cab-server (implemented in a later task)"
  )

  func run() async throws {
    print("petrel-cab-demo: not yet implemented")
  }
}
