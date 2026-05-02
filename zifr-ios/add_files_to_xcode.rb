require 'xcodeproj'

project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'Zifr' }

# Find the group Zifr/Views/Financial
group = project.main_group.find_subpath('Zifr/Views/Financial', true)

files_to_add = [
  'EditInstitutionSheet.swift',
  'InstitutionAccountsSection.swift',
  'InstitutionCardsSection.swift',
  'InstitutionLoansSection.swift',
  'InstitutionAccountHUD.swift',
  'LoanPaymentHUD.swift',
  'EditCardSheet.swift',
  'EditLoanSheet.swift',
  'LoanPaymentsLedgerView.swift'
]

files_to_add.each do |filename|
  file_path = "Zifr/Views/Financial/#{filename}"
  
  # Check if file exists in the file system
  unless File.exist?(file_path)
    puts "File not found: #{file_path}"
    next
  end

  # Check if file reference already exists in the group
  existing = group.files.find { |f| f.path == filename }
  if existing
    puts "File already in Xcode project: #{filename}"
    next
  end

  # Add file reference to the group
  file_ref = group.new_reference(filename)
  
  # Add the file to the target's source build phase
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename} to project."
end

project.save
puts "Saved Zifr.xcodeproj"
