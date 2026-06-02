import Foundation

struct LinkTokenResponse: Decodable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct PublicTokenRequest: Encodable {
    let publicToken: String
    let clientUserID: String

    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
        case clientUserID = "client_user_id"
    }
}

struct BackendMessageResponse: Decodable {
    let message: String?
    let status: String?
}

struct PlaidRawResponse: Decodable {
    let rawJSON: String
}
