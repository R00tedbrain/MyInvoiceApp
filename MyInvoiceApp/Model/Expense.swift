// Expense.swift
struct Expense: Identifiable, Equatable {
    var id: Int?
    var concept: String
    var expenseDate: String
    var amount: Double
}
