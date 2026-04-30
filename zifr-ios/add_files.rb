require 'xcodeproj'
project_path = "/Users/yager/Downloads/cifr---entrepreneur's-company-manager/zifr-ios/Zifr.xcodeproj"
project = Xcodeproj::Project.open(project_path)

group_company = project.main_group.find_subpath(File.join('Zifr', 'Views', 'Company'), true)
group_services = project.main_group.find_subpath(File.join('Zifr', 'Services'), true)

target = project.targets.first

def add_file_if_needed(project, group, target, path)
  unless group.files.any? { |f| f.path == File.basename(path) }
    file_ref = group.new_reference(path)
    target.add_file_references([file_ref])
    puts "Added #{File.basename(path)}"
  end
end

add_file_if_needed(project, group_services, target, 'TickerService.swift')
add_file_if_needed(project, group_company, target, 'HomeHeroView.swift')
add_file_if_needed(project, group_company, target, 'HomeBillingTimeline.swift')

project.save
