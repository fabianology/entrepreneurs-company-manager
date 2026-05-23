import Foundation

enum AnyJSON {
    case string(String)
    case object([String: AnyJSON])
}

struct User {
    var userMetadata: [String: AnyJSON]
}

func test(user: User?) {
    if let user = user,
       case let .string(avatarUrlString) = user.userMetadata["avatar_url"],
       let url = URL(string: avatarUrlString) {
        print(url)
    }
}
