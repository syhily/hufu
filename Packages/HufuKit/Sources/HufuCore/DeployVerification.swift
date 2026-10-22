public import Foundation

/// What counts as a successful deploy. librime reports overall success even when one
/// schema failed to compile, so both the input method and the CLI check the built
/// output themselves.
public enum DeployVerification {
    /// Schema IDs in `default.yaml` whose `<id>.schema.yaml` is missing from staging.
    public static func missingSchemas(stagingDir: URL) -> [String] {
        guard let config = try? ConfigValue.load(contentsOf: stagingDir.appendingPathComponent("default.yaml")),
              let schemas = config.value(at: "schema_list")?.listValue else { return [] }
        return schemas.compactMap { $0["schema"]?.stringValue }.filter { schema in
            !FileManager.default.fileExists(atPath: stagingDir.appendingPathComponent("\(schema).schema.yaml").path)
        }
    }
}
