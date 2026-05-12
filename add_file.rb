require 'xcodeproj'
project_path = 'zifr-ios/Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)

file_path = 'zifr-ios/Zifr/Views/Subscriptions/PremiumSubscriptionCard.swift'
group = project.main_group.find_subpath('Zifr/Views/Subscriptions', true)
file_ref = group.new_file('PremiumSubscriptionCard.swift')

target = project.targets.find { |t| t.name == 'Zifr' }
target.source_build_phase.add_file_reference(file_ref)

project.save
puts "Added file to project"
