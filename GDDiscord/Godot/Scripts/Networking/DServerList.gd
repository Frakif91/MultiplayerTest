class_name DServerList extends Resource

@export var server_list : Dictionary[String, DServer]

const server_storage_path := "user://GDDiscord/stored_server_list.dsrv"

## Get Server profile from RAM, if not found (or loaded), return null else return DServer
func get_server_profile(name : String) -> DServer:
	return server_list.get(name,null)

func add_server_profile(dserv : DServer):
	server_list[dserv.name] = dserv

func store_servers_profiles() -> void:
	var file = FileAccess.open(server_storage_path, FileAccess.ModeFlags.WRITE)
	if file:
		file.store_var(server_list)
	else:
		push_error("Failed to write file " + server_storage_path + " : " + error_string(FileAccess.get_open_error()))
	file.close()

func retrieve_servers_profiles(): #-> Dictionary[String, DServer]:
	if not FileAccess.file_exists(server_storage_path): return
	var file = FileAccess.open(server_storage_path, FileAccess.ModeFlags.READ)
	if file:
		var rv = file.get_var()
		server_list = rv
		file.close()
		return rv
	push_error("Failed to read file " + server_storage_path + " : " + error_string(FileAccess.get_open_error()))
	return {}
