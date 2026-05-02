require 'xcodeproj'
project = Xcodeproj::Project.open('Zifr.xcodeproj')
target = project.targets.find { |t| t.name == 'Zifr' }
views_group = project.main_group.find_subpath('Zifr/Views', false)
dash_group = views_group.children.find { |g| g.name == 'Dashboard' || g.path == 'Dashboard' }

filename = 'LiquidActionBar.swift'
unless dash_group.files.find { |f| f.path == filename }
  file_ref = dash_group.new_reference(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename}"
  project.save
end
