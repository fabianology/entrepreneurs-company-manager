require 'xcodeproj'
project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath(File.join('Zifr', 'Views', 'Company'), true)
file_ref = group.files.find { |f| f.path == 'CompanyMetaSheet.swift' }
if file_ref
  target.source_build_phase.remove_file_reference(file_ref)
  file_ref.remove_from_project
end
project.save
