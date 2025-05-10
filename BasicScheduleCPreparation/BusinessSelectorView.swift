// BusinessSelectorView.swift
import SwiftUI

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
            Text("Business")
                .font(.headline)
            
            HStack {
                Picker("Select Business", selection: $selectedBusinessId) {
                    Text("Select business...").tag(nil as UUID?)
                    
                    ForEach(businessViewModel.businesses) { business in
                        Text(business.wrappedName).tag(business.wrappedId as UUID?)
                    }
                }
                .onChange(of: selectedBusinessId) { _, newId in
                    if let newId = newId, let business = businessViewModel.getBusiness(by: newId) {
                        selectedBusinessName = business.wrappedName
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
            selectedBusinessId = newBusiness.wrappedId
            selectedBusinessName = newBusiness.wrappedName
            
            // Reset form fields
            newBusinessName = ""
            newBusinessType = BusinessViewModel.businessTypes.first ?? ""
            
            // Close the sheet
            showingAddBusinessSheet = false
        }
    }
}
