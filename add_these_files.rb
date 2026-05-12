require 'xcodeproj'
project_path = 'zifr-ios/Zifr.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Zifr' }

files_to_add = [
  { path: 'zifr-ios/Zifr/Services/AI/GeminiLiveModels.swift', group_path: 'Zifr/Services/AI', name: 'GeminiLiveModels.swift' },
  { path: 'zifr-ios/Zifr/Services/AI/GeminiLiveClient.swift', group_path: 'Zifr/Services/AI', name: 'GeminiLiveClient.swift' },
  { path: 'zifr-ios/Zifr/Services/AI/AudioCaptureManager.swift', group_path: 'Zifr/Services/AI', name: 'AudioCaptureManager.swift' },
  { path: 'zifr-ios/Zifr/Services/AI/AudioPlaybackManager.swift', group_path: 'Zifr/Services/AI', name: 'AudioPlaybackManager.swift' },
  { path: 'zifr-ios/Zifr/Views/Assistant/PulsingOrbView.swift', group_path: 'Zifr/Views/Assistant', name: 'PulsingOrbView.swift' },
  { path: 'zifr-ios/Zifr/Views/Assistant/AssistantOnboardingView.swift', group_path: 'Zifr/Views/Assistant', name: 'AssistantOnboardingView.swift' }
]

files_to_add.each do |f|
  group = project.main_group.find_subpath(f[:group_path], true)
  # Check if it already exists
  file_ref = group.files.find { |file| file.path == f[:name] } || group.new_file(f[:name])
  # Check if it's already in the build phase
  unless target.source_build_phase.files_references.include?(file_ref)
    target.source_build_phase.add_file_reference(file_ref)
  end
end

project.save
puts "Added files successfully"
