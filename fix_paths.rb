require 'xcodeproj'
project_path = 'zifr-ios/Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)

ai_group = project.main_group.find_subpath('Zifr/Services/AI', false)
if ai_group
  ai_group.set_path('AI')
end

as_group = project.main_group.find_subpath('Zifr/Views/Assistant', false)
if as_group
  as_group.set_path('Assistant')
end

project.save
puts "Fixed group paths"
