require 'xcodeproj'
project_path = 'zifr-ios/Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove bad file references from the target and project
['EntityDocumentSection.swift', 'FinancialReceiptView.swift', 'EntitySubscriptionSection.swift', 'EntityHomeViewModel.swift', 'EntityFinancialSection.swift'].each do |filename|
  # remove from target
  target.source_build_phase.files.dup.each do |build_file|
    if build_file.file_ref && build_file.file_ref.name == filename
      build_file.remove_from_project
    end
  end
  # remove from groups
  project.main_group.recursive_children.each do |node|
    if node.is_a?(Xcodeproj::Project::Object::PBXFileReference) && (node.name == filename || node.path == filename)
      node.remove_from_project
    end
  end
end

group = project.main_group.find_subpath(File.join('Zifr', 'Views', 'Company', 'EntityHome'), true)
group.set_source_tree('<group>')
group.set_path('EntityHome') # Explicitly set the path to 'EntityHome'

Dir.glob("zifr-ios/Zifr/Views/Company/EntityHome/*.swift").each do |file|
  filename = file.split('/').last
  file_ref = group.new_reference(filename)
  target.add_file_references([file_ref])
end

project.save
