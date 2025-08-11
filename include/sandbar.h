#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <fcft/fcft.h>
#include <fcntl.h>
#include <linux/input-event-codes.h>
#include <pixman.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <wayland-client.h>
#include <wayland-cursor.h>
#include <wayland-util.h>

#ifdef __unix__
#include <unistd.h>
#endif

#include "../utf8.h"
#include "xdg-shell-protocol.h"
#include "wlr-layer-shell-unstable-v1-protocol.h"
#include "river-status-unstable-v1-protocol.h"
#include "river-control-unstable-v1-protocol.h"
# pragma once

typedef struct {
	struct wl_output *wl_output;
	struct wl_surface *wl_surface;
	struct zwlr_layer_surface_v1 *layer_surface;
	struct zriver_output_status_v1 *river_output_status;
	
	uint32_t registry_name;
	char *output_name;
  
	bool configured;
	uint32_t width, height;
	uint32_t textpadding;
	uint32_t stride, bufsize;
	
	uint32_t mtags, ctags, urg;
	bool sel;
	char *layout, *title, *status;
	
	bool hidden, bottom;
	bool redraw;
  
	struct wl_list link;
} Bar;

typedef struct {
	struct wl_seat *wl_seat;
	struct wl_pointer *wl_pointer;
	struct zriver_seat_status_v1 *river_seat_status;
	uint32_t registry_name;
  
	Bar *bar;
	bool hovering;
	uint32_t pointer_x, pointer_y;
	uint32_t pointer_button;
  
	char *mode;
	
	struct wl_list link;
} Seat;


extern
const pixman_color_t active_fg_color;

extern
const pixman_color_t active_bg_color;

extern
const pixman_color_t inactive_fg_color;

extern
const pixman_color_t inactive_bg_color;

extern
const pixman_color_t urgent_fg_color;

extern
const pixman_color_t urgent_bg_color;

extern
const pixman_color_t title_fg_color;

extern
const pixman_color_t title_bg_color;



extern
uint32_t height;

extern
uint32_t textpadding;

extern
uint32_t vertical_padding;

extern
uint32_t buffer_scale;

extern
const struct wl_buffer_listener wl_buffer_listener;

extern
int parse_color(const char *str, pixman_color_t *clr);

extern
struct zriver_control_v1 *river_control;

extern
char **tags;

extern
uint32_t tags_l;

extern
bool hidden;

extern
bool bottom;

extern
bool hide_vacant;

extern
bool no_title;

extern
bool no_status_commands;

extern
bool no_mode;

extern
bool no_layout;

extern
bool hide_normal_mode;

extern
struct wl_compositor *compositor;

extern
struct wl_shm *shm;

extern
struct wl_cursor_image *cursor_image;

extern
struct wl_surface *cursor_surface;

extern
struct wl_list bar_list;

extern
struct wl_list seat_list;

extern
struct fcft_font *font;

extern
uint32_t draw_text(
  char *text,
  uint32_t x,
  uint32_t y,
  pixman_image_t *foreground,
  pixman_image_t *background,
  pixman_color_t *fg_color,
  pixman_color_t *bg_color,
  uint32_t max_x,
  uint32_t buf_height,
  uint32_t padding,
  bool commands
);

extern
const struct wl_pointer_listener pointer_listener;

extern
const struct wl_output_listener output_listener;

extern
bool run_display;

extern
int draw_frame(Bar *bar);

extern
int allocate_shm_file(size_t size);

extern
const struct zwlr_layer_surface_v1_listener layer_surface_listener;

extern
const struct wl_seat_listener seat_listener;

extern
const struct zriver_output_status_v1_listener river_output_status_listener;

extern
int c_main(int argc, char **argv);

