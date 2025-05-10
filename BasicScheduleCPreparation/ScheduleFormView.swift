// Complete ScheduleFormView.swift
import SwiftUI

struct ScheduleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    @StateObject private var businessViewModel = BusinessViewModel()
    
    // Transaction type state
    @State private var transactionType = "expense"
    
    // Simple state variables
    @State private var date = Date()
    @State private var amount = Decimal(0)
    @State private var store = ""
    @State private var selectedCategory = ""
    @State private var notes = ""
    @State private var photoURL: String? = nil
    
    // Business state
    @State private var selectedBusinessId: UUID? = nil
    @State private var selectedBusinessName = ""
    @State private var showNoBusinessAlert = false
    
    // Non-state properties
    let userId: String
    let editingItem: Schedule?
    
    var body: some View {
        NavigationStack {
            Form {
                // Business selection section
                Section("Business Details") {
                    BusinessSelectorView(
                        businessViewModel: businessViewModel,
                        selectedBusinessId: $selectedBusinessId,
                        selectedBusinessName: $selectedBusinessName,
                        userId: userId
                    )
                }
                
                // Transaction type selection
                Section {
                    Picker("Transaction Type", selection: $transactionType) {
                        Text("Income").tag("income")
                        Text("Expense").tag("expense")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: transactionType) { _, newValue in
                        // Reset category when changing transaction type
                        if let firstCategory = newValue == "income" ?
                            ScheduleViewModel.incomeCategories.first :
                            ScheduleViewModel.expenseCategories.first {
                            selectedCategory = firstCategory
                        }
                    }
                }
                
                // Transaction details
                Section("Transaction Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    TextField("Payee/Store", text: $store)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("$")
                        TextField("Amount", value: $amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                        
                        Picker("Category", selection: $selectedCategory) {
                            if transactionType == "income" {
                                ForEach(ScheduleViewModel.incomeCategories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            } else {
                                ForEach(ScheduleViewModel.expenseCategories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                // Notes section
                Section("Notes") {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Add any additional details here...")
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .opacity(notes.isEmpty ? 0.25 : 1)
                    }
                }
                
                // Receipt section
                Section("Receipt") {
                    PhotoPicker(selectedPhotoURL: $photoURL)
                }
            }
            .navigationTitle(editingItem == nil ? "New Entry" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if validateForm() {
                            saveForm()
                        }
                    }
                }
            }
            .alert("No Business Selected", isPresented: $showNoBusinessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please select or create a business before saving this entry.")
            }
        }
        .onAppear {
            businessViewModel.fetchBusinesses()
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        if let item = editingItem {
            // Load existing item data
            date = item.date ?? Date()
            amount = item.amount?.decimalValue ?? Decimal(0)
            store = item.store ?? ""
            selectedCategory = item.category ?? ""
            notes = item.notes ?? ""
            photoURL = item.photoURL
            transactionType = item.transactionType ?? "expense"
            
            // Handle business ID - convert from NSUUID to UUID
            if let businessIdNSUUID = item.businessId as? NSUUID {
                let businessIdString = businessIdNSUUID.uuidString
                selectedBusinessId = UUID(uuidString: businessIdString)
                selectedBusinessName = item.businessName ?? ""
            }
        } else {
            // Set defaults for new item
            transactionType = "expense"
            selectedCategory = ScheduleViewModel.expenseCategories.first ?? ""
            
            // If there's only one business, select it automatically
            if businessViewModel.businesses.count == 1 {
                let business = businessViewModel.businesses[0]
                selectedBusinessId = business.id
                selectedBusinessName = business.name ?? ""
            }
        }
    }
    
    private func validateForm() -> Bool {
        // Check if business is selected
        if selectedBusinessId == nil {
            showNoBusinessAlert = true
            return false
        }
        
        // Basic validation - ensure store name isn't empty
        if store.isEmpty {
            return false
        }
        
        return true
    }
    
    private func saveForm() {
        guard let businessId = selectedBusinessId else { return }
        
        if let item = editingItem {
            viewModel.updateScheduleItem(
                item,
                date: date,
                amount: amount,
                store: store,
                category: selectedCategory,
                notes: notes.isEmpty ? nil : notes,
                photoURL: photoURL,
                businessId: businessId,
                businessName: selectedBusinessName,
                transactionType: transactionType,
                userId: userId
            )
        } else {
            viewModel.addScheduleItem(
                date: date,
                amount: amount,
                store: store,
                category: selectedCategory,
                notes: notes.isEmpty ? nil : notes,
                photoURL: photoURL,
                businessId: businessId,
                businessName: selectedBusinessName,
                transactionType: transactionType,
                userId: userId
            )
        }
        dismiss()
    }
}

struct BusinessSelectorView: View {
    @ObservedObject var businessViewModel: BusinessViewModel
    @Binding var selectedBusinessId: UUID?
    @Binding var selectedBusinessName: String
    
    @State private var showingAddBusinessSheet = false
    @FocusState private var isBusinessNameFocused: Bool
    @State private var newBusinessName = ""
    @State private var newBusinessType = BusinessViewModel.businessTypes.first ?? ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let userId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Business", selection: $selectedBusinessId) {
                    Text("Select business...").tag(nil as UUID?)
                    
                    ForEach(businessViewModel.businesses, id: \.id) { business in
                        Text(business.name ?? "").tag(business.id as UUID?)
                    }
                }
                .onChange(of: selectedBusinessId) { _, newId in
                    if let newId = newId, let business = businessViewModel.getBusiness(by: newId) {
                        selectedBusinessName = business.name ?? ""
                    } else {
                        selectedBusinessName = ""
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button(action: {
                    showingAddBusinessSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddBusinessSheet) {
            addBusinessView
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var addBusinessView: some View {
        NavigationStack {
            Form {
                Section("Business Information") {
                    TextField("Business Name", text: $newBusinessName)
                        .focused($isBusinessNameFocused)
                    
                    Picker("Business Type", selection: $newBusinessType) {
                        ForEach(BusinessViewModel.businessTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Button("Create Business") {
                        addNewBusiness()
                    }
                    .disabled(newBusinessName.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Add Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddBusinessSheet = false
                    }
                }
            }
            .onAppear {
                isBusinessNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }
    
    private func addNewBusiness() {
        guard !newBusinessName.isEmpty else { return }
        
        // Check if business name already exists
        if businessViewModel.doesBusinessExist(name: newBusinessName) {
            errorMessage = "A business with this name already exists."
            showingError = true
            return
        }
        
        // Add the business
        businessViewModel.addBusiness(name: newBusinessName, businessType: newBusinessType, userId: userId) { newBusiness in
            // Select the newly created business
            selectedBusinessId = newBusiness.id
            selectedBusinessName = newBusiness.name ?? ""
            
            // Reset form fields
            newBusinessName = ""
            newBusinessType = BusinessViewModel.businessTypes.first ?? ""
            
            // Close the sheet
            showingAddBusinessSheet = false
        }
    }
}
