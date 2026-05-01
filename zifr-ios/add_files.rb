require 'xcodeproj'

project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

files_to_add = [
  'Zifr/Services/SupabaseService.swift'
]

files_to_add.each do |file_path|
  file_ref = project.main_group.find_file_by_path(file_path) || project.main_group.new_reference(file_path)
  
  unless target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
    puts "Added #{file_path}"
  else
    puts "Already added #{file_path}"
  end
end

project.save
puts "Saved project."
