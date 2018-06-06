#
# Description: Assign the Owner tag "Unknown" to new projects
#
# This is called when a pod is started, because there's no event for new projects.
#

module ManageIQ
  module Automate
    module Container
      module Openshift
        module Operations
          module Methods
            class TagPodProject
              def initialize(handle = $evm)
                @handle = handle
              end

              def main
                event = @handle.root['event_stream']
                
                ems = @handle.vmdb(:ext_management_system, event.ems_id)
                
                projects = @handle.vmdb(:container_project).where({
                  ems_id: event.ems_id, 
                  name: event.container_namespace, 
                  deleted_on: nil})
                
                if projects.length != 1
                  @handle.log("warn", "Expected to find one project \"#{event.container_namespace}\" in EMS #{ems.name} but got #{projects.length}")
                else
                  project = projects.first
                  
                  if project.tags(:owner).length > 0
                    @handle.log("info", "Project \"#{project.name}\" already has an owner tag, skipping")
                  else
                    tag = "owner/unknown_#{ems.name.downcase}"
                    @handle.log("info", "Assigning tag \"#{tag}\" to project \"#{project.name}\"")
                    project.tag_assign(tag)
                  end
                end  
              end
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Container::Openshift::Operations::Methods::TagPodProject.new.main
end
