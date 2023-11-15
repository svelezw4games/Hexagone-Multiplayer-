###############################################################################
##
## User Local Profile Data
##
## We use this resource to save the user's profile locally.
##
## In other strategies, we might allow players to login with their email or
## using a different strategy. In this instance, we 
##
## This is a local mirror of the profile stored on the database.
class_name ProfileData
extends Resource

## The name deetermines where the profile gets saved
## it is always `default`, but could be made to use different profile names
## if necessary.
## This could be useful if you want multiple users sharing profiles on the same
## machine (like in Smash Brothers) or to simulate multiple users locally.
static var PROFILE_NAME = "default"


## Custom player name. This is presentational only
@export var player_name := "":
	set(value):
		player_name = value
		save()
		emit_changed()


## Used as a unique identifier for logins
## Instead of this, we could require emails and put people through a sign-up
## process. For most games though, you want to reduce friction as much as
## possible.
@export var login_uuid := "":
	set(value):
		login_uuid = value
		save()
		emit_changed()


## Used as a unique password for logins
## For an environment where logins are important, we may either request that
## the user remembers the password, or store this in a secure way, for example
## using the user's keychain 
@export var login_key := "":
	set(value):
		login_key = value
		save()
		emit_changed()


## Saves the current resource to disk
func save() -> void:
	ResourceSaver.save(self, ProfileData.get_profile_path())


## Changes the uuid and key, but keeps the player's name
func reset() -> void:
	ProfileData.generate_profile_data(self)


func _to_string() -> String:
	return "[Profile %s: %s]"%[player_name, login_uuid]


## Returns the file path for this profile
static func get_profile_path() -> String:
	return "res://%s.tres"%[PROFILE_NAME]


## Loads the resource. Godot caches calls, so this can be used every time needed.
## This function will create a new profile file if one wasn't found
static func restore() -> ProfileData:
	if not FileAccess.file_exists(ProfileData.get_profile_path()):
		var new_data := ProfileData.new()
		generate_profile_data(new_data)
		return new_data
	var data := ResourceLoader.load(ProfileData.get_profile_path())
	return data


## Fills the profile with initial data
static func generate_profile_data(new_data: ProfileData) -> void:
	new_data.login_uuid = ProfileData.get_uuid()
	new_data.login_key = ProfileData.get_uuid()
	new_data.player_name = "Player" if new_data.player_name == "" else new_data.player_name
	new_data.save()


################################## UUID ########################################


## Dispenses UUIDs
static var _uuid_generator := UUIDGenerator.new():
	set(_value):
		push_error("GameState._uuid_generator is a read-only property")
		assert(false, "_uuid_generator is a read only property")
	get:
		return _uuid_generator


## Generates a String relatively guaranteed to be unique
##
static func get_uuid() -> String:
	return _uuid_generator.generate_v4()


## Internal class used internally to generate v4 UUIDs.
## 
## Taken from res://addons/w4gd/w4utils.gd
## Because W4Utils is not available at the beginning of the tutorial.
## This class can be replaced, and the line
## ```gdscript
## static var _uuid_generator := UUIDGenerator.new():
## ```
## Can be replaced with:
## ```gdscript
## static var _uuid_generator := W4Utils.UUIDGenerator.new():
## ```
class UUIDGenerator extends RefCounted:
	var crypto := Crypto.new()
	var rng := RandomNumberGenerator.new()

	func generate_v4() -> String:
		var b := PackedByteArray()
		if crypto == null:
			b.resize(16)
			for i in range(16):
				b[i] = rng.randi() % 256
		else:
			b = crypto.generate_random_bytes(16)
		b[6] = (b[6] & 0x0f) | 0x40
		b[8] = (b[8] & 0x3f) | 0x80
		return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
			b[0], b[1], b[2], b[3],
			b[4], b[5],
			b[6], b[7],
			b[8], b[9],
			b[10], b[11], b[12], b[13], b[14], b[15],
		]
