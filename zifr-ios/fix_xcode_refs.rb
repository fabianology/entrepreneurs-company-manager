require 'xcodeproj'
project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove the bad ones
bad_refs = []
project.files.each do |f|
    if f.path.include?("Zifr/Models/Zifr/Models") || f.path.include?("Zifr/Views/Zifr/Views") || f.path == "Zifr/Models/ActivityLog.swift" || f.path == "Zifr/Views/ActivityLogsView.swift"
        bad_refs << f
    end
end

bad_refs.each do |f|
    target.source_build_phase.remove_file_reference(f)
    f.remove_from_project
end

# Add them correctly
models_group = project.main_group.find_subpath('Zifr/Models', true)
models_ref = models_group.new_file('ActivityLog.swift')
target.source_build_phase.add_file_reference(models_ref)

views_group = project.main_group.find_subpath('Zifr/Views', true)
views_ref = views_group.new_file('ActivityLogsView.swift')
target.source_build_phase.add_file_reference(views_ref)

project.save
puts "Fixed Xcode project references."
