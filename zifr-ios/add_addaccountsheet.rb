require 'xcodeproj'
project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group_path = File.join('Zifr', 'Views', 'Financial')
group = project.main_group.find_subpath(group_path, true)

# check if already added
existing = group.files.find { |f| f.path == 'AddAccountSheet.swift' }
if existing.nil?
  file_ref = group.new_reference('AddAccountSheet.swift')
  target.add_file_references([file_ref])
  project.save
  puts "Added AddAccountSheet.swift"
else
  puts "Already exists"
end
