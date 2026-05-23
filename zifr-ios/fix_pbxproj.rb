require 'xcodeproj'

project_path = "Zifr.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('Zifr/Views/Auth', true)

# Remove the broken reference
broken_ref = group.files.find { |f| f.path == "Zifr/Views/Auth/ResetPasswordSheet.swift" }
if broken_ref
    target.source_build_phase.remove_file_reference(broken_ref)
    broken_ref.remove_from_project
end

# Add the correct reference
unless group.files.any? { |f| f.path == "ResetPasswordSheet.swift" }
    file_reference = group.new_reference("ResetPasswordSheet.swift")
    target.source_build_phase.add_file_reference(file_reference)
end

project.save
puts "Fixed pbxproj"
