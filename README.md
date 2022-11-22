# kvm_scripts-remote_migrate_vm
Migrate a VM from a remote host to another remote host with minimal "middleman" work.

TODO:
- Test/Add ability to do more than 1 virtual hard drive/qcow2 file.
- Branch out beyond just qcow2 files.
- Switch to getops instead of all of that other inflexible garbage.
- Do additional checking before copying things around. Provide better feedback on what VMs already exist on both remote hosts.
