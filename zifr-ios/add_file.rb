require 'xcodeproj'

project_path = "Zifr.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('Zifr/Views/Auth', true)

file_path = "Zifr/Views/Auth/ResetPasswordSheet.swift"

unless group.files.any? { |f| f.path == file_path || f.real_path.to_s.end_with?(file_path) }
    file_reference = group.new_reference(file_path)
    target.source_build_phase.add_file_reference(file_reference)
    project.save
    puts "Added to pbxproj"
else
    puts "Already exists"
end
