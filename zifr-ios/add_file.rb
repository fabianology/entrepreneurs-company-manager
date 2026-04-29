require 'xcodeproj'
project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath(File.join('Zifr', 'Views', 'Company'), true)
file_ref = group.new_reference('CompanyMetaSheet.swift')
target.add_file_references([file_ref])
project.save
