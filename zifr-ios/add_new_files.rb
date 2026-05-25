require 'xcodeproj'

project_path = "Zifr.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

files_to_add = [
    { path: "Zifr/Models/ActivityLog.swift", group: "Zifr/Models" },
    { path: "Zifr/Views/ActivityLogsView.swift", group: "Zifr/Views" }
]

files_to_add.each do |file_info|
    group = project.main_group.find_subpath(file_info[:group], true)
    file_path = file_info[:path]
    
    unless group.files.any? { |f| f.path == file_path || f.real_path.to_s.end_with?(file_path) }
        file_reference = group.new_reference(file_path)
        target.source_build_phase.add_file_reference(file_reference)
        puts "Added #{file_path} to pbxproj"
    else
        puts "#{file_path} Already exists"
    end
end

project.save
