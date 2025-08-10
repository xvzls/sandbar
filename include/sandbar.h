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
bool run_display;

extern
int draw_frame(Bar *bar);

extern
int allocate_shm_file(size_t size);

extern
void layer_surface_closed(
  void *data,
  struct zwlr_layer_surface_v1 *surface
);

/* Layer-surface setup adapted from layer-shell example in [wlroots] */
extern
void layer_surface_configure(
  void *data,
  struct zwlr_layer_surface_v1 *surface,
	uint32_t serial,
	uint32_t w,
	uint32_t h
);

extern
const struct zwlr_layer_surface_v1_listener layer_surface_listener;

extern
int c_main(int argc, char **argv);

