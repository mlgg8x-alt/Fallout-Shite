class_name Interactable
extends Node
## Makes its parent physics body usable by the player.
##
## Add as a child of any CollisionObject3D. The player's interaction ray finds
## it on whatever collider it hits and shows [member prompt] on the HUD.

signal interacted(interactor: Node)

@export var prompt := "Use"
@export var enabled := true


func interact(interactor: Node) -> void:
	if enabled:
		interacted.emit(interactor)


## Returns the first Interactable attached to [param node], or null.
static func find_on(node: Node) -> Interactable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Interactable:
			return child
	return null
