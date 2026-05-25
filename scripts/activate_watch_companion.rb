#!/usr/bin/env ruby
require 'xcodeproj'
require 'pathname'

ROOT = Pathname.new(__dir__).join('..').expand_path
PROJECT_PATH = ROOT.join('Agedcare-shared.xcodeproj')
APP_TARGET_NAME = 'Agedcare-shared'
WATCH_APP_TARGET_NAME = 'AgedcareWatchApp'
WATCH_EXTENSION_TARGET_NAME = 'AgedcareWatchExtension'

project = Xcodeproj::Project.open(PROJECT_PATH.to_s)
main_target = project.targets.find { |target| target.name == APP_TARGET_NAME }
abort("Missing #{APP_TARGET_NAME} target") unless main_target

def ensure_group(parent, name, path)
  parent.children.find { |child| child.respond_to?(:path) && child.path == path } || parent.new_group(name, path)
end

def ensure_file(group, path)
  filename = File.basename(path)
  existing = group.files.find { |file| file.path == filename || file.path == path }
  existing.path = filename if existing && existing.path != filename
  return existing if existing
  group.new_file(filename)
end

def ensure_dependency(target, dependency_target)
  return if target.dependencies.any? { |dependency| dependency.target == dependency_target }
  target.add_dependency(dependency_target)
end

def ensure_build_file(phase, file_ref)
  return if phase.files_references.include?(file_ref)
  phase.add_file_reference(file_ref)
end

watch_app_target = project.targets.find { |target| target.name == WATCH_APP_TARGET_NAME } ||
  project.new_target(:watch2_app, WATCH_APP_TARGET_NAME, :watchos, '11.0')

watch_extension_target = project.targets.find { |target| target.name == WATCH_EXTENSION_TARGET_NAME } ||
  project.new_target(:watch2_extension, WATCH_EXTENSION_TARGET_NAME, :watchos, '11.0')

main_group = project.main_group
watch_app_group = ensure_group(main_group, 'AgedcareWatch', 'AgedcareWatch')
watch_extension_group = ensure_group(main_group, 'AgedcareWatchExtension', 'AgedcareWatchExtension')

watch_extension_sources = %w[
  AgedcareWatchExtension/AgedcareWatchApp.swift
  AgedcareWatchExtension/WatchSessionManager.swift
  AgedcareWatchExtension/WatchDashboardView.swift
]

watch_extension_target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  if file_ref.path&.start_with?('AgedcareWatchExtension/')
    build_file.remove_from_project
    file_ref.remove_from_project
  end
end

watch_extension_sources.each do |source_path|
  file_ref = ensure_file(watch_extension_group, source_path)
  ensure_build_file(watch_extension_target.source_build_phase, file_ref)
end

watch_app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'wcs.Agedcare-shared.watchkitapp'
  config.build_settings['INFOPLIST_FILE'] = 'AgedcareWatch/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '11.0'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '5'
  config.build_settings['MARKETING_VERSION'] = '1.0.3'
  config.build_settings['DEVELOPMENT_TEAM'] = 'TM2WG7HH96'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

watch_extension_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'wcs.Agedcare-shared.watchkitapp.watchkitextension'
  config.build_settings['INFOPLIST_FILE'] = 'AgedcareWatchExtension/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '11.0'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '5'
  config.build_settings['MARKETING_VERSION'] = '1.0.3'
  config.build_settings['DEVELOPMENT_TEAM'] = 'TM2WG7HH96'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'AgedcareWatchExtension/AgedcareWatchExtension.entitlements'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

ensure_dependency(watch_app_target, watch_extension_target)

main_target.dependencies.select { |dependency| dependency.target == watch_app_target }.each(&:remove_from_project)
main_target.copy_files_build_phases.select { |phase| phase.name == 'Embed Watch Content' }.each do |phase|
  phase.files.select { |file| file.file_ref == watch_app_target.product_reference }.each(&:remove_from_project)
  phase.remove_from_project if phase.files.empty?
end

embed_watch_extension = watch_app_target.copy_files_build_phases.find { |phase| phase.name == 'Embed Watch Extension' } ||
  watch_app_target.new_copy_files_build_phase('Embed Watch Extension')
embed_watch_extension.dst_subfolder_spec = '13'
ensure_build_file(embed_watch_extension, watch_extension_target.product_reference)

project.save
puts "Activated #{WATCH_APP_TARGET_NAME} and #{WATCH_EXTENSION_TARGET_NAME} in #{PROJECT_PATH.basename}"
