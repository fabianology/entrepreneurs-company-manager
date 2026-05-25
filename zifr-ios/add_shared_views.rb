require 'xcodeproj'
project_path = 'Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

dashboard_group = project.main_group.find_subpath('Zifr/Views/Dashboard', true)

# Add SharedItemCardView
card_view_path = 'SharedItemCardView.swift'
if !dashboard_group.files.any? { |f| f.path == card_view_path }
  card_ref = dashboard_group.new_file(card_view_path)
  target.source_build_phase.add_file_reference(card_ref)
  puts "Added SharedItemCardView.swift"
end

# Add SharedItemOverrideBanner
banner_path = 'SharedItemOverrideBanner.swift'
if !dashboard_group.files.any? { |f| f.path == banner_path }
  banner_ref = dashboard_group.new_file(banner_path)
  target.source_build_phase.add_file_reference(banner_ref)
  puts "Added SharedItemOverrideBanner.swift"
end

project.save
puts "Saved project."
