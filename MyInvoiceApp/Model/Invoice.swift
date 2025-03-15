import Foundation

struct Invoice: Identifiable, Equatable {
    var id: Int? = nil
    
    // NUEVO: guardamos el id del emisor (si se elige)
    var issuerId: Int? = nil
    
    // Información general
    var invoiceNumber: Int
    var invoiceDate: String
    
    // Datos del emisor
    var issuerName: String
    var issuerAddress: String
    var issuerNIF: String
    
    // Datos del cliente
    var clientName: String
    var clientAddress: String
    var clientNIF: String
    
    // Observaciones
    var observaciones: String
    
    // Items
    var items: [InvoiceItem]
    
    // Impuestos
    var ivaPercentage: Double
    var irpfPercentage: Double
    
    // Totales
    var baseImponible: Double
    var totalIVA: Double
    var totalIRPF: Double
    var totalFactura: Double
}
