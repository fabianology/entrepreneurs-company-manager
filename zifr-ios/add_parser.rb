require 'xcodeproj'
project_path = "/Users/yager/Downloads/cifr---entrepreneur's-company-manager/zifr-ios/Zifr.xcodeproj"
project = Xcodeproj::Project.open(project_path)
group = project.main_group.find_subpath(File.join('Zifr', 'Views', 'Company'), true)
target = project.targets.first
unless group.files.any? { |f| f.path == 'HomeRenewalParser.swift' }
  file_ref = group.new_reference('HomeRenewalParser.swift')
  target.add_file_references([file_ref])
end
project.save
