/obj/structure/screen_shell
	name = "screen"

/obj/structure/screen_shell/tilemap
	var/width = 64
	var/height = 64
	//Mostly inspired by the PPU on the GameBoy
	var/list/tileset //64 8x8 tiles
	var/list/tilemap //2 sets of 8x8 grid of tiles, 64x64 grid of pixels
	var/list/palette //8 sets of 8 colors
	var/active_map = 1 //Which tilemap is currently active
	var/list/grid

	var/default_color = "#ffffff"

/obj/structure/screen_shell/tilemap/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/shell, list(
		new /obj/item/circuit_component/tilemap()
	), SHELL_CAPACITY_LARGE)
	tileset = new/list(64,8,8)
	tilemap = new/list(2,64)
	palette = new/list(8,8)
	grid = new/list(width,height)

//Explaination of a technique used here: (i-1&0x3f)+1 will modulo i by 64 with 0 becoming 64, 0x7 instead of 0x3f will turn zeros into 8

/obj/structure/screen_shell/tilemap/proc/generate_pixel_grid()
	var/list/current_map = tilemap[active_map]
	for(var/i in 0 to width-1)
		for(var/j in 0 to height-1)
			var/color = palette[1 /*hardcoded for testing*/][tileset[(current_map[((j & 0x38) | ((i & 0x38) >> 3)-1&0x3f)+1]-1&0x3f)+1][(i-1&0x7)+1][(j-1&0x7)+1]] //Sometimes I hate list indices starting 1 instead of 0
			grid[i+1][j+1] = istext(color) ? color : default_color


/obj/structure/screen_shell/tilemap/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Bitmap", name)
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/structure/screen_shell/tilemap/ui_data(mob/user)
	. = ..()
	.["grid"] = grid

/obj/structure/screen_shell/tilemap/proc/set_tile(list/new_data, target_index)
	for(var/i in 0 to min(width*height-1,length(new_data)-1))
		tileset[(target_index-1&0x3f)+1][(i-1&0x7)+1][((i>>3)-1&0x7)+1] = new_data[i+1]

/obj/structure/screen_shell/tilemap/proc/set_map(list/new_data, target_index)
	for(var/i in 1 to min(width*height,length(new_data)))
		tilemap[(target_index-1&0x1)+1][i] = new_data[i]

/obj/structure/screen_shell/tilemap/proc/set_palette(list/new_data, target_index)
	var/selected_palette = palette[(target_index-1&0x7)+1]
	for(var/i in 1 to min(8, length(new_data)))
		var/raw_color_num = new_data[i]
		selected_palette[i] = rgb((raw_color_num & 0xff0000) >> 16, (raw_color_num & 0xff00) >> 8, raw_color_num & 0xff)

/obj/item/circuit_component/tilemap
	display_name = "Tilemap"
	desc = "A graphics processing unit that shows an image via a grid of tile designed to be easily manipulated during runtime."

	var/obj/structure/screen_shell/tilemap/attached_screen

	var/datum/port/input/new_data //New data to override internal value
	var/datum/port/input/modify_index //Index of data to be modified

	var/datum/port/input/set_tile //Sets tile data using given data and index
	var/datum/port/input/set_map //Sets tilemap data using given data and index
	var/datum/port/input/set_palette //Sets palette data using given data and index

	var/datum/port/input/switch_map //Sets active tilemap to given index

	var/datum/port/input/update_screen //Renders changes to screen

/obj/item/circuit_component/tilemap/populate_ports()
	new_data = add_input_port("New Data", PORT_TYPE_LIST)
	modify_index = add_input_port("Modify Index", PORT_TYPE_NUMBER)
	set_tile = add_input_port("Set Tile", PORT_TYPE_SIGNAL)
	set_map = add_input_port("Set Tilemap", PORT_TYPE_SIGNAL)
	set_palette = add_input_port("Set Palette", PORT_TYPE_SIGNAL)
	update_screen = add_input_port("Update Screen", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/tilemap/register_shell(atom/movable/shell)
	. = ..()
	if(istype(shell, /obj/structure/screen_shell/tilemap))
		attached_screen = shell

/obj/item/circuit_component/tilemap/unregister_shell(atom/movable/shell)
	attached_screen = null
	return ..()

/obj/item/circuit_component/tilemap/input_received(datum/port/input/port)

	if(!attached_screen)
		return

	if(COMPONENT_TRIGGERED_BY(set_tile, port))
		attached_screen.set_tile(new_data, modify_index)
	if(COMPONENT_TRIGGERED_BY(set_map, port))
		attached_screen.set_map(new_data, modify_index)
	if(COMPONENT_TRIGGERED_BY(set_palette, port))
		attached_screen.set_palette(new_data, modify_index)
	if(COMPONENT_TRIGGERED_BY(update_screen, port))
		attached_screen.generate_pixel_grid()
