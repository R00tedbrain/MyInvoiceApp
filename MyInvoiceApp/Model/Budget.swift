// Budget.swift
struct Budget: Identifiable, Equatable {
    var id: Int?
    var budgetNumber: Int
    var budgetDate: String
    var issuerId: Int
    var clientId: Int
    var observaciones: String
    
    var items: [BudgetItem]
    
    var ivaPercentage: Double
    var irpfPercentage: Double
    
    var baseImponible: Double
    var totalIVA: Double
    var totalIRPF: Double
    var totalBudget: Double
}
