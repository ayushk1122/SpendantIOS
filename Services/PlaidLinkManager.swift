import Foundation
import LinkKit

final class PlaidLinkManager {
    static func createConfiguration(
        linkToken: String,
        onSuccess: @escaping (String) -> Void
    ) -> LinkTokenConfiguration {
        return LinkTokenConfiguration(token: linkToken) { success in
            let publicToken = success.publicToken
            print("PUBLIC TOKEN:", publicToken)
            onSuccess(publicToken)
        }
    }
}
