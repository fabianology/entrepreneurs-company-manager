require 'xcodeproj'
project_path = 'zifr-ios/Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Zifr' }

bad_names = ['GeminiLiveModels.swift', 'GeminiLiveClient.swift', 'AudioCaptureManager.swift', 'AudioPlaybackManager.swift', 'PulsingOrbView.swift', 'AssistantOnboardingView.swift']

target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && bad_names.include?(build_file.file_ref.name || build_file.file_ref.path)
    build_file.remove_from_project
  end
end

project.files.each do |file|
  if bad_names.include?(file.name) || bad_names.include?(file.path)
    file.remove_from_project
  end
end

files_to_add = [
  { path: 'Zifr/Services/AI/GeminiLiveModels.swift', group_path: 'Zifr/Services/AI', name: 'GeminiLiveModels.swift' },
  { path: 'Zifr/Services/AI/GeminiLiveClient.swift', group_path: 'Zifr/Services/AI', name: 'GeminiLiveClient.swift' },
  { path: 'Zifr/Services/AI/AudioCaptureManager.swift', group_path: 'Zifr/Services/AI', name: 'AudioCaptureManager.swift' },
  { path: 'Zifr/Services/AI/AudioPlaybackManager.swift', group_path: 'Zifr/Services/AI', name: 'AudioPlaybackManager.swift' },
  { path: 'Zifr/Views/Assistant/PulsingOrbView.swift', group_path: 'Zifr/Views/Assistant', name: 'PulsingOrbView.swift' },
  { path: 'Zifr/Views/Assistant/AssistantOnboardingView.swift', group_path: 'Zifr/Views/Assistant', name: 'AssistantOnboardingView.swift' }
]

files_to_add.each do |f|
  group = project.main_group
  f[:group_path].split('/').each do |subgroup|
    next_group = group.children.find { |c| c.class == Xcodeproj::Project::Object::PBXGroup && (c.name == subgroup || c.path == subgroup) }
    if next_group.nil?
      next_group = group.new_group(subgroup, subgroup)
    end
    group = next_group
  end
  
  file_ref = group.new_file(f[:name])
  target.source_build_phase.add_file_reference(file_ref)
end

project.save
puts "Fixed xcodeproj"
