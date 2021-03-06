import FluentMySQL
import Vapor
import Authentication
import Crypto

// Set token to expire after 48 hours
let timeAlive: TimeInterval = 48 * 60 * 60

struct UserToken: MySQLModel {
    
    /// See `Model`.
    static var deletedAtKey: TimestampKey? { return \.expiresAt }
    
    /// UserToken's unique identifier.
    var id: Int?
    
    /// Unique token string.
    var string: String
    
    /// Reference to user that owns this token.
    var userID: User.ID
    
    /// Expiration date. Token will no longer be valid after this point.
    var expiresAt: Date?
    
    /// Creates a new `UserToken`.
    init(id: Int? = nil, string: String, userID: User.ID) {
        self.id = id
        self.string = string
        self.expiresAt = Date.init(timeInterval: timeAlive, since: .init())
        self.userID = userID
    }
    
    /// Creates a new `UserToken` for a given user.
    static func create(userID: User.ID) throws -> UserToken {
        // Generate a random 128-bit, base64-encoded string.
        let string = try CryptoRandom().generateData(count: 16).base64EncodedString()
        // Init a new `UserToken` from that string.
        return .init(string: string, userID: userID)
    }
}

/// Define coding keys for `UserToken`.
extension UserToken {
    
    enum CodingKeys: String, CodingKey {
        case id
        case string
        case userID = "user_id"
        case expiresAt = "expires_at"
    }
}

extension UserToken {
    /// Fluent relation to the user that owns this token.
    var user: Parent<UserToken, User> {
        return parent(\.userID)
    }
}

/// Allows this model to be used as a TokenAuthenticatable's token.
extension UserToken: Token {
    /// See `Token`.
    typealias UserType = User
    
    /// See `Token`.
    static var tokenKey: WritableKeyPath<UserToken, String> {
        return \.string
    }
    
    /// See `Token`.
    static var userIDKey: WritableKeyPath<UserToken, User.ID> {
        return \.userID
    }
}

/// Allows `UserToken` to be used as a Fluent migration.
extension UserToken: Migration {
    /// See `Migration`.
    static func prepare(on conn: MySQLConnection) -> Future<Void> {
        return MySQLDatabase.create(UserToken.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.string)
            builder.field(for: \.userID)
            builder.field(for: \.expiresAt)
            builder.reference(from: \.userID, to: \User.id)
        }
    }
}

/// Allows `UserToken` to be encoded to and decoded from HTTP messages.
extension UserToken: Content { }

/// Allows `UserToken` to be used as a dynamic parameter in route definitions.
extension UserToken: Parameter { }
