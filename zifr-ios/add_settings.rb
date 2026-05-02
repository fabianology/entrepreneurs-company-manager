require 'xcodeproj'
project = Xcodeproj::Project.open('Zifr.xcodeproj')
target = project.targets.find { |t| t.name == 'Zifr' }
settings_group = project.main_group.find_subpath('Zifr/Views/Settings', true)

filename = 'AdminSettingsView.swift'
unless settings_group.files.find { |f| f.path == filename }
  file_ref = settings_group.new_reference(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename}"
  project.save
end
