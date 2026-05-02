require 'xcodeproj'
project = Xcodeproj::Project.open('Zifr.xcodeproj')
target = project.targets.find { |t| t.name == 'Zifr' }

project.main_group.recursive_children.each do |node|
  if node.name == 'LiquidActionBar.swift' || node.path == 'LiquidActionBar.swift'
    target.source_build_phase.remove_file_reference(node)
    node.remove_from_project
  end
end
project.save
puts "Fixed LiquidActionBar."
