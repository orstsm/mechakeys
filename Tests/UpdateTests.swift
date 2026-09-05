import Foundation

@main
struct UpdateTests {
    static func main() throws {
        precondition(ReleaseVersion("v2.11.0")! > ReleaseVersion("2.9.9")!)
        precondition(ReleaseVersion("2.11.0")! == ReleaseVersion("v2.11.0")!)
        for invalid in ["", "2.11", "2.11.0-beta", "2.-1.0", "2.11.999999999999999999999999999", "2.11.0/path"] {
            precondition(ReleaseVersion(invalid) == nil)
        }
        for link in ["http://github.com/orstsm/mechakeys/releases/tag/v3.0.0", "https://evil.example/release", "https://github.com/other/repo/releases/tag/v3.0.0", "https://github.com@evil.example/orstsm/mechakeys/releases/tag/v3.0.0"] {
            let release = GitHubRelease(tag_name: "v3.0.0", html_url: link, draft: false, prerelease: false)
            precondition(release.safeURL == nil)
        }
        let valid = GitHubRelease(tag_name: "v3.0.0", html_url: "https://github.com/orstsm/mechakeys/releases/tag/v3.0.0", draft: false, prerelease: false)
        precondition(valid.safeURL != nil)
        print("PASS: numeric version comparison, malformed versions, trusted release links")
    }
}
