/obj/structure/screen_shell
	name = "screen"

/obj/structure/screen_shell/tilemap
	var/width = 64
	var/height = 64
	//Mostly inspired by the PPU on the GameBoy
	var/list/tileset //64 8x8 tiles
	var/list/tilemap //2 sets of 8x8 grid of tiles, 64x64 grid of pixels
	var/list/tilemap_attributes //a list of bitfields corresponding to each tile in the tilemaps
	var/list/palette //8 sets of 8 colors
	var/active_map = 1 //Which tilemap is currently active
	var/list/grid

	var/default_color = "#ffffff"

/obj/structure/screen_shell/tilemap/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/shell, list(
		new /obj/item/circuit_component/tilemap,
		new /obj/item/circuit_component/tilemap/tileset(),
		new /obj/item/circuit_component/tilemap/tilemap(),
		new /obj/item/circuit_component/tilemap/tile_attributes(),
		new /obj/item/circuit_component/tilemap/palette(),
	), SHELL_CAPACITY_LARGE)
	tileset = new/list(64,8,8)
	tilemap = new/list(2,64)
	tilemap_attributes = new/list(2,64)
	palette = new/list(8,8)
	grid = new/list(width,height)

//Explanation of a technique used here: (i-1&0x3f)+1 will modulo i by 64 with 0 becoming 64, 0x7 instead of 0x3f will turn zeros into 8
//Because I need a range of different modulos, and the input isn't the leading character on the left, neither a constant nor a marco seems appropriate.

// To get our color for a pixel at (i,j), we first get the tile that (i,j) is in, then we find the pixel in that tile that corresponds to our point,
// and then use the number at that pixel to index that tile's palette to find the color we need.
/obj/structure/screen_shell/tilemap/proc/generate_pixel_grid()
	var/list/current_map = tilemap[active_map]
	var/list/current_attributes = tilemap_attributes[active_map]
	for(var/i in 0 to width-1)
		for(var/j in 0 to height-1)
			var/map_index = ((j & 0x38) | ((i & 0x38) >> 3)-1&0x7)+1
			var/tile_attributes = current_attributes[map_index]
			var/tile_x = tile_attributes & COMP_FLIP_X ? (i-1&0x7)+1 : 8-((i-1&0x7)+1) //Flip tile horizontally
			var/tile_y = tile_attributes & COMP_FLIP_Y ? (j-1&0x7)+1 : 8-((j-1&0x7)+1) //Flip tile vertically
			var/color = palette[(tile_attributes-1&0x7)+1][(tileset[(current_map[map_index]-1&0x3f)+1][tile_x][tile_y]-1&0x7)+1] //Sometimes I hate list indices starting 1 instead of 0
			grid[i+1][j+1] = istext(color) ? color : default_color //If it's a string it, should *probably* be a valid rgb code.


/obj/structure/screen_shell/tilemap/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Bitmap", name)
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/structure/screen_shell/tilemap/ui_data(mob/user)
	. = ..()
	.["grid"] = grid

/obj/structure/screen_shell/tilemap/ui_act(action, params)
	. = ..()
	switch(action) //I doubt I'll add more actions, but I'll make this a switch just in case
		if("clicked")
			SEND_SIGNAL(src, COMSIG_SCREEN_SHELL_CLICKED, text2num(params["x"]), text2num(params["y"]))

//Pixels are assigned left to right then top to bottom.
/obj/structure/screen_shell/tilemap/proc/set_tile(list/new_data, target_index)
	var/list/selected_tile = tileset[(target_index-1&0x3f)+1]
	for(var/i in 0 to min(width*height-1,length(new_data)-1))
		selected_tile[(i-1&0x7)+1][((i>>3)-1&0x7)+1] = isnum(new_data[i+1]) ? new_data[i+1] : 0

//Similar to tiles themselves, tiles are assigned left to right then top to bottom.
/obj/structure/screen_shell/tilemap/proc/set_map(list/new_data, target_index)
	var/list/selected_tilemap = tilemap[(target_index-1&0x1)+1]
	for(var/i in 1 to min(width*height,length(new_data)))
		selected_tilemap[i] = isnum(new_data[i]) ? new_data[i] : 0

/obj/structure/screen_shell/tilemap/proc/set_attributes(list/new_data, target_index)
	var/list/selected_attributes = tilemap_attributes[(target_index-1&0x1)+1]
	for(var/i in 1 to min(width*height,length(new_data)))
		selected_attributes[i] = isnum(new_data[i]) ? new_data[i] : 0

/obj/structure/screen_shell/tilemap/proc/set_palette(list/new_data, target_index)
	var/list/selected_palette = palette[(target_index-1&0x7)+1]
	for(var/i in 1 to min(8, length(new_data)))
		var/raw_color_num = isnum(new_data[i]) ? new_data[i] : 0
		selected_palette[i] = rgb((raw_color_num & 0xff0000) >> 16, (raw_color_num & 0xff00) >> 8, raw_color_num & 0xff)

//We split functionality into multiple components so that they can be compartmentalized to relevant locations in the circuit,
//as well as allowing each list to be written to in the same circuit tick.

/obj/item/circuit_component/tilemap
	display_name = "Tilemap"
	desc = "A graphics processing unit that shows an image via a grid of tile designed to be easily manipulated during runtime."

	var/obj/structure/screen_shell/tilemap/attached_screen

	//Screen controls

	var/datum/port/input/update_screen //Renders changes to screen

	//Clicks

	var/datum/port/output/click_x //X coordinate of the last click
	var/datum/port/output/click_y //Y coordinate of the last click
	var/datum/port/output/clicked //The screen has been clicked

/obj/item/circuit_component/tilemap/populate_ports()
	update_screen = add_input_port("Update Screen", PORT_TYPE_SIGNAL)

	click_x = add_output_port("Mouse X", PORT_TYPE_NUMBER)
	click_y = add_output_port("Mouse Y", PORT_TYPE_NUMBER)
	clicked = add_output_port("Clicked", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/tilemap/register_shell(atom/movable/shell)
	. = ..()
	if(istype(shell, /obj/structure/screen_shell/tilemap))
		attached_screen = shell
		RegisterSignal(attached_screen, COMSIG_SCREEN_SHELL_CLICKED, PROC_REF(on_clicked))

/obj/item/circuit_component/tilemap/unregister_shell(atom/movable/shell)
	UnregisterSignal(attached_screen, COMSIG_SCREEN_SHELL_CLICKED)
	attached_screen = null
	return ..()

/obj/item/circuit_component/tilemap/input_received(datum/port/input/port)

	if(!attached_screen)
		return

	if(COMPONENT_TRIGGERED_BY(update_screen, port))
		attached_screen.generate_pixel_grid()

/obj/item/circuit_component/tilemap/proc/on_clicked(_, x, y)
	click_x.set_output(x)
	click_y.set_output(y)
	clicked.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/tilemap/tileset
	var/datum/port/input/new_tile_data
	var/datum/port/input/index

	var/datum/port/output/retrieved_tile

	var/datum/port/input/set_tile
	var/datum/port/input/get_tile
	var/datum/port/output/tile_set
	var/datum/port/output/tile_retrieved

/obj/item/circuit_component/tilemap/tileset/populate_ports()
	new_tile_data = add_input_port("New Tile", PORT_TYPE_LIST)
	index = add_input_port("Index", PORT_TYPE_NUMBER)

	retrieved_tile = add_output_port("Retrieved Tile", PORT_TYPE_LIST)

	set_tile = add_input_port("Set Tile", PORT_TYPE_SIGNAL)
	get_tile = add_input_port("Get Tile", PORT_TYPE_SIGNAL)
	tile_set = add_output_port("Tile Set", PORT_TYPE_SIGNAL)
	tile_retrieved = add_output_port("Tile Retrieved", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/tilemap/tileset/input_received(datum/port/input/port)

	if(!attached_screen)
		return

	if(COMPONENT_TRIGGERED_BY(set_tile, port))
		attached_screen.set_tile(new_tile_data.value, index.value)
		tile_set.set_output(COMPONENT_SIGNAL)
	if(COMPONENT_TRIGGERED_BY(get_tile, port))
		var/list/constructed_tile = new(64)
		for(var/i in 1 to 64)
			constructed_tile[i] = attached_screen.tileset[index.value][(i-1&0x7)+1][((i>>3)-1&0x7)+1]
		retrieved_tile.set_output(constructed_tile)
		tile_retrieved.set_output(COMPONENT_SIGNAL)

//Control the tilemap, set ids for each tile.
//2 8x8 Tilemaps, indexed left to right then top to bottom

/obj/item/circuit_component/tilemap/tilemap
	var/datum/port/input/new_tilemap
	var/datum/port/input/index

	var/datum/port/output/retrieved_tilemap

	var/datum/port/input/set_tilemap
	var/datum/port/input/get_tilemap
	var/datum/port/output/tilemap_set
	var/datum/port/output/tilemap_retrieved

/obj/item/circuit_component/tilemap/tilemap/populate_ports()
	new_tilemap = add_input_port("New Tilemap", PORT_TYPE_LIST)
	index = add_input_port("Index", PORT_TYPE_NUMBER)

	retrieved_tilemap = add_output_port("Retrieved Tilemap", PORT_TYPE_LIST)

	set_tilemap = add_input_port("Set Tilemap", PORT_TYPE_SIGNAL)
	get_tilemap = add_input_port("Get Tilemap", PORT_TYPE_SIGNAL)
	tilemap_set = add_output_port("Tilemap Set", PORT_TYPE_SIGNAL)
	tilemap_retrieved = add_output_port("Tilemap Retrieved", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/tilemap/tilemap/input_received(datum/port/input/port)

	if(!attached_screen)
		return

	if(COMPONENT_TRIGGERED_BY(set_tilemap, port))
		attached_screen.set_map(new_tilemap.value, index.value)
		tilemap_set.set_output(COMPONENT_SIGNAL)
	if(COMPONENT_TRIGGERED_BY(get_tilemap, port))
		var/list/selected_tilemap = attached_screen.tilemap[(index.value-1&0x1)+1]
		retrieved_tilemap.set_output(selected_tilemap.Copy())
		tilemap_retrieved.set_output(COMPONENT_SIGNAL)

//Sets the attributes for each tile in the tilemaps
//Attributes are bitfields as followed
// |    4    |    3    | 2  1  0 | bit
// | Flip-Y  | Flip-X  | Palette | property

/obj/item/circuit_component/tilemap/tile_attributes
	var/datum/port/input/new_tilemap_attributes
	var/datum/port/input/index

	var/datum/port/output/retrieved_tilemap_attributes

	var/datum/port/input/set_attributes
	var/datum/port/input/get_attributes
	var/datum/port/output/attributes_set
	var/datum/port/output/attributes_retrieved

/obj/item/circuit_component/tilemap/tile_attributes/populate_ports()
	new_tilemap_attributes = add_input_port("New Attributes", PORT_TYPE_LIST)
	index = add_input_port("Index", PORT_TYPE_NUMBER)

	retrieved_tilemap_attributes = add_output_port("Retrieved Attributes", PORT_TYPE_LIST)

	set_attributes = add_input_port("Set Attributes", PORT_TYPE_SIGNAL)
	get_attributes = add_input_port("Get Attributes", PORT_TYPE_SIGNAL)
	attributes_set = add_output_port("Attributes Set", PORT_TYPE_SIGNAL)
	attributes_retrieved = add_output_port("Attributes Retrieved", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/tilemap/tile_attributes/input_received(datum/port/input/port)

	if(!attached_screen)
		return

	if(COMPONENT_TRIGGERED_BY(set_attributes, port))
		attached_screen.set_attributes(new_tilemap_attributes.value, index.value)
		attributes_set.set_output(COMPONENT_SIGNAL)
		return
	if(COMPONENT_TRIGGERED_BY(get_attributes, port))
		var/list/selected_attributes = attached_screen.tilemap_attributes[(index.value-1&0x1)+1]
		retrieved_tilemap_attributes.set_output(selected_attributes.Copy())
		attributes_retrieved.set_output(COMPONENT_SIGNAL)


/obj/item/circuit_component/tilemap/palette
	var/datum/port/input/new_palette
	var/datum/port/input/index

	var/datum/port/output/retrieved_palette

	var/datum/port/input/set_palette
	var/datum/port/input/get_palette
	var/datum/port/output/palette_set
	var/datum/port/output/palette_recieved

/obj/item/circuit_component/tilemap/palette/populate_ports()
	new_palette = add_input_port("New Palette", PORT_TYPE_LIST)
	index = add_input_port("Index", PORT_TYPE_LIST)

	retrieved_palette = add_output_port("Retrieved Palette", PORT_TYPE_LIST)

	set_palette = add_input_port("Set Palette", PORT_TYPE_SIGNAL)
	get_palette = add_input_port("Get Palette", PORT_TYPE_SIGNAL)
	palette_set = add_output_port("Palette Set", PORT_TYPE_SIGNAL)
	palette_recieved = add_output_port("Palette Recieved", PORT_TYPE_SIGNAL)



/obj/item/circuit_component/tilemap/palette/input_received(datum/port/input/port)
	if(!attached_screen)
		return

	if(COMPONENT_TRIGGERED_BY(set_palette, port))
		attached_screen.set_palette(new_palette.value, index.value)
		palette_set.set_output(COMPONENT_SIGNAL)
		return
	if(COMPONENT_TRIGGERED_BY(get_palette, port))
		var/list/selected_palette = attached_screen.palette[(index.value-1&0x7)+1]
		retrieved_palette.set_output(selected_palette.Copy())
		palette_recieved.set_output(COMPONENT_SIGNAL)
		return

