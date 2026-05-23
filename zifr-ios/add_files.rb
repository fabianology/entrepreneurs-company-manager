require 'xcodeproj'

project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('Zifr/Views', true)

file_path_1 = 'Zifr/Views/EditProfileView.swift'
if !group.files.any? { |f| f.path == File.basename(file_path_1) }
  file_ref_1 = group.new_reference(File.basename(file_path_1))
  target.add_file_references([file_ref_1])
end

file_path_2 = 'Zifr/Views/PremiumUpgradeView.swift'
if !group.files.any? { |f| f.path == File.basename(file_path_2) }
  file_ref_2 = group.new_reference(File.basename(file_path_2))
  target.add_file_references([file_ref_2])
end

project.save
