//
//  DatabaseManager.swift
//  MyInvoiceApp
//
//  Versión con migraciones + tablas extra
//

import Foundation
import SQLite3
import SwiftUI

class DatabaseManager: ObservableObject {
    
    private var db: OpaquePointer?
    
    // Publicados (lo de siempre)
    @Published var invoices: [Invoice] = []
    @Published var clients:  [Client]  = []
    
    // MARK: - Init
    init() {
        print("DEBUG DatabaseManager: init()")
        openDatabase()
        checkAndPerformMigrations()  // Migraciones en vez de createTablesIfNeeded()
        
        // Cargar datos principales
        fetchAllInvoices()
        fetchAllClients()
    }
    
    deinit {
        print("DEBUG DatabaseManager: deinit() - cerrando DB")
        sqlite3_close(db)
    }
    
    // MARK: - Abrir DB
    private func openDatabase() {
        print("DEBUG DatabaseManager: openDatabase() - intentando abrir BD")
        do {
            let fileUrl = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("MyInvoicesDB.sqlite")
            
            print("DEBUG DatabaseManager: Ruta BD = \(fileUrl.path)")
            
            if sqlite3_open(fileUrl.path, &db) != SQLITE_OK {
                print("ERROR DatabaseManager: No se pudo abrir la BD")
            } else {
                print("DEBUG DatabaseManager: BD abierta en: \(fileUrl.path)")
            }
        } catch {
            print("ERROR DatabaseManager: No se pudo crear ruta BD: \(error)")
        }
    }
    
    // MARK: - Migraciones
    private func checkAndPerformMigrations() {
        let currentVersion = getDBVersion()
        print("DEBUG DatabaseManager: Versión actual del esquema = \(currentVersion)")
        
        // ============= Versión 1 =============
        // Tablas básicas (invoices, invoice_items, clients) + col "nick" en clients
        if currentVersion < 1 {
            print("DEBUG DatabaseManager: Migrando a versión 1...")
            
            let createInvoiceTable = """
            CREATE TABLE IF NOT EXISTS invoices(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                invoiceNumber INTEGER,
                invoiceDate TEXT,
                issuerName TEXT,
                issuerAddress TEXT,
                issuerNIF TEXT,
                clientName TEXT,
                clientAddress TEXT,
                clientNIF TEXT,
                observaciones TEXT,
                ivaPercentage REAL,
                irpfPercentage REAL,
                baseImponible REAL,
                totalIVA REAL,
                totalIRPF REAL,
                totalFactura REAL
            );
            """
            let createItemsTable = """
            CREATE TABLE IF NOT EXISTS invoice_items(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                invoiceId INTEGER,
                concept TEXT,
                model TEXT,
                bastidor TEXT,
                itemDate TEXT,
                amount REAL
            );
            """
            let createClientsTable = """
            CREATE TABLE IF NOT EXISTS clients(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                address TEXT,
                nif TEXT
            );
            """
            
            sqlite3_exec(db, createInvoiceTable, nil, nil, nil)
            sqlite3_exec(db, createItemsTable,   nil, nil, nil)
            sqlite3_exec(db, createClientsTable, nil, nil, nil)
            
            // Añadir columna "nick" a clients
            let addNickColumn = "ALTER TABLE clients ADD COLUMN nick TEXT;"
            sqlite3_exec(db, addNickColumn, nil, nil, nil)
            
            setDBVersion(1)
        }
        
        // ============= Versión 2 =============
        // Nuevas tablas: issuers, services, expenses, budgets, budget_items
        if currentVersion < 2 {
            print("DEBUG DatabaseManager: Migrando a versión 2...")
            
            let createIssuersTable = """
            CREATE TABLE IF NOT EXISTS issuers(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                address TEXT,
                nif TEXT,
                phone TEXT
            );
            """
            let createServicesTable = """
            CREATE TABLE IF NOT EXISTS services(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                serviceName TEXT,
                serviceDescription TEXT,
                servicePrice REAL
            );
            """
            let createExpensesTable = """
            CREATE TABLE IF NOT EXISTS expenses(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                concept TEXT,
                expenseDate TEXT,
                amount REAL
            );
            """
            let createBudgetsTable = """
            CREATE TABLE IF NOT EXISTS budgets(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                budgetNumber INTEGER,
                budgetDate TEXT,
                issuerId INTEGER,
                clientId INTEGER,
                observaciones TEXT,
                ivaPercentage REAL,
                irpfPercentage REAL,
                baseImponible REAL,
                totalIVA REAL,
                totalIRPF REAL,
                totalBudget REAL
            );
            """
            let createBudgetItemsTable = """
            CREATE TABLE IF NOT EXISTS budget_items(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                budgetId INTEGER,
                concept TEXT,
                model TEXT,
                bastidor TEXT,
                itemDate TEXT,
                amount REAL
            );
            """
            
            sqlite3_exec(db, createIssuersTable,     nil, nil, nil)
            sqlite3_exec(db, createServicesTable,    nil, nil, nil)
            sqlite3_exec(db, createExpensesTable,    nil, nil, nil)
            sqlite3_exec(db, createBudgetsTable,     nil, nil, nil)
            sqlite3_exec(db, createBudgetItemsTable, nil, nil, nil)
            
            setDBVersion(2)
        }
        
        // ============= Versión 3 =============
        // Tabla app_settings (para personalizar etiquetas, etc.)
        if currentVersion < 3 {
            print("DEBUG DatabaseManager: Migrando a versión 3...")
            
            let createSettingsTable = """
            CREATE TABLE IF NOT EXISTS app_settings(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                settingKey TEXT NOT NULL UNIQUE,
                settingValue TEXT
            );
            """
            sqlite3_exec(db, createSettingsTable, nil, nil, nil)
            
            // Insertar valores por defecto (etiquetas)
            let defaultLabels = [
                ("column_concept_label",   "Concepto"),
                ("column_model_label",     "Modelo"),
                ("column_bastidor_label",  "Bastidor"),
                ("column_date_label",      "Fecha"),
                ("column_amount_label",    "Importe")
            ]
            for (key, val) in defaultLabels {
                let insert = """
                INSERT OR IGNORE INTO app_settings (settingKey, settingValue)
                VALUES ('\(key)', '\(val)');
                """
                sqlite3_exec(db, insert, nil, nil, nil)
            }
            
            setDBVersion(3)
        }
        
        // ============= Versión 4 =============
        // Añadir issuerId a invoices
        if currentVersion < 4 {
            print("DEBUG DatabaseManager: Migrando a versión 4...")
            let addIssuerId = "ALTER TABLE invoices ADD COLUMN issuerId INTEGER DEFAULT NULL;"
            sqlite3_exec(db, addIssuerId, nil, nil, nil)
            
            setDBVersion(4)
        }

        // ============= Versión 5 =============
        // Asegurar la tabla app_settings aunque partamos de versión 4
        // (así se crea si no existía, para que setSettingValue / getSettingValue funcionen)
        if currentVersion < 5 {
            print("DEBUG DatabaseManager: Migrando a versión 5 (asegurar app_settings)...")
            
            let createSettingsTable = """
            CREATE TABLE IF NOT EXISTS app_settings(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                settingKey TEXT NOT NULL UNIQUE,
                settingValue TEXT
            );
            """
            sqlite3_exec(db, createSettingsTable, nil, nil, nil)
            
            // Insertar por defecto (si no existen) las 5 etiquetas principales
            let defaultLabels = [
                ("column_concept_label",   "Concepto"),
                ("column_model_label",     "Modelo"),
                ("column_bastidor_label",  "Bastidor"),
                ("column_date_label",      "Fecha"),
                ("column_amount_label",    "Importe")
            ]
            for (key, val) in defaultLabels {
                let insert = """
                INSERT OR IGNORE INTO app_settings (settingKey, settingValue)
                VALUES ('\(key)', '\(val)');
                """
                sqlite3_exec(db, insert, nil, nil, nil)
            }

            setDBVersion(5)
        }
        
        print("DEBUG DatabaseManager: Migraciones completadas. Versión final = \(getDBVersion())")
    }
    
    private func getDBVersion() -> Int {
        var version: Int32 = 0
        let query = "PRAGMA user_version;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                version = sqlite3_column_int(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return Int(version)
    }
    
    private func setDBVersion(_ newVersion: Int) {
        let query = "PRAGMA user_version = \(newVersion);"
        sqlite3_exec(db, query, nil, nil, nil)
        print("DEBUG DatabaseManager: DB schema version actualizada a \(newVersion)")
    }
    
    // =========================================================================
    //  AQUI ABAJO: El mismo CRUD de Facturas y Clientes que ya tenías,
    //  con la adición de issuerId para las facturas.
    // =========================================================================
    
    // MARK: - CRUD de Facturas
    func insertInvoice(_ invoice: Invoice) {
        print("DEBUG DatabaseManager: insertInvoice() -> \(invoice)")
        
        // Ahora añadimos issuerId al final
        let sql = """
        INSERT INTO invoices
        (invoiceNumber, invoiceDate, issuerName, issuerAddress, issuerNIF,
         clientName, clientAddress, clientNIF, observaciones,
         ivaPercentage, irpfPercentage, baseImponible, totalIVA, totalIRPF, totalFactura,
         issuerId)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_int(statement,    1, Int32(invoice.invoiceNumber))
            sqlite3_bind_text(statement,   2, invoice.invoiceDate,    -1, transient)
            sqlite3_bind_text(statement,   3, invoice.issuerName,     -1, transient)
            sqlite3_bind_text(statement,   4, invoice.issuerAddress,  -1, transient)
            sqlite3_bind_text(statement,   5, invoice.issuerNIF,      -1, transient)
            
            sqlite3_bind_text(statement,   6, invoice.clientName,     -1, transient)
            sqlite3_bind_text(statement,   7, invoice.clientAddress,  -1, transient)
            sqlite3_bind_text(statement,   8, invoice.clientNIF,      -1, transient)
            sqlite3_bind_text(statement,   9, invoice.observaciones,  -1, transient)
            
            sqlite3_bind_double(statement, 10, invoice.ivaPercentage)
            sqlite3_bind_double(statement, 11, invoice.irpfPercentage)
            sqlite3_bind_double(statement, 12, invoice.baseImponible)
            sqlite3_bind_double(statement, 13, invoice.totalIVA)
            sqlite3_bind_double(statement, 14, invoice.totalIRPF)
            sqlite3_bind_double(statement, 15, invoice.totalFactura)
            
            // Nuevo: issuerId
            sqlite3_bind_int(statement,    16, Int32(invoice.issuerId ?? 0))
            
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                print("DEBUG DatabaseManager: Factura insertada con éxito")
                let newID = sqlite3_last_insert_rowid(db)
                // Insertar items
                for item in invoice.items {
                    insertInvoiceItem(item, invoiceId: Int(newID))
                }
            } else {
                let err = sqlite3_errmsg(db).map(String.init) ?? "desconocido"
                print("ERROR DatabaseManager: Error insertando invoice: \(err)")
            }
        }
        sqlite3_finalize(statement)
        
        fetchAllInvoices()
    }
    
    private func insertInvoiceItem(_ item: InvoiceItem, invoiceId: Int) {
        print("DEBUG DatabaseManager: insertInvoiceItem() -> invoiceId=\(invoiceId), item=\(item)")
        
        let sql = """
        INSERT INTO invoice_items
        (invoiceId, concept, model, bastidor, itemDate, amount)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_int(statement,    1, Int32(invoiceId))
            sqlite3_bind_text(statement,   2, item.concept,   -1, transient)
            sqlite3_bind_text(statement,   3, item.model,     -1, transient)
            sqlite3_bind_text(statement,   4, item.bastidor,  -1, transient)
            sqlite3_bind_text(statement,   5, item.date,      -1, transient)
            sqlite3_bind_double(statement, 6, item.amount)
            
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                print("DEBUG DatabaseManager: Item insertado correctamente")
            } else {
                let err = sqlite3_errmsg(db).map(String.init) ?? "desconocido"
                print("ERROR DatabaseManager: Error insertando item: \(err)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func fetchAllInvoices() {
        print("DEBUG DatabaseManager: fetchAllInvoices()")
        invoices.removeAll()
        
        let sql = "SELECT * FROM invoices ORDER BY invoiceNumber DESC;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                // Columnas: 0..15 y la 16 = issuerId (añadida en version 4)
                let id            = sqlite3_column_int(statement, 0)
                let invoiceNumber = sqlite3_column_int(statement, 1)
                
                guard
                    let invoiceDatePtr   = sqlite3_column_text(statement, 2),
                    let issuerNamePtr    = sqlite3_column_text(statement, 3),
                    let issuerAddressPtr = sqlite3_column_text(statement, 4),
                    let issuerNIFPtr     = sqlite3_column_text(statement, 5),
                    let clientNamePtr    = sqlite3_column_text(statement, 6),
                    let clientAddressPtr = sqlite3_column_text(statement, 7),
                    let clientNIFPtr     = sqlite3_column_text(statement, 8)
                else {
                    print("DEBUG DatabaseManager: Faltan columnas en 'invoices'?")
                    continue
                }
                
                let observacionesPtr = sqlite3_column_text(statement, 9)
                
                let invoiceDate   = String(cString: invoiceDatePtr)
                let issuerName    = String(cString: issuerNamePtr)
                let issuerAddress = String(cString: issuerAddressPtr)
                let issuerNIF     = String(cString: issuerNIFPtr)
                let clientName    = String(cString: clientNamePtr)
                let clientAddress = String(cString: clientAddressPtr)
                let clientNIF     = String(cString: clientNIFPtr)
                
                let observaciones = observacionesPtr != nil
                    ? String(cString: observacionesPtr!)
                    : ""
                
                let ivaPercentage  = sqlite3_column_double(statement, 10)
                let irpfPercentage = sqlite3_column_double(statement, 11)
                let baseImponible  = sqlite3_column_double(statement, 12)
                let totalIVA       = sqlite3_column_double(statement, 13)
                let totalIRPF      = sqlite3_column_double(statement, 14)
                let totalFactura   = sqlite3_column_double(statement, 15)
                
                // Leer issuerId (col 16), si no existe vendrá 0
                let rawIssuerId = sqlite3_column_int(statement, 16)
                let invoiceIssuerId: Int? = (rawIssuerId == 0) ? nil : Int(rawIssuerId)
                
                let items = fetchItems(forInvoiceId: Int(id))
                
                let invoice = Invoice(
                    id: Int(id),
                    issuerId: invoiceIssuerId,
                    invoiceNumber: Int(invoiceNumber),
                    invoiceDate: invoiceDate,
                    issuerName: issuerName,
                    issuerAddress: issuerAddress,
                    issuerNIF: issuerNIF,
                    clientName: clientName,
                    clientAddress: clientAddress,
                    clientNIF: clientNIF,
                    observaciones: observaciones,
                    items: items,
                    ivaPercentage: ivaPercentage,
                    irpfPercentage: irpfPercentage,
                    baseImponible: baseImponible,
                    totalIVA: totalIVA,
                    totalIRPF: totalIRPF,
                    totalFactura: totalFactura
                )
                invoices.append(invoice)
            }
        }
        sqlite3_finalize(statement)
        
        print("DEBUG DatabaseManager: fetchAllInvoices -> \(invoices.count) facturas")
    }
    
    private func fetchItems(forInvoiceId invoiceId: Int) -> [InvoiceItem] {
        print("DEBUG DatabaseManager: fetchItems(forInvoiceId: \(invoiceId))")
        var results: [InvoiceItem] = []
        
        let sql = """
        SELECT id, concept, model, bastidor, itemDate, amount
        FROM invoice_items
        WHERE invoiceId = \(invoiceId);
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let itemId = sqlite3_column_int(statement, 0)
                guard
                    let conceptPtr   = sqlite3_column_text(statement, 1),
                    let modelPtr     = sqlite3_column_text(statement, 2),
                    let bastidorPtr  = sqlite3_column_text(statement, 3),
                    let datePtr      = sqlite3_column_text(statement, 4)
                else {
                    continue
                }
                
                let concept  = String(cString: conceptPtr)
                let model    = String(cString: modelPtr)
                let bastidor = String(cString: bastidorPtr)
                let date     = String(cString: datePtr)
                let amount   = sqlite3_column_double(statement, 5)
                
                let item = InvoiceItem(
                    id: Int(itemId),
                    localUUID: UUID(),
                    concept: concept,
                    model: model,
                    bastidor: bastidor,
                    date: date,
                    amount: amount
                )
                results.append(item)
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    func updateInvoice(_ invoice: Invoice) {
        print("DEBUG DatabaseManager: updateInvoice() -> \(invoice)")
        guard let rowId = invoice.id else { return }
        
        // Añadimos issuerId al final del SET
        let sql = """
        UPDATE invoices
        SET invoiceNumber = ?, invoiceDate = ?, issuerName = ?, issuerAddress = ?, issuerNIF = ?,
            clientName = ?, clientAddress = ?, clientNIF = ?, observaciones = ?,
            ivaPercentage = ?, irpfPercentage = ?, baseImponible = ?, totalIVA = ?, totalIRPF = ?, totalFactura = ?,
            issuerId = ?
        WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_int(statement, 1, Int32(invoice.invoiceNumber))
            sqlite3_bind_text(statement, 2, invoice.invoiceDate,   -1, t)
            sqlite3_bind_text(statement, 3, invoice.issuerName,    -1, t)
            sqlite3_bind_text(statement, 4, invoice.issuerAddress, -1, t)
            sqlite3_bind_text(statement, 5, invoice.issuerNIF,     -1, t)
            
            sqlite3_bind_text(statement, 6, invoice.clientName,     -1, t)
            sqlite3_bind_text(statement, 7, invoice.clientAddress,  -1, t)
            sqlite3_bind_text(statement, 8, invoice.clientNIF,      -1, t)
            sqlite3_bind_text(statement, 9, invoice.observaciones,  -1, t)
            
            sqlite3_bind_double(statement, 10, invoice.ivaPercentage)
            sqlite3_bind_double(statement, 11, invoice.irpfPercentage)
            sqlite3_bind_double(statement, 12, invoice.baseImponible)
            sqlite3_bind_double(statement, 13, invoice.totalIVA)
            sqlite3_bind_double(statement, 14, invoice.totalIRPF)
            sqlite3_bind_double(statement, 15, invoice.totalFactura)
            
            // issuerId
            sqlite3_bind_int(statement, 16, Int32(invoice.issuerId ?? 0))
            
            // id
            sqlite3_bind_int(statement, 17, Int32(rowId))
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                let err = sqlite3_errmsg(db).map(String.init) ?? "desconocido"
                print("ERROR DatabaseManager: Al actualizar invoice: \(err)")
            }
        }
        sqlite3_finalize(statement)
        
        // Borrar items antiguos
        let deleteItems = "DELETE FROM invoice_items WHERE invoiceId = \(rowId);"
        sqlite3_exec(db, deleteItems, nil, nil, nil)
        
        // Insertar items nuevos
        for item in invoice.items {
            insertInvoiceItem(item, invoiceId: rowId)
        }
        
        fetchAllInvoices()
    }
    
    func deleteInvoice(_ invoice: Invoice) {
        print("DEBUG DatabaseManager: deleteInvoice() -> \(invoice)")
        guard let rowId = invoice.id else { return }
        
        let sqlInvoice = "DELETE FROM invoices WHERE id = \(rowId);"
        let sqlItems   = "DELETE FROM invoice_items WHERE invoiceId = \(rowId);"
        
        sqlite3_exec(db, sqlInvoice, nil, nil, nil)
        sqlite3_exec(db, sqlItems,   nil, nil, nil)
        
        fetchAllInvoices()
    }
    
    func getNextInvoiceNumber() -> Int {
        print("DEBUG DatabaseManager: getNextInvoiceNumber()")
        let sql = "SELECT MAX(invoiceNumber) FROM invoices;"
        var statement: OpaquePointer?
        var maxNumber: Int32 = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                maxNumber = sqlite3_column_int(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return Int(maxNumber) + 1
    }
    
    // MARK: - CRUD de Clientes
    func insertClient(_ client: Client) {
        print("DEBUG DatabaseManager: insertClient() -> \(client)")
        
        let sql = """
        INSERT INTO clients
        (name, address, nif, nick)
        VALUES (?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, client.name,    -1, t)
            sqlite3_bind_text(statement, 2, client.address, -1, t)
            sqlite3_bind_text(statement, 3, client.nif,     -1, t)
            sqlite3_bind_text(statement, 4, client.nick,    -1, t)
            
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        fetchAllClients()
    }
    
    func fetchAllClients() {
        print("DEBUG DatabaseManager: fetchAllClients()")
        clients.removeAll()
        
        let sql = "SELECT id, name, address, nif, nick FROM clients ORDER BY name ASC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id        = sqlite3_column_int(statement, 0)
                let namePtr   = sqlite3_column_text(statement, 1)
                let addrPtr   = sqlite3_column_text(statement, 2)
                let nifPtr    = sqlite3_column_text(statement, 3)
                let nickPtr   = sqlite3_column_text(statement, 4)
                
                let name  = namePtr  != nil ? String(cString: namePtr!)  : ""
                let addr  = addrPtr  != nil ? String(cString: addrPtr!)  : ""
                let nif   = nifPtr   != nil ? String(cString: nifPtr!)   : ""
                let nick  = nickPtr  != nil ? String(cString: nickPtr!)  : ""
                
                let c = Client(
                    id: Int(id),
                    name: name,
                    address: addr,
                    nif: nif,
                    nick: nick
                )
                clients.append(c)
            }
        }
        sqlite3_finalize(statement)
        print("DEBUG DatabaseManager: fetchAllClients -> \(clients.count) clientes")
    }
    
    func updateClient(_ client: Client) {
        print("DEBUG DatabaseManager: updateClient() -> \(client)")
        guard let rowId = client.id else { return }
        
        let sql = """
        UPDATE clients
        SET name = ?, address = ?, nif = ?, nick = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, client.name,    -1, t)
            sqlite3_bind_text(statement, 2, client.address, -1, t)
            sqlite3_bind_text(statement, 3, client.nif,     -1, t)
            sqlite3_bind_text(statement, 4, client.nick,    -1, t)
            sqlite3_bind_int(statement, 5, Int32(rowId))
            
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        fetchAllClients()
    }
    
    func deleteClient(_ client: Client) {
        print("DEBUG DatabaseManager: deleteClient() -> \(client)")
        guard let rowId = client.id else { return }
        
        let sql = "DELETE FROM clients WHERE id = \(rowId);"
        sqlite3_exec(db, sql, nil, nil, nil)
        fetchAllClients()
    }
    
    // =========================================================================
    //  CRUD de Issuers (emisores)
    // =========================================================================
    func insertIssuer(name: String, address: String, nif: String, phone: String) {
        let sql = "INSERT INTO issuers (name, address, nif, phone) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, name,    -1, t)
            sqlite3_bind_text(statement, 2, address, -1, t)
            sqlite3_bind_text(statement, 3, nif,     -1, t)
            sqlite3_bind_text(statement, 4, phone,   -1, t)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func fetchAllIssuers() -> [Issuer] {
        var issuers: [Issuer] = []
        let sql = "SELECT id, name, address, nif, phone FROM issuers;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id   = sqlite3_column_int(statement, 0)
                let namePtr    = sqlite3_column_text(statement, 1)
                let addrPtr    = sqlite3_column_text(statement, 2)
                let nifPtr     = sqlite3_column_text(statement, 3)
                let phonePtr   = sqlite3_column_text(statement, 4)
                
                let issuer = Issuer(
                    id: Int(id),
                    name:    namePtr   != nil ? String(cString: namePtr!)   : "",
                    address: addrPtr   != nil ? String(cString: addrPtr!)   : "",
                    nif:     nifPtr    != nil ? String(cString: nifPtr!)    : "",
                    phone:   phonePtr  != nil ? String(cString: phonePtr!)  : ""
                )
                issuers.append(issuer)
            }
        }
        sqlite3_finalize(statement)
        return issuers
    }
    
    func updateIssuer(_ issuer: Issuer) {
        guard let rowId = issuer.id else { return }
        let sql = """
        UPDATE issuers
        SET name = ?, address = ?, nif = ?, phone = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, issuer.name,    -1, t)
            sqlite3_bind_text(statement, 2, issuer.address, -1, t)
            sqlite3_bind_text(statement, 3, issuer.nif,     -1, t)
            sqlite3_bind_text(statement, 4, issuer.phone,   -1, t)
            sqlite3_bind_int(statement, 5, Int32(rowId))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func deleteIssuer(_ issuer: Issuer) {
        guard let rowId = issuer.id else { return }
        let sql = "DELETE FROM issuers WHERE id = \(rowId);"
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    
    // =========================================================================
    //  CRUD de Servicios (services)
    // =========================================================================
    func insertService(_ service: Service) {
        let sql = """
        INSERT INTO services (serviceName, serviceDescription, servicePrice)
        VALUES (?, ?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, service.serviceName,        -1, t)
            sqlite3_bind_text(statement, 2, service.serviceDescription, -1, t)
            sqlite3_bind_double(statement, 3, service.servicePrice)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func fetchAllServices() -> [Service] {
        var results: [Service] = []
        let sql = "SELECT id, serviceName, serviceDescription, servicePrice FROM services;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int(statement, 0)
                let namePtr = sqlite3_column_text(statement, 1)
                let descPtr = sqlite3_column_text(statement, 2)
                let price   = sqlite3_column_double(statement, 3)
                
                let s = Service(
                    id: Int(id),
                    serviceName:        namePtr != nil ? String(cString: namePtr!) : "",
                    serviceDescription: descPtr != nil ? String(cString: descPtr!) : "",
                    servicePrice:       price
                )
                results.append(s)
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    func updateService(_ service: Service) {
        guard let rowId = service.id else { return }
        let sql = """
        UPDATE services
        SET serviceName = ?, serviceDescription = ?, servicePrice = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, service.serviceName,        -1, t)
            sqlite3_bind_text(statement, 2, service.serviceDescription, -1, t)
            sqlite3_bind_double(statement, 3, service.servicePrice)
            sqlite3_bind_int(statement, 4, Int32(rowId))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func deleteService(_ service: Service) {
        guard let rowId = service.id else { return }
        let sql = "DELETE FROM services WHERE id = \(rowId);"
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    
    // =========================================================================
    //  CRUD de Gastos (expenses)
    // =========================================================================
    func insertExpense(concept: String, expenseDate: String, amount: Double) {
        let sql = "INSERT INTO expenses (concept, expenseDate, amount) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, concept,     -1, t)
            sqlite3_bind_text(statement, 2, expenseDate, -1, t)
            sqlite3_bind_double(statement, 3, amount)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func fetchAllExpenses() -> [Expense] {
        var results: [Expense] = []
        let sql = "SELECT id, concept, expenseDate, amount FROM expenses ORDER BY expenseDate DESC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id     = sqlite3_column_int(statement, 0)
                let cPtr   = sqlite3_column_text(statement, 1)
                let dPtr   = sqlite3_column_text(statement, 2)
                let amount = sqlite3_column_double(statement, 3)
                
                let e = Expense(
                    id: Int(id),
                    concept:    cPtr != nil ? String(cString: cPtr!) : "",
                    expenseDate: dPtr != nil ? String(cString: dPtr!) : "",
                    amount:     amount
                )
                results.append(e)
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    func updateExpense(_ expense: Expense) {
        guard let rowId = expense.id else { return }
        let sql = """
        UPDATE expenses
        SET concept = ?, expenseDate = ?, amount = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, expense.concept,     -1, t)
            sqlite3_bind_text(statement, 2, expense.expenseDate, -1, t)
            sqlite3_bind_double(statement, 3, expense.amount)
            sqlite3_bind_int(statement, 4, Int32(rowId))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func deleteExpense(_ expense: Expense) {
        guard let rowId = expense.id else { return }
        let sql = "DELETE FROM expenses WHERE id = \(rowId);"
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    
    // =========================================================================
    //  CRUD de Presupuestos (budgets)
    // =========================================================================
    func insertBudget(_ budget: Budget) {
        let sql = """
        INSERT INTO budgets
        (budgetNumber, budgetDate, issuerId, clientId, observaciones,
         ivaPercentage, irpfPercentage, baseImponible, totalIVA, totalIRPF, totalBudget)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_int(statement,   1, Int32(budget.budgetNumber))
            sqlite3_bind_text(statement,  2, budget.budgetDate,   -1, t)
            sqlite3_bind_int(statement,   3, Int32(budget.issuerId))
            sqlite3_bind_int(statement,   4, Int32(budget.clientId))
            sqlite3_bind_text(statement,  5, budget.observaciones, -1, t)
            
            sqlite3_bind_double(statement, 6,  budget.ivaPercentage)
            sqlite3_bind_double(statement, 7,  budget.irpfPercentage)
            sqlite3_bind_double(statement, 8,  budget.baseImponible)
            sqlite3_bind_double(statement, 9,  budget.totalIVA)
            sqlite3_bind_double(statement, 10, budget.totalIRPF)
            sqlite3_bind_double(statement, 11, budget.totalBudget)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let newId = Int(sqlite3_last_insert_rowid(db))
                // Insertar items
                for item in budget.items {
                    insertBudgetItem(item, budgetId: newId)
                }
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func insertBudgetItem(_ item: BudgetItem, budgetId: Int) {
        let sql = """
        INSERT INTO budget_items
        (budgetId, concept, model, bastidor, itemDate, amount)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_int(statement,    1, Int32(budgetId))
            sqlite3_bind_text(statement,   2, item.concept,   -1, t)
            sqlite3_bind_text(statement,   3, item.model,     -1, t)
            sqlite3_bind_text(statement,   4, item.bastidor,  -1, t)
            sqlite3_bind_text(statement,   5, item.itemDate,  -1, t)
            sqlite3_bind_double(statement, 6, item.amount)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func fetchAllBudgets() -> [Budget] {
        var results: [Budget] = []
        let sql = "SELECT * FROM budgets ORDER BY budgetNumber DESC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id           = sqlite3_column_int(statement, 0)
                let budgetNumber = sqlite3_column_int(statement, 1)
                guard let datePtr = sqlite3_column_text(statement, 2) else { continue }
                
                let issuerId  = sqlite3_column_int(statement, 3)
                let clientId  = sqlite3_column_int(statement, 4)
                let obsPtr    = sqlite3_column_text(statement, 5)
                let ivaP      = sqlite3_column_double(statement, 6)
                let irpfP     = sqlite3_column_double(statement, 7)
                let baseImp   = sqlite3_column_double(statement, 8)
                let tIva      = sqlite3_column_double(statement, 9)
                let tIrpf     = sqlite3_column_double(statement, 10)
                let tBudget   = sqlite3_column_double(statement, 11)
                
                let budgetDate    = String(cString: datePtr)
                let observaciones = obsPtr != nil ? String(cString: obsPtr!) : ""
                
                let items = fetchBudgetItems(budgetId: Int(id))
                let b = Budget(
                    id: Int(id),
                    budgetNumber: Int(budgetNumber),
                    budgetDate: budgetDate,
                    issuerId: Int(issuerId),
                    clientId: Int(clientId),
                    observaciones: observaciones,
                    items: items,
                    ivaPercentage: ivaP,
                    irpfPercentage: irpfP,
                    baseImponible: baseImp,
                    totalIVA: tIva,
                    totalIRPF: tIrpf,
                    totalBudget: tBudget
                )
                results.append(b)
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    private func fetchBudgetItems(budgetId: Int) -> [BudgetItem] {
        var items: [BudgetItem] = []
        let sql = """
        SELECT id, concept, model, bastidor, itemDate, amount
        FROM budget_items
        WHERE budgetId = \(budgetId);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let itemId   = sqlite3_column_int(statement, 0)
                let cPtr     = sqlite3_column_text(statement, 1)
                let mPtr     = sqlite3_column_text(statement, 2)
                let bPtr     = sqlite3_column_text(statement, 3)
                let dPtr     = sqlite3_column_text(statement, 4)
                let amount   = sqlite3_column_double(statement, 5)
                
                let item = BudgetItem(
                    id: Int(itemId),
                    concept:   cPtr != nil ? String(cString: cPtr!) : "",
                    model:     mPtr != nil ? String(cString: mPtr!) : "",
                    bastidor:  bPtr != nil ? String(cString: bPtr!) : "",
                    itemDate:  dPtr != nil ? String(cString: dPtr!) : "",
                    amount:    amount
                )
                items.append(item)
            }
        }
        sqlite3_finalize(statement)
        return items
    }
    
    func updateBudget(_ budget: Budget) {
        print("DEBUG DatabaseManager: updateBudget() -> \(budget)")
        guard let rowId = budget.id else { return }
        
        let sql = """
        UPDATE budgets
        SET budgetNumber = ?, budgetDate = ?, issuerId = ?, clientId = ?, observaciones = ?,
            ivaPercentage = ?, irpfPercentage = ?, baseImponible = ?, totalIVA = ?, totalIRPF = ?, totalBudget = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_int(statement,   1, Int32(budget.budgetNumber))
            sqlite3_bind_text(statement,  2, budget.budgetDate,   -1, t)
            sqlite3_bind_int(statement,   3, Int32(budget.issuerId))
            sqlite3_bind_int(statement,   4, Int32(budget.clientId))
            sqlite3_bind_text(statement,  5, budget.observaciones, -1, t)
            
            sqlite3_bind_double(statement, 6,  budget.ivaPercentage)
            sqlite3_bind_double(statement, 7,  budget.irpfPercentage)
            sqlite3_bind_double(statement, 8,  budget.baseImponible)
            sqlite3_bind_double(statement, 9,  budget.totalIVA)
            sqlite3_bind_double(statement, 10, budget.totalIRPF)
            sqlite3_bind_double(statement, 11, budget.totalBudget)
            
            sqlite3_bind_int(statement,   12, Int32(rowId))
            
            let stepRes = sqlite3_step(statement)
            if stepRes != SQLITE_DONE {
                let err = sqlite3_errmsg(db).map(String.init) ?? "desconocido"
                print("ERROR DatabaseManager: updateBudget -> \(err)")
            }
        }
        sqlite3_finalize(statement)
        
        // Borramos sus items
        let deleteItems = "DELETE FROM budget_items WHERE budgetId = \(rowId);"
        sqlite3_exec(db, deleteItems, nil, nil, nil)
        
        // Insertar items de nuevo
        for item in budget.items {
            insertBudgetItem(item, budgetId: rowId)
        }
        
        print("DEBUG DatabaseManager: Presupuesto actualizado id=\(rowId)")
    }
    
    func deleteBudget(_ budget: Budget) {
        print("DEBUG DatabaseManager: deleteBudget() -> \(budget)")
        guard let rowId = budget.id else {
            print("DEBUG DatabaseManager: Budget sin 'id', no se puede borrar.")
            return
        }
        
        let sqlBudget = "DELETE FROM budgets WHERE id = \(rowId);"
        let sqlItems  = "DELETE FROM budget_items WHERE budgetId = \(rowId);"
        
        sqlite3_exec(db, sqlBudget, nil, nil, nil)
        sqlite3_exec(db, sqlItems,  nil, nil, nil)
        
        print("DEBUG DatabaseManager: Presupuesto borrado id=\(rowId)")
        
        // Autorefrescar tras borrar
        fetchAllBudgets()
    }
    
    // MARK: - app_settings (ej. para columnas personalizables)
    func getSettingValue(forKey key: String) -> String {
        let sql = "SELECT settingValue FROM app_settings WHERE settingKey = ?;"
        var statement: OpaquePointer?
        var result = ""
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            // Usamos destructor 'transient' en vez de nil
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, key, -1, t)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                if let valPtr = sqlite3_column_text(statement, 0) {
                    result = String(cString: valPtr)
                    print("DEBUG getSettingValue(\(key)) => result=\(result)")
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    func setSettingValue(_ value: String, forKey key: String) {
        print("DEBUG DatabaseManager: setSettingValue(\(value), forKey: \(key))")
        let sql = """
        INSERT OR REPLACE INTO app_settings (settingKey, settingValue)
        VALUES (?, ?);
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            // Usamos destructor 'transient' en vez de nil
            let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            
            sqlite3_bind_text(statement, 1, key,   -1, t)
            sqlite3_bind_text(statement, 2, value, -1, t)
            
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        print("DEBUG DatabaseManager: setSettingValue FINISHED")
    }
    
    // MARK: - Backup / Restore
    func backupDatabase(to destinationURL: URL) -> Bool {
        print("DEBUG DatabaseManager: backupDatabase(to: \(destinationURL.path))")
        do {
            let fileUrl = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("MyInvoicesDB.sqlite")
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: fileUrl, to: destinationURL)
            print("DEBUG DatabaseManager: Backup completado con éxito")
            return true
        } catch {
            print("ERROR DatabaseManager: backupDatabase -> \(error)")
            return false
        }
    }
    
    func restoreDatabase(from sourceURL: URL) -> Bool {
        print("DEBUG DatabaseManager: restoreDatabase(from: \(sourceURL.path))")
        do {
            // Cerrar la DB si está abierta
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
            // Ruta local
            let fileUrl = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("MyInvoicesDB.sqlite")
            
            // Borramos la BD actual (si existe)
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                try FileManager.default.removeItem(at: fileUrl)
            }
            // Copiamos el fichero
            try FileManager.default.copyItem(at: sourceURL, to: fileUrl)
            
            // Re-abrimos la DB y migramos
            openDatabase()
            checkAndPerformMigrations()
            
            // Recargamos datos
            fetchAllInvoices()
            fetchAllClients()
            
            print("DEBUG DatabaseManager: Restore completado con éxito")
            return true
        } catch {
            print("ERROR DatabaseManager: restoreDatabase -> \(error)")
            return false
        }
    }
}
