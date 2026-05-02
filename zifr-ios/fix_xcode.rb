require 'xcodeproj'
project = Xcodeproj::Project.open('Zifr.xcodeproj')
target = project.targets.find { |t| t.name == 'Zifr' }

# Find and remove the broken reference
project.main_group.recursive_children.each do |node|
  if node.name == 'AdminSettingsView.swift' || node.path == 'AdminSettingsView.swift'
    target.source_build_phase.remove_file_reference(node)
    node.remove_from_project
  end
end

# Now add it properly
views_group = project.main_group.find_subpath('Zifr/Views', false)
settings_group = views_group.children.find { |g| g.name == 'Settings' || g.path == 'Settings' }
unless settings_group
  settings_group = views_group.new_group('Settings', 'Settings')
end

file_ref = settings_group.new_reference('AdminSettingsView.swift')
target.source_build_phase.add_file_reference(file_ref)
project.save
puts "Fixed."
