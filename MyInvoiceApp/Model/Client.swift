import Foundation

struct Client: Identifiable, Equatable {
    var id: Int? = nil
    var name: String
    var address: String
    var nif: String
    var nick: String = ""  // ← Campo nuevo
}
