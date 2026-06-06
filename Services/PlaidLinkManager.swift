import Foundation
import LinkKit

final class PlaidLinkManager {
    static func createConfiguration(
        linkToken: String,
        onSuccess: @escaping (PlaidLinkSuccess) -> Void
    ) -> LinkTokenConfiguration {
        return LinkTokenConfiguration(token: linkToken) { success in
            let institution = success.metadata.institution
            let result = PlaidLinkSuccess(
                publicToken: success.publicToken,
                institutionID: institution.id,
                institutionName: institution.name
            )
            onSuccess(result)
        }
    }
}
