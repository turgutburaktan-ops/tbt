require 'xcodeproj'
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |target| target.name == 'Runner' }
abort('Runner target missing') unless runner
share = project.targets.find { |target| target.name == 'TBTShare' } || project.new_target(:app_extension, 'TBTShare', :ios, '15.0')
group = project.main_group.find_subpath('TBTShare', true)
group.set_source_tree('<group>')
group.set_path('TBTShare')
file = group.files.find { |item| item.path == 'ShareViewController.swift' } || group.new_file('ShareViewController.swift')
share.source_build_phase.add_file_reference(file) unless share.source_build_phase.files_references.include?(file)
runner_group = project.main_group.find_subpath('Runner', false)
scene = runner_group.files.find { |item| item.path == 'ShareSceneDelegate.swift' } || runner_group.new_file('ShareSceneDelegate.swift')
runner.source_build_phase.add_file_reference(scene) unless runner.source_build_phase.files_references.include?(scene)
runner.build_configurations.each { |config| config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements' }
share.build_configurations.each do |config|
  host = runner.build_configurations.find { |item| item.name == config.name }
  config.base_configuration_reference = host.base_configuration_reference
  config.build_settings.merge!({'PRODUCT_NAME' => 'TBTShare', 'PRODUCT_MODULE_NAME' => 'TBTShare', 'PRODUCT_BUNDLE_IDENTIFIER' => 'com.tbt.social.TBTShare', 'INFOPLIST_FILE' => 'TBTShare/Info.plist', 'CODE_SIGN_ENTITLEMENTS' => 'TBTShare/TBTShare.entitlements', 'SWIFT_VERSION' => '5.0', 'IPHONEOS_DEPLOYMENT_TARGET' => '15.0', 'SKIP_INSTALL' => 'YES', 'APPLICATION_EXTENSION_API_ONLY' => 'YES', 'ENABLE_BITCODE' => 'NO', 'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'})
end
runner.add_dependency(share) unless runner.dependencies.any? { |dependency| dependency.target == share }
phase = runner.copy_files_build_phases.find { |item| item.name == 'Embed Share Extension' } || runner.new_copy_files_build_phase('Embed Share Extension')
phase.dst_subfolder_spec = '13'
ref = phase.files.find { |item| item.file_ref == share.product_reference } || phase.add_file_reference(share.product_reference)
ref.settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
runner.build_phases.delete(phase)
index = runner.build_phases.index { |item| item.respond_to?(:name) && item.name == 'Thin Binary' } || runner.build_phases.length
runner.build_phases.insert(index, phase)
project.save
