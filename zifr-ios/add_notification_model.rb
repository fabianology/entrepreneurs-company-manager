require 'xcodeproj'
project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

models_group = project.main_group.find_subpath('Zifr/Models', true)

# Add AppNotification.swift
notification_path = 'AppNotification.swift'
if !models_group.files.any? { |f| f.path == notification_path }
  notification_ref = models_group.new_file(notification_path)
  target.source_build_phase.add_file_reference(notification_ref)
  puts "Added AppNotification.swift"
end

project.save
puts "Saved project."
