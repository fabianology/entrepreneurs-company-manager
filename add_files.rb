require 'xcodeproj'
project_path = 'zifr-ios/Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath(File.join('Zifr', 'Views', 'Company', 'EntityHome'), true)

Dir.glob("zifr-ios/Zifr/Views/Company/EntityHome/*.swift").each do |file|
  next if target.source_build_phase.files_references.any? { |ref| ref.path == file }
  file_ref = group.new_reference(file.split('/').last)
  target.add_file_references([file_ref])
end

project.save
