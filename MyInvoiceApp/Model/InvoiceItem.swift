import Foundation

struct InvoiceItem: Identifiable, Equatable {
    var id: Int?
    var localUUID = UUID()
    
    var concept: String
    var model: String
    var bastidor: String
    var date: String
    var amount: Double
}
